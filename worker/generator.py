"""Resumable Bible interpretation generator for Ollama.

Safety: this script never generates anything unless --run is supplied. A dry-run
plan is printed by default. It also asks for confirmation on an interactive
terminal unless --yes is given, and it stops itself when the time budget is up.

Examples
--------
    python generator.py --status
    python generator.py --dry-run --perspectives core --hours 10
    python generator.py --run --perspectives core --hours 10 --yes
    python generator.py --run --books jhn,psa,rom --perspectives core --yes
    python generator.py --run --perspectives catholic,protestant,orthodox,historical_critical --resume

The script writes directly to the same database the API server reads, so results
appear in the app immediately. Re-running it skips chapters/perspectives that
already exist (unless --force is used).
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / "deploy" / ".env")
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "backend"))
from canon import BOOKS, CATHOLIC, PROTESTANT  # noqa: E402

from ai import (  # noqa: E402
    CORE,
    PERSPECTIVE_BY_ID,
    PERSPECTIVES,
    generate_notes,
    list_models,
    resolve_model,
)
from store import make_store  # noqa: E402
from translations import ensure_bundle  # noqa: E402
from research import search_context  # noqa: E402

POPULAR = [
    "jhn", "psa", "rom", "mat", "gen", "pro", "isa", "luk", "act", "eph",
    "php", "heb", "jas", "1jn", "rev", "mrk", "1co", "2co", "gal", "col",
    "1pe", "2pe", "1th", "2th", "1ti", "2ti", "tit", "phm", "jud", "jos",
]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def parse_perspectives(value: str) -> list[str]:
    if value.strip().lower() in ("core", "default"):
        return list(CORE)
    if value.strip().lower() in ("all", "everything"):
        return [p["id"] for p in PERSPECTIVES]
    ids = [part.strip() for part in value.split(",") if part.strip()]
    unknown = [pid for pid in ids if pid not in PERSPECTIVE_BY_ID]
    if unknown:
        raise SystemExit(
            f"Unknown perspective(s): {', '.join(unknown)}\n"
            f"Available: {', '.join(p['id'] for p in PERSPECTIVES)}"
        )
    return ids


def canonical_books(kind: str) -> list[tuple[str, int]]:
    if kind == "protestant":
        source = PROTESTANT
    elif kind == "catholic":
        source = CATHOLIC
    else:
        raise SystemExit(f"Unknown canon: {kind}")
    # CATHOLIC currently lists deuterocanonical books after the NT in BOOKS;
    # move them before the NT for a natural reading order.
    ordered = [b for b in source if b[3] in ("OT", "DC")] + [b for b in source if b[3] == "NT"]
    return [(b[0], b[6]) for b in ordered]


def order_books(books: list[tuple[str, int]], mode: str) -> list[tuple[str, int]]:
    if mode == "canonical":
        return books
    if mode == "nt-first":
        return [b for b in books if b[0] in NT_IDS] + [b for b in books if b[0] not in NT_IDS]
    if mode == "ot-first":
        return [b for b in books if b[0] not in NT_IDS] + [b for b in books if b[0] in NT_IDS]
    if mode == "random":
        shuffled = list(books)
        random.Random(42).shuffle(shuffled)
        return shuffled
    if mode == "popular":
        rank = {book_id: index for index, book_id in enumerate(POPULAR)}
        return sorted(books, key=lambda b: (rank.get(b[0], 999), b[0]))
    raise SystemExit(f"Unknown order: {mode}")


NT_IDS = {b[0] for b in BOOKS if b[3] == "NT"}


def filter_books(
    books: list[tuple[str, int]],
    include: str | None,
    exclude: str | None,
) -> list[tuple[str, int]]:
    if include:
        wanted = [b.strip() for b in include.split(",") if b.strip()]
        missing = [b for b in wanted if b not in {x[0] for x in books}]
        if missing:
            raise SystemExit(f"Unknown book id(s): {', '.join(missing)}")
        books = [b for b in books if b[0] in wanted]
    if exclude:
        unwanted = {b.strip() for b in exclude.split(",") if b.strip()}
        books = [b for b in books if b[0] not in unwanted]
    return books


def expected_calls(books: list[tuple[str, int]], perspectives: list[str]) -> int:
    return sum(chapters for _, chapters in books) * len(perspectives)


def fmt_duration(seconds: float) -> str:
    seconds = max(0, int(seconds))
    return f"{seconds // 3600:02d}:{(seconds % 3600) // 60:02d}:{seconds % 60:02d}"


def estimate_seconds(
    pending_chapters: int,
    perspective_count: int,
    words: int,
    tokens_per_second: float,
    chars_per_chapter: int = 4200,
) -> float:
    output_tokens = perspective_count * int(words * 1.45)
    prompt_tokens = int(chars_per_chapter / 3.6) + 320
    prefill = prompt_tokens / 700.0
    decode = output_tokens / max(1.0, tokens_per_second)
    return pending_chapters * (prefill + decode + 1.2)


def get_pending(store, books, perspectives, force: bool) -> list[dict[str, Any]]:
    pending = []
    for book_id, chapter_count in books:
        for chapter in range(1, chapter_count + 1):
            if force:
                missing = list(perspectives)
            else:
                existing = {row["perspective"] for row in store.get_chapter(book_id, chapter)}
                missing = [p for p in perspectives if p not in existing]
            if missing:
                pending.append({"book": book_id, "chapter": chapter, "missing": missing})
    return pending


def print_status(store, books, perspectives) -> None:
    coverage = store.coverage()
    total_chapters = sum(c for _, c in books)
    print(f"Storage backend: {coverage.get('backend')}")
    print(f"Interpretations: {coverage.get('total_interpretations', 0):,}")
    print(f"Chapters covered: {coverage.get('chapters_covered', 0):,} / {total_chapters:,}")
    print(f"Expected interpretations for selected canon/perspectives: {total_chapters * len(perspectives):,}")
    print("\nBy perspective:")
    for pid in perspectives:
        p = PERSPECTIVE_BY_ID[pid]
        print(f"  {p['label']:<26} {coverage.get('by_perspective', {}).get(pid, 0):>7,}")
    print("\nBy book (chapters covered):")
    by_book = coverage.get("by_book", {})
    for book_id, count in books:
        row = by_book.get(book_id, {})
        if row:
            print(f"  {book_id:<5} {row.get('chapters', 0):>3} / {count:<3} chapters")


def confirm(args, pending_chapters: int, estimated: float) -> bool:
    if args.yes:
        return True
    if not sys.stdin.isatty():
        print("Refusing to run non-interactively without --yes.")
        return False
    print()
    print(f"About to generate {pending_chapters:,} chapter batches using {args.model}.")
    print(f"Estimated time: {fmt_duration(estimated)} (hard budget: {args.hours:.1f} h).")
    answer = input("Start generation on your GPU now? [y/N] ").strip().lower()
    return answer in ("y", "yes")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate resumable, multi-perspective Bible study notes with Ollama.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--run", action="store_true", help="actually generate (default is a dry run)")
    parser.add_argument("--yes", action="store_true", help="skip the interactive confirmation")
    parser.add_argument("--status", action="store_true", help="show coverage and exit")
    parser.add_argument("--dry-run", action="store_true", help="show the plan without generating")
    parser.add_argument("--hours", type=float, default=10.0, help="hard time budget in hours")
    parser.add_argument("--model", default=os.environ.get("OLLAMA_MODEL", "auto"), help="Ollama model name")
    parser.add_argument("--ollama-url", default=os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434"))
    parser.add_argument("--perspectives", default="core", help="core, all, or comma-separated ids")
    parser.add_argument("--canon", choices=["protestant", "catholic"], default="protestant")
    parser.add_argument("--order", choices=["popular", "canonical", "nt-first", "ot-first", "random"], default="popular")
    parser.add_argument("--books", help="comma-separated book ids (e.g. jhn,psa,rom)")
    parser.add_argument("--exclude-books", help="comma-separated book ids to skip")
    parser.add_argument("--chapters", help="chapter range for every selected book, e.g. 1-5")
    parser.add_argument("--limit", type=int, default=0, help="stop after N chapter batches (0 = no limit)")
    parser.add_argument("--force", action="store_true", help="regenerate even if notes already exist")
    parser.add_argument("--words", type=int, default=90, help="target words per perspective")
    parser.add_argument("--max-chars", type=int, default=9000, help="maximum chapter characters sent to the model")
    parser.add_argument("--research", action="store_true", help="add optional web search snippets to prompts")
    parser.add_argument("--research-results", type=int, default=3, help="maximum web results per perspective")
    parser.add_argument("--num-ctx", type=int, default=8192, help="Ollama context window")
    parser.add_argument("--temperature", type=float, default=0.45)
    parser.add_argument("--translation", default="en-kjv", help="source text translation id")
    parser.add_argument("--tokens-per-second", type=float, default=28.0, help="estimate only; calibrate from your GPU")
    parser.add_argument("--sleep", type=float, default=0.0, help="pause between batches in seconds")
    parser.add_argument("--log", default=str(ROOT / "data" / "generation_runs.jsonl"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    os.environ["OLLAMA_URL"] = args.ollama_url
    perspectives = parse_perspectives(args.perspectives)
    books = order_books(filter_books(canonical_books(args.canon), args.books, args.exclude_books), args.order)

    if args.chapters:
        try:
            first, last = args.chapters.split("-")
            first, last = int(first), int(last)
        except ValueError:
            raise SystemExit("--chapters must look like 1-5")
        books = [(b, min(c, last)) for b, c in books]
        # The filter must keep chapters first..last, so adjust pending below.
        chapter_range = (first, last)
    else:
        chapter_range = None

    store = make_store()
    if args.status:
        print_status(store, books, perspectives)
        return 0

    pending = get_pending(store, books, perspectives, args.force)
    if chapter_range:
        first, last = chapter_range
        pending = [p for p in pending if first <= p["chapter"] <= last]
    if args.limit:
        pending = pending[: args.limit]

    model = resolve_model(args.model)
    models = list_models(args.ollama_url)
    estimated = estimate_seconds(len(pending), len(perspectives), args.words, args.tokens_per_second)
    total_chapters = sum(c for _, c in books)

    print("Bible AI — interpretation generator")
    print(f"Storage:      {store.backend}")
    print(f"Source text:  {args.translation} (public-domain KJV by default)")
    print(f"Canon:        {args.canon} ({len(books)} books, {total_chapters:,} chapters)")
    print(f"Order:        {args.order}")
    print(f"Perspectives: {', '.join(perspectives)}")
    print(f"Model:        {model}")
    if models:
        print(f"Ollama:       online, {len(models)} model(s) available")
    else:
        print("Ollama:       NOT reachable (is `ollama serve` running?)")
    print(f"Pending:      {len(pending):,} chapter batches")
    print(f"Budget:       {args.hours:.1f} h (hard stop)")

    if not pending:
        print("\nNothing to do — every selected perspective already exists. Use --force to regenerate.")
        return 0

    if not args.run:
        print()
        print("DRY RUN: nothing will be generated.")
        print(f"Estimated compute time: {fmt_duration(estimated)} at {args.tokens_per_second:.0f} tok/s output.")
        print("Re-run with --run to start. Output is resumable and written directly to the database.")
        print("Tip: `python generator.py --status` shows current coverage at any time.")
        return 0

    if not models:
        raise SystemExit("Ollama is not reachable. Start it with `ollama serve` and try again.")
    if not confirm(args, len(pending), estimated):
        print("Cancelled.")
        return 1

    started = time.monotonic()
    budget_seconds = max(1.0, args.hours * 3600.0)
    completed = 0
    failed = 0
    generated_perspective_count = 0
    durations: list[float] = []
    run_log = {
        "started_at": utc_now(),
        "model": model,
        "perspectives": perspectives,
        "canon": args.canon,
        "budget_hours": args.hours,
        "research": args.research,
    }
    print(f"\nStarting at {run_log['started_at']}. Press Ctrl+C to stop cleanly; progress is saved.\n")

    bundle = ensure_bundle(args.translation)
    bundle_books = {b["id"]: b for b in bundle["books"]}

    try:
        for index, item in enumerate(pending, start=1):
            elapsed = time.monotonic() - started
            remaining_budget = budget_seconds - elapsed
            avg = sum(durations[-5:]) / len(durations[-5:]) if durations else estimated / max(1, len(pending))
            if remaining_budget <= max(8.0, avg * 0.35):
                print(f"\nTime budget reached after {fmt_duration(elapsed)}. Stopping cleanly.")
                break

            book, chapter, missing = item["book"], item["chapter"], item["missing"]
            ref = f"{book} {chapter}"
            try:
                book_meta = bundle_books[book]
                verses = book_meta["chapters"][chapter - 1]
                verse_end = len(verses)
                text = "\n".join(f"{i + 1}. {t}" for i, t in enumerate(verses) if t)
                reference = f"{book_meta['name']} {chapter} (verses 1–{verse_end})"
                research_by_perspective = {}
                if args.research:
                    research_by_perspective = {
                        pid: search_context(
                            f"{reference} {PERSPECTIVE_BY_ID[pid]['label']} biblical interpretation",
                            args.research_results,
                        )
                        for pid in missing
                    }
                call_started = time.monotonic()
                notes = {}
                meta = {"eval_count": 0, "eval_duration_ms": 0, "duration_ms": 0, "calls": 0, "research": {}}
                for pid in missing:
                    generated, generated_meta = generate_notes(
                        reference=reference,
                        translation_name=bundle["name"],
                        text=text,
                        perspective_ids=[pid],
                        model=model,
                        words=args.words,
                        max_chars=args.max_chars,
                        num_ctx=args.num_ctx,
                        temperature=args.temperature,
                        research=research_by_perspective.get(pid),
                    )
                    notes.update(generated)
                    for key in ("eval_count", "eval_duration_ms", "duration_ms", "calls"):
                        meta[key] += generated_meta.get(key, 0)
                    meta["research"][pid] = research_by_perspective.get(pid, [])
                elapsed_call = time.monotonic() - call_started
                durations.append(elapsed_call)
                completed += 1
                for pid, content in notes.items():
                    label = PERSPECTIVE_BY_ID[pid]["label"]
                    store.save_interpretation(
                        {
                            "book": book,
                            "chapter": chapter,
                            "verse_start": 1,
                            "verse_end": verse_end,
                            "perspective": pid,
                            "label": label,
                            "content": content,
                            "model": model,
                            "scope": "chapter",
                            "source": f"ollama:{model}",
                            "sample": 0,
                            "tokens": int(meta.get("eval_count", 0) / max(1, len(notes))),
                            "duration_ms": int(elapsed_call * 1000 / max(1, len(notes))),
                            "created_at": utc_now(),
                            "research": meta["research"].get(pid, []),
                        }
                    )
                    store.save_attempt(book, chapter, pid, "done")
                    generated_perspective_count += 1
                missing_after = [p for p in missing if p not in notes]
                for pid in missing_after:
                    store.save_attempt(book, chapter, pid, "missing", "Model did not return this perspective")
                if missing_after:
                    failed += 1

                done = index
                eta = (sum(durations) / len(durations)) * (len(pending) - done) if durations else 0
                fps = meta.get("eval_count", 0) / max(0.001, meta.get("eval_duration_ms", 1) / 1000)
                print(
                    f"[{done:>5}/{len(pending)}] {ref:<8} +{len(notes)} notes "
                    f"in {elapsed_call:5.1f}s ({fps:4.1f} tok/s) | "
                    f"elapsed {fmt_duration(time.monotonic() - started)} | "
                    f"ETA {fmt_duration(min(eta, max(0, budget_seconds - (time.monotonic() - started))))} | "
                    f"total {completed} batches",
                    flush=True,
                )
                if args.sleep > 0:
                    time.sleep(args.sleep)
            except KeyboardInterrupt:
                raise
            except Exception as exc:
                failed += 1
                print(f"[{index:>5}/{len(pending)}] {ref:<8} FAILED: {exc}", flush=True)
                for pid in missing:
                    store.save_attempt(book, chapter, pid, "error", str(exc))
                time.sleep(1.0)
    except KeyboardInterrupt:
        print("\nInterrupted. Progress is saved; re-run the same command to resume.")
    finally:
        total_elapsed = time.monotonic() - started
        summary = {
            **run_log,
            "finished_at": utc_now(),
            "elapsed_seconds": int(total_elapsed),
            "batches_completed": completed,
            "batches_failed": failed,
            "perspectives_saved": generated_perspective_count,
        }
        print(
            f"\nFinished: {completed} batches, {generated_perspective_count} perspectives, "
            f"{failed} failed, {fmt_duration(total_elapsed)} elapsed."
        )
        try:
            Path(args.log).parent.mkdir(parents=True, exist_ok=True)
            with open(args.log, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(summary, ensure_ascii=False) + "\n")
        except OSError:
            pass
        print(f"Run log: {args.log}")
        print(f"Resume with: python generator.py --run --perspectives {','.join(perspectives)} --hours {args.hours:g}")
        print_status(store, books, perspectives)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

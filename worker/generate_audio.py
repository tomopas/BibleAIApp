"""Generate chapter-level MP3 narration with edge-tts (resumable).

This is optional: the Flutter app can narrate the Bible on-device with the
system TTS engine. This script is for a hosted audio library served by the API.

    pip install edge-tts
    python worker/generate_audio.py --dry-run
    python worker/generate_audio.py --run --voice en-US-AriaNeural --hours 8

Audio files are written to data/audio/{translation}/{book}/{chapter}.mp3
and are served at /api/audio/...
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "backend"))
from translations import DATA_DIR, ensure_bundle  # noqa: E402

AUDIO_DIR = DATA_DIR / "audio"

VOICES = {
    "en": "en-US-AriaNeural",
    "de": "de-DE-KatjaNeural",
    "fr": "fr-FR-DeniseNeural",
    "es": "es-ES-ElviraNeural",
    "pt": "pt-BR-FranciscaNeural",
    "nl": "nl-NL-ColetteNeural",
    "ru": "ru-RU-SvetlanaNeural",
    "pl": "pl-PL-ZofiaNeural",
    "cs": "cs-CZ-VlastaNeural",
    "hu": "hu-HU-NoemiNeural",
    "fi": "fi-FI-NooraNeural",
    "sv": "sv-SE-SofieNeural",
    "no": "nb-NO-PernilleNeural",
    "zh": "zh-CN-XiaoxiaoNeural",
    "ja": "ja-JP-NanamiNeural",
    "ko": "ko-KR-SunHiNeural",
    "vi": "vi-VN-HoaiMyNeural",
    "tl": "fil-PH-BlessicaNeural",
    "la": "it-IT-ElsaNeural",
    "he": "he-IL-HilaNeural",
    "el": "el-GR-AthinaNeural",
    "eo": "en-US-AriaNeural",
    "hy": "hy-AM-AnahitNeural",
    "syr": "en-US-AriaNeural",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Bible chapter MP3s with edge-tts.")
    parser.add_argument("--run", action="store_true", help="actually synthesise audio (default: dry run)")
    parser.add_argument("--yes", action="store_true", help="skip confirmation")
    parser.add_argument("--translation", default="en-kjv")
    parser.add_argument("--voice", default="", help="edge-tts voice name (auto by language if omitted)")
    parser.add_argument("--rate", default="+0%", help="speech rate, e.g. +10%% or -5%%")
    parser.add_argument("--hours", type=float, default=8.0, help="hard time budget in hours")
    parser.add_argument("--books", help="comma-separated book ids")
    parser.add_argument("--start-book", help="skip until this book id")
    parser.add_argument("--limit", type=int, default=0, help="stop after N chapters")
    parser.add_argument("--sleep", type=float, default=0.4, help="pause between chapters")
    parser.add_argument("--bitrate", default="48k", help="MP3 bitrate passed to ffmpeg")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        import edge_tts  # noqa: F401
    except ImportError:
        print("edge-tts is not installed. Run: pip install edge-tts")
        print("Alternatively use the app's built-in device narration.")
        return 2

    bundle = ensure_bundle(args.translation)
    voice = args.voice or VOICES.get(bundle.get("languageCode", "en"), "en-US-AriaNeural")
    include = {b.strip() for b in args.books.split(",")} if args.books else None
    all_books = [b for b in bundle["books"] if not include or b["id"] in include]
    if args.start_book:
        ids = [b["id"] for b in all_books]
        if args.start_book in ids:
            all_books = all_books[ids.index(args.start_book):]

    jobs = []
    for book in all_books:
        for chapter_index in range(1, len(book["chapters"]) + 1):
            target = AUDIO_DIR / args.translation / book["id"] / f"{chapter_index}.mp3"
            if target.exists() and target.stat().st_size > 1000:
                continue
            jobs.append((book, chapter_index, target))
    if args.limit:
        jobs = jobs[: args.limit]

    print(f"Translation: {bundle['name']} ({args.translation})")
    print(f"Voice:       {voice}  rate {args.rate}")
    print(f"Chapters:    {len(jobs):,} pending")
    print(f"Output:      {AUDIO_DIR}")
    if not jobs:
        print("Nothing to do — all selected chapters already have audio.")
        return 0
    if not args.run:
        print("\nDRY RUN: no audio generated. Add --run to start.")
        print(f"Estimated time: {len(jobs) * 2.2 / 60:.0f}–{len(jobs) * 5.0 / 60:.0f} minutes (network-dependent).")
        return 0
    if not args.yes and sys.stdin.isatty():
        answer = input("Generate audio now with Microsoft edge-tts? [y/N] ").strip().lower()
        if answer not in ("y", "yes"):
            print("Cancelled.")
            return 1

    import edge_tts

    started = time.monotonic()
    budget = args.hours * 3600
    done = 0
    failed = 0

    async def one(text: str, target: Path) -> None:
        target.parent.mkdir(parents=True, exist_ok=True)
        tmp = target.with_suffix(".part.mp3")
        communicate = edge_tts.Communicate(text, voice, rate=args.rate, boundary="SentenceBoundary")
        await communicate.save(str(tmp))
        tmp.replace(target)

    async def run() -> None:
        nonlocal done, failed
        for index, (book, chapter, target) in enumerate(jobs, start=1):
            if time.monotonic() - started >= budget:
                print("Time budget reached; stopping cleanly.")
                break
            verses = book["chapters"][chapter - 1]
            text = " ".join(v for v in verses if v).strip()
            if not text:
                continue
            try:
                await one(text, target)
                done += 1
                elapsed = time.monotonic() - started
                eta = (elapsed / done) * (len(jobs) - done)
                print(
                    f"[{index:>5}/{len(jobs)}] {book['id']} {chapter:<3} "
                    f"{target.stat().st_size / 1024:6.0f} KB | {elapsed/60:5.1f} min | ETA {eta/60:5.1f} min",
                    flush=True,
                )
            except Exception as exc:  # noqa: BLE001
                failed += 1
                print(f"[{index:>5}/{len(jobs)}] {book['id']} {chapter:<3} FAILED: {exc}", flush=True)
            await asyncio.sleep(args.sleep)

    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        print("\nInterrupted. Existing files are kept; run again to resume.")

    manifest = []
    for path in sorted(AUDIO_DIR.rglob("*.mp3")):
        rel = path.relative_to(AUDIO_DIR).as_posix()
        manifest.append({"path": rel, "size": path.stat().st_size})
    with open(AUDIO_DIR / "manifest.json", "w", encoding="utf-8") as fh:
        json.dump({"generated": len(manifest), "items": manifest}, fh, indent=2)
    print(f"\nDone: {done} new chapters, {failed} failures, {len(manifest):,} files in library.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

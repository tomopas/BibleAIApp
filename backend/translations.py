"""Public-domain translation catalogue and on-demand bundle builder."""

from __future__ import annotations

import html
import json
import os
import re
import sys
import threading
import time
import urllib.parse
from pathlib import Path
from typing import Any

import httpx

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from canon import BY_SCROLLMAPPER  # noqa: E402

DATA_DIR = Path(os.environ.get("BIBLEAI_DATA", ROOT / "data"))
CACHE_DIR = DATA_DIR / "translations"
CATALOG_PATH = ROOT / "backend" / "catalog.json"
RAW_BASE = "https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json"
CACHE_VERSION = 1

ALIASES = {
    "Prayer of Manasses": "man",
    "Esther (Greek)": "addest",
    "Prayer of Azariah": "s3y",
}


def _load_catalog() -> list[dict[str, Any]]:
    with open(CATALOG_PATH, encoding="utf-8") as fh:
        entries = json.load(fh)
    for entry in entries:
        entry.setdefault("sort", 999)
        entry.setdefault("canon", "protestant")
        entry.setdefault("bundled", False)
    entries.sort(key=lambda e: (e["sort"], e["id"]))
    return entries


CATALOG = _load_catalog()
BY_ID = {entry["id"]: entry for entry in CATALOG}
_locks: dict[str, threading.Lock] = {}
_locks_guard = threading.Lock()


def catalog() -> list[dict[str, Any]]:
    result = []
    for entry in CATALOG:
        item = dict(entry)
        meta = CACHE_DIR / f"{entry['id']}.meta.json"
        if meta.exists():
            try:
                item["cached"] = True
                item["verseCount"] = json.loads(meta.read_text(encoding="utf-8")).get("verseCount", 0)
                item["sizeBytes"] = meta.stat().st_size
            except Exception:
                item["cached"] = True
        else:
            item["cached"] = False
        result.append(item)
    return result


def get_entry(translation_id: str) -> dict[str, Any]:
    entry = BY_ID.get(translation_id)
    if not entry:
        raise KeyError(f"Unknown translation: {translation_id}")
    return entry


def _lock_for(translation_id: str) -> threading.Lock:
    with _locks_guard:
        if translation_id not in _locks:
            _locks[translation_id] = threading.Lock()
        return _locks[translation_id]


def _clean_text(value: str) -> str:
    value = html.unescape(value or "")
    value = value.replace("\u200b", "").replace("\ufeff", "")
    value = re.sub(r"[ \t]+", " ", value)
    return value.strip()


def _chapter_verses(chapter: dict[str, Any]) -> list[str]:
    raw = chapter.get("verses") or []
    if not raw:
        return []
    numbered: dict[int, str] = {}
    for verse in raw:
        try:
            number = int(verse.get("verse", 0))
        except (TypeError, ValueError):
            continue
        if number <= 0:
            continue
        numbered[number] = _clean_text(verse.get("text", ""))
    if not numbered:
        return []
    last = max(numbered)
    return [numbered.get(i, "") for i in range(1, last + 1)]


def _normalise(entry: dict[str, Any], source: dict[str, Any]) -> dict[str, Any]:
    canon_scope = entry.get("canon", "protestant")
    books: list[dict[str, Any]] = []
    verse_count = 0
    for book in source.get("books", []):
        source_name = book.get("name", "")
        meta = BY_SCROLLMAPPER.get(source_name)
        if meta is None and source_name in ALIASES:
            meta = BY_SCROLLMAPPER.get(ALIASES[source_name])
        if meta is None:
            # Books outside the supported canon (e.g. Laodiceans, additional psalms)
            continue
        testament = meta[3]
        if canon_scope == "protestant" and testament == "DC":
            continue
        if canon_scope == "ot" and testament == "NT":
            continue
        if canon_scope == "nt" and testament != "NT":
            continue

        chapters: list[list[str]] = []
        for chapter in book.get("chapters", []):
            verses = _chapter_verses(chapter)
            if not verses:
                continue
            chapters.append(verses)
            verse_count += sum(1 for v in verses if v)
        if not chapters:
            continue
        books.append(
            {
                "id": meta[0],
                "name": meta[1],
                "abbreviation": meta[2],
                "testament": testament,
                "order": len(books) + 1,
                "chapters": chapters,
            }
        )

    if not books:
        raise ValueError(f"No usable books found for {entry['id']}")

    return {
        "id": entry["id"],
        "name": entry["name"],
        "abbreviation": entry["abbreviation"],
        "language": entry.get("language", ""),
        "languageCode": entry.get("languageCode", ""),
        "license": entry.get("license", ""),
        "source": entry.get("source", ""),
        "description": entry.get("description", ""),
        "year": entry.get("year", ""),
        "canon": canon_scope,
        "verseCount": verse_count,
        "builtAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "cacheVersion": CACHE_VERSION,
        "books": books,
    }


def bundle_path(translation_id: str) -> Path:
    return CACHE_DIR / f"{translation_id}.json"


def meta_path(translation_id: str) -> Path:
    return CACHE_DIR / f"{translation_id}.meta.json"


def load_cached(translation_id: str) -> dict[str, Any] | None:
    path = bundle_path(translation_id)
    if not path.exists():
        return None
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None


def ensure_bundle(translation_id: str, refresh: bool = False) -> dict[str, Any]:
    entry = get_entry(translation_id)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = bundle_path(translation_id)
    with _lock_for(translation_id):
        if path.exists() and not refresh:
            cached = load_cached(translation_id)
            if cached and cached.get("cacheVersion") == CACHE_VERSION:
                return cached
        source_name = entry["sourceFile"]
        url = f"{RAW_BASE}/{urllib.parse.quote(source_name)}.json"
        with httpx.Client(timeout=180, follow_redirects=True) as client:
            response = client.get(url, headers={"User-Agent": "BibleAIApp/1.0"})
            response.raise_for_status()
            source = response.json()
        payload = _normalise(entry, source)
        tmp = path.with_suffix(".tmp")
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, separators=(",", ":"))
        tmp.replace(path)
        with open(meta_path(translation_id), "w", encoding="utf-8") as fh:
            json.dump(
                {
                    "id": translation_id,
                    "bookCount": len(payload["books"]),
                    "verseCount": payload["verseCount"],
                    "builtAt": payload["builtAt"],
                },
                fh,
                ensure_ascii=False,
            )
        print(f"[translations] built {translation_id}: {len(payload['books'])} books, {payload['verseCount']:,} verses")
        return payload


def chapter_text(translation_id: str, book_id: str, chapter: int) -> tuple[str, int, str]:
    """Return (text, verse_count, book_name). Raises KeyError/IndexError."""
    bundle = ensure_bundle(translation_id)
    for book in bundle["books"]:
        if book["id"] != book_id:
            continue
        index = int(chapter) - 1
        if index < 0 or index >= len(book["chapters"]):
            raise IndexError(f"{book_id} has no chapter {chapter}")
        verses = book["chapters"][index]
        lines = [f"{i + 1}. {text}" for i, text in enumerate(verses) if text]
        return "\n".join(lines), len(verses), book["name"]
    raise KeyError(f"Book not found: {book_id}")


def book_chapter_counts(translation_id: str = "en-kjv") -> dict[str, int]:
    bundle = ensure_bundle(translation_id)
    return {book["id"]: len(book["chapters"]) for book in bundle["books"]}

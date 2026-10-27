"""Builds the offline starter Bible bundled with the app.

Downloads the public-domain KJV from the scrollmapper/bible_databases project,
normalises it to the app's compact bundle format, and writes a gzipped asset.
The KJV text is public domain.
"""

from __future__ import annotations

import gzip
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))
from canon import BY_SCROLLMAPPER, PROTESTANT  # noqa: E402

SOURCE = "https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/KJV.json"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "bibles", "en-kjv.json.gz")


def main() -> None:
    print("Downloading KJV from scrollmapper…")
    req = urllib.request.Request(SOURCE, headers={"User-Agent": "BibleAIApp-builder"})
    raw = json.load(urllib.request.urlopen(req, timeout=120))

    by_name = {b["name"]: b for b in raw["books"]}
    books = []
    verse_total = 0
    for order, meta in enumerate(PROTESTANT, start=1):
        book = by_name.get(meta[4])
        if not book:
            raise SystemExit(f"Book missing from source: {meta[4]}")
        chapters = []
        for chapter in book["chapters"]:
            verses = [v["text"].strip() for v in chapter["verses"]]
            chapters.append(verses)
            verse_total += len(verses)
        books.append(
            {
                "id": meta[0],
                "name": meta[1],
                "abbreviation": meta[2],
                "testament": meta[3],
                "order": order,
                "chapters": chapters,
            }
        )

    payload = {
        "id": "en-kjv",
        "name": "King James Version",
        "abbreviation": "KJV",
        "language": "English",
        "languageCode": "en",
        "license": "Public Domain",
        "source": "scrollmapper/bible_databases",
        "description": "The Authorized (King James) Version, 1769 standardized text.",
        "books": books,
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    data = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    with gzip.open(OUT, "wb", compresslevel=9) as fh:
        fh.write(data)
    print(f"Wrote {OUT}")
    print(f"{len(books)} books, {verse_total:,} verses, {len(data) / 1e6:.2f} MB uncompressed")


if __name__ == "__main__":
    main()

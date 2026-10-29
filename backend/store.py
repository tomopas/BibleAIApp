"""Persistence for AI interpretations.

The default backend is a small SQLite database. MongoDB is supported by setting
MONGO_URI (and optionally MONGO_DB); if the connection fails the server falls
back to SQLite so the app keeps working.
"""

from __future__ import annotations

import json
import os
import sqlite3
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
DATA_DIR = Path(os.environ.get("BIBLEAI_DATA", ROOT / "data"))
DB_PATH = Path(os.environ.get("BIBLEAI_DB", DATA_DIR / "bibleai.db"))


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class BaseStore:
    backend = "base"

    def save_interpretation(self, row: dict[str, Any]) -> None:
        raise NotImplementedError

    def get_chapter(self, book: str, chapter: int) -> list[dict[str, Any]]:
        raise NotImplementedError

    def get_passage(self, book: str, chapter: int, verse: int) -> list[dict[str, Any]]:
        rows = self.get_chapter(book, chapter)
        matches = [
            r
            for r in rows
            if r.get("scope") == "chapter"
            or int(r.get("verse_start", 1)) <= verse <= int(r.get("verse_end", 999))
        ]
        # Prefer a focused passage over a whole-chapter overview.
        matches.sort(key=lambda r: (r.get("scope") == "chapter", int(r["verse_end"]) - int(r["verse_start"]), r["perspective"]))
        return matches

    def coverage(self) -> dict[str, Any]:
        raise NotImplementedError

    def save_attempt(self, book: str, chapter: int, perspective: str, status: str, error: str = "") -> None:
        pass

    def get_attempts(self) -> dict[tuple[str, int, str], dict[str, Any]]:
        return {}

    def save_sync(self, user_id: str, payload: dict[str, Any]) -> None:
        raise NotImplementedError

    def get_sync(self, user_id: str) -> dict[str, Any] | None:
        raise NotImplementedError

    def close(self) -> None:
        pass


class SQLiteStore(BaseStore):
    backend = "sqlite"

    def __init__(self, path: Path = DB_PATH) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()
        self._init()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path, timeout=30)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=NORMAL")
        return conn

    def _init(self) -> None:
        with self._connect() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS interpretations (
                    id TEXT PRIMARY KEY,
                    book TEXT NOT NULL,
                    chapter INTEGER NOT NULL,
                    verse_start INTEGER NOT NULL DEFAULT 1,
                    verse_end INTEGER NOT NULL DEFAULT 999,
                    perspective TEXT NOT NULL,
                    label TEXT NOT NULL DEFAULT '',
                    content TEXT NOT NULL,
                    model TEXT NOT NULL DEFAULT '',
                    scope TEXT NOT NULL DEFAULT 'chapter',
                    source TEXT NOT NULL DEFAULT '',
                    sample INTEGER NOT NULL DEFAULT 0,
                    tokens INTEGER NOT NULL DEFAULT 0,
                    duration_ms INTEGER NOT NULL DEFAULT 0,
                    research_json TEXT NOT NULL DEFAULT '[]',
                    created_at TEXT NOT NULL
                );
                CREATE UNIQUE INDEX IF NOT EXISTS idx_interp_unique
                    ON interpretations(book, chapter, verse_start, verse_end, perspective);
                CREATE INDEX IF NOT EXISTS idx_interp_chapter
                    ON interpretations(book, chapter);
                CREATE TABLE IF NOT EXISTS generation_attempts (
                    book TEXT NOT NULL,
                    chapter INTEGER NOT NULL,
                    perspective TEXT NOT NULL,
                    status TEXT NOT NULL,
                    error TEXT NOT NULL DEFAULT '',
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY(book, chapter, perspective)
                );
                CREATE TABLE IF NOT EXISTS sync_data (
                    user_id TEXT PRIMARY KEY,
                    payload TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """
            )
            columns = {row[1] for row in conn.execute("PRAGMA table_info(interpretations)")}
            if "research_json" not in columns:
                conn.execute("ALTER TABLE interpretations ADD COLUMN research_json TEXT NOT NULL DEFAULT '[]'")

    def save_interpretation(self, row: dict[str, Any]) -> None:
        row = dict(row)
        row.setdefault("created_at", utc_now())
        row.setdefault("verse_start", 1)
        row.setdefault("verse_end", 999)
        row.setdefault("scope", "chapter")
        row.setdefault("label", row.get("perspective", ""))
        row.setdefault("model", "")
        row.setdefault("source", "")
        row.setdefault("sample", 0)
        row.setdefault("tokens", 0)
        row.setdefault("duration_ms", 0)
        row.setdefault("research", [])
        row["id"] = row.get("id") or (
            f"{row['book']}:{row['chapter']}:{row['verse_start']}:{row['verse_end']}:{row['perspective']}"
        )
        with self._lock, self._connect() as conn:
            conn.execute(
                """
                INSERT INTO interpretations
                    (id, book, chapter, verse_start, verse_end, perspective, label, content,
                     model, scope, source, sample, tokens, duration_ms, research_json, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    label=excluded.label, content=excluded.content, model=excluded.model,
                    scope=excluded.scope, source=excluded.source, sample=excluded.sample,
                    tokens=excluded.tokens, duration_ms=excluded.duration_ms,
                    research_json=excluded.research_json,
                    created_at=excluded.created_at
                """,
                (
                    row["id"],
                    row["book"],
                    int(row["chapter"]),
                    int(row["verse_start"]),
                    int(row["verse_end"]),
                    row["perspective"],
                    row["label"],
                    row["content"],
                    row["model"],
                    row["scope"],
                    row["source"],
                    int(row["sample"]),
                    int(row["tokens"]),
                    int(row["duration_ms"]),
                    json.dumps(row["research"], ensure_ascii=False),
                    row["created_at"],
                ),
            )

    def get_chapter(self, book: str, chapter: int) -> list[dict[str, Any]]:
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT * FROM interpretations WHERE book=? AND chapter=? ORDER BY verse_start, perspective",
                (book, int(chapter)),
            ).fetchall()
        result = []
        for row in rows:
            item = dict(row)
            item["research"] = json.loads(item.pop("research_json", "[]") or "[]")
            result.append(item)
        return result

    def coverage(self) -> dict[str, Any]:
        with self._connect() as conn:
            total = conn.execute("SELECT COUNT(*) FROM interpretations").fetchone()[0]
            chapters = conn.execute(
                "SELECT COUNT(*) FROM (SELECT DISTINCT book, chapter FROM interpretations)"
            ).fetchone()[0]
            by_perspective = {
                r["perspective"]: r["n"]
                for r in conn.execute(
                    "SELECT perspective, COUNT(*) AS n FROM interpretations GROUP BY perspective"
                ).fetchall()
            }
            by_book = {
                r["book"]: {"chapters": r["chapters"], "interpretations": r["n"]}
                for r in conn.execute(
                    "SELECT book, COUNT(DISTINCT chapter) AS chapters, COUNT(*) AS n "
                    "FROM interpretations GROUP BY book"
                ).fetchall()
            }
        return {
            "total_interpretations": total,
            "chapters_covered": chapters,
            "by_perspective": by_perspective,
            "by_book": by_book,
            "backend": self.backend,
        }

    def save_attempt(self, book: str, chapter: int, perspective: str, status: str, error: str = "") -> None:
        with self._lock, self._connect() as conn:
            conn.execute(
                """
                INSERT INTO generation_attempts(book, chapter, perspective, status, error, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(book, chapter, perspective) DO UPDATE SET
                    status=excluded.status, error=excluded.error, updated_at=excluded.updated_at
                """,
                (book, int(chapter), perspective, status, error[:1000], utc_now()),
            )

    def get_attempts(self) -> dict[tuple[str, int, str], dict[str, Any]]:
        with self._connect() as conn:
            rows = conn.execute("SELECT * FROM generation_attempts").fetchall()
        return {(r["book"], int(r["chapter"]), r["perspective"]): dict(r) for r in rows}

    def save_sync(self, user_id: str, payload: dict[str, Any]) -> None:
        with self._lock, self._connect() as conn:
            conn.execute(
                """
                INSERT INTO sync_data(user_id, payload, updated_at) VALUES (?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET payload=excluded.payload, updated_at=excluded.updated_at
                """,
                (user_id, json.dumps(payload, ensure_ascii=False, separators=(",", ":")), utc_now()),
            )

    def get_sync(self, user_id: str) -> dict[str, Any] | None:
        with self._connect() as conn:
            row = conn.execute("SELECT * FROM sync_data WHERE user_id=?", (user_id,)).fetchone()
        if not row:
            return None
        return {"user_id": row["user_id"], "updated_at": row["updated_at"], "data": json.loads(row["payload"])}


class MongoStore(BaseStore):
    backend = "mongodb"

    def __init__(self, uri: str, db_name: str = "bibleai") -> None:
        from pymongo import ASCENDING, MongoClient

        self.client = MongoClient(uri, serverSelectionTimeoutMS=4000)
        self.client.admin.command("ping")
        self.db = self.client[db_name]
        self.interp = self.db["interpretations"]
        self.attempts = self.db["generation_attempts"]
        self.sync = self.db["sync_data"]
        self.interp.create_index(
            [("book", ASCENDING), ("chapter", ASCENDING), ("verse_start", ASCENDING),
             ("verse_end", ASCENDING), ("perspective", ASCENDING)],
            unique=True,
        )

    def save_interpretation(self, row: dict[str, Any]) -> None:
        row = dict(row)
        row.setdefault("created_at", utc_now())
        row.setdefault("verse_start", 1)
        row.setdefault("verse_end", 999)
        row.setdefault("scope", "chapter")
        row.setdefault("label", row.get("perspective", ""))
        row.setdefault("model", "")
        row.setdefault("source", "")
        row.setdefault("sample", 0)
        row.setdefault("tokens", 0)
        row.setdefault("duration_ms", 0)
        row.setdefault(
            "id",
            f"{row['book']}:{row['chapter']}:{row['verse_start']}:{row['verse_end']}:{row['perspective']}",
        )
        self.interp.replace_one({"id": row["id"]}, row, upsert=True)

    def get_chapter(self, book: str, chapter: int) -> list[dict[str, Any]]:
        cursor = self.interp.find({"book": book, "chapter": int(chapter)}, {"_id": 0}).sort(
            [("verse_start", 1), ("perspective", 1)]
        )
        return list(cursor)

    def coverage(self) -> dict[str, Any]:
        total = self.interp.count_documents({})
        by_perspective = {
            d["_id"]: d["n"]
            for d in self.interp.aggregate([{"$group": {"_id": "$perspective", "n": {"$sum": 1}}}])
        }
        by_book = {
            d["_id"]: {"chapters": len(d["chapters"]), "interpretations": d["n"]}
            for d in self.interp.aggregate(
                [
                    {"$group": {"_id": "$book", "chapters": {"$addToSet": "$chapter"}, "n": {"$sum": 1}}},
                ]
            )
        }
        chapters = len(
            list(
                self.interp.aggregate(
                    [{"$group": {"_id": {"book": "$book", "chapter": "$chapter"}}}, {"$count": "n"}]
                )
            )
        )
        return {
            "total_interpretations": total,
            "chapters_covered": chapters,
            "by_perspective": by_perspective,
            "by_book": by_book,
            "backend": self.backend,
        }

    def save_attempt(self, book: str, chapter: int, perspective: str, status: str, error: str = "") -> None:
        self.attempts.replace_one(
            {"book": book, "chapter": int(chapter), "perspective": perspective},
            {
                "book": book,
                "chapter": int(chapter),
                "perspective": perspective,
                "status": status,
                "error": error[:1000],
                "updated_at": utc_now(),
            },
            upsert=True,
        )

    def get_attempts(self) -> dict[tuple[str, int, str], dict[str, Any]]:
        return {
            (r["book"], int(r["chapter"]), r["perspective"]): r
            for r in self.attempts.find({}, {"_id": 0})
        }

    def save_sync(self, user_id: str, payload: dict[str, Any]) -> None:
        self.sync.replace_one(
            {"user_id": user_id},
            {"user_id": user_id, "payload": payload, "updated_at": utc_now()},
            upsert=True,
        )

    def get_sync(self, user_id: str) -> dict[str, Any] | None:
        row = self.sync.find_one({"user_id": user_id}, {"_id": 0})
        if not row:
            return None
        return {"user_id": row["user_id"], "updated_at": row["updated_at"], "data": row.get("payload", {})}

    def close(self) -> None:
        self.client.close()


def make_store() -> BaseStore:
    mode = os.environ.get("BIBLEAI_STORAGE", "auto").lower()
    uri = os.environ.get("MONGO_URI", "").strip()
    if mode in ("auto", "mongo") and uri:
        try:
            store = MongoStore(uri, os.environ.get("MONGO_DB", "bibleai"))
            print(f"[storage] connected to MongoDB ({os.environ.get('MONGO_DB', 'bibleai')})")
            return store
        except Exception as exc:  # pragma: no cover - depends on local setup
            print(f"[storage] MongoDB unavailable ({exc}); falling back to SQLite")
            if mode == "mongo":
                raise
            fallback = SQLiteStore()
            fallback.connection_error = str(exc)
            return fallback
    return SQLiteStore()

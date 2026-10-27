"""Bible AI local API server.

Run:
    cd server
    python -m uvicorn app:app --host 0.0.0.0 --port 8765 --reload

The server is intentionally small and local-first:
* SQLite by default, MongoDB if MONGO_URI is set
* Translation bundles are downloaded from public-domain sources and cached
* Ollama is used only for explicit generation requests from the app or generator
"""

from __future__ import annotations

import json
import os
import threading
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel, Field
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / "deploy" / ".env")

from ai import CORE, PERSPECTIVES, PERSPECTIVE_BY_ID, generate_notes, list_models, resolve_model
from store import make_store
from translations import (
    CACHE_DIR,
    DATA_DIR,
    book_chapter_counts,
    bundle_path,
    catalog,
    chapter_text,
    ensure_bundle,
    get_entry,
)

AUDIO_DIR = DATA_DIR / "audio"
AUDIO_DIR.mkdir(parents=True, exist_ok=True)
AUDIO_PUBLIC_BASE_URL = os.environ.get("AUDIO_PUBLIC_BASE_URL", "").rstrip("/")


def _env_flag(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


# On-demand Ollama jobs are opt-in. The serving deployment relies on
# pre-generated interpretations in MongoDB/SQLite, so it must not depend on a
# GPU or an Ollama instance being up.
LIVE_GENERATION = _env_flag("BIBLEAI_LIVE_GENERATION", False)

_AUDIO_PROBE_TTL = 60.0
_audio_probe_cache: dict[str, tuple[float, bool, int]] = {}
_audio_probe_lock = threading.Lock()
_s3_client: Any = None
_s3_bucket = ""
_s3_checked = False


def _audio_store() -> tuple[Any, str]:
    """Lazily build the RustFS/S3 client used to check uploaded chapters."""
    global _s3_client, _s3_bucket, _s3_checked
    if _s3_checked:
        return _s3_client, _s3_bucket
    _s3_checked = True
    endpoint = os.environ.get("AUDIO_S3_ENDPOINT", "").strip()
    bucket = os.environ.get("AUDIO_S3_BUCKET", "").strip()
    if not endpoint or not bucket:
        return None, ""
    try:
        import boto3

        _s3_client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            region_name=os.environ.get("AUDIO_S3_REGION", "us-east-1"),
            aws_access_key_id=os.environ.get("AUDIO_S3_ACCESS_KEY", ""),
            aws_secret_access_key=os.environ.get("AUDIO_S3_SECRET_KEY", ""),
        )
        _s3_bucket = bucket
    except Exception:  # noqa: BLE001
        _s3_client = None
        _s3_bucket = ""
    return _s3_client, _s3_bucket


def _audio_available(translation_id: str, book: str, chapter: int) -> tuple[bool, int]:
    """Return whether the app can fetch this chapter, and its size in bytes.

    When a public object-store URL is configured the app downloads from RustFS,
    so the bucket is the source of truth. Local files are only used when no
    public URL is set or the store cannot be reached.
    """
    path = AUDIO_DIR / translation_id / book / f"{chapter}.mp3"
    key = f"{translation_id}/{book}/{chapter}.mp3"
    now = time.monotonic()
    with _audio_probe_lock:
        cached = _audio_probe_cache.get(key)
        if cached is not None and now - cached[0] < _AUDIO_PROBE_TTL:
            return cached[1], cached[2]

    local_available = path.exists()
    available = local_available
    size = path.stat().st_size if local_available else 0

    if AUDIO_PUBLIC_BASE_URL:
        client, bucket = _audio_store()
        if client is not None:
            uploaded: bool | None = None
            uploaded_size = 0
            try:
                head = client.head_object(Bucket=bucket, Key=key)
                uploaded = True
                uploaded_size = int(head.get("ContentLength", 0) or 0)
            except Exception as exc:  # noqa: BLE001
                status = (
                    getattr(exc, "response", {})
                    .get("ResponseMetadata", {})
                    .get("HTTPStatusCode")
                )
                if status == 404:
                    uploaded = False
            if uploaded is not None:
                available, size = uploaded, uploaded_size

    with _audio_probe_lock:
        _audio_probe_cache[key] = (now, available, size)
    return available, size

app = FastAPI(title="Bible AI API", version="1.0.0")
app.add_middleware(GZipMiddleware, minimum_size=1200)
_cors_origins = [
    origin.strip()
    for origin in os.environ.get("BIBLE_AI_CORS_ORIGINS", "http://localhost,http://127.0.0.1").split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

store = make_store()
JOBS: dict[str, dict[str, Any]] = {}
JOBS_LOCK = threading.Lock()
GENERATION_LOCK = threading.Lock()
JOB_RETENTION = 100

EXPECTED_CHAPTERS = 1189


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class GenerateRequest(BaseModel):
    book: str
    chapter: int = Field(ge=1, le=200)
    verseStart: int = Field(default=1, ge=1)
    verseEnd: int | None = Field(default=None, ge=1)
    perspectives: list[str] = Field(default_factory=lambda: list(CORE))
    translation: str = "en-kjv"
    model: str | None = None
    words: int = Field(default=90, ge=40, le=220)
    force: bool = False


class SyncRequest(BaseModel):
    data: dict[str, Any]


class JobCreateResponse(BaseModel):
    jobId: str
    status: str


def _trim_jobs() -> None:
    if len(JOBS) <= JOB_RETENTION:
        return
    finished = sorted(
        ((job_id, job) for job_id, job in JOBS.items() if job["status"] in ("done", "error")),
        key=lambda item: item[1].get("createdAt", ""),
    )
    for job_id, _ in finished[: max(0, len(JOBS) - JOB_RETENTION)]:
        JOBS.pop(job_id, None)


def _update_job(job_id: str, **fields: Any) -> None:
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if job:
            job.update(fields)


def _run_generation(job_id: str, req: GenerateRequest) -> None:
    _update_job(job_id, status="running", startedAt=utc_now(), message="Loading passage…")
    try:
        bundle = ensure_bundle(req.translation)
        book_meta = next((b for b in bundle["books"] if b["id"] == req.book), None)
        if book_meta is None:
            raise ValueError(f"Book {req.book} is not in {req.translation}")
        chapters = book_meta["chapters"]
        if req.chapter < 1 or req.chapter > len(chapters):
            raise ValueError(f"{req.book} has no chapter {req.chapter}")
        verses = chapters[req.chapter - 1]
        verse_end = req.verseEnd or len(verses)
        verse_end = min(verse_end, len(verses))
        verse_start = max(1, min(req.verseStart, verse_end))
        scope = "chapter" if verse_start == 1 and verse_end == len(verses) else "passage"
        text = "\n".join(
            f"{i}. {verses[i - 1]}" for i in range(verse_start, verse_end + 1) if verses[i - 1]
        )
        if not text.strip():
            raise ValueError("The selected passage has no text")

        existing = {
            row["perspective"]
            for row in store.get_chapter(req.book, req.chapter)
            if row.get("scope") == scope
            and int(row.get("verse_start", 1)) == verse_start
            and int(row.get("verse_end", 999)) == verse_end
        }
        requested = [p for p in req.perspectives if p in PERSPECTIVE_BY_ID]
        missing = requested if req.force else [p for p in requested if p not in existing]
        if not missing:
            _update_job(
                job_id,
                status="done",
                finishedAt=utc_now(),
                progress=1.0,
                message="All requested perspectives already exist.",
                result={"saved": 0, "skipped": requested, "notes": []},
            )
            return

        model = resolve_model(req.model)
        reference = f"{book_meta['name']} {req.chapter}"
        if scope == "passage":
            reference += f":{verse_start}–{verse_end}"
        _update_job(
            job_id,
            message=f"Asking {model} for {len(missing)} perspective(s)…",
            progress=0.15,
            model=model,
            total=len(missing),
        )
        notes, meta = generate_notes(
            reference=reference,
            translation_name=bundle["name"],
            text=text,
            perspective_ids=missing,
            model=model,
            words=req.words,
        )
        saved = []
        for pid, content in notes.items():
            with JOBS_LOCK:
                cancelled = JOBS.get(job_id, {}).get("cancelRequested", False)
            if cancelled:
                _update_job(job_id, status="cancelled", finishedAt=utc_now(), progress=1.0, message="Cancelled")
                return
            label = PERSPECTIVE_BY_ID[pid]["label"]
            row = {
                "book": req.book,
                "chapter": req.chapter,
                "verse_start": verse_start,
                "verse_end": verse_end,
                "perspective": pid,
                "label": label,
                "content": content,
                "model": model,
                "scope": scope,
                "source": f"ollama:{model}",
                "sample": 0,
                "tokens": int(meta.get("eval_count", 0) / max(1, len(notes))),
                "duration_ms": int(meta.get("duration_ms", 0) / max(1, len(notes))),
                "created_at": utc_now(),
            }
            store.save_interpretation(row)
            store.save_attempt(req.book, req.chapter, pid, "done")
            saved.append(row)
        for pid in missing:
            if pid not in notes:
                store.save_attempt(req.book, req.chapter, pid, "missing", "Model returned no note")
        _update_job(
            job_id,
            status="done",
            finishedAt=utc_now(),
            progress=1.0,
            message=f"Saved {len(saved)} perspective(s).",
            result={
                "saved": len(saved),
                "missing": [p for p in missing if p not in notes],
                "notes": saved,
                "meta": meta,
                "scope": scope,
                "verseStart": verse_start,
                "verseEnd": verse_end,
            },
        )
    except Exception as exc:  # noqa: BLE001 - job errors must be reported to the app
        _update_job(
            job_id,
            status="error",
            finishedAt=utc_now(),
            progress=1.0,
            message=str(exc),
            error=str(exc),
        )
    finally:
        try:
            GENERATION_LOCK.release()
        except RuntimeError:
            pass


@app.get("/", response_class=HTMLResponse)
def index() -> str:
    coverage = store.coverage()
    ollama = list_models() if LIVE_GENERATION else []
    if not LIVE_GENERATION:
        ollama_status = '<span class="bad">disabled (pre-generated mode)</span>'
    elif ollama:
        ollama_status = f'<span class="ok">online ({len(ollama)} models)</span>'
    else:
        ollama_status = '<span class="bad">offline</span>'
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Bible AI API</title>
<style>
body{{font-family:system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.55;color:#222}}
code{{background:#f3f0e8;padding:2px 6px;border-radius:4px}} .ok{{color:#1f7a4d}} .bad{{color:#a33}}
</style></head><body>
<h1>Bible AI API</h1>
<p>Status: <span class="ok">running</span> · storage: <code>{store.backend}</code> ·
Ollama: {ollama_status}</p>
<p>{coverage.get('total_interpretations', 0):,} interpretations across
{coverage.get('chapters_covered', 0):,} chapters.</p>
<h3>Endpoints</h3>
<ul>
<li><a href="/docs">/docs</a> — interactive OpenAPI docs</li>
<li><a href="/api/health">/api/health</a></li>
<li><a href="/api/catalog">/api/catalog</a></li>
<li><a href="/api/interpretations/coverage">/api/interpretations/coverage</a></li>
</ul>
<p>Point the app at this machine's LAN address (for example <code>http://192.168.1.10:8765</code>).</p>
</body></html>"""


@app.get("/api/health")
def health() -> dict[str, Any]:
    models = list_models() if LIVE_GENERATION else []
    return {
        "status": "ok",
        "time": utc_now(),
        "storage": store.backend,
        "liveGeneration": LIVE_GENERATION,
        "ollama": {
            "enabled": LIVE_GENERATION,
            "online": bool(models),
            "models": models,
        },
        "interpretations": store.coverage().get("total_interpretations", 0),
        "catalogSize": len(catalog()),
        "expectedChapters": EXPECTED_CHAPTERS,
    }


@app.get("/api/catalog")
def get_catalog() -> dict[str, Any]:
    return {"translations": catalog(), "perspectives": PERSPECTIVES}


@app.get("/api/perspectives")
def get_perspectives() -> dict[str, Any]:
    return {"perspectives": PERSPECTIVES, "core": CORE}


@app.get("/api/translations/{translation_id}/bundle")
def get_bundle(translation_id: str, refresh: int = 0) -> FileResponse:
    try:
        get_entry(translation_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    try:
        ensure_bundle(translation_id, refresh=bool(refresh))
    except Exception as exc:  # noqa: BLE001 - network/source errors are useful to the client
        raise HTTPException(status_code=502, detail=f"Could not build translation: {exc}") from exc
    path = bundle_path(translation_id)
    if not path.exists():
        raise HTTPException(status_code=500, detail="Translation cache missing")
    return FileResponse(
        path,
        media_type="application/json",
        filename=f"{translation_id}.json",
        headers={"Cache-Control": "public, max-age=86400", "X-BibleAI-Cache": CACHE_DIR.name},
    )


@app.get("/api/translations/{translation_id}/books")
def get_books(translation_id: str) -> dict[str, Any]:
    try:
        bundle = ensure_bundle(translation_id)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return {
        "translation": {
            "id": bundle["id"],
            "name": bundle["name"],
            "abbreviation": bundle["abbreviation"],
            "language": bundle["language"],
            "license": bundle["license"],
        },
        "books": [
            {
                "id": b["id"],
                "name": b["name"],
                "abbreviation": b["abbreviation"],
                "testament": b["testament"],
                "order": b["order"],
                "chapterCount": len(b["chapters"]),
            }
            for b in bundle["books"]
        ],
    }


@app.get("/api/interpretations")
def get_interpretations(
    book: str = Query(..., min_length=2),
    chapter: int = Query(..., ge=1),
    verse: int | None = Query(default=None, ge=1),
) -> dict[str, Any]:
    rows = store.get_chapter(book, chapter)
    passage = []
    overview = []
    if verse is not None:
        passage = [
            r
            for r in rows
            if r.get("scope") == "passage"
            and int(r.get("verse_start", 1)) <= verse <= int(r.get("verse_end", 999))
        ]
        overview = [r for r in rows if r.get("scope") == "chapter"]
    else:
        overview = [r for r in rows if r.get("scope") == "chapter"]
    available = sorted({r["perspective"] for r in (passage or overview)})
    return {
        "book": book,
        "chapter": chapter,
        "verse": verse,
        "passage": passage,
        "chapterOverview": overview,
        "all": rows,
        "available": available,
        "missing": [p["id"] for p in PERSPECTIVES if p["id"] not in available],
        "perspectives": PERSPECTIVES,
    }


@app.get("/api/interpretations/coverage")
def get_coverage() -> dict[str, Any]:
    coverage = store.coverage()
    coverage["expectedChapters"] = EXPECTED_CHAPTERS
    coverage["expectedWithCore"] = EXPECTED_CHAPTERS * len(CORE)
    coverage["perspectives"] = PERSPECTIVES
    return coverage


@app.post("/api/generate", response_model=JobCreateResponse)
def start_generation(req: GenerateRequest) -> JobCreateResponse:
    if not LIVE_GENERATION:
        raise HTTPException(
            status_code=403,
            detail=(
                "Live generation is disabled on this server. Interpretations are pre-generated "
                "and served from the database. Set BIBLEAI_LIVE_GENERATION=1 to enable on-demand jobs."
            ),
        )
    if not GENERATION_LOCK.acquire(blocking=False):
        raise HTTPException(status_code=429, detail="A generation job is already running. Try again shortly.")
    if not req.perspectives:
        GENERATION_LOCK.release()
        raise HTTPException(status_code=400, detail="No perspectives requested")
    unknown = [p for p in req.perspectives if p not in PERSPECTIVE_BY_ID]
    if unknown:
        GENERATION_LOCK.release()
        raise HTTPException(status_code=400, detail=f"Unknown perspectives: {unknown}")
    if len(req.perspectives) > 10:
        GENERATION_LOCK.release()
        raise HTTPException(status_code=400, detail="At most 10 perspectives per on-demand request")
    job_id = uuid.uuid4().hex[:12]
    with JOBS_LOCK:
        JOBS[job_id] = {
            "id": job_id,
            "status": "queued",
            "createdAt": utc_now(),
            "request": req.model_dump(),
            "progress": 0.0,
            "message": "Queued",
        }
        _trim_jobs()
    thread = threading.Thread(target=_run_generation, args=(job_id, req), daemon=True, name=f"gen-{job_id}")
    thread.start()
    return JobCreateResponse(jobId=job_id, status="queued")


@app.get("/api/jobs/{job_id}")
def get_job(job_id: str) -> dict[str, Any]:
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        return json.loads(json.dumps(job))


@app.post("/api/jobs/{job_id}/cancel")
def cancel_job(job_id: str) -> dict[str, Any]:
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        if job["status"] in ("done", "error", "cancelled"):
            return {"ok": True, "status": job["status"]}
        job["cancelRequested"] = True
        job["message"] = "Cancellation requested"
    return {"ok": True, "status": "cancelling"}


@app.post("/api/sync")
def sync(user_id: str = Query(..., min_length=3, max_length=120), req: SyncRequest | None = None) -> dict[str, Any]:
    if req is None:
        raise HTTPException(status_code=400, detail="Missing sync payload")
    store.save_sync(user_id, req.data)
    return {"ok": True, "updatedAt": utc_now()}


@app.get("/api/sync/{user_id}")
def get_sync(user_id: str) -> dict[str, Any]:
    data = store.get_sync(user_id)
    if data is None:
        raise HTTPException(status_code=404, detail="No sync data for this user")
    return data


@app.get("/api/audio/info/{translation_id}/{book}/{chapter}")
def audio_info(translation_id: str, book: str, chapter: int) -> dict[str, Any]:
    available, size = _audio_available(translation_id, book, chapter)
    relative_url = f"/api/audio/{translation_id}/{book}/{chapter}.mp3"
    return {
        "available": available,
        "url": f"{AUDIO_PUBLIC_BASE_URL}/audio/{translation_id}/{book}/{chapter}.mp3"
        if AUDIO_PUBLIC_BASE_URL
        else relative_url,
        "size": size,
        "provider": "kokoro",
        "providerLabel": "Recommended: Kokoro local TTS",
        "model": "Kokoro-82M",
        "modelLicense": "Apache-2.0",
        "distributionNote": "Verify the selected Bible translation license before redistribution.",
    }


@app.get("/api/audio/provider")
def audio_provider() -> dict[str, Any]:
    return {
        "id": "kokoro",
        "label": "Recommended: Kokoro local TTS",
        "model": "Kokoro-82M",
        "modelLicense": "Apache-2.0",
        "local": True,
        "description": "High-quality server-side narration generated locally without sending Bible text to a hosted TTS service.",
        "distributionNote": "Confirm the Bible translation and selected voice/dependency licenses before redistribution.",
        "delivery": "nginx-rustfs" if AUDIO_PUBLIC_BASE_URL else "api-filesystem",
    }


@app.get("/api/audio/{translation_id}/{book}/{chapter}.mp3")
def audio_file(translation_id: str, book: str, chapter: int) -> FileResponse:
    path = AUDIO_DIR / translation_id / book / f"{chapter}.mp3"
    if not path.exists():
        raise HTTPException(
            status_code=404,
            detail="No audio for this chapter. Run worker/generate_kokoro_audio.py or use device TTS in the app.",
        )
    return FileResponse(path, media_type="audio/mpeg", filename=f"{translation_id}-{book}-{chapter}.mp3")


@app.get("/api/audio/manifest")
def audio_manifest() -> dict[str, Any]:
    items = []
    if AUDIO_DIR.exists():
        for path in AUDIO_DIR.rglob("*.mp3"):
            rel = path.relative_to(AUDIO_DIR)
            items.append({"path": rel.as_posix(), "size": path.stat().st_size})
    items.sort(key=lambda x: x["path"])
    return {
        "count": len(items),
        "items": items,
        "base": "/api/audio",
        "provider": "kokoro",
        "providerLabel": "Recommended: Kokoro local TTS",
        "model": "Kokoro-82M",
        "modelLicense": "Apache-2.0",
        "delivery": "nginx-rustfs" if AUDIO_PUBLIC_BASE_URL else "api-filesystem",
    }


@app.get("/api/books/{translation_id}")
def books(translation_id: str) -> dict[str, Any]:
    try:
        return {"chapters": book_chapter_counts(translation_id)}
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.get("/api/chapter/{translation_id}/{book}/{chapter}")
def chapter(translation_id: str, book: str, chapter: int) -> dict[str, Any]:
    try:
        text, count, name = chapter_text(translation_id, book, chapter)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {"book": book, "name": name, "chapter": chapter, "verseCount": count, "text": text}


@app.on_event("shutdown")
def shutdown() -> None:
    store.close()

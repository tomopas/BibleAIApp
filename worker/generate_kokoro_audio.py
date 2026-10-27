"""Generate resumable chapter MP3 narration with local Kokoro TTS.

Kokoro runs locally and does not upload Bible text to a hosted TTS provider.
Completed chapters are written atomically, so rerunning this script resumes
from the first missing or incomplete chapter.

Install the server dependencies and ffmpeg:

    pip install -r worker/requirements.txt
    ffmpeg -version

Examples:

    python worker/generate_kokoro_audio.py --dry-run
    python worker/generate_kokoro_audio.py --run --translation en-kjv --yes
    python worker/generate_kokoro_audio.py --run --no-upload     # local files only
    python worker/generate_kokoro_audio.py --run --force          # redo existing audio
    python worker/generate_kokoro_audio.py --pause-file data/audio.pause

Verse numbers are not spoken; only the verse text is narrated.

Use --device cuda (or auto, the default) to run inference on an NVIDIA GPU.
A CUDA build of torch is required; the PyPI Windows wheel is CPU-only.

To pause a running job, create the pause file. Remove it to continue:

    touch data/audio.pause
    rm data/audio.pause

Audio is stored under data/audio/{translation}/{book}/{chapter}.mp3.
Progress is stored in data/audio/{translation}/kokoro-progress.json and,
when MONGO_URI is configured, mirrored to MongoDB.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / "deploy" / ".env")
sys.path.insert(0, str(ROOT / "backend"))
from translations import DATA_DIR, ensure_bundle  # noqa: E402

AUDIO_DIR = DATA_DIR / "audio"
PROVIDER = "kokoro"
MODEL = "Kokoro-82M"
MODEL_REPO = "hexgrad/Kokoro-82M"
MODEL_LICENSE = "Apache-2.0"
DEFAULT_VOICE = "af_heart"
DEFAULT_LANGUAGE = "a"
DEFAULT_DEVICE = "auto"
MAX_UPLOAD_FAILURES = 5
# 1 = "Verse N: ..." was spoken, 2 = plain verse text only.
SPEECH_FORMAT_VERSION = 2


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Bible chapter MP3s with local Kokoro.")
    parser.add_argument("--run", action="store_true", help="actually generate audio")
    parser.add_argument("--dry-run", action="store_true", help="plan work without generating audio")
    parser.add_argument("--yes", action="store_true", help="skip confirmation")
    parser.add_argument("--translation", default="en-kjv")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help="Kokoro voice, e.g. af_heart")
    parser.add_argument("--language", default=DEFAULT_LANGUAGE, help="Kokoro language code, e.g. a or b")
    parser.add_argument("--books", help="comma-separated book ids")
    parser.add_argument("--start-book", help="resume planning at this book id")
    parser.add_argument("--limit", type=int, default=0, help="stop after N pending chapters")
    parser.add_argument("--pause-file", default="", help="file whose presence pauses between chapters")
    parser.add_argument("--bitrate", default="64k", help="MP3 bitrate passed to ffmpeg")
    parser.add_argument(
        "--device",
        default=DEFAULT_DEVICE,
        choices=("auto", "cuda", "cpu"),
        help="inference device; auto uses CUDA when a CUDA build of torch is installed",
    )
    parser.add_argument("--no-upload", action="store_true", help="generate locally without uploading to RustFS/S3")
    parser.add_argument("--force", action="store_true", help="regenerate chapters that already have audio")
    return parser.parse_args()


def progress_path(translation: str) -> Path:
    return AUDIO_DIR / translation / "kokoro-progress.json"


def load_progress(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"provider": PROVIDER, "model": MODEL, "license": MODEL_LICENSE, "chapters": {}}
    try:
        with path.open(encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict) and isinstance(data.get("chapters"), dict):
            return data
    except (OSError, ValueError):
        pass
    return {"provider": PROVIDER, "model": MODEL, "license": MODEL_LICENSE, "chapters": {}}


def save_progress(path: Path, progress: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8") as fh:
        json.dump(progress, fh, ensure_ascii=False, indent=2)
    tmp.replace(path)


def sync_progress(translation: str, progress: dict[str, Any]) -> None:
    uri = os.environ.get("MONGO_URI")
    if not uri:
        return
    try:
        from pymongo import MongoClient

        client = MongoClient(uri, serverSelectionTimeoutMS=4000)
        client.admin.command("ping")
        db = client[os.environ.get("MONGO_DB", "bibleai")]
        db["audio_generation"].replace_one(
            {"translation": translation, "provider": PROVIDER},
            {
                "translation": translation,
                "provider": PROVIDER,
                "model": MODEL,
                "modelLicense": MODEL_LICENSE,
                "voice": progress.get("voice", DEFAULT_VOICE),
                "updatedAt": utc_now(),
                "chapters": progress.get("chapters", {}),
            },
            upsert=True,
        )
        client.close()
    except Exception as exc:  # Mongo is optional; the local checkpoint remains authoritative.
        print(f"[kokoro] MongoDB progress sync unavailable: {exc}", file=sys.stderr)


def s3_client() -> Any | None:
    """Return a reusable S3 client for RustFS, or None when uploads are disabled."""
    endpoint = os.environ.get("AUDIO_S3_ENDPOINT", "").strip()
    if not endpoint:
        return None
    import boto3

    return boto3.client(
        "s3",
        endpoint_url=endpoint,
        region_name=os.environ.get("AUDIO_S3_REGION", "us-east-1"),
        aws_access_key_id=os.environ.get("AUDIO_S3_ACCESS_KEY"),
        aws_secret_access_key=os.environ.get("AUDIO_S3_SECRET_KEY"),
    )


def upload_audio(client: Any, bucket: str, target: Path, translation: str) -> str:
    key = f"{translation}/{target.relative_to(AUDIO_DIR / translation).as_posix()}"
    client.upload_file(
        str(target),
        bucket,
        key,
        ExtraArgs={"ContentType": "audio/mpeg", "CacheControl": "public, max-age=31536000, immutable"},
    )
    return key


def check_ffmpeg() -> None:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg is required and must be available on PATH")


def build_jobs(
    bundle: dict[str, Any],
    translation: str,
    progress: dict[str, Any],
    args: argparse.Namespace,
    upload_enabled: bool,
) -> list[tuple[str, int, Path, bool]]:
    """Return (book, chapter, target, needs_generation) work items."""
    include = {b.strip().lower() for b in args.books.split(",")} if args.books else None
    books = [b for b in bundle["books"] if not include or b["id"] in include]
    if args.start_book:
        start_book = args.start_book.strip().lower()
        ids = [b["id"] for b in books]
        if start_book not in ids:
            raise ValueError(f"Unknown start book: {args.start_book}")
        books = books[ids.index(start_book):]

    jobs = []
    for book in books:
        for chapter, verses in enumerate(book["chapters"], start=1):
            target = AUDIO_DIR / translation / book["id"] / f"{chapter}.mp3"
            entry = progress.get("chapters", {}).get(f"{book['id']}:{chapter}", {})
            if target.exists() and target.stat().st_size > 1000 and not args.force:
                # File already exists: only queue it when the RustFS object is missing.
                if upload_enabled and not entry.get("objectKey"):
                    jobs.append((book["id"], chapter, target, False))
                continue
            if any(verse.strip() for verse in verses):
                jobs.append((book["id"], chapter, target, True))
    return jobs[: args.limit] if args.limit else jobs


def generate_chapter(text: str, pipeline: Any, voice: str) -> Any:
    import numpy as np

    parts = []
    for _, _, audio in pipeline(text, voice=voice, speed=0.92, split_pattern=r"\n+"):
        if hasattr(audio, "detach"):
            audio = audio.detach().cpu().numpy()
        parts.append(audio)
    if not parts:
        raise RuntimeError("Kokoro returned no audio")
    return np.concatenate(parts)


def resolve_device(requested: str) -> str:
    """Return 'cuda' or 'cpu'; raise when explicit CUDA is unavailable."""
    if requested == "cpu":
        return "cpu"
    import torch

    if torch.cuda.is_available():
        return "cuda"
    if requested == "cuda":
        raise RuntimeError(
            f"CUDA requested but torch {torch.__version__} has no GPU support. "
            "Install a CUDA build:\n"
            "  pip install --index-url https://download.pytorch.org/whl/cu126 torch"
        )
    return "cpu"


def describe_device(requested: str) -> str:
    try:
        import torch
    except ImportError:
        return "unknown (torch not installed)"
    try:
        device = resolve_device(requested)
    except RuntimeError:
        return f"cuda unavailable (torch {torch.__version__} is a CPU build)"
    if device == "cuda":
        return f"cuda ({torch.cuda.get_device_name(0)})"
    if torch.version.cuda is None:
        return "cpu (torch is a CPU-only build; install a CUDA wheel to use the GPU)"
    return "cpu"


def main() -> int:
    args = parse_args()
    bundle = ensure_bundle(args.translation)
    progress_file = progress_path(args.translation)
    progress = load_progress(progress_file)
    previous_speech_version = int(progress.get("speechVersion") or 1)
    finished_chapters = sum(
        1 for item in progress.get("chapters", {}).values() if item.get("status") == "done"
    )
    progress.update(
        translation=args.translation,
        provider=PROVIDER,
        model=MODEL,
        modelLicense=MODEL_LICENSE,
        voice=args.voice,
        language=args.language,
        speechVersion=SPEECH_FORMAT_VERSION,
    )
    upload_enabled = not args.no_upload and bool(os.environ.get("AUDIO_S3_ENDPOINT", "").strip())
    jobs = build_jobs(bundle, args.translation, progress, args, upload_enabled)
    print(f"Translation: {bundle['name']} ({args.translation})")
    print(f"Provider:    Kokoro local TTS ({MODEL}, {MODEL_LICENSE})")
    print(f"Voice:       {args.voice}")
    print(f"Device:      {describe_device(args.device)}")
    print(f"Upload:      {'RustFS ' + os.environ.get('AUDIO_S3_ENDPOINT', '') if upload_enabled else 'disabled (local files only)'}")
    print(f"Output:      {AUDIO_DIR / args.translation}")
    print(f"Pending:     {len(jobs):,} chapters")
    print(f"Checkpoint:  {progress_file}")
    if finished_chapters and previous_speech_version != SPEECH_FORMAT_VERSION and not args.force:
        print(
            f"Warning:     {finished_chapters} finished chapter(s) were spoken with "
            f"format v{previous_speech_version} (verse numbers included). "
            "Add --force to regenerate them without numbering.",
            file=sys.stderr,
        )
    if not jobs:
        print("Nothing to do — all selected chapters already have audio.")
        return 0
    if not args.run:
        print("DRY RUN: add --run to generate audio.")
        return 0
    if not args.yes and sys.stdin.isatty():
        if input("Generate local Kokoro narration now? [y/N] ").strip().lower() not in ("y", "yes"):
            return 1

    check_ffmpeg()
    try:
        import soundfile as sf
        from kokoro import KPipeline
    except ImportError as exc:
        print("Install worker/requirements.txt before running Kokoro.", file=sys.stderr)
        print(f"Missing dependency: {exc}", file=sys.stderr)
        return 2

    try:
        device = resolve_device(args.device)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    pipeline = KPipeline(lang_code=args.language, repo_id=MODEL_REPO, device=device)

    bucket = os.environ.get("AUDIO_S3_BUCKET", "bible-audio")
    upload_client = None
    if upload_enabled:
        try:
            upload_client = s3_client()
        except Exception as exc:  # noqa: BLE001 - uploads must never block narration
            print(f"[kokoro] Uploads disabled: {exc}", file=sys.stderr)
        if upload_client is None:
            upload_enabled = False

    pause_file = Path(args.pause_file) if args.pause_file else None
    stop_requested = False
    upload_failures = 0

    def request_stop(_signum: int, _frame: Any) -> None:
        nonlocal stop_requested
        stop_requested = True
        print("\nStop requested; finishing no new chapter and preserving the checkpoint.")

    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGTERM, request_stop)

    for index, (book_id, chapter, target, needs_generation) in enumerate(jobs, start=1):
        while pause_file and pause_file.exists() and not stop_requested:
            print(f"Paused ({pause_file}); remove it to continue.", flush=True)
            time.sleep(5)
        if stop_requested:
            break

        key = f"{book_id}:{chapter}"
        entry: dict[str, Any] = dict(progress["chapters"].get(key) or {})

        if needs_generation:
            book = next(book for book in bundle["books"] if book["id"] == book_id)
            verses = book["chapters"][chapter - 1]
            text = "\n".join(verse.strip() for verse in verses if verse.strip())
            progress["chapters"][key] = {"status": "running", "startedAt": utc_now()}
            save_progress(progress_file, progress)
            sync_progress(args.translation, progress)
            tmp_wav = target.with_suffix(".part.wav")
            tmp_mp3 = target.with_suffix(".part.mp3")
            try:
                target.parent.mkdir(parents=True, exist_ok=True)
                audio = generate_chapter(text, pipeline, args.voice)
                sf.write(tmp_wav, audio, 24000, subtype="PCM_16")
                subprocess.run(
                    ["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp_wav), "-b:a", args.bitrate, str(tmp_mp3)],
                    check=True,
                )
                tmp_mp3.replace(target)
                tmp_wav.unlink(missing_ok=True)
            except Exception as exc:  # noqa: BLE001 - one bad chapter must not stop the run
                tmp_wav.unlink(missing_ok=True)
                tmp_mp3.unlink(missing_ok=True)
                progress["chapters"][key] = {"status": "error", "error": str(exc), "updatedAt": utc_now()}
                save_progress(progress_file, progress)
                sync_progress(args.translation, progress)
                print(f"[{index:>4}/{len(jobs)}] {book_id} {chapter} failed: {exc}", file=sys.stderr)
                continue
            entry = {"status": "done", "completedAt": utc_now()}

        # The MP3 is on disk at this point. Upload problems are warnings, not failures.
        entry["path"] = str(target.relative_to(AUDIO_DIR)).replace("\\", "/")
        entry["size"] = target.stat().st_size
        entry["status"] = "done"
        entry.pop("error", None)

        if upload_client is not None:
            try:
                entry["objectKey"] = upload_audio(upload_client, bucket, target, args.translation)
                entry.pop("uploadError", None)
                upload_failures = 0
            except Exception as exc:  # noqa: BLE001 - keep the local file no matter what
                upload_failures += 1
                entry["uploadError"] = str(exc)
                print(
                    f"[{index:>4}/{len(jobs)}] {book_id} {chapter} saved locally, upload failed: {exc}",
                    file=sys.stderr,
                )
                if upload_failures >= MAX_UPLOAD_FAILURES:
                    upload_client = None
                    print(
                        "[kokoro] RustFS unreachable; continuing without uploads. "
                        "Rerun the same command later to upload finished chapters.",
                        file=sys.stderr,
                    )

        progress["chapters"][key] = entry
        save_progress(progress_file, progress)
        sync_progress(args.translation, progress)
        where = "uploaded" if entry.get("objectKey") else "local"
        print(f"[{index:>4}/{len(jobs)}] {book_id} {chapter:>3} done ({where})", flush=True)

    print("Stopped cleanly; rerun the same command to resume.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

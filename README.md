# Bible AI

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Data License: CC BY 4.0](https://img.shields.io/badge/Data_License-CC_BY_4.0-lightgrey.svg)](DATA_LICENSE.md)
[![Hugging Face Dataset](https://img.shields.io/badge/%F0%9F%A4%97%20Hugging%20Face-KJV%20Audio%20Dataset-yellow)](https://huggingface.co/datasets/Tomopas/bibleai-audio)
[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Render](https://img.shields.io/badge/Render-Deployed-46E3B7?logo=render&logoColor=white)](https://render.com)

**Bible AI** is an offline-first Bible study app featuring AI-powered comparative study perspectives, complete audio narration, and multi-device synchronization.

Designed for believers, students, and churches, Bible AI can be run **100% free with zero cloud bills** or fully self-hosted on a local church LAN.

---

## Highlights

- 📖 **Offline-First Scripture Reader**: Bundled King James Version (KJV) with zero-latency full-text search, highlights, personal notes, bookmarks, and customizable reading plans. Additional public-domain translations can be downloaded on demand.
- 🧠 **Comparative Study Perspectives**: Explore how different Christian traditions and scholarly disciplines understand each passage (Catholic, Protestant, Orthodox, Historical-Critical, Evangelical, Reformed, etc.). Notes are pre-generated using local LLMs (Ollama) so users get instant answers without needing expensive server GPUs.
- 🎙️ **Full Audio Narration**: 1,189 chapter-by-chapter narrations generated with [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) (Apache-2.0). Streamed at high speed via Hugging Face's global CDN or played through on-device TTS.
- ☁️ **100% Free Cloud Architecture**: Zero credit card required. Hosted on Render (FastAPI), MongoDB Atlas (M0 Shared), and Hugging Face Datasets (Git LFS CDN).
- 🏛️ **Church & Local LAN Ready**: Full Docker Compose stack (`api`, `mongo`, `rustfs` S3, `nginx`) for air-gapped church networks or personal servers.
- 📱 **Cross-Platform**: Android release APKs and App Bundle (Google Play ready), with Windows desktop support.

---

## Screenshots & Audio Demo

| Home & Dashboard | Book Selection | Scripture Reader | Audio Controls |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/home.png" width="200" alt="Home Dashboard" /> | <img src="docs/screenshots/books.png" width="200" alt="Book Navigation" /> | <img src="docs/screenshots/reader.png" width="200" alt="Scripture Reader" /> | <img src="docs/screenshots/audio_narration.png" width="200" alt="Audio Narration Controls" /> |

### 🎙️ Audio Narration Samples

Sample chapter narrations generated with Kokoro-82M voice `af_heart`:

- 🔊 **Old Testament**: [Genesis 1 (`genesis_chapter_1.mp3`)](docs/audio/genesis_chapter_1.mp3)
- 🔊 **New Testament**: [Matthew 1 (`matthew_chapter_1.mp3`)](docs/audio/matthew_chapter_1.mp3)

The complete 66-book audio dataset (1,189 MP3s, ~2.14 GB) is published on Hugging Face:  
👉 **[Tomopas/bibleai-audio on Hugging Face Datasets](https://huggingface.co/datasets/Tomopas/bibleai-audio)**

---

## Architecture Overview

```
                      ┌──────────────────────────────────────────────┐
                      │              Client Layer                    │
                      │  • Android App (Download via GitHub)        │
                      │  • Flutter Desktop (Windows / macOS / Linux) │
                      └──────────────┬────────────────┬──────────────┘
                                     │                │
                        API requests │                │ Audio stream (MP3)
                                     ▼                ▼
┌──────────────────────────────────────┐    ┌──────────────────────────────────────┐
│           Render (Free Web)          │    │       Hugging Face Datasets          │
│  FastAPI Backend (Docker runtime)    │    │  • 1,189 KJV MP3 files (~2.14 GB)    │
│  • /api/interpretations              │    │  • Cloudflare-accelerated CDN        │
│  • /api/audio/info                   │    │  • HTTP Range streaming support      │
│  • /api/sync                         │    │  • 100% Free, NO credit card         │
└──────────────────┬───────────────────┘    └──────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│       MongoDB Atlas (M0 Free)        │
│  • 512 MB Persistent Cloud Storage   │
│  • Pre-generated study notes & sync  │
└──────────────────────────────────────┘
```

| Component | Technology | Free Host / Runtime | Credit Card Needed? |
|---|---|---|---|
| **Mobile App** | Flutter 3.44 / Dart 3.12 | [GitHub Releases](https://github.com/tomopas/BibleAIApp/releases) | No |
| **Backend API** | FastAPI / Python 3.12 | [Render Free Web Service](https://render.com) | No |
| **Database** | MongoDB 7 | [MongoDB Atlas (M0 Free)](https://www.mongodb.com/cloud/atlas) | No |
| **Audio Storage** | Kokoro-82M MP3s (~2.1 GB) | [Hugging Face Datasets](https://huggingface.co/datasets/Tomopas/bibleai-audio) | No |
| **Worker (TTS/LLM)** | PyTorch, Kokoro, Ollama | Local PC / NVIDIA RTX GPU | No |

---

## Repository Structure

```text
├── android/                 # Android native project and Gradle build configs
├── assets/                  # Bundled KJV text, fonts, and catalog fallback
├── backend/                 # FastAPI REST API application
│   ├── ai.py                # Ollama client and study perspective templates
│   ├── app.py               # Main API routes (health, catalog, audio, sync)
│   ├── store.py             # Storage layer (MongoDB with SQLite fallback)
│   ├── Dockerfile           # Backend container definition
│   └── requirements.txt     # Python API dependencies
├── deploy/                  # Self-hosted Docker Compose stack (Mongo, RustFS, Nginx)
├── docs/                    # Documentation, screenshots, audio samples, and release guides
├── exports/                 # Portable JSON exports of interpretations
├── lib/                     # Flutter cross-platform source code
│   ├── data/                # Database helpers, audio service, API client
│   ├── state/               # Application state management (Provider)
│   └── ui/                  # Screens, reader, audio player, theme
├── scripts/                 # Automation scripts (e.g. keystore generator)
├── shared/                  # Shared perspective definitions (perspectives.json)
├── tools/                   # Canon mappings and dataset tools
└── worker/                  # Batch data generation scripts (Kokoro TTS, Ollama)
    ├── generate_kokoro_audio.py
    └── generator.py
```

---

## 1. Cloud Deployment (100% Free, No Credit Card)

You can host the entire backend and audio delivery without spending a cent:

### Step 1: Database (MongoDB Atlas M0 Free)
1. Sign up at [mongodb.com/cloud/atlas](https://www.mongodb.com/cloud/atlas) (select the Free M0 tier).
2. Under **Network Access**, add `0.0.0.0/0` (allow access from anywhere).
3. Under **Database Access**, create a user and copy the connection string:
   ```text
   mongodb+srv://<user>:<password>@cluster0.abcde.mongodb.net/?retryWrites=true&w=majority
   ```
4. Import the included interpretations export (`exports/interpretations.json`):
   ```bash
   mongoimport --uri "mongodb+srv://<user>:<password>@cluster0.abcde.mongodb.net/bibleai" \
               --collection interpretations \
               --file exports/interpretations.json \
               --jsonArray
   ```

### Step 2: Audio CDN (Hugging Face Datasets)
The full King James Version narration dataset is already public at [Tomopas/bibleai-audio](https://huggingface.co/datasets/Tomopas/bibleai-audio).

If you want to host your own audio repository:
1. Create a public dataset on [huggingface.co](https://huggingface.co).
2. Upload the `audio/` directory via the Hugging Face CLI:
   ```bash
   pip install huggingface_hub
   huggingface-cli login
   huggingface-cli upload <YOUR_USERNAME>/bibleai-audio ./data/audio/en-kjv audio/en-kjv --repo-type=dataset
   ```

### Step 3: Backend API (Render Free Web Service)
This repository includes a [`render.yaml`](render.yaml) blueprint:
1. Create a free account on [render.com](https://render.com).
2. Click **New +** -> **Web Service** and connect your GitHub repository.
3. Configure:
   - **Runtime**: `Docker`
   - **Dockerfile Path**: `backend/Dockerfile`
   - **Docker Context**: `.`
   - **Plan**: `Free`
   - **Health Check Path**: `/api/health`
4. Set Environment Variables:
   - `MONGO_URI`: Your MongoDB Atlas connection string.
   - `MONGO_DB`: `bibleai`
   - `BIBLEAI_LIVE_GENERATION`: `0`
   - `AUDIO_PUBLIC_BASE_URL`: `https://huggingface.co/datasets/Tomopas/bibleai-audio/resolve/main`
   - `AUDIO_CDN_ALWAYS_AVAILABLE`: `1`
   - `BIBLE_AI_CORS_ORIGINS`: `*`
5. Click **Create Web Service**. Render will build and deploy your API with free HTTPS:
   ```text
   https://bibleai-api.onrender.com/api/health
   ```

> [!NOTE]
> Render free web services spin down after 15 minutes of inactivity and take ~30 seconds to wake up on the first request. Because Bible AI is offline-first, users can read Scripture and play audio instantly—only online study notes and cloud sync query the API.

---

## 2. Self-Hosted / Local Church LAN Deployment

If you prefer complete data sovereignty, want to run offline, or serve a local congregation over Wi-Fi:

### Requirements
- Docker with Compose v2
- Port 80 available on the host machine

### Setup
1. Copy the example environment file:
   ```bash
   cp deploy/.env.example deploy/.env
   ```
2. Set your server's LAN IP:
   ```ini
   AUDIO_PUBLIC_BASE_URL=http://192.168.1.10
   AUDIO_S3_SECRET_KEY=generate-a-random-secret
   ```
3. Start the stack:
   ```bash
   docker compose -f deploy/docker-compose.yml up -d --build
   ```
4. Check health:
   ```bash
   curl http://127.0.0.1/api/health
   ```

The local stack includes:
- **FastAPI**: REST API on port 80 (via Nginx reverse proxy).
- **MongoDB**: Storage for study notes and sync.
- **RustFS (S3)**: High-speed local S3-compatible audio storage on port 9000.
- **Nginx**: Static audio streaming and SSL termination.

---

## 3. Flutter App

### Download Release Binaries
Pre-built installable APKs are available on the [Releases](https://github.com/tomopas/BibleAIApp/releases) page:
- `BibleAI-vX.Y.Z-arm64-v8a.apk`: Modern Android smartphones & tablets (recommended).
- `BibleAI-vX.Y.Z-armeabi-v7a.apk`: Older 32-bit Android devices.
- `BibleAI-vX.Y.Z-x86_64.apk`: Android emulators & ChromeOS.
- `BibleAI-vX.Y.Z.aab`: Android App Bundle for Google Play Store upload.

### Connecting the App to Your Backend
The app can connect to any hosted or local Bible AI API instance:
- **In-App Settings**: Open **Settings → Server** (gear icon) and enter your backend URL:
  ```text
  https://bibleai-api.onrender.com
  ```
  *(Or `http://192.168.1.10` for a local LAN server, or `http://10.0.2.2:8765` for Android Emulator).*
- **Build-Time Injection**: When building APKs, inject the URL directly:
  ```bash
  flutter build apk --release --dart-define=API_BASE_URL=https://bibleai-api.onrender.com
  ```

### Build from Source
```bash
# Clone the repository
git clone https://github.com/tomopas/BibleAIApp.git
cd BibleAIApp

# Fetch dependencies and run static analysis
flutter pub get
flutter analyze
flutter test

# Run on connected device or emulator
flutter run
```

For complete instructions on generating release keys, signing configurations, and GitHub Actions automation, see the [Android Release Guide](docs/RELEASE.md).

---

## 4. Python Worker (Data Generation)

The Python worker is decoupled from the backend and is used for long-running batch generation jobs.

### Setup Environment
```bash
cd worker
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### Audio Generation with Kokoro-82M
Narration is generated chapter by chapter. Generation is fully resumable:

```bash
# Generate 1 chapter test (CPU)
python worker/generate_kokoro_audio.py --run --translation en-kjv --books GEN --limit 1 --yes

# Generate complete Bible with NVIDIA CUDA acceleration
python worker/generate_kokoro_audio.py --run --translation en-kjv --device cuda --yes
```

To enable GPU acceleration on Windows, install the PyTorch CUDA wheel:
```powershell
pip install torch --index-url https://download.pytorch.org/whl/cu126
```

### Study Perspectives with Ollama
Generate comparative theological and scholarly notes using local open-source LLMs:

```bash
# Start Ollama
ollama run qwen3.5:9b

# Check current database coverage
python worker/generator.py --status

# Generate comparative perspectives for Genesis 1
python worker/generator.py --run --model qwen3.5:9b --books gen --limit 1 --perspectives core --yes
```

The worker supports standard core perspectives:
- `catholic` — Roman Catholic theological & patristic commentary.
- `protestant` — Protestant & Evangelical theological perspectives.
- `orthodox` — Eastern Orthodox liturgical and church father interpretations.
- `historical_critical` — Modern scholarly, historical, and textual criticism.

---

## Configuration Reference

Server configuration can be set via environment variables (or `deploy/.env` for Docker):

| Variable | Description | Default |
|---|---|---|
| `MONGO_URI` | MongoDB connection URI (Atlas or local) | `mongodb://127.0.0.1:27017` |
| `MONGO_DB` | Database name | `bibleai` |
| `AUDIO_PUBLIC_BASE_URL` | Base URL where chapter MP3s are served | `""` |
| `AUDIO_CDN_ALWAYS_AVAILABLE` | Report CDN audio as available without local files | `1` |
| `BIBLEAI_LIVE_GENERATION` | Allow on-demand Ollama generation via API | `0` |
| `BIBLE_AI_CORS_ORIGINS` | Allowed origins for web clients | `*` |
| `PORT` | Listening port for FastAPI | `8765` |
| `AUDIO_S3_ENDPOINT` | Local S3/RustFS endpoint (for local Docker stack) | `http://127.0.0.1:9000` |
| `AUDIO_S3_BUCKET` | Local S3 bucket name | `bible-audio` |

---

## Licensing & Attribution

- **Source Code**: Licensed under the [Apache License 2.0](LICENSE). See [NOTICE](NOTICE).
- **Generated Datasets**: Released under [Creative Commons Attribution 4.0 (CC BY 4.0)](DATA_LICENSE.md).
- **Scripture Text**: The King James Version (KJV) is in the public domain in the United States and most jurisdictions.
- **Kokoro-82M**: Licensed under Apache-2.0 by [hexgrad](https://huggingface.co/hexgrad/Kokoro-82M).
- **Fonts**: The bundled [Lora](https://fonts.google.com/specimen/Lora) font is licensed under the SIL Open Font License.
- **Translations Catalog**: Downloaded translations are sourced from public-domain and open-license repositories at [scrollmapper/bible_databases](https://github.com/scrollmapper/bible_databases).

# Android Release Guide

This document describes how to generate signing credentials, configure automated GitHub Actions releases, build local release packages, and publish Bible AI to GitHub Releases or Google Play.

---

## 1. Release Architecture

The Android release process produces two formats:

| Format | File Pattern | Purpose |
|---|---|---|
| **AAB (Android App Bundle)** | `BibleAI-vX.Y.Z.aab` | Upload format for Google Play Store (Google generates device-tailored APKs). |
| **Split APKs (arm64-v8a, armeabi-v7a, x86_64)** | `BibleAI-vX.Y.Z-<abi>.apk` | Standalone installable APKs for direct download / GitHub Releases. Split builds keep file size minimal (avoiding universal APK bloat). |

### Security & Network defaults
- **Release builds enforce HTTPS**: By default, cleartext (`http://`) traffic is disabled in release builds.
- **LAN testing exception**: If testing against a local church LAN server without TLS, pass `-PallowCleartext=true` during gradle build.
- **Backend URL injection**: Set at build time using `--dart-define=API_BASE_URL=https://api.yourdomain.com`. Users can still override this in the in-app Settings screen.

---

## 2. Generating Signing Credentials

A release build requires an upload keystore (`upload-keystore.jks`) and a configuration file (`android/key.properties`). Both are **gitignored** to prevent accidental credential leakage.

### Option A: Automated (PowerShell on Windows)

Run the included helper script:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new-upload-keystore.ps1
```

This script:
1. Generates an RSA 4096-bit PKCS12 keystore at `android/app/upload-keystore.jks`.
2. Generates a strong random password.
3. Automatically writes `android/key.properties`.
4. Outputs the exact GitHub Secrets and Base64 string to copy into your repository.

### Option B: Manual (keytool)

1. Generate keystore:
   ```bash
   keytool -genkeypair -v \
     -keystore android/app/upload-keystore.jks \
     -storetype PKCS12 \
     -alias upload \
     -keyalg RSA \
     -keysize 4096 \
     -validity 10000
   ```

2. Create `android/key.properties` (based on `android/key.properties.example`):
   ```properties
   storeFile=upload-keystore.jks
   storePassword=your-keystore-password
   keyAlias=upload
   keyPassword=your-keystore-password
   ```

> [!CAUTION]
> **BACK UP `android/app/upload-keystore.jks` IMMEDIATELY.**
> If you lose your upload keystore, you cannot update an existing app on Google Play without an involved identity-recovery process with Google support. Keep an offline copy in a secure password manager or encrypted drive.

---

## 3. Configuring GitHub Actions for Automated Releases

Automated releases trigger whenever you push a version tag (`v*`).

Go to your GitHub repository:
**Settings** -> **Secrets and variables** -> **Actions**

### Required Secrets
Add the following under **Repository secrets**:

| Secret Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded string of `android/app/upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Password used when creating the keystore |
| `ANDROID_KEY_ALIAS` | Key alias (default: `upload`) |
| `ANDROID_KEY_PASSWORD` | Key password (matches keystore password for PKCS12) |

To encode the keystore to Base64 manually:
- **PowerShell**: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/upload-keystore.jks")) | Set-Clipboard`
- **Linux / macOS**: `base64 -w 0 android/app/upload-keystore.jks | pbcopy`

### Optional Variables
Add under **Repository variables**:

| Variable Name | Value | Description |
|---|---|---|
| `API_BASE_URL` | `https://api.yourdomain.com` | Base URL of your hosted FastAPI backend (e.g., on Render or Heroku). |

---

## 4. Release Workflow & Versioning

1. **Update `pubspec.yaml`**:
   Increment `version: <name>+<codeNumber>`:
   ```yaml
   version: 1.0.1+2
   ```
   *Note*: Google Play requires an incremented `codeNumber` (+2, +3, ...) for every upload.

2. **Commit and tag**:
   ```bash
   git add pubspec.yaml
   git commit -m "chore(release): bump version to 1.0.1+2"
   git tag v1.0.1
   git push origin main --tags
   ```

3. **GitHub Actions handles the rest**:
   The `Android Release` workflow will:
   - Verify the tag version matches `pubspec.yaml`.
   - Run `flutter analyze` and `flutter test`.
   - Restore the upload keystore from secrets.
   - Build `BibleAI-v1.0.1.aab` and split APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
   - Generate SHA-256 checksums (`SHA256SUMS.txt`).
   - Create a GitHub Release with all binary assets attached.

---

## 5. Local Release Builds

If building locally on your workstation:

```bash
# 1. Standard production release (HTTPS-only, using upload keystore if present):
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yourdomain.com
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://api.yourdomain.com

# 2. LAN / Local test build (allows plain http:// server URLs):
flutter build apk --release --split-per-abi -PallowCleartext=true
```

Built artifacts are located at:
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- APKs: `build/app/outputs/flutter-apk/app-<abi>-release.apk`

---

## 6. Publishing Channels

### Option A: GitHub Releases (Zero Cost & Fast)
- Great for direct distribution, beta testing, and sideloading.
- Users can install `BibleAI-vX.Y.Z-arm64-v8a.apk` directly on Android.
- Compatible with [Obtainium](https://github.com/ImranR98/Obtainium) for automatic app updates directly from GitHub releases.

### Option B: Google Play Store
- **One-time developer fee**: Google Play requires a $25 one-time registration fee.
- **Testing requirement**: New personal developer accounts must run a closed test with at least 12 testers opted in for 14 days before applying for production access.
- **Upload artifact**: Upload `BibleAI-vX.Y.Z.aab` to Play Console -> Production / Closed Testing.
- **Application ID**: The default is `com.bibleai.bible_ai_app`. If you wish to customize it (e.g. `app.bibleai.reader`), change `applicationId` in `android/app/build.gradle.kts` **before** uploading your very first build (it cannot be changed afterwards).

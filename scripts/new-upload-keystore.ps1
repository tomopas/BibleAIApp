<#
.SYNOPSIS
  Generates an Android upload keystore and writes android/key.properties.

.DESCRIPTION
  Creates an RSA 4096-bit PKCS12 upload keystore at android/app/upload-keystore.jks,
  generates a random strong password, and writes android/key.properties. Both files
  are already gitignored.

  After running:
  1. BACK UP android/app/upload-keystore.jks to a safe password manager or offline USB.
     Losing it means you can never push updates to the Play Store.
  2. For GitHub Actions automated releases, add the printed secrets to:
     Repo Settings -> Secrets and variables -> Actions
#>

[CmdletBinding()]
param(
  [string]$Alias = "upload",
  [int]$ValidityDays = 10000,
  [string]$DistinguishedName = "CN=Bible AI, OU=Mobile, O=Bible AI, L=Unknown, ST=Unknown, C=US"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$appDir = Join-Path $repoRoot "android\app"
$keystorePath = Join-Path $appDir "upload-keystore.jks"
$propsPath = Join-Path $repoRoot "android\key.properties"

if (Test-Path $keystorePath) {
  Write-Error "Keystore already exists at $keystorePath. Refusing to overwrite. Delete it first if you really want to regenerate it."
}

# Find keytool from JDK.
$keytool = $null
if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\keytool.exe"))) {
  $keytool = Join-Path $env:JAVA_HOME "bin\keytool.exe"
} else {
  $cmd = Get-Command keytool.exe -ErrorAction SilentlyContinue
  if ($cmd) {
    $keytool = $cmd.Source
  }
}

if (-not $keytool) {
  Write-Error "keytool.exe not found. Set JAVA_HOME or add the JDK bin directory to PATH."
}

# Generate a strong 32-character alphanumeric password (avoids shell escaping pitfalls).
$chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 32
$rng.GetBytes($bytes)
$passwordChars = foreach ($b in $bytes) { $chars[$b % $chars.Length] }
$password = -join $passwordChars

Write-Host "Creating keystore with keytool: $keytool"
& $keytool -genkeypair `
  -v `
  -keystore $keystorePath `
  -storetype PKCS12 `
  -alias $Alias `
  -keyalg RSA `
  -keysize 4096 `
  -validity $ValidityDays `
  -storepass $password `
  -keypass $password `
  -dname $DistinguishedName

if ($LASTEXITCODE -ne 0) {
  Write-Error "keytool failed with exit code $LASTEXITCODE"
}

# Write android/key.properties.
$propsContent = @"
storeFile=upload-keystore.jks
storePassword=$password
keyAlias=$Alias
keyPassword=$password
"@
Set-Content -Path $propsPath -Value $propsContent -Encoding Ascii -NoNewline

# Base64 encode the keystore so it can be added as a GitHub secret.
$keystoreBytes = [System.IO.File]::ReadAllBytes($keystorePath)
$keystoreBase64 = [Convert]::ToBase64String($keystoreBytes)

Write-Host ""
Write-Host "=== Upload keystore generated ===" -ForegroundColor Green
Write-Host "Keystore:   $keystorePath"
Write-Host "Properties: $propsPath"
Write-Host ""
Write-Host "WARNING: BACK UP $keystorePath NOW." -ForegroundColor Yellow
Write-Host "If you lose this file, you can NEVER update the app on the Google Play Store." -ForegroundColor Yellow
Write-Host ""
Write-Host "=== GitHub Actions Secrets ===" -ForegroundColor Cyan
Write-Host "Add these in your repository: Settings -> Secrets and variables -> Actions -> Secrets:"
Write-Host "  ANDROID_KEYSTORE_PASSWORD : $password"
Write-Host "  ANDROID_KEY_ALIAS         : $Alias"
Write-Host "  ANDROID_KEY_PASSWORD      : $password"
Write-Host "  ANDROID_KEYSTORE_BASE64   : (use the value below)"
Write-Host ""
Write-Host "Base64 keystore (one continuous line):"
Write-Host $keystoreBase64
Write-Host ""
Write-Host "=== Optional Repository Variable ===" -ForegroundColor Cyan
Write-Host "Add under Settings -> Secrets and variables -> Actions -> Variables:"
Write-Host "  API_BASE_URL : https://api.yourdomain.com (or leave empty for emulator default)"
Write-Host ""

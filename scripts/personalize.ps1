<#
.SYNOPSIS
    Personalize Bible AI for your church or organization (PowerShell wrapper).

.DESCRIPTION
    Wraps scripts/personalize.py to configure custom Bible/app name, church details,
    website, and assets for Android, Web/PWA, and desktop builds.

.EXAMPLE
    .\scripts\personalize.ps1
    .\scripts\personalize.ps1 -Config church_config.example.json
    .\scripts\personalize.ps1 -Name "Grace Bible" -Org "Grace Church" -Website "https://gracechurch.org"
    .\scripts\personalize.ps1 -Reset
#>

[CmdletBinding()]
param(
    [string]$Config,
    [switch]$Reset,
    [string]$Name,
    [string]$ShortName,
    [string]$Org,
    [string]$Tagline,
    [string]$WelcomeTitle,
    [string]$WelcomeMessage,
    [string]$Website,
    [string]$Email,
    [string]$ServiceInfo,
    [string]$Icon,
    [string]$Banner,
    [switch]$DryRun
)

$scriptPath = Join-Path $PSScriptRoot "personalize.py"

$pythonArgs = @($scriptPath)

if ($Reset) {
    $pythonArgs += "--reset"
}
if ($Config) {
    $pythonArgs += @("--config", $Config)
}
if ($Name) {
    $pythonArgs += @("--name", $Name)
}
if ($ShortName) {
    $pythonArgs += @("--short-name", $ShortName)
}
if ($Org) {
    $pythonArgs += @("--org", $Org)
}
if ($Tagline) {
    $pythonArgs += @("--tagline", $Tagline)
}
if ($WelcomeTitle) {
    $pythonArgs += @("--welcome-title", $WelcomeTitle)
}
if ($WelcomeMessage) {
    $pythonArgs += @("--welcome-message", $WelcomeMessage)
}
if ($Website) {
    $pythonArgs += @("--website", $Website)
}
if ($Email) {
    $pythonArgs += @("--email", $Email)
}
if ($ServiceInfo) {
    $pythonArgs += @("--service-info", $ServiceInfo)
}
if ($Icon) {
    $pythonArgs += @("--icon", $Icon)
}
if ($Banner) {
    $pythonArgs += @("--banner", $Banner)
}
if ($DryRun) {
    $pythonArgs += "--dry-run"
}

python @pythonArgs

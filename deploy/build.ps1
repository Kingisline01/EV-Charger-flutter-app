<#
.SYNOPSIS
  ChargeShare Windows PowerShell Build & Deployment Script

.DESCRIPTION
  Builds ChargeShare Flutter Web and/or Android APK/Bundle with custom backend parameters
  and can automatically upload web assets to your Ubuntu server via SCP.

.EXAMPLE
  .\deploy\build.ps1 -Target web -BackendUrl https://api.yourdomain.com -AnonKey "ey..."
  .\deploy\build.ps1 -Target apk -BackendUrl https://api.yourdomain.com
  .\deploy\build.ps1 -Target web -DeployServer root@your-server-ip
#>

param (
    [ValidateSet("web", "apk", "bundle", "all")]
    [string]$Target = "web",

    [string]$BackendUrl = "https://api.yourdomain.com",
    [string]$AnonKey = "",
    [switch]$DemoMode = $false,
    [string]$DeployServer = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "⚡ ChargeShare Flutter Build Script" -ForegroundColor Green
Write-Host "• Target:        $Target" -ForegroundColor Yellow
Write-Host "• Backend URL:   $BackendUrl" -ForegroundColor Yellow
Write-Host "• Demo Mode:     $DemoMode" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# Read fallback key from .env or deploy/.env.production if not provided
if (-not $AnonKey) {
    if (Test-Path "$ScriptDir\.env.production") {
        $envMatch = Get-Content "$ScriptDir\.env.production" | Select-String "^ANON_KEY=(.+)$"
        if ($envMatch) {
            $AnonKey = $envMatch.Matches[0].Groups[1].Value.Trim()
            Write-Host "Loaded ANON_KEY from deploy/.env.production" -ForegroundColor DarkGray
        }
    }
    if (-not $AnonKey -and (Test-Path "$ProjectRoot\.env")) {
        $envMatch = Get-Content "$ProjectRoot\.env" | Select-String "^SUPABASE_ANON_KEY=(.+)$"
        if ($envMatch) {
            $AnonKey = $envMatch.Matches[0].Groups[1].Value.Trim()
            Write-Host "Loaded ANON_KEY from .env" -ForegroundColor DarkGray
        }
    }
}

$DartDefines = @(
    "--dart-define=SUPABASE_URL=$BackendUrl",
    "--dart-define=SUPABASE_ANON_KEY=$AnonKey",
    "--dart-define=DEMO_MODE=$($DemoMode.ToString().ToLower())"
)

Write-Host "`n[1/3] Running flutter pub get..." -ForegroundColor Cyan
flutter pub get

if ($Target -eq "web" -or $Target -eq "all") {
    Write-Host "`n[2/3] Compiling Flutter Web (Release)..." -ForegroundColor Cyan
    flutter build web --release @DartDefines

    Write-Host "`nWeb build completed: build/web/" -ForegroundColor Green

    if ($DeployServer) {
        Write-Host "Syncing web assets to Ubuntu server ($DeployServer:/var/www/chargeshare/web/)..." -ForegroundColor Yellow
        scp -r "$ProjectRoot\build\web\*" "${DeployServer}:/var/www/chargeshare/web/"
        Write-Host "✅ Web frontend synced to Ubuntu server successfully!" -ForegroundColor Green
    }
}

if ($Target -eq "apk" -or $Target -eq "all") {
    Write-Host "`nCompiling Android Release APK..." -ForegroundColor Cyan
    flutter build apk --release @DartDefines
    Write-Host "✅ Android APK created: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
}

if ($Target -eq "bundle" -or $Target -eq "all") {
    Write-Host "`nCompiling Android App Bundle (AAB)..." -ForegroundColor Cyan
    flutter build appbundle --release @DartDefines
    Write-Host "✅ Android App Bundle created: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "🎉 Build process finished successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

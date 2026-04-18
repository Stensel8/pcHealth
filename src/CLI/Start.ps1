#Requires -Version 5.1
# ============================================================================
# pcHealth -- CLI Launcher (Windows)
# Checks dependencies, elevates to admin, then starts the CLI.
# Stays PS 5.1-compatible so it can bootstrap PS7 on fresh systems.
# ============================================================================

$ErrorActionPreference = 'Stop'

$onLinux = [bool]$IsLinux

if (-not $onLinux) {
    # -- 0. Minimum OS version: Windows build 26200 (25H2) ------------------------
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 26200) {
        Write-Host "[!!] pcHealth requires Windows build 26200 (25H2) or higher." -ForegroundColor Red
        Write-Host "     Your build: $build" -ForegroundColor Red
        Write-Host "     Update Windows and try again." -ForegroundColor Yellow
        Read-Host 'Press Enter to exit'
        exit 1
    }

    # -- 1. Elevate ----------------------------------------------------------------
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        Start-Process $shell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# -- 2. Dependency check -------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] Checking dependencies...' -ForegroundColor Cyan

$pwshOk = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)

$pad = 24
$label = 'PowerShell 7'
$dots  = '.' * ($pad - $label.Length)
if ($pwshOk) {
    Write-Host "  $label $dots OK" -ForegroundColor Green
} else {
    Write-Host "  $label $dots NOT FOUND" -ForegroundColor Red
}

# -- 3. Install missing dependencies ------------------------------------------
if (-not $pwshOk) {
    Write-Host ''
    Write-Host '[pcHealth] PowerShell 7 is required to run this application.' -ForegroundColor Yellow

    $answer = Read-Host '           Install now via winget? [Y/N]'
    if ($answer -notmatch '^[Yy]') {
        Write-Host ''
        Write-Host '[!!] Cannot continue without PowerShell 7.' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host '[!!] winget is not available. Install PowerShell 7 manually:' -ForegroundColor Red
        Write-Host '     https://aka.ms/powershell' -ForegroundColor Cyan
        Read-Host 'Press Enter to exit'
        exit 1
    }

    Write-Host ''
    Write-Host '[pcHealth] Installing PowerShell 7...' -ForegroundColor Cyan
    winget install --id Microsoft.PowerShell -e --silent `
        --accept-package-agreements --accept-source-agreements

    # Refresh PATH so pwsh is findable in the current session.
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host '[!!] Installation completed but pwsh was not found. Please restart and try again.' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }

    Write-Host '[OK] PowerShell 7 installed.' -ForegroundColor Green
}

# -- 4. Launch CLI -------------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] All dependencies satisfied. Starting pcHealth...' -ForegroundColor Green
Write-Host ''

$appScript = Join-Path $PSScriptRoot 'app.ps1'
& pwsh -NoProfile -ExecutionPolicy Bypass -File $appScript

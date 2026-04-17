#Requires -Version 5.1
# ============================================================================
# pcHealth — Windows Launcher
# Checks dependencies (PowerShell 7, winget), elevates, then starts the CLI.
# Compatible with PS 5.1 so it can bootstrap PS7 from any Windows system.
# ============================================================================

$ErrorActionPreference = 'Stop'

# ── 0. Minimum OS version: Windows build 26200 (25H2) ────────────────────────
$build = [System.Environment]::OSVersion.Version.Build
if ($build -lt 26200) {
    Write-Host "[!!] pcHealth requires Windows build 26200 (25H2) or higher." -ForegroundColor Red
    Write-Host "     Your build: $build" -ForegroundColor Red
    Write-Host "     Update Windows and try again." -ForegroundColor Yellow
    Read-Host 'Press Enter to exit'
    exit 1
}

# ── 1. Elevate ────────────────────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    Start-Process $shell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ── 2. Ensure PowerShell 7 ────────────────────────────────────────────────────
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Write-Host '[pcHealth] PowerShell 7 not found. Installing via winget...' -ForegroundColor Yellow

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host '[!!] winget is not available. Install PowerShell 7 manually:' -ForegroundColor Red
        Write-Host '     https://aka.ms/powershell' -ForegroundColor Cyan
        Read-Host 'Press Enter to exit'
        exit 1
    }

    winget install --id Microsoft.PowerShell -e --silent `
        --accept-package-agreements --accept-source-agreements

    # Refresh PATH so pwsh is findable in the current session
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host '[!!] Installation completed but pwsh was not found. Please restart and try again.' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }

    Write-Host '[OK] PowerShell 7 installed.' -ForegroundColor Green
}

# ── 3. Launch CLI ─────────────────────────────────────────────────────────────
$cliScript = Join-Path $PSScriptRoot 'src\CLI\Start.ps1'
& pwsh -NoProfile -ExecutionPolicy Bypass -File $cliScript

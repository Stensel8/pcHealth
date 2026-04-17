# ============================================================================
# pcHealth — Windows 10
# Entry point. Requires PowerShell 7+ and Administrator privileges.
# ============================================================================

$ErrorActionPreference = 'Stop'

# --- Admin check: re-launch elevated if not already running as administrator.
# This replaces #Requires -RunAsAdministrator, which would just crash with a
# cryptic error. Instead we silently re-launch so the user only sees one UAC prompt.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host 'Administrator privileges required. Relaunching elevated...' -ForegroundColor Yellow
    # Prefer pwsh (PS7) for the elevated session; fall back to Windows PowerShell 5.
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    Start-Process -FilePath $shell `
        -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

# --- PS7 check: give a clear download hint instead of a cryptic parse error.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host 'ERROR: PowerShell 7 or higher is required to run pcHealth.' -ForegroundColor Red
    Write-Host 'Download the latest version at: https://aka.ms/powershell' -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

# --- Console resize: wide enough for hardware tables, tall enough for menus.
try {
    $ui  = $Host.UI.RawUI
    $buf = $ui.BufferSize
    $buf.Width = 220
    $ui.BufferSize = $buf          # buffer must be set before window (window <= buffer)
    $win         = $ui.WindowSize
    $win.Width   = [Math]::Min(220, $ui.MaxPhysicalWindowSize.Width)
    $win.Height  = [Math]::Min(50,  $ui.MaxPhysicalWindowSize.Height)
    $ui.WindowSize = $win
} catch {
    Write-Verbose "Console resize skipped on non-interactive host: $_"
}

# $Global:pcHealthRoot is used by Tools.ps1 to build paths to the tools/ folder.
# It must be set before dot-sourcing the menus so they can reference it at call time.
$Global:pcHealthRoot = $PSScriptRoot

# Read the central VERSION file from the repo root so menus can display it
# without hardcoding the version in individual scripts.
$versionFile = Join-Path $PSScriptRoot '..\..\VERSION'
$Global:PcVersion = if (Test-Path $versionFile) {
    (Get-Content $versionFile -Raw).Trim()
} else {
    'unknown'
}

# Dot-sourcing (. operator) loads each file into the current session so all
# functions defined inside them become available here, just like defining them inline.
# Order matters: Helpers must load first because Main/Tools/Programs call its functions.
. "$PSScriptRoot\menus\Helpers.ps1"
. "$PSScriptRoot\menus\Main.ps1"
. "$PSScriptRoot\menus\Tools.ps1"
. "$PSScriptRoot\menus\Programs.ps1"

Show-MainMenu

#Requires -Version 7.0
# ============================================================================
# pcHealth — CLI
# Auto-detects platform (Windows 10/11/Linux) and loads menus.
# ============================================================================

$ErrorActionPreference = 'Stop'

# ── Platform detection + minimum version guards ───────────────────────────────
if ($IsLinux) {
    # Require kernel 7.0+
    $kernelVersion = (uname -r)
    $kernelMajor   = [int]($kernelVersion -split '[\.\-]')[0]
    if ($kernelMajor -lt 7) {
        Write-Host "[!!] pcHealth requires Linux kernel 7.0 or higher." -ForegroundColor Red
        Write-Host "     Your kernel: $kernelVersion" -ForegroundColor Red
        exit 1
    }
    $Global:PcPlatform      = 'Linux'
    $Global:PcPlatformLabel = 'Linux'
} else {
    # Require Windows build 19045 (Windows 10 22H2) or higher
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 19045) {
        Write-Host "[!!] pcHealth requires Windows build 19045 (Windows 10 22H2) or higher." -ForegroundColor Red
        Write-Host "     Your build: $build" -ForegroundColor Red
        exit 1
    }
    if ($build -ge 22000) {
        $Global:PcPlatform      = 'Windows11'
        $Global:PcPlatformLabel = 'Windows 11'
    } else {
        $Global:PcPlatform      = 'Windows10'
        $Global:PcPlatformLabel = 'Windows 10'
    }
}

# Console resize — Windows only. Terminal width/height on Linux is managed by
# the shell and cannot be set programmatically via RawUI on most hosts.
if (-not $IsLinux) {
    try {
        $ui        = $Host.UI.RawUI
        $buf       = $ui.BufferSize
        $buf.Width = 220
        $ui.BufferSize = $buf
        $win           = $ui.WindowSize
        $win.Width     = [Math]::Min(220, $ui.MaxPhysicalWindowSize.Width)
        $win.Height    = [Math]::Min(50,  $ui.MaxPhysicalWindowSize.Height)
        $ui.WindowSize = $win
    } catch {
        Write-Verbose "Console resize skipped on non-interactive host: $_"
    }
}

# $Global:pcHealthRoot is used by menus to resolve the tools/ path.
# Set before dot-sourcing so menus can reference it at load time.
$Global:pcHealthRoot = $PSScriptRoot

$versionFile = Join-Path $PSScriptRoot '..' 'VERSION'
$Global:PcVersion = if (Test-Path $versionFile) {
    (Get-Content $versionFile -Raw).Trim()
} else { 'unknown' }

# Order matters: Helpers must load before Main/Tools/Programs.
. (Join-Path $PSScriptRoot 'menus' 'Helpers.ps1')
. (Join-Path $PSScriptRoot 'menus' 'Main.ps1')
. (Join-Path $PSScriptRoot 'menus' 'Tools.ps1')
. (Join-Path $PSScriptRoot 'menus' 'Programs.ps1')

Show-MainMenu

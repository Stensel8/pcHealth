#Requires -Version 7.0
# ============================================================================
# pcHealth -- CLI
# Auto-detects platform (Windows/Linux) and loads menus.
# ============================================================================

$ErrorActionPreference = 'Stop'

# -- Platform detection + version guards ---------------------------------------
if ($IsLinux) {
    # Also checked in start.sh; repeated here as safety net for direct invocation.
    # Hard minimum: kernel 6.0. Recommended: 7.0.
    $kernelVersion = (uname -r)
    $kernelMajor   = [int]($kernelVersion -split '[\.\-]')[0]
    if ($kernelMajor -lt 6) {
        Write-Host "[!!] pcHealth cannot run on kernel $kernelVersion." -ForegroundColor Red
        Write-Host "     Minimum required: kernel 6.0." -ForegroundColor Red
        exit 1
    } elseif ($kernelMajor -lt 7) {
        Write-Host "[!] Your kernel ($kernelVersion) is below the recommended version (7.0)." -ForegroundColor Yellow
        Write-Host "    Some features may not work correctly. Consider updating your kernel." -ForegroundColor Yellow
        Write-Host "    https://www.kernel.org/" -ForegroundColor DarkGray
        Write-Host ""
    }
    $Global:PcPlatform      = 'Linux'
    $Global:PcPlatformLabel = 'Linux'
} elseif ($IsWindows) {
    # Also checked in Start.ps1 before elevation; repeated here as safety net.
    # Hard minimum: build 19045 (Win 10 22H2). Recommended: 26200 (Win 11 25H2).
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 19045) {
        Write-Host "[!!] pcHealth cannot run on Windows build $build." -ForegroundColor Red
        Write-Host "     Minimum required: build 19045 (Windows 10 version 22H2)." -ForegroundColor Red
        Write-Host "     Please upgrade your system." -ForegroundColor Yellow
        exit 1
    } elseif ($build -lt 26200) {
        Write-Host "[!] Your Windows build ($build) is below the recommended version (26200 / Windows 11 25H2)." -ForegroundColor Yellow
        Write-Host "    Some features may not work correctly. Consider updating Windows." -ForegroundColor Yellow
        Write-Host "    https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information" -ForegroundColor DarkGray
        Write-Host "    https://learn.microsoft.com/en-us/windows/release-health/release-information" -ForegroundColor DarkGray
        Write-Host ""
    }
    $Global:PcPlatform      = 'Windows'
    $Global:PcPlatformLabel = 'Windows'
} else {
    Write-Host "[!!] Unsupported platform. pcHealth supports Windows and Linux only." -ForegroundColor Red
    exit 1
}

# Console resize -- Windows only. Terminal width/height on Linux is managed by
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

$versionFile = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'VERSION'
$Global:PcVersion = if (Test-Path $versionFile) {
    (Get-Content $versionFile -Raw).Trim()
} else { 'unknown' }

# Order matters: Helpers must load before Main/Tools/Programs.
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Helpers.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Main.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Tools.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath 'menus' -AdditionalChildPath 'Programs.ps1')

Show-MainMenu

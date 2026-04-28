#Requires -Version 5.1
# ============================================================================
# pcHealth -- CLI Launcher (Windows)
# Checks dependencies, elevates to admin, then starts the CLI.
# Stays PS 5.1-compatible so it can bootstrap PS7 on fresh systems.
# ============================================================================

$ErrorActionPreference = 'Stop'

$onLinux = ($PSVersionTable.PSEdition -eq 'Core') -and [bool]$IsLinux

if (-not $onLinux) {
    # -- 0. OS version check -------------------------------------------------------
    # Hard minimum: build 19045 (Win 10 22H2) — last supported Win 10 release.
    # Recommended:  build 26200 (Win 11 25H2) — latest feature release.
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 19045) {
        Write-Host "[!!] pcHealth cannot run on Windows build $build." -ForegroundColor Red
        Write-Host "     Minimum required: build 19045 (Windows 10 version 22H2)." -ForegroundColor Red
        Write-Host "     Please upgrade your system." -ForegroundColor Yellow
        Read-Host 'Press Enter to exit'
        exit 1
    } elseif ($build -lt 26200) {
        Write-Host "[!] Your Windows build ($build) is below the recommended version (26200 / Windows 11 25H2)." -ForegroundColor Yellow
        Write-Host "    Some features may not work correctly. Consider updating Windows." -ForegroundColor Yellow
        Write-Host "    https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information" -ForegroundColor DarkGray
        Write-Host "    https://learn.microsoft.com/en-us/windows/release-health/release-information" -ForegroundColor DarkGray
        Write-Host ""
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

$pad = 24
function Write-DepStatus($label, $ok, [bool]$Optional = $false) {
    $dots = '.' * ($pad - $label.Length)
    if ($ok) {
        Write-Host "  $label $dots OK"            -ForegroundColor Green
    } elseif ($Optional) {
        Write-Host "  $label $dots not installed" -ForegroundColor Yellow
    } else {
        Write-Host "  $label $dots NOT FOUND"     -ForegroundColor Red
    }
}

$pwshOk     = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
$smartctlOk = $onLinux `
    ? [bool](Get-Command smartctl -ErrorAction SilentlyContinue) `
    : ((Test-Path (Join-Path $env:ProgramFiles 'smartmontools\bin\smartctl.exe')) -or
       [bool](Get-Command smartctl -ErrorAction SilentlyContinue))

Write-DepStatus 'PowerShell 7'  $pwshOk
Write-DepStatus 'smartmontools' $smartctlOk $true

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

# -- 3b. Optional: smartmontools -----------------------------------------------
if (-not $smartctlOk) {
    Write-Host ''
    Write-Host '[pcHealth] smartmontools is recommended for SMART disk health data (life %, temperature, hours).' -ForegroundColor Yellow

    $answer = Read-Host '           Install now? [Y/N]'
    if ($answer -match '^[Yy]') {
        if ($onLinux) {
            if     (Get-Command apt-get -ErrorAction SilentlyContinue) { sudo apt-get install -y smartmontools }
            elseif (Get-Command dnf     -ErrorAction SilentlyContinue) { sudo dnf install -y smartmontools }
            elseif (Get-Command pacman  -ErrorAction SilentlyContinue) { sudo pacman -S --noconfirm smartmontools }
            else { Write-Host '[!!] No supported package manager found. Install smartmontools manually.' -ForegroundColor Yellow }
        } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id smartmontools.smartmontools -e --silent `
                --accept-package-agreements --accept-source-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('Path', 'User')
        } else {
            Write-Host '[!!] winget not available. Install from: https://www.smartmontools.org/' -ForegroundColor Yellow
        }
        if (Get-Command smartctl -ErrorAction SilentlyContinue) {
            Write-Host '[OK] smartmontools installed.' -ForegroundColor Green
        } else {
            Write-Host '[!!] Install may need a restart to take effect.' -ForegroundColor Yellow
        }
    } else {
        Write-Host '     Skipping — SMART data will be limited.' -ForegroundColor DarkGray
    }
}

# -- 4. Launch CLI -------------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] All dependencies satisfied. Starting pcHealth...' -ForegroundColor Green
Write-Host ''

$appScript = Join-Path $PSScriptRoot 'app.ps1'
& pwsh -NoProfile -ExecutionPolicy Bypass -File $appScript

#Requires -Version 5.1
# ============================================================================
# pcHealth -- CLI Launcher
# PS5.1-compatible bootstrap: enforces PS7, admin/root, and optional deps.
# On Windows: runs under PS5 → installs PS7 if needed → relaunches in PS7.
# On Linux:   pwsh (PS7) is assumed pre-installed; checks root + kernel.
# ============================================================================

$ErrorActionPreference = 'Stop'
$onLinux = ($PSVersionTable.PSEdition -eq 'Core') -and [bool]$IsLinux
$isPwsh7 = $PSVersionTable.PSVersion.Major -ge 7

# -- Linux: kernel version check + root guard ---------------------------------
if ($onLinux) {
    # Start.ps1 runs before Helpers.ps1 is loaded, so guard the null here:
    # calling .Trim() on a missing command's output throws before the check below.
    $kernelStr   = "$(& uname -r 2>$null)".Trim()
    if (-not $kernelStr) {
        Write-Host "[!!] Could not determine kernel version (uname -r returned nothing)." -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }
    $kernelMajor = [int]($kernelStr -split '[.-]')[0]
    if ($kernelMajor -lt 7) {
        Write-Host "[!!] pcHealth cannot run on kernel $kernelStr." -ForegroundColor Red
        Write-Host "     Minimum required: kernel 7.0." -ForegroundColor Red
        Write-Host "     https://www.kernel.org/" -ForegroundColor DarkGray
        Read-Host 'Press Enter to exit'
        exit 1
    }

    $isRoot = ("$(& id -u 2>$null)".Trim() -eq '0')
    if (-not $isRoot) {
        Write-Host '[!!] pcHealth must be run as root on Linux.' -ForegroundColor Red
        Write-Host '     Run: sudo pwsh src/CLI/Start.ps1'       -ForegroundColor Yellow
        exit 1
    }
}

# -- Windows: build check, elevate, relaunch in PS7 ---------------------------
if (-not $onLinux) {
    # Windows support tiers -- see README.md and SECURITY.md.
    #   >= 26200  recommended : the build every release is tested on
    #   >= 19045  supported   : Windows 10 22H2 and up; also the GUI's floor
    #   >= 14393  legacy      : runs, but untested -- winget may be missing
    #   <  14393  blocked     : PowerShell 7 does not run on these builds
    # The floor is PowerShell 7's own, not a preference: below 1607 there is no
    # pwsh to bootstrap, so the CLI cannot start no matter what pcHealth allows.
    $recommendedBuild = 26200   # Windows 11 25H2
    $supportedBuild   = 19045   # Windows 10 22H2
    $hardMinimumBuild = 14393   # Windows 10 1607
    $build = [System.Environment]::OSVersion.Version.Build

    if ($build -lt $hardMinimumBuild) {
        Write-Host "[!!] pcHealth cannot run on Windows build $build." -ForegroundColor Red
        Write-Host "     Minimum required: build $hardMinimumBuild (Windows 10 version 1607)," -ForegroundColor Red
        Write-Host "     the oldest build PowerShell 7 supports." -ForegroundColor Red
        Write-Host "     https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows" -ForegroundColor DarkGray
        Read-Host 'Press Enter to exit'
        exit 1
    } elseif ($build -lt $supportedBuild) {
        Write-Host ''
        Write-Host "[!] Legacy Windows build $build -- below the supported floor of $supportedBuild (10 22H2)." -ForegroundColor Yellow
        Write-Host "    pcHealth continues, but this build is not tested. Tools that need winget" -ForegroundColor Yellow
        Write-Host "    stay unavailable until winget is installed (Tools > Repair Winget)." -ForegroundColor DarkGray
    } elseif ($build -lt $recommendedBuild) {
        Write-Host ''
        Write-Host "[!] Windows build $build is supported; $recommendedBuild (11 25H2) is recommended." -ForegroundColor Yellow
        Write-Host "    https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information" -ForegroundColor DarkGray
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        $shell    = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        $shellCmd = Get-Command $shell -ErrorAction SilentlyContinue
        if (-not $shellCmd) { Write-Host "[!!] Shell '$shell' not found." -ForegroundColor Red; exit 1 }
        Start-Process -FilePath $shellCmd.Source `
                      -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" `
                      -Verb RunAs
        exit
    }

    # Relaunch in PS7 if elevation landed in PS5 (pattern from WinDeploy)
    if (-not $isPwsh7) {
        $pwshExe = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
        if (-not (Test-Path $pwshExe)) {
            $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
            $pwshExe = if ($pwshCmd) { $pwshCmd.Source } else { $null }
        }
        if ($pwshExe) {
            Write-Host '[pcHealth] Relaunching in PowerShell 7...' -ForegroundColor Yellow
            Start-Process -FilePath $pwshExe `
                          -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" `
                          -Wait -NoNewWindow
            exit
        }
        # Fall through — pwsh not found yet; installer below will handle it.
    }
}

# -- Dependency check ----------------------------------------------------------
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

# On Linux, pwsh is already running — trivially satisfied.
$pwshOk = $onLinux -or [bool](Get-Command pwsh -ErrorAction SilentlyContinue)

$smartctlOk = if ($onLinux) {
    [bool](Get-Command smartctl -ErrorAction SilentlyContinue)
} else {
    (Test-Path (Join-Path $env:ProgramFiles 'smartmontools\bin\smartctl.exe')) -or
    [bool](Get-Command smartctl -ErrorAction SilentlyContinue)
}

if (-not $onLinux) { Write-DepStatus 'PowerShell 7'  $pwshOk }
Write-DepStatus -label 'smartmontools' -ok $smartctlOk -Optional $true

# -- Install PowerShell 7 (Windows only) --------------------------------------
if (-not $onLinux -and -not $pwshOk) {
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
    winget install --source winget --id Microsoft.PowerShell -e --silent `
        --accept-package-agreements --accept-source-agreements

    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host '[!!] Installation completed but pwsh was not found. Please restart and try again.' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }

    Write-Host '[OK] PowerShell 7 installed.' -ForegroundColor Green
}

# -- Optional: smartmontools --------------------------------------------------
if (-not $smartctlOk) {
    Write-Host ''
    Write-Host '[pcHealth] smartmontools is recommended for full SMART disk health data.' -ForegroundColor Yellow
    Write-Host '           Without it, life %, temperature and power-on hours are unavailable.' -ForegroundColor DarkGray

    $prompt = if ($onLinux) { '           Install now? [Y/N]' } else { '           Install now via winget? [Y/N]' }
    $answer = Read-Host $prompt
    if ($answer -match '^[Yy]') {
        if ($onLinux) {
            if     (Get-Command apt-get -ErrorAction SilentlyContinue) { apt-get install -y smartmontools }
            elseif (Get-Command dnf     -ErrorAction SilentlyContinue) { dnf install -y smartmontools }
            elseif (Get-Command pacman  -ErrorAction SilentlyContinue) { pacman -S --noconfirm smartmontools }
            else { Write-Host '[!!] No supported package manager found. Install smartmontools manually.' -ForegroundColor Yellow }
        } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --source winget --id smartmontools.smartmontools -e --silent `
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

# -- Launch app ----------------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] All dependencies satisfied. Starting pcHealth...' -ForegroundColor Green
Write-Host ''

$appScript = Join-Path $PSScriptRoot 'app.ps1'
& pwsh -NoProfile -ExecutionPolicy Bypass -File $appScript

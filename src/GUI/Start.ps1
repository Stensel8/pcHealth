#Requires -Version 5.1
# ============================================================================
# pcHealth -- GUI Launcher (Windows)
# Checks dependencies, elevates to admin, builds and launches the WinUI 3 app.
# Stays PS 5.1-compatible so it can bootstrap dependencies on fresh systems.
# ============================================================================

$ErrorActionPreference = 'Stop'

# -- 0. Windows only -----------------------------------------------------------
# $IsLinux / $IsMacOS are PS6+ variables; on PS 5.1 they are $null (falsy).
if ($IsLinux -or $IsMacOS) {
    Write-Host '[!!] The pcHealth GUI is not available on Linux or macOS.' -ForegroundColor Red
    Write-Host '     Use src/CLI/start.sh to run the CLI version.'         -ForegroundColor Yellow
    exit 1
}

# Minimum OS version: Windows build 26200 (25H2)
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

# -- 2. Dependency check -------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] Checking dependencies...' -ForegroundColor Cyan

$pad = 24

function Write-DepStatus($label, $ok) {
    $dots = '.' * ($pad - $label.Length)
    if ($ok) {
        Write-Host "  $label $dots OK"        -ForegroundColor Green
    } else {
        Write-Host "  $label $dots NOT FOUND" -ForegroundColor Red
    }
}

$pwshOk   = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
$dotnetOk = $false
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    $sdks = dotnet --list-sdks 2>$null
    $dotnetOk = ($sdks -match '^10\.')
}

Write-DepStatus 'PowerShell 7'  $pwshOk
Write-DepStatus '.NET 10 SDK'   $dotnetOk

# -- 3. Install missing dependencies ------------------------------------------
function Install-ViaWinget($displayName, $wingetId, $manualUrl) {
    Write-Host ''
    Write-Host "[pcHealth] $displayName is required to run this application." -ForegroundColor Yellow

    $answer = Read-Host '           Install now via winget? [Y/N]'
    if ($answer -notmatch '^[Yy]') {
        Write-Host ''
        Write-Host "[!!] Cannot continue without $displayName." -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "[!!] winget is not available. Install $displayName manually:" -ForegroundColor Red
        Write-Host "     $manualUrl" -ForegroundColor Cyan
        Read-Host 'Press Enter to exit'
        exit 1
    }

    Write-Host ''
    Write-Host "[pcHealth] Installing $displayName..." -ForegroundColor Cyan
    winget install --id $wingetId -e --silent `
        --accept-package-agreements --accept-source-agreements

    # Refresh PATH so newly installed tools are findable in this session.
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

if (-not $pwshOk) {
    Install-ViaWinget 'PowerShell 7' 'Microsoft.PowerShell' 'https://aka.ms/powershell'

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host '[!!] Installation completed but pwsh was not found. Please restart and try again.' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }
    Write-Host '[OK] PowerShell 7 installed.' -ForegroundColor Green
}

if (-not $dotnetOk) {
    Install-ViaWinget '.NET 10 SDK' 'Microsoft.DotNet.SDK.10' 'https://dotnet.microsoft.com/download/dotnet/10.0'

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Host '[!!] Installation completed but dotnet was not found. Please restart and try again.' -ForegroundColor Red
        Read-Host 'Press Enter to exit'
        exit 1
    }
    Write-Host '[OK] .NET 10 SDK installed.' -ForegroundColor Green
}

# -- 4. Detect architecture and locate output EXE -----------------------------
$projectFile = Join-Path $PSScriptRoot 'pcHealth\pcHealth.csproj'
$rid         = if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq
                   [System.Runtime.InteropServices.Architecture]::Arm64) { 'win-arm64' } else { 'win-x64' }
$exePath     = Join-Path $PSScriptRoot "pcHealth\bin\Release\net10.0-windows10.0.19041.0\$rid\pcHealth.exe"

# -- 5. Build ------------------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] All dependencies satisfied. Building pcHealth...' -ForegroundColor Green
Write-Host ''

dotnet build $projectFile -c Release --nologo -v minimal

if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '[!!] Build failed. See output above for details.' -ForegroundColor Red
    Read-Host 'Press Enter to exit'
    exit 1
}

# -- 6. Launch -----------------------------------------------------------------
Write-Host ''
Write-Host '[pcHealth] Build succeeded. Launching pcHealth...' -ForegroundColor Green
Start-Process -FilePath $exePath

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

# Recommended and hard minimum Windows build versions (see README.md)
$recommendedBuild = 26200   # 25H2+
$hardMinimumBuild = 19045   # 22H2 (hard minimum)
$build = [System.Environment]::OSVersion.Version.Build

if ($build -lt $hardMinimumBuild) {
    Write-Host "[!!] pcHealth requires at least Windows build $hardMinimumBuild (22H2)." -ForegroundColor Red
    Write-Host "     Your build: $build" -ForegroundColor Red
    Write-Host "     Update Windows and try again." -ForegroundColor Yellow
    Read-Host 'Press Enter to exit'
    exit 1
} elseif ($build -lt $recommendedBuild) {
    Write-Host "[!] Recommended Windows build is $recommendedBuild (25H2+)." -ForegroundColor Yellow
    Write-Host "    Your build: $build" -ForegroundColor Yellow
    Write-Host "    pcHealth will continue but some features may be limited." -ForegroundColor DarkGray
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

$pwshOk   = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
$dotnetOk = $false
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    $sdks = dotnet --list-sdks 2>$null
    $dotnetOk = ($sdks -match '^10\.')
}
$smartctlOk = (Test-Path (Join-Path $env:ProgramFiles 'smartmontools\bin\smartctl.exe')) -or
              [bool](Get-Command smartctl -ErrorAction SilentlyContinue)

Write-DepStatus 'PowerShell 7'   $pwshOk
Write-DepStatus '.NET 10 SDK'    $dotnetOk
Write-DepStatus 'smartmontools'  $smartctlOk  $true

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
    winget install --source winget --id $wingetId -e --silent `
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

# -- 3b. Optional: smartmontools (SMART disk health data) ----------------------
if (-not $smartctlOk) {
    Write-Host ''
    Write-Host '[pcHealth] smartmontools is recommended for full SMART disk health data.' -ForegroundColor Yellow
    Write-Host '           Without it, life %, temperature and power-on hours are unavailable.' -ForegroundColor DarkGray

    $answer = Read-Host '           Install now via winget? [Y/N]'
    if ($answer -match '^[Yy]') {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host '[!!] winget not available. Install from: https://www.smartmontools.org/' -ForegroundColor Yellow
        } else {
            winget install --source winget --id smartmontools.smartmontools -e --silent `
                --accept-package-agreements --accept-source-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('Path', 'User')
            $smartctlOk = (Test-Path (Join-Path $env:ProgramFiles 'smartmontools\bin\smartctl.exe')) -or
                          [bool](Get-Command smartctl -ErrorAction SilentlyContinue)
            if ($smartctlOk) {
                Write-Host '[OK] smartmontools installed.' -ForegroundColor Green
            } else {
                Write-Host '[!!] Install may need a restart to take effect.' -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host '     Skipping — SMART data will fall back to Windows Storage API.' -ForegroundColor DarkGray
    }
}

# -- 4. Detect architecture and derive output EXE path from csproj ------------
$projectFile = Join-Path $PSScriptRoot 'pcHealth\pcHealth.csproj'

# Detect the native architecture; default to win-x64 for everything else.
$rid = if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq
           [System.Runtime.InteropServices.Architecture]::Arm64) { 'win-arm64' } else { 'win-x64' }

# Read TargetFramework from the csproj so this path never drifts from the project.
$tfm     = ([xml](Get-Content $projectFile)).Project.PropertyGroup.TargetFramework |
               Where-Object { $_ } | Select-Object -First 1
$exePath = Join-Path $PSScriptRoot "pcHealth\bin\Release\$tfm\$rid\pcHealth.exe"

# -- 5. Build ------------------------------------------------------------------
Write-Host ''
Write-Host "[pcHealth] All dependencies satisfied. Building pcHealth ($rid)..." -ForegroundColor Green
Write-Host ''

dotnet build $projectFile -c Release -r $rid --nologo -v minimal

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

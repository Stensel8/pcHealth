# ============================================================================
# pcHealth — Windows 11 Thin Launcher
# Launches the shared CLI core from Shared/CLI/Start.ps1
# ============================================================================

$ErrorActionPreference = 'Stop'

# --- Admin check: re-launch elevated if not already running as administrator.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host 'Administrator privileges required. Relaunching elevated...' -ForegroundColor Yellow
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    Start-Process -FilePath $shell `
        -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File \`"$PSCommandPath\`"" `
        -Verb RunAs
    exit
}

# --- PS7 check
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host 'ERROR: PowerShell 7 or higher is required to run pcHealth.' -ForegroundColor Red
    Write-Host 'Download the latest version at: https://aka.ms/powershell' -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

# Launch the shared CLI core
. "$PSScriptRoot\..\..\Shared\CLI\Start.ps1"

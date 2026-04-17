# ============================================================================
# pcHealth — Linux Thin Launcher
# Launches the shared CLI core from Shared/CLI/Start.ps1
# Note: Uses root check instead of UAC, no console resize on Linux
# ============================================================================

$ErrorActionPreference = 'Stop'

# --- PS7 check
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host 'ERROR: PowerShell 7 or higher is required to run pcHealth.' -ForegroundColor Red
    Write-Host 'Download the latest version at: https://aka.ms/powershell' -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

# --- Root check for Linux
if ($IsLinux) {
    if ([System.Environment]::GetEnvironmentVariable('USER') -ne 'root') {
        Write-Host 'Root privileges required. Please run with sudo.' -ForegroundColor Red
        exit 1
    }
}

# Launch the shared CLI core
. "$PSScriptRoot\..\..\Shared\CLI\Start.ps1"

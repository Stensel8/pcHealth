#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 10 — Update HP Drivers (HP Image Assistant)
# ============================================================================

$swSetup = "$env:SystemDrive\SWSetup"

Write-Host "`nInstalling HP Image Assistant via winget...`n" -ForegroundColor Cyan

winget install --id HP.ImageAssistant --accept-source-agreements --accept-package-agreements

Write-Host ''
Write-Host "HP Image Assistant scans your HP system for outdated drivers and firmware." -ForegroundColor DarkGray
Write-Host "Default install location: $swSetup — look for HPImageAssistant.exe`n"     -ForegroundColor DarkGray

$open = (Read-Host "Open $swSetup now? (y/n)").Trim().ToLower()
if ($open -eq 'y') {
    if (Test-Path $swSetup) {
        Start-Process $swSetup
    } else {
        Write-Host "[!] $swSetup not found. HP Image Assistant may have installed elsewhere.`n" -ForegroundColor Yellow
    }
}

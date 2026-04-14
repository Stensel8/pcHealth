#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Update HP Drivers (HP Image Assistant)
# ============================================================================

Write-Host "`nInstalling HP Image Assistant via winget...`n" -ForegroundColor Cyan

winget install --id HP.ImageAssistant --accept-source-agreements --accept-package-agreements

Write-Host ''
Write-Host "HP Image Assistant scans your HP system for outdated drivers and firmware." -ForegroundColor DarkGray
Write-Host "Default install location: C:\SWSetup — look for HPImageAssistant.exe`n"   -ForegroundColor DarkGray

$open = (Read-Host "Open C:\SWSetup now? (y/n)").Trim().ToLower()
if ($open -eq 'y') {
    if (Test-Path 'C:\SWSetup') {
        Start-Process 'C:\SWSetup'
    } else {
        Write-Host "[!] C:\SWSetup not found. HP Image Assistant may have installed elsewhere.`n" -ForegroundColor Yellow
    }
}

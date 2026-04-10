#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — DISM Health Check
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  DISM Health Check" -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

Write-Host "[>>] Running CheckHealth..." -ForegroundColor Yellow
DISM /Online /Cleanup-Image /CheckHealth
Write-Host "[OK] CheckHealth completed.`n" -ForegroundColor Green

Write-Host "[>>] Running ScanHealth (this may take a few minutes)..." -ForegroundColor Yellow
DISM /Online /Cleanup-Image /ScanHealth
Write-Host "[OK] ScanHealth completed.`n" -ForegroundColor Green

$repair = (Read-Host "Attempt repair with RestoreHealth? Requires internet or install media. (y/n)").Trim().ToLower()
if ($repair -eq 'y') {
    Write-Host "`n[>>] Running RestoreHealth..." -ForegroundColor Yellow
    DISM /Online /Cleanup-Image /RestoreHealth
    Write-Host "[OK] RestoreHealth completed.`n" -ForegroundColor Green
} else {
    Write-Host "`nRepair skipped.`n" -ForegroundColor DarkGray
}

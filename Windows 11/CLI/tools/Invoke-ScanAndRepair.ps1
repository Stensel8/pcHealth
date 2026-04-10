#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Scan + Repair (SFC + DISM combined)
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Scan + Repair  (SFC + DISM)" -ForegroundColor Cyan
Write-Host "$('=' * 60)" -ForegroundColor Cyan
Write-Host "  This tool runs SFC and DISM to detect and repair corrupt or"
Write-Host "  missing Windows system files. This can take several minutes.`n"

Write-Host "[>>] Step 1/4 — System File Checker (SFC)..." -ForegroundColor Yellow
sfc /scannow
Write-Host "[OK] SFC scan completed.`n" -ForegroundColor Green

Write-Host "[>>] Step 2/4 — DISM CheckHealth..." -ForegroundColor Yellow
DISM /Online /Cleanup-Image /CheckHealth
Write-Host "[OK] CheckHealth completed.`n" -ForegroundColor Green

Write-Host "[>>] Step 3/4 — DISM ScanHealth..." -ForegroundColor Yellow
DISM /Online /Cleanup-Image /ScanHealth
Write-Host "[OK] ScanHealth completed.`n" -ForegroundColor Green

$repair = (Read-Host "Attempt repair with DISM RestoreHealth? Requires internet or install media. (y/n)").Trim().ToLower()
if ($repair -eq 'y') {
    Write-Host "`n[>>] Step 4/4 — DISM RestoreHealth..." -ForegroundColor Yellow
    DISM /Online /Cleanup-Image /RestoreHealth
    Write-Host "[OK] RestoreHealth completed.`n" -ForegroundColor Green

    Write-Host "[>>] Final SFC pass to verify repairs..." -ForegroundColor Yellow
    sfc /scannow
    Write-Host "[OK] Final SFC completed.`n" -ForegroundColor Green
} else {
    Write-Host "`nRepair skipped.`n" -ForegroundColor DarkGray
}

Write-Host "$('=' * 60)" -ForegroundColor Green
Write-Host "  Scan complete. Check output above for results." -ForegroundColor Green
Write-Host "  If issues persist: C:\Windows\Logs\CBS\CBS.log" -ForegroundColor Green
Write-Host "$('=' * 60)`n" -ForegroundColor Green

#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — DISM Health Check
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  DISM Health Check" -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

# Use the full path so DISM is found in WinRE/recovery environments where
# System32 may not be on PATH, and call via & so $LASTEXITCODE is populated.
$dism = "$env:SystemRoot\System32\Dism.exe"

Write-Host "[>>] Running CheckHealth..." -ForegroundColor Yellow
& $dism /Online /Cleanup-Image /CheckHealth
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!!] CheckHealth returned exit code $LASTEXITCODE.`n" -ForegroundColor Red
} else {
    Write-Host "[OK] CheckHealth completed.`n" -ForegroundColor Green
}

Write-Host "[>>] Running ScanHealth (this may take a few minutes)..." -ForegroundColor Yellow
& $dism /Online /Cleanup-Image /ScanHealth
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!!] ScanHealth returned exit code $LASTEXITCODE.`n" -ForegroundColor Red
} else {
    Write-Host "[OK] ScanHealth completed.`n" -ForegroundColor Green
}

$repair = (Read-Host "Attempt repair with RestoreHealth? Requires internet or install media. (y/n)").Trim().ToLower()
if ($repair -eq 'y') {
    Write-Host "`n[>>] Running RestoreHealth..." -ForegroundColor Yellow
    & $dism /Online /Cleanup-Image /RestoreHealth
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!!] RestoreHealth returned exit code $LASTEXITCODE.`n" -ForegroundColor Red
    } else {
        Write-Host "[OK] RestoreHealth completed.`n" -ForegroundColor Green
    }
} else {
    Write-Host "`nRepair skipped.`n" -ForegroundColor DarkGray
}

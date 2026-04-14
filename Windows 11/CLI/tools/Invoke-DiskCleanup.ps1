#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Disk Cleanup
# Opens the built-in Disk Cleanup utility.
# ============================================================================

Write-Host "`nOpening Disk Cleanup...`n" -ForegroundColor Cyan
Start-Process cleanmgr.exe
Write-Host "[OK] Disk Cleanup window opened.`n" -ForegroundColor Green

#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Disk Optimization
# Opens the built-in Disk Optimization (Defragment and Optimize Drives) GUI.
# ============================================================================

Write-Host "`nOpening Disk Optimization...`n" -ForegroundColor Cyan
Start-Process dfrgui.exe
Write-Host "[OK] Disk Optimization window opened.`n" -ForegroundColor Green

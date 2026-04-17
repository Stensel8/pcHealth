#Requires -Version 7.0
# ============================================================================
# pcHealth -- System File Scan (SFC)
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  System File Checker (SFC)" -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan
Write-Host "Scanning all protected system files. This may take a few minutes.`n" -ForegroundColor Yellow

sfc /scannow

Write-Host "`n[OK] SFC scan completed." -ForegroundColor Green
Write-Host "     If issues were found, check: C:\Windows\Logs\CBS\CBS.log`n" -ForegroundColor DarkGray

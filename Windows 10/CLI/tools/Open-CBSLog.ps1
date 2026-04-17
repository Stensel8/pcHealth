#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 10 — Open CBS Log
# ============================================================================

$logPath = 'C:\Windows\Logs\CBS\CBS.log'

if (Test-Path $logPath) {
    Write-Host "`nOpening CBS.log...`n" -ForegroundColor Cyan
    Start-Process $logPath
    Write-Host "[OK] CBS.log opened.`n" -ForegroundColor Green
} else {
    Write-Host "`n[!] CBS.log not found at $logPath`n" -ForegroundColor Yellow
}

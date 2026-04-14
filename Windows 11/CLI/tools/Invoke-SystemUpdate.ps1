#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Update System Programs (winget)
# ============================================================================

Write-Host "`nDetecting updatable packages...`n" -ForegroundColor Cyan

winget upgrade

Write-Host ''
$confirm = (Read-Host "Proceed with updating all packages? (y/n)").Trim().ToLower()

if ($confirm -eq 'y') {
    Write-Host "`nUpdating all packages...`n" -ForegroundColor Yellow
    winget upgrade --all --accept-source-agreements --accept-package-agreements --silent
    Write-Host "`n[OK] Update complete.`n" -ForegroundColor Green
} else {
    Write-Host "`nUpdate cancelled.`n" -ForegroundColor DarkGray
}

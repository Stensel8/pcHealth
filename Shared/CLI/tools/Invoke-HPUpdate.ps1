#Requires -Version 7.0
# ============================================================================
# pcHealth — Update HP Drivers
# Installs HP Image Assistant which detects and updates HP-specific drivers.
# ============================================================================

Write-Host "`nInstalling HP Image Assistant via winget...`n" -ForegroundColor Cyan
Write-Host "Note: HP Image Assistant is only useful on HP devices.`n" -ForegroundColor DarkGray

winget install --id HP.ImageAssistant --accept-source-agreements --accept-package-agreements

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] HP Image Assistant installed. Launch it to update HP drivers.`n" -ForegroundColor Green
} else {
    Write-Host "`n[!!] Installation returned exit code $LASTEXITCODE.`n" -ForegroundColor Red
}

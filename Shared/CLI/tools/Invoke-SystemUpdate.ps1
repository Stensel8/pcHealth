#Requires -Version 7.0
# ============================================================================
# pcHealth — Update System Programs
# Upgrades all installed winget packages.
# ============================================================================

Write-Host "`nUpgrading all installed packages via winget...`n" -ForegroundColor Cyan
winget upgrade --all --accept-source-agreements --accept-package-agreements
Write-Host "`n[OK] winget upgrade completed.`n" -ForegroundColor Green

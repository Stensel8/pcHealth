#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Restart Audio Drivers
# ============================================================================

Write-Host "`nRestarting audio services...`n" -ForegroundColor Cyan

Write-Host "[>>] Stopping AudioEndpointBuilder..." -ForegroundColor Yellow
Stop-Service -Name 'AudioEndpointBuilder' -Force -ErrorAction SilentlyContinue
Write-Host "[>>] Stopping Audiosrv..." -ForegroundColor Yellow
Stop-Service -Name 'Audiosrv' -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 1

Write-Host "[>>] Starting AudioEndpointBuilder..." -ForegroundColor Yellow
Start-Service -Name 'AudioEndpointBuilder' -ErrorAction SilentlyContinue
Write-Host "[>>] Starting Audiosrv..." -ForegroundColor Yellow
Start-Service -Name 'Audiosrv' -ErrorAction SilentlyContinue

Write-Host "`n[OK] Audio services restarted. Test your audio now.`n" -ForegroundColor Green

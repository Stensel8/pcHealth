#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Repair Winget
# Credits: @asheroto — https://github.com/asheroto/winget-install
# ============================================================================

Write-Host "`n  Repairing winget using the winget-install module" -ForegroundColor Cyan
Write-Host "  Credits: @asheroto — https://github.com/asheroto/winget-install`n" -ForegroundColor DarkGray

Write-Host "[>>] Installing winget-install script from PSGallery..." -ForegroundColor Yellow
try {
    Install-Script -Name winget-install -Force -Scope CurrentUser -ErrorAction Stop
    Write-Host "[OK] Script installed." -ForegroundColor Green
} catch {
    Write-Host "[!!] Failed to install script: $_" -ForegroundColor Red
    return
}

Write-Host "[>>] Running winget-install (this may take a moment)..." -ForegroundColor Yellow
# winget-install calls exit internally, which would kill our session if invoked
# directly. Running it in a child process keeps our session alive.
#
# Install-Script places the .ps1 in the user's Scripts folder, which may not be
# on PATH in an elevated child process. Resolve the path explicitly and use
# -File so PowerShell locates it regardless of PATH configuration.
$installed   = Get-InstalledScript winget-install -ErrorAction SilentlyContinue
$scriptArgs  = if ($installed) {
    $scriptFile = Join-Path $installed.InstalledLocation 'winget-install.ps1'
    "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`" -Force"
} else {
    # Fallback: rely on the Scripts directory being on PATH.
    '-NoProfile -ExecutionPolicy Bypass -Command winget-install -Force'
}
$result = Start-Process pwsh -ArgumentList $scriptArgs -Wait -PassThru
if ($result.ExitCode -eq 0) {
    Write-Host "[OK] Winget repair complete." -ForegroundColor Green
} else {
    Write-Host "[!!] Repair exited with code $($result.ExitCode)." -ForegroundColor Red
}

Write-Host ''

#Requires -Version 7.0
# ============================================================================
# pcHealth — Update Packages (Linux)
# Detects the distro package manager and runs a full system upgrade.
# ============================================================================

Write-Host "`nDetecting package manager...`n" -ForegroundColor Cyan

if (Get-Command apt -ErrorAction SilentlyContinue) {
    Write-Host "[>>] Using apt — updating package lists..." -ForegroundColor Yellow
    & sudo apt update
    Write-Host "`n[>>] Upgrading packages..." -ForegroundColor Yellow
    & sudo apt upgrade -y
} elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
    Write-Host "[>>] Using dnf — upgrading packages..." -ForegroundColor Yellow
    & sudo dnf upgrade -y
} elseif (Get-Command pacman -ErrorAction SilentlyContinue) {
    Write-Host "[>>] Using pacman — upgrading packages..." -ForegroundColor Yellow
    & sudo pacman -Syu --noconfirm
} elseif (Get-Command zypper -ErrorAction SilentlyContinue) {
    Write-Host "[>>] Using zypper — upgrading packages..." -ForegroundColor Yellow
    & sudo zypper update -y
} else {
    Write-Host "[!!] No supported package manager found (apt/dnf/pacman/zypper).`n" -ForegroundColor Red
    return
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] Package update complete.`n" -ForegroundColor Green
} else {
    Write-Host "`n[!!] Update returned exit code $LASTEXITCODE.`n" -ForegroundColor Red
}

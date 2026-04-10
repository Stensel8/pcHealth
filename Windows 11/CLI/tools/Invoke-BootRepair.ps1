#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Boot Record Repair
# Attempts to repair the boot record via CHKDSK, SFC, BOOTREC and BCDBOOT.
# Best run from a recovery environment (WinRE/CMD) with Administrator rights.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Red
Write-Host "  Boot Record Repair" -ForegroundColor Red
Write-Host "$('=' * 60)`n" -ForegroundColor Red
Write-Host "  WARNING: This operation modifies boot-critical files." -ForegroundColor Yellow
Write-Host "  Incorrect use can render the system unbootable." -ForegroundColor Yellow
Write-Host "  Only proceed if you understand what you are doing.`n" -ForegroundColor Yellow

$confirm1 = (Read-Host "  Type 'yes' to continue or anything else to cancel").Trim().ToLower()
if ($confirm1 -ne 'yes') {
    Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray
    return
}

$confirm2 = (Read-Host "  Last chance — type 'CONFIRM' in capitals to proceed").Trim()
if ($confirm2 -ne 'CONFIRM') {
    Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray
    return
}

function Get-WindowsDrive {
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'X' } | ForEach-Object {
        if (Test-Path (Join-Path $_.Root 'Windows\System32')) { return "$($_.Name):" }
    } | Select-Object -First 1
}

Write-Host "`n[>>] Step 1/3 — CHKDSK..." -ForegroundColor Yellow
$win = Get-WindowsDrive
if ($win) { cmd /c "chkdsk $win /f /r" } else { Write-Warning "Windows partition not found, skipping CHKDSK." }
Write-Host "[OK] CHKDSK done.`n" -ForegroundColor Green

Write-Host "[>>] Step 2/3 — SFC (offline)..." -ForegroundColor Yellow
if ($win) {
    $windir = Join-Path $win 'Windows'
    cmd /c "sfc /scannow /offbootdir=$win\ /offwindir=$windir"
} else { Write-Warning "Skipping offline SFC." }
Write-Host "[OK] SFC done.`n" -ForegroundColor Green

Write-Host "[>>] Step 3/3 — BOOTREC..." -ForegroundColor Yellow
cmd /c 'bootrec /fixmbr'     # Rewrites the Master Boot Record code (not the partition table)
# Capture /fixboot output — on UEFI systems this often returns "Access is denied"
# because the EFI System Partition is not mounted. We handle that below.
$fixboot = cmd /c 'bootrec /fixboot' 2>&1
cmd /c 'bootrec /scanos'    # Scans all disks for Windows installations
cmd /c 'bootrec /rebuildbcd' # Rebuilds the Boot Configuration Data store

if ($fixboot -match 'Access is denied|Toegang geweigerd') {
    # On UEFI/GPT systems, /fixboot needs access to the EFI System Partition (ESP).
    # 'mountvol S: /S' mounts the ESP as drive S: so BCDBOOT can write boot files to it.
    Write-Warning "/fixboot access denied — attempting BCDBOOT fallback (EFI)..."
    cmd /c 'mountvol S: /S' 2>$null
    if (Test-Path 'S:\') {
        # /f ALL writes boot files for both UEFI and legacy BIOS, covering both cases.
        cmd /c "bcdboot $windir /s S: /f ALL"
        Write-Host "[OK] BCDBOOT completed." -ForegroundColor Green
    } else {
        Write-Warning "Could not mount EFI partition. Manual intervention may be required."
    }
}
Write-Host "[OK] BOOTREC done.`n" -ForegroundColor Green

Write-Host "All steps completed. Reboot the system to verify.`n" -ForegroundColor Green

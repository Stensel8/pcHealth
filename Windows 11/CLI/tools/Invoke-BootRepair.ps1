#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Boot Record Repair
# Attempts to repair the boot record via CHKDSK, SFC, BOOTREC and BCDBOOT.
# Best run from a recovery environment (WinRE/CMD) with Administrator rights.
# ============================================================================

# Danger theme (red) — mirrors the BAT file's `color 0C` for this section.
Set-PcTheme 'Danger'
Clear-Host

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

Write-Host "`n[>>] Step 1/3 — Disk repair..." -ForegroundColor Yellow
$win    = Get-WindowsDrive
# Derive $windir here so it is available in every step, including the bcdboot
# fallback in step 3. Without this, $windir would be $null if $win is $null and
# bcdboot would run with an empty path argument.
$windir = if ($win) { Join-Path $win 'Windows' } else { $null }

if ($win) {
    $driveLetter = $win.TrimEnd(':')
    # X:\ is present only in WinPE/WinRE — its absence means a live Windows session.
    # Repair-Volume -OfflineScanAndFix requires the volume to be offline, so fall back
    # to an online-safe scan when running from a live session.
    if (Test-Path 'X:\') {
        Repair-Volume -DriveLetter $driveLetter -OfflineScanAndFix
    } else {
        Write-Warning "Live session detected — using online scan only. Run from WinRE for a full offline repair."
        Repair-Volume -DriveLetter $driveLetter -Scan
    }
} else { Write-Warning "Windows partition not found, skipping disk repair." }
Write-Host "[OK] Disk repair done.`n" -ForegroundColor Green

Write-Host "[>>] Step 2/3 — SFC (offline)..." -ForegroundColor Yellow
if ($win) {
    # sfc.exe has no PowerShell equivalent — call directly without cmd /c.
    & sfc.exe /scannow /offbootdir="$win\" /offwindir="$windir"
} else { Write-Warning "Skipping offline SFC." }
Write-Host "[OK] SFC done.`n" -ForegroundColor Green

Write-Host "[>>] Step 3/3 — BOOTREC..." -ForegroundColor Yellow
# bootrec.exe, mountvol.exe and bcdboot.exe have no PowerShell equivalents.
# Call them directly — no cmd /c wrapper needed in PowerShell 7.
& bootrec.exe /fixmbr      # Rewrites the Master Boot Record code (not the partition table)

# Capture /fixboot output — on UEFI systems this often returns "Access is denied"
# because the EFI System Partition is not mounted. We handle that below.
$fixboot = & bootrec.exe /fixboot 2>&1
& bootrec.exe /scanos      # Scans all disks for Windows installations
& bootrec.exe /rebuildbcd  # Rebuilds the Boot Configuration Data store

if ($fixboot -match 'Access is denied') {
    # On UEFI/GPT systems, /fixboot needs access to the EFI System Partition (ESP).
    # mountvol /S mounts the ESP as drive S: so bcdboot can write boot files to it.
    Write-Warning "/fixboot access denied — attempting bcdboot fallback (EFI)..."
    & mountvol.exe S: /S
    if (Test-Path 'S:\') {
        # /f ALL writes boot files for both UEFI and legacy BIOS, covering both cases.
        & bcdboot.exe $windir /s S: /f ALL
        Write-Host "[OK] bcdboot completed." -ForegroundColor Green
    } else {
        Write-Warning "Could not mount EFI partition. Manual intervention may be required."
    }
}
Write-Host "[OK] BOOTREC done.`n" -ForegroundColor Green

Write-Host "All steps completed. Reboot the system to verify.`n" -ForegroundColor Green

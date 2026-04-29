#Requires -Version 7.0
# ============================================================================
# pcHealth -- Boot Record Repair
# Attempts to repair the boot record via CHKDSK, SFC, BOOTREC and BCDBOOT.
# Best run from a recovery environment (WinRE/CMD) with Administrator rights.
# ============================================================================

if (Get-Command Set-PcTheme -ErrorAction SilentlyContinue) {
    Set-PcTheme 'Danger'
    Clear-PcHost
}

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

$confirm2 = (Read-Host "  Last chance -- type 'CONFIRM' in capitals to proceed").Trim()
if ($confirm2 -ne 'CONFIRM') {
    Write-Host "`n  Cancelled.`n" -ForegroundColor DarkGray
    return
}

function Get-WindowsDrive {
    # 'return' inside ForEach-Object is a continue, not a function exit.
    # Select-Object -First 1 ensures only the first match is used.
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'X' } | ForEach-Object {
        if (Test-Path (Join-Path $_.Root 'Windows\System32')) { "$($_.Name):" }
    } | Select-Object -First 1
}

Write-Host "`n[>>] Step 1/3 -- Disk repair..." -ForegroundColor Yellow
$win    = Get-WindowsDrive
$windir = if ($win) { Join-Path $win 'Windows' } else { $null }

if ($win) {
    $driveLetter = $win.TrimEnd(':')
    if (Test-Path 'X:\') {
        Repair-Volume -DriveLetter $driveLetter -OfflineScanAndFix
    } else {
        Write-Warning "Live session detected -- using online scan only. Run from WinRE for a full offline repair."
        Repair-Volume -DriveLetter $driveLetter -Scan
    }
} else { Write-Warning "Windows partition not found, skipping disk repair." }
Write-Host "[OK] Disk repair done.`n" -ForegroundColor Green

Write-Host "[>>] Step 2/3 -- SFC (offline)..." -ForegroundColor Yellow
if ($win) {
    Start-Process -FilePath "$env:SystemRoot\System32\sfc.exe" `
        -ArgumentList "/scannow /offbootdir=`"$win\`" /offwindir=`"$windir`"" `
        -Wait -NoNewWindow
} else { Write-Warning "Skipping offline SFC." }
Write-Host "[OK] SFC done.`n" -ForegroundColor Green

Write-Host "[>>] Step 3/3 -- BOOTREC..." -ForegroundColor Yellow
& bootrec.exe /fixmbr
$fixboot = & bootrec.exe /fixboot 2>&1
& bootrec.exe /scanos
& bootrec.exe /rebuildbcd

if ($fixboot -match 'Access is denied') {
    Write-Warning "/fixboot access denied -- attempting bcdboot fallback (EFI)..."
    & mountvol.exe S: /S
    if (Test-Path 'S:\') {
        & bcdboot.exe $windir /s S: /f ALL
        Write-Host "[OK] bcdboot completed." -ForegroundColor Green
    } else {
        Write-Warning "Could not mount EFI partition. Manual intervention may be required."
    }
}
Write-Host "[OK] BOOTREC done.`n" -ForegroundColor Green

Write-Host "All steps completed. Reboot the system to verify.`n" -ForegroundColor Green

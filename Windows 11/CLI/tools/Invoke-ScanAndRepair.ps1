#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Scan + Repair (SFC + DISM combined)
# ============================================================================

# Both SFC and DISM write directly to the console (SFC via WriteConsole,
# DISM via \r-based progress bar). Piping either one breaks their output.
# Run both directly, then read their log files for the result.

function Get-SfcStatus {
    $cbsLog = 'C:\Windows\Logs\CBS\CBS.log'
    if (-not (Test-Path $cbsLog)) { return 'Unknown — CBS log not found' }
    $text = (Get-Content $cbsLog -ErrorAction SilentlyContinue |
                 Where-Object { $_ -match '\[SR\]' } |
                 Select-Object -Last 30) -join ' '
    if     ($text -match 'did not find any integrity violations')         { 'Clean — no violations found' }
    elseif ($text -match 'found corrupt files and successfully repaired') { 'Issues found and repaired' }
    elseif ($text -match 'found corrupt files but was unable to fix')     { 'Issues found — could not repair all' }
    elseif ($text -match 'could not perform the requested operation')      { 'Could not run — check permissions' }
    else                                                                   { 'Unknown — review CBS log' }
}

function Get-DismStatus {
    param([int]$ExitCode)
    if ($ExitCode -ne 0) { return "Failed (exit code $ExitCode)" }
    $dismLog = 'C:\Windows\Logs\DISM\dism.log'
    if (-not (Test-Path $dismLog)) { return 'Completed — no DISM log found' }
    $text = (Get-Content $dismLog -ErrorAction SilentlyContinue |
                 Select-Object -Last 60) -join ' '
    if     ($text -match 'No component store corruption detected')       { 'Clean — no corruption detected' }
    elseif ($text -match 'The restore operation completed successfully') { 'Restored successfully' }
    elseif ($text -match 'component store is repairable')                { 'Corruption found — repairable' }
    else                                                                  { 'Completed — check DISM log' }
}

function Get-ResultColor {
    param([string]$Status)
    switch -Wildcard ($Status) {
        'Clean*'                    { 'Green'    }
        'Issues found and repaired' { 'Green'    }
        'Restored*'                 { 'Green'    }
        'Skipped'                   { 'DarkGray' }
        'Corruption found*'         { 'Yellow'   }
        'Unknown*'                  { 'Yellow'   }
        'Completed*'                { 'Yellow'   }
        default                     { 'Red'      }
    }
}

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Scan + Repair  (SFC + DISM)" -ForegroundColor Cyan
Write-Host "$('=' * 60)" -ForegroundColor Cyan
Write-Host "  This tool runs SFC and DISM to detect and repair corrupt or"
Write-Host "  missing Windows system files. This can take several minutes.`n"

# --- Step 1/4 — SFC ---
Write-Host "[>>] Step 1/4 — System File Checker (SFC)..." -ForegroundColor Yellow
sfc /scannow
$sfc1Status = Get-SfcStatus
Write-Host "[OK] SFC done.`n" -ForegroundColor Green

# --- Step 2/4 — DISM CheckHealth ---
Write-Host "[>>] Step 2/4 — DISM CheckHealth..." -ForegroundColor Yellow
DISM /Online /Cleanup-Image /CheckHealth
$checkStatus = Get-DismStatus $LASTEXITCODE
Write-Host "[OK] CheckHealth done.`n" -ForegroundColor Green

# --- Step 3/4 — DISM ScanHealth ---
Write-Host "[>>] Step 3/4 — DISM ScanHealth..." -ForegroundColor Yellow
DISM /Online /Cleanup-Image /ScanHealth
$scanStatus = Get-DismStatus $LASTEXITCODE
Write-Host "[OK] ScanHealth done.`n" -ForegroundColor Green

# --- Step 4/4 — DISM RestoreHealth (optional) + final SFC ---
$restoreStatus = 'Skipped'
$sfc2Status    = 'Skipped'

$repair = (Read-Host "Attempt repair with DISM RestoreHealth? Requires internet or install media. (y/n)").Trim().ToLower()
if ($repair -eq 'y') {
    Write-Host "`n[>>] Step 4/4 — DISM RestoreHealth..." -ForegroundColor Yellow
    DISM /Online /Cleanup-Image /RestoreHealth
    $restoreStatus = Get-DismStatus $LASTEXITCODE
    Write-Host "[OK] RestoreHealth done.`n" -ForegroundColor Green

    Write-Host "[>>] Final SFC pass to verify repairs..." -ForegroundColor Yellow
    sfc /scannow
    $sfc2Status = Get-SfcStatus
    Write-Host "[OK] Final SFC done.`n" -ForegroundColor Green
} else {
    Write-Host "`n  Repair skipped.`n" -ForegroundColor DarkGray
}

# --- Results summary ---
Write-Host "$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Results Summary" -ForegroundColor Cyan
Write-Host "$('=' * 60)" -ForegroundColor Cyan
Write-Host ""

$results = [ordered]@{
    'SFC (initial)'      = $sfc1Status
    'DISM CheckHealth'   = $checkStatus
    'DISM ScanHealth'    = $scanStatus
    'DISM RestoreHealth' = $restoreStatus
    'SFC (final)'        = $sfc2Status
}

foreach ($key in $results.Keys) {
    $val = $results[$key]
    Write-Host ("  {0,-22}: " -f $key) -NoNewline
    Write-Host $val -ForegroundColor (Get-ResultColor $val)
}

Write-Host ""
Write-Host "$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Full log: C:\Windows\Logs\CBS\CBS.log" -ForegroundColor DarkGray
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

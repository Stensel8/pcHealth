# ============================================================================
# pcHealth - Windows 11 - V1.9.1
# ============================================================================
# Windows System File Scanner
# Scans for corrupt or missing system files using SFC and DISM.
# Requires Administrator privileges.
# ============================================================================

#Requires -RunAsAdministrator

function Write-Header {
    param([string]$Text)
    $line = "=" * 60
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "$line`n" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host "[>>] $Text" -ForegroundColor Yellow
}

function Write-Done {
    param([string]$Text)
    Write-Host "[OK] $Text`n" -ForegroundColor Green
}

# ============================================================================
# STEP 1: SFC Scan
# ============================================================================
Write-Header "pcHealth | Windows System File Scanner"
Write-Host "This tool runs SFC and DISM to detect and repair corrupt or"
Write-Host "missing Windows system files. This can take several minutes.`n"

Write-Step "Running System File Checker (SFC)..."
Write-Host "  sfc /scannow will scan all protected system files.`n"
sfc /scannow

Write-Done "SFC scan completed."

# ============================================================================
# STEP 2: DISM Health Check
# ============================================================================
Write-Step "Checking Windows image health with DISM..."
DISM /Online /Cleanup-Image /CheckHealth
Write-Done "DISM CheckHealth completed."

Write-Step "Scanning Windows image for component store corruption..."
DISM /Online /Cleanup-Image /ScanHealth
Write-Done "DISM ScanHealth completed."

# ============================================================================
# STEP 3: Ask to attempt repair
# ============================================================================
$repair = Read-Host "`nDo you want to attempt repair with DISM RestoreHealth? (y/n)"

if ($repair -eq 'y' -or $repair -eq 'Y') {
    Write-Step "Running DISM RestoreHealth (requires internet or install media)..."
    DISM /Online /Cleanup-Image /RestoreHealth
    Write-Done "DISM RestoreHealth completed."

    Write-Host "Running SFC again to verify repairs..." -ForegroundColor Yellow
    sfc /scannow
    Write-Done "Final SFC scan completed."
} else {
    Write-Host "`nRepair skipped." -ForegroundColor Gray
}

# ============================================================================
# DONE
# ============================================================================
Write-Host "`n$("=" * 60)" -ForegroundColor Green
Write-Host "  Scan complete. Check the output above for results." -ForegroundColor Green
Write-Host "  If issues persist, check: C:\Windows\Logs\CBS\CBS.log" -ForegroundColor Green
Write-Host "$("=" * 60)`n" -ForegroundColor Green

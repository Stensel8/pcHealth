# ============================================================================
# pcHealth - Windows 10
# ============================================================================
# Windows Product Key Grabber (CLI)
# Extracts the Windows product key via OA3 (UEFI/BIOS) and registry decode.
# Outputs results to the console. Invoked from pcHealth.bat.
# ============================================================================

# ============================================================================
# GENERIC KEY DATABASE
# ============================================================================
$GenericKeys = @{
    'VK7JG-NPHTM-C97JM-9MPGT-3V66T' = 'Windows 11 Pro'
    'YTMG3-N6DKC-DKB77-7M9GH-8HVX7' = 'Windows 11 Pro N'
    'YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY' = 'Windows 11 Home'
    'TX9XD-98N7V-6WMQ6-BX7FG-H8Q99' = 'Windows 11 Home N'
    'NPPR9-FWDCX-D2C8J-H872K-2YT43' = 'Windows 11 Enterprise'
    'NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J' = 'Windows 11 Pro for Workstations'
    'W269N-WFGWX-YVC9B-4J6C9-T83GX' = 'Windows 10/11 Pro'
}

function Get-ProductKeyFromDigitalProductId {
    try {
        $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $DigitalProductId = (Get-ItemProperty -Path $RegPath -ErrorAction Stop).DigitalProductId

        if (-not $DigitalProductId) { return $null }

        $key = $DigitalProductId[52..66]
        $chars = "BCDFGHJKMPQRTVWXY2346789"
        $productKey = ""

        $isWin8Plus = ($key[14] -shr 3) -band 1
        $key[14] = ($key[14] -band 0xF7) -bor (($isWin8Plus -band 2) -shl 2)

        for ($i = 24; $i -ge 0; $i--) {
            $cur = 0
            for ($j = 14; $j -ge 0; $j--) {
                $cur = ($cur -shl 8) -bor $key[$j]
                $key[$j] = [math]::Floor($cur / 24)
                $cur = $cur % 24
            }
            $productKey = $chars[$cur] + $productKey
        }

        if ($isWin8Plus) {
            $firstChar = $productKey[0]
            $nIndex = 0
            for ($i = 0; $i -lt $chars.Length; $i++) {
                if ($chars[$i] -eq $firstChar) { $nIndex = $i; break }
            }
            $productKey = $productKey.Substring(1)
            $productKey = $productKey.Insert($nIndex, "N")
        }

        $formattedKey = ""
        for ($i = 0; $i -lt 25; $i++) {
            $formattedKey += $productKey[$i]
            if (($i + 1) % 5 -eq 0 -and $i -lt 24) { $formattedKey += "-" }
        }

        return $formattedKey
    } catch {
        return $null
    }
}

function Get-ProductKeyFromOA3 {
    try {
        $key = (Get-CimInstance -Query 'SELECT * FROM SoftwareLicensingService' -ErrorAction Stop).OA3xOriginalProductKey
        if ($key) { return $key }
    } catch {}
    return $null
}

function Get-WindowsVersion {
    try {
        $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $ProductID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductID
        return @{ Name = $OS.Caption; Build = $OS.BuildNumber; ProductID = $ProductID }
    } catch {
        return @{ Name = "Unknown Windows Version"; Build = "Unknown"; ProductID = "Unknown" }
    }
}

function Test-ProductKeyFormat {
    param([string]$Key)
    if ([string]::IsNullOrEmpty($Key)) { return $false }
    return $Key -match '^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$'
}

# ============================================================================
# MAIN
# ============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  pcHealth | Windows Key Grabber (CLI)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$WinVersion = Get-WindowsVersion
Write-Host "  OS        : $($WinVersion.Name) (Build $($WinVersion.Build))" -ForegroundColor Cyan
Write-Host "  Product ID: $($WinVersion.ProductID)" -ForegroundColor Cyan
Write-Host ""

$oa3Key = Get-ProductKeyFromOA3
$regKey = Get-ProductKeyFromDigitalProductId

Write-Host "  Extraction methods:" -ForegroundColor Yellow
if ($oa3Key -and (Test-ProductKeyFormat $oa3Key)) {
    Write-Host "  [+] OA3 (UEFI/BIOS)        : $oa3Key" -ForegroundColor Green
} else {
    Write-Host "  [-] OA3 (UEFI/BIOS)        : Not found" -ForegroundColor DarkGray
}

if ($regKey -and (Test-ProductKeyFormat $regKey)) {
    Write-Host "  [+] Registry (DigitalProdId): $regKey" -ForegroundColor Green
} else {
    Write-Host "  [-] Registry (DigitalProdId): Not found" -ForegroundColor DarkGray
}

Write-Host ""

$bestKey    = if ($regKey) { $regKey } elseif ($oa3Key) { $oa3Key } else { $null }
$bestSource = if ($regKey) { "Registry (DigitalProductId)" } elseif ($oa3Key) { "UEFI/BIOS Firmware (OA3)" } else { "None" }

if ($bestKey) {
    $isGeneric = $GenericKeys.ContainsKey($bestKey)

    Write-Host "  Primary key : " -NoNewline
    if ($isGeneric) {
        Write-Host $bestKey -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  WARNING: This is a generic/placeholder key ($($GenericKeys[$bestKey]))." -ForegroundColor Yellow
        Write-Host "           It will NOT activate Windows." -ForegroundColor Yellow
    } else {
        Write-Host $bestKey -ForegroundColor Green
    }
    Write-Host "  Source      : $bestSource" -ForegroundColor Cyan
    Write-Host ""

    $save = Read-Host "  Save key to a text file on your Desktop? (y/n)"
    if ($save -ieq 'y') {
        $desktop  = [Environment]::GetFolderPath("Desktop")
        $fileName = Join-Path $desktop "pcHealth-WindowsKey-$(Get-Date -Format 'yyyy-MM-dd').txt"
        $lines = @(
            "pcHealth - Windows Product Key Report",
            "Generated : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "",
            "OS        : $($WinVersion.Name) (Build $($WinVersion.Build))",
            "Product ID: $($WinVersion.ProductID)",
            "",
            "OA3 (UEFI/BIOS)         : $(if ($oa3Key) { $oa3Key } else { 'Not found' })",
            "Registry (DigitalProdId): $(if ($regKey) { $regKey } else { 'Not found' })",
            "",
            "Primary Key : $bestKey",
            "Source      : $bestSource"
        )
        if ($isGeneric) {
            $lines += ""
            $lines += "WARNING: Generic placeholder key ($($GenericKeys[$bestKey])). This key will not activate Windows."
        }
        $lines | Out-File -FilePath $fileName -Encoding UTF8
        Write-Host ""
        Write-Host "  Saved to: $fileName" -ForegroundColor Green
    }
} else {
    Write-Host "  No product key found." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Your system may use a digital licence linked to your" -ForegroundColor DarkGray
    Write-Host "  Microsoft account, or was activated via KMS/MAK." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green

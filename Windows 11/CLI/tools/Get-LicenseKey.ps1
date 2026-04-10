#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Windows License Key
# Attempts OA3 (UEFI/BIOS firmware) and DigitalProductId (registry decode).
# ============================================================================

# Generic/placeholder keys (KMS client setup keys - do not activate Windows)
$genericKeys = @{
    'VK7JG-NPHTM-C97JM-9MPGT-3V66T' = 'Windows 11 Pro'
    'YTMG3-N6DKC-DKB77-7M9GH-8HVX7' = 'Windows 11 Pro N'
    'YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY' = 'Windows 11 Home'
    'TX9XD-98N7V-6WMQ6-BX7FG-H8Q99' = 'Windows 11 Home N'
    'NPPR9-FWDCX-D2C8J-H872K-2YT43' = 'Windows 11 Enterprise'
    'NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J' = 'Windows 11 Pro for Workstations'
    'W269N-WFGWX-YVC9B-4J6C9-T83GX' = 'Windows 10/11 Pro'
}

function Get-KeyFromOA3 {
    try {
        $key = (Get-CimInstance -Query 'SELECT * FROM SoftwareLicensingService').OA3xOriginalProductKey
        return $key
    } catch { return $null }
}

function Get-KeyFromDigitalProductId {
    # Windows stores the active product key in the registry as a binary blob (DigitalProductId).
    # The key is encoded using a custom Base24 algorithm — 24 characters that exclude
    # vowels (no A/E/I/O/U) and ambiguous digits (no 0/1/5) to avoid offensive words
    # and confusion between similar-looking characters.
    # Charset: BCDFGHJKMPQRTVWXY2346789
    try {
        $dpid  = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DigitalProductId
        if (-not $dpid) { return $null }

        # The encoded key lives in bytes 52–66 (15 bytes) of the blob.
        $key   = $dpid[52..66]
        $chars = 'BCDFGHJKMPQRTVWXY2346789'
        $productKey = ''

        # Windows 8+ keys have a special 'N' character embedded. This flag is stored
        # in the high bits of byte 14 and must be cleared before decoding.
        $isWin8Plus = ($key[14] -shr 3) -band 1
        $key[14]    = ($key[14] -band 0xF7) -bor (($isWin8Plus -band 2) -shl 2)

        # Base24 decode: 25 iterations, each producing one character.
        # Works like converting a base-256 number to base-24, digit by digit.
        for ($i = 24; $i -ge 0; $i--) {
            $cur = 0
            for ($j = 14; $j -ge 0; $j--) {
                $cur     = ($cur -shl 8) -bor $key[$j]  # shift accumulator and add next byte
                $key[$j] = [math]::Floor($cur / 24)      # quotient stays in the array
                $cur     = $cur % 24                      # remainder is the current character index
            }
            $productKey = $chars[$cur] + $productKey      # prepend (we're going right-to-left)
        }

        # Re-insert the 'N' at the correct position for Windows 8+ keys.
        if ($isWin8Plus) {
            $firstChar = $productKey[0]
            $nIndex = 0
            for ($i = 0; $i -lt $chars.Length; $i++) {
                if ($chars[$i] -eq $firstChar) { $nIndex = $i; break }
            }
            $productKey = $productKey.Substring(1).Insert($nIndex, 'N')
        }

        # Format as XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
        $formatted = ''
        for ($i = 0; $i -lt 25; $i++) {
            $formatted += $productKey[$i]
            if (($i + 1) % 5 -eq 0 -and $i -lt 24) { $formatted += '-' }
        }
        return $formatted
    } catch { return $null }
}

function Test-KeyFormat {
    param([string]$Key)
    return $Key -match '^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$'
}

# ---- Run both methods ----
Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host "  Windows License Key" -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

$os = Get-CimInstance -ClassName Win32_OperatingSystem
Write-Host "  Detected: $($os.Caption) (Build $($os.BuildNumber))`n" -ForegroundColor Yellow

Write-Host "  [>>] Method 1: OA3 (UEFI/BIOS firmware)..." -ForegroundColor DarkGray
$oa3Key = Get-KeyFromOA3
$oa3OK  = $oa3Key -and (Test-KeyFormat $oa3Key)
Write-Host "       $(if ($oa3OK) { '[+] Found' } else { '[-] Not found' })$(if ($oa3OK) { ": $oa3Key" } else { '' })" -ForegroundColor $(if ($oa3OK) { 'Green' } else { 'DarkGray' })

Write-Host "  [>>] Method 2: DigitalProductId (registry decode)..." -ForegroundColor DarkGray
$regKey = Get-KeyFromDigitalProductId
$regOK  = $regKey -and (Test-KeyFormat $regKey)
Write-Host "       $(if ($regOK) { '[+] Found' } else { '[-] Not found' })$(if ($regOK) { ": $regKey" } else { '' })" -ForegroundColor $(if ($regOK) { 'Green' } else { 'DarkGray' })

# Registry key = the currently active key (preferred — this is what Windows uses right now).
# OA3 key = the original key burned into UEFI/BIOS by the manufacturer (fallback).
# On upgraded or re-activated systems both can exist and may differ.
$bestKey    = if ($regOK) { $regKey } elseif ($oa3OK) { $oa3Key } else { $null }
$bestSource = if ($regOK) { 'Registry (DigitalProductId)' } elseif ($oa3OK) { 'UEFI/BIOS (OA3)' } else { 'None' }

Write-Host ''
if ($bestKey) {
    $isGeneric = $genericKeys.ContainsKey($bestKey)
    Write-Host "  Primary Key  : $bestKey" -ForegroundColor $(if ($isGeneric) { 'Yellow' } else { 'Green' })
    Write-Host "  Source       : $bestSource"
    if ($isGeneric) {
        Write-Host "`n  [!] WARNING: This is a generic placeholder key ($($genericKeys[$bestKey]))." -ForegroundColor Yellow
        Write-Host "      It will not activate Windows. Your system may use a digital license" -ForegroundColor Yellow
        Write-Host "      linked to your Microsoft account, or was activated via KMS/MAK.`n"    -ForegroundColor Yellow
    } else {
        Write-Host "`n  Save this key in a secure location for future re-activation.`n" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  No product key found.`n" -ForegroundColor Red
    Write-Host "  Your system may use a digital license linked to your Microsoft account,`n  or volume licensing (KMS/MAK).`n" -ForegroundColor DarkGray
}

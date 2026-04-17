#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 10 — System Information
# ============================================================================

$os      = Get-CimInstance -ClassName Win32_OperatingSystem
$cs      = Get-CimInstance -ClassName Win32_ComputerSystem
$cpu     = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1

# DisplayVersion (e.g. "25H2") and UBR are only in the registry — WMI doesn't expose them.
$ntCv      = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$winVer    = $ntCv.DisplayVersion
$ubr       = $ntCv.UBR
$fullBuild = if ($ubr) { "$($os.BuildNumber).$ubr" } else { $os.BuildNumber }

# Firmware (UEFI) — Win32_BIOS holds the version string and release date.
# $env:firmware_type reports 'UEFI' or 'Legacy' set by the Windows boot loader.
$fw        = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
$fwType    = if ($env:firmware_type) { $env:firmware_type } else { 'Unknown' }
$fwVersion = if ($fw.SMBIOSBIOSVersion) { $fw.SMBIOSBIOSVersion } else { 'Unknown' }
$fwDate    = if ($fw.ReleaseDate) { $fw.ReleaseDate.ToString('yyyy-MM-dd') } else { 'Unknown' }

# Secure Boot — Confirm-SecureBootUEFI throws on legacy firmware, so we catch it.
$secureBoot = try {
    if (Confirm-SecureBootUEFI) { 'Enabled' } else { 'Disabled' }
} catch { 'N/A' }

# TPM — Get-Tpm for ready/present state; Win32_Tpm for the spec version (1.2 vs 2.0).
$tpmState   = Get-Tpm -ErrorAction SilentlyContinue
$tpmWmi     = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' `
                  -ClassName Win32_Tpm -ErrorAction SilentlyContinue
$tpmVersion = if ($tpmWmi.SpecVersion) { ($tpmWmi.SpecVersion -split ',')[0].Trim() } else { 'N/A' }
$tpmStatus  = if ($tpmState.TpmReady)   { 'Ready' }
              elseif ($tpmState.TpmPresent) { 'Present (not ready)' }
              else { 'Not present' }

[PSCustomObject]@{
    'Computer Name'      = $env:COMPUTERNAME
    'OS Name'            = $os.Caption
    'Windows Version'    = $winVer
    'OS Build'           = $fullBuild
    'Architecture'       = $os.OSArchitecture
    'Manufacturer'       = $cs.Manufacturer
    'Model'              = $cs.Model
    'Firmware Type'      = $fwType
    'Firmware Version'   = $fwVersion
    'Firmware Date'      = $fwDate
    'Secure Boot'        = $secureBoot
    'TPM Version'        = $tpmVersion
    'TPM Status'         = $tpmStatus
    'Processor'          = $cpu.Name
    'Total RAM (GB)'     = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    'Install Date'       = $os.InstallDate.ToString('yyyy-MM-dd')
    'Last Boot'          = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
    'System Directory'   = $os.SystemDirectory
    'Windows Directory'  = $os.WindowsDirectory
} | Format-List | Out-Host

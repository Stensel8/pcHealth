#Requires -Version 7.0
# ============================================================================
# pcHealth -- System Information
# ============================================================================

if ($IsLinux) {
    $hostname  = [System.Net.Dns]::GetHostName()
    $kernel    = (& uname -r 2>$null).Trim()
    $arch      = (& uname -m 2>$null).Trim()
    $uptime    = (& 'uptime' -p 2>$null).Trim()
    $user      = $env:USER ?? $env:USERNAME

    $osRelease = @{}
    if (Test-Path '/etc/os-release') {
        Get-Content '/etc/os-release' | ForEach-Object {
            if ($_ -match '^(\w+)=(.*)$') {
                $osRelease[$Matches[1]] = $Matches[2].Trim('"')
            }
        }
    }
    $osName = $osRelease['PRETTY_NAME'] ?? $osRelease['NAME'] ?? 'Linux'

    $memInfo = @{}
    if (Test-Path '/proc/meminfo') {
        Get-Content '/proc/meminfo' | ForEach-Object {
            if ($_ -match '^(\w+):\s+(\d+)') {
                $memInfo[$Matches[1]] = [long]$Matches[2]
            }
        }
    }
    $totalRamGB = if ($memInfo['MemTotal']) { [Math]::Round($memInfo['MemTotal'] / 1MB, 2) } else { 'N/A' }

    [PSCustomObject]@{
        'Computer Name'   = $hostname
        'OS Name'         = $osName
        'Kernel'          = $kernel
        'Architecture'    = $arch
        'Total RAM (GB)'  = $totalRamGB
        'Uptime'          = $uptime
        'User'            = $user
    } | Format-List | Out-Host

} else {
    $os    = Get-CimInstance -ClassName Win32_OperatingSystem
    $cs    = Get-CimInstance -ClassName Win32_ComputerSystem
    $cpu   = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $ntCv  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue

    $winVer    = $ntCv.DisplayVersion
    $ubr       = $ntCv.UBR
    $fullBuild = if ($ubr) { "$($os.BuildNumber).$ubr" } else { $os.BuildNumber }

    $fw        = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
    $fwType    = if ($env:firmware_type) { $env:firmware_type } else { 'Unknown' }
    $fwVersion = if ($fw.SMBIOSBIOSVersion) { $fw.SMBIOSBIOSVersion } else { 'Unknown' }
    $fwDate    = if ($fw.ReleaseDate) { $fw.ReleaseDate.ToString('yyyy-MM-dd') } else { 'Unknown' }

    $secureBoot = try {
        if (Confirm-SecureBootUEFI) { 'Enabled' } else { 'Disabled' }
    } catch { 'N/A' }

    $tpmState   = Get-Tpm -ErrorAction SilentlyContinue
    $tpmWmi     = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' `
                      -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    $tpmVersion = if ($tpmWmi.SpecVersion) { ($tpmWmi.SpecVersion -split ',')[0].Trim() } else { 'N/A' }
    $tpmStatus  = if ($tpmState.TpmReady)      { 'Ready' }
                  elseif ($tpmState.TpmPresent) { 'Present (not ready)' }
                  else { 'Not present' }

    [PSCustomObject]@{
        'Computer Name'    = $env:COMPUTERNAME
        'OS Name'          = $os.Caption
        'Windows Version'  = $winVer
        'OS Build'         = $fullBuild
        'Architecture'     = $os.OSArchitecture
        'Manufacturer'     = $cs.Manufacturer
        'Model'            = $cs.Model
        'Firmware Type'    = $fwType
        'Firmware Version' = $fwVersion
        'Firmware Date'    = $fwDate
        'Secure Boot'      = $secureBoot
        'TPM Version'      = $tpmVersion
        'TPM Status'       = $tpmStatus
        'Processor'        = $cpu.Name
        'Total RAM (GB)'   = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        'Install Date'     = $os.InstallDate.ToString('yyyy-MM-dd')
        'Last Boot'        = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
        'System Directory' = $os.SystemDirectory
        'Windows Directory'= $os.WindowsDirectory
    } | Format-List | Out-Host
}

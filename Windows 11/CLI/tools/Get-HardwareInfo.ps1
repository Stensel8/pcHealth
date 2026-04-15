#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — Hardware Information
# CPU, GPU, Storage (SMART via smartmontools), RAM, Chipset.
# Uses modern CIM/PnP interfaces. WMIC is deprecated since Windows 11.
# ============================================================================

# Prints a styled section header: "─── Title ──────────────────────────────"
function Write-SectionHeader {
    param([string]$Title)
    $prefix  = '─── '
    $fill    = '─' * [Math]::Max(0, 90 - $prefix.Length - $Title.Length - 1)
    Write-Host "`n$prefix$Title $fill" -ForegroundColor Cyan
}

# --- smartmontools pre-check ---
# smartctl is required for the Storage section (SMART data, temperature, life left).
# Check once at startup so the prompt appears before any output.
function Find-Smartctl {
    $inPath = Get-Command smartctl -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    $prog = "$env:ProgramFiles\smartmontools\bin\smartctl.exe"
    if (Test-Path $prog) { return $prog }
    return $null
}

$smartctl = Find-Smartctl
if (-not $smartctl) {
    Write-Host "`nsmartmontools is required to read storage SMART data (temperature, hours, life left)." -ForegroundColor Yellow
    $answer = (Read-Host "  Install it now via winget? [y/n]").Trim().ToLower()
    if ($answer -eq 'y') {
        Write-Host "  Installing smartmontools..." -ForegroundColor Yellow
        winget install --id smartmontools.smartmontools -e --silent `
            --accept-package-agreements --accept-source-agreements
        $smartctl = Find-Smartctl
        if ($smartctl) {
            Write-Host "  smartmontools installed successfully.`n" -ForegroundColor Green
        } else {
            Write-Warning "Install completed but smartctl was not found. Storage section will be skipped."
        }
    } else {
        Write-Host "  Skipping storage readout.`n" -ForegroundColor DarkGray
    }
}

# --- CPU ---
$cpuData = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
if ($cpuData) {
    Write-SectionHeader 'CPU Information'
    $cpuData | Select-Object @{N='CPU Name';  E={$_.Name}},
                              @{N='Cores';    E={$_.NumberOfCores}},
                              @{N='Threads';  E={$_.NumberOfLogicalProcessors}},
                              @{N='Base Speed (MHz)'; E={$_.MaxClockSpeed}} |
              Format-Table -AutoSize | Out-Host
} else {
    Write-Warning "CPU information not available."
}

# --- GPU ---
# The display driver writes HardwareInformation.qwMemorySize (64-bit) into the
# registry when it loads — the same value that DXGI/Task Manager reads.
# AdapterRAM in WMI is a 32-bit field, so it caps at 4 GB on large cards.
# AMD drivers sometimes store qwMemorySize as REG_BINARY rather than REG_QWORD,
# so we handle both types.

# HardwareInformation.qwMemorySize is a 64-bit registry value written by the display
# driver — not capped at 4 GB unlike Win32_VideoController.AdapterRAM (32-bit WMI).
# AMD drivers sometimes store it as REG_BINARY rather than REG_QWORD.
function ConvertTo-VramGB {
    param($raw)
    if ($null -eq $raw) { return $null }
    $bytes = if ($raw -is [byte[]] -and $raw.Length -ge 8) {
        [BitConverter]::ToInt64($raw, 0)
    } elseif ($raw -isnot [byte[]]) {
        [long]$raw
    } else { 0L }
    if ($bytes -le 0) { return $null }
    return [Math]::Round($bytes / 1GB, 2)
}

$classKey    = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
$regAdapters = @()
try {
    $regAdapters = @(
        Get-ChildItem $classKey -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^\d' } |
            ForEach-Object { Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue } |
            Where-Object { $null -ne (ConvertTo-VramGB $_.'HardwareInformation.qwMemorySize') }
    )
} catch {
    Write-Warning "Registry adapter key unreadable — falling back to AdapterRAM: $_"
}

$gpuData = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
if ($gpuData) {
    Write-SectionHeader 'GPU Information'
    $gpuData | ForEach-Object {
        $gpu = $_

        # Exact name match, then partial, then sole-entry fallback (single-GPU systems).
        $regEntry = $regAdapters | Where-Object {
            $_.'HardwareInformation.AdapterString' -eq $gpu.Name
        } | Select-Object -First 1

        if (-not $regEntry) {
            $regEntry = $regAdapters | Where-Object {
                $a = $_.'HardwareInformation.AdapterString'
                $a -and ($gpu.Name -like "*$a*" -or $a -like "*$($gpu.Name)*")
            } | Select-Object -First 1
        }

        if (-not $regEntry -and $regAdapters.Count -eq 1) {
            $regEntry = $regAdapters[0]
        }

        # iGPU (Intel/AMD APU): no dedicated VRAM — show 'Shared' instead of 0.
        $vramGB = if ($regEntry) {
            ConvertTo-VramGB $regEntry.'HardwareInformation.qwMemorySize'
        } elseif ($gpu.AdapterRAM -ge 1GB) {
            [Math]::Round($gpu.AdapterRAM / 1GB, 2)
        } else { 'Shared' }

        [PSCustomObject]@{
            Name          = $gpu.Name
            'Video Proc.' = $gpu.VideoProcessor
            'Driver Ver.' = $gpu.DriverVersion
            'Driver Date' = if ($gpu.DriverDate) { $gpu.DriverDate.ToString('yyyy-MM-dd') } else { 'N/A' }
            'VRAM (GB)'   = $vramGB
        }
    } | Format-Table -AutoSize | Out-Host
} else {
    Write-Warning "GPU information not available."
}

# --- Storage ---
# smartmontools (smartctl) provides richer SMART data than Windows built-ins:
# temperature, power-on hours, and accurate life remaining for SSDs and NVMe drives.
# Life remaining:
#   NVMe  — percentage_used from health log → remaining = 100 - used.
#   SATA  — attribute 231 (SSD_Life_Left), then 202 (Percent_Lifetime_Remaining),
#            then 177 (Wear_Leveling_Count). All store remaining life in .value.
Write-SectionHeader 'Storage'

if ($smartctl) {
    $scanData = (& $smartctl --scan --json 2>$null) | ConvertFrom-Json -ErrorAction SilentlyContinue
    $devices  = $scanData.devices

    if ($devices) {
        $storageRows = @(foreach ($dev in $devices) {
            $data = (& $smartctl -a $dev.name --json 2>$null) | ConvertFrom-Json -ErrorAction SilentlyContinue
            if (-not $data -or -not $data.model_name) { continue }

            # Drive type — NVMe is always SSD; SATA with rotation_rate=0 is SSD, else HDD.
            $busType   = switch ($dev.type) {
                'nvme'  { 'NVMe' }
                'sat'   { 'SATA' }
                default { $dev.type.ToUpper() }
            }
            $mediaType = if ($dev.type -eq 'nvme') { 'SSD' }
                         elseif ($data.rotation_rate -gt 0) { 'HDD' }
                         else { 'SSD' }

            $lifeLeft = 'N/A'
            if ($dev.type -eq 'nvme') {
                $pct = $data.nvme_smart_health_information_log.percentage_used
                if ($null -ne $pct) { $lifeLeft = "$([Math]::Max(0, 100 - [int]$pct))%" }
            } elseif ($mediaType -eq 'SSD') {
                $wearAttr = $data.ata_smart_attributes.table |
                    Where-Object { $_.id -in @(231, 202, 177) } |
                    Select-Object -First 1
                if ($wearAttr) { $lifeLeft = "$($wearAttr.value)%" }
            }

            [PSCustomObject]@{
                Model       = $data.model_name
                Bus         = $busType
                Type        = $mediaType
                'Size (GB)' = if ($data.capacity.bytes) { [Math]::Round($data.capacity.bytes / 1GB, 0) } else { 'N/A' }
                'Temp (°C)' = if ($null -ne $data.temperature.current) { $data.temperature.current } else { 'N/A' }
                'Hours'     = if ($data.power_on_time.hours) { $data.power_on_time.hours } else { 'N/A' }
                'Life Left' = $lifeLeft
                Health      = if ($data.smart_status.passed -eq $true)  { 'Healthy' }
                              elseif ($data.smart_status.passed -eq $false) { 'FAILING' }
                              else { 'Unknown' }
            }
        })

        if ($storageRows) {
            $storageRows | Format-Table -AutoSize | Out-Host
        } else {
            Write-Warning "smartctl returned no usable device data."
        }
    } else {
        Write-Warning "smartctl scan found no devices."
    }
} else {
    Write-Warning "Storage section skipped — smartmontools not available."
}

# --- RAM ---
# Win32_PhysicalMemory.Manufacturer reads the JEDEC SPD chip, which consumer
# brands (Corsair, Crucial, G.Skill, etc.) often leave blank or set to "Unknown".
# Fall back to inferring the brand from the part number prefix.
function Resolve-RamManufacturer {
    param([string]$Manufacturer, [string]$PartNumber)
    $m = $Manufacturer.Trim()
    if ($m -and $m -ne 'Unknown') { return $m }
    switch -Wildcard ($PartNumber.Trim()) {
        'CM*'        { return 'Corsair' }
        'CT*'        { return 'Crucial' }
        'BL*'        { return 'Crucial' }
        'KVR*'       { return 'Kingston' }
        'HX*'        { return 'HyperX / Kingston' }
        'F4-*'       { return 'G.Skill' }
        'F5-*'       { return 'G.Skill' }
        'TED*'       { return 'TeamGroup' }
        'TEAMGROUP*' { return 'TeamGroup' }
        'MTA*'       { return 'Micron' }
        'MT*'        { return 'Micron' }
        'M378*'      { return 'Samsung' }
        'M471*'      { return 'Samsung' }
        'AD4*'       { return 'ADATA' }
        'AX4*'       { return 'ADATA (XPG)' }
        default      { return 'Unknown' }
    }
}

$ramData = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
if ($ramData) {
    Write-SectionHeader 'Memory (RAM) Modules'
    $ramData | Select-Object @{N='Slot';         E={$_.BankLabel}},
                              @{N='Capacity(GB)'; E={[Math]::Round($_.Capacity / 1GB, 2)}},
                              @{N='Speed(MT/s)';  E={$_.Speed}},
                              @{N='Part Number';  E={$_.PartNumber.Trim()}},
                              @{N='Manufacturer'; E={Resolve-RamManufacturer $_.Manufacturer $_.PartNumber}} |
               Format-Table -AutoSize | Out-Host

    $totalGB = [Math]::Round(($ramData | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
    Write-Host "Total Installed RAM: $totalGB GB`n" -ForegroundColor Green
} else {
    Write-Warning "RAM information not available."
}

# --- Chipset ---
# The SMBus controller is part of the chipset on both AMD and Intel platforms.
# Its PnP driver version and date represent the chipset driver package version.
Write-SectionHeader 'Chipset'
$smbus = Get-PnpDevice -Class System -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -like '*SMBus*' -and $_.Status -eq 'OK' } |
    Select-Object -First 1

if ($smbus) {
    $chipsetVer  = (Get-PnpDeviceProperty -InstanceId $smbus.InstanceId `
                        -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction SilentlyContinue).Data
    $chipsetDate = (Get-PnpDeviceProperty -InstanceId $smbus.InstanceId `
                        -KeyName 'DEVPKEY_Device_DriverDate' -ErrorAction SilentlyContinue).Data

    [PSCustomObject]@{
        Device            = $smbus.FriendlyName
        'Driver Version'  = if ($chipsetVer)  { $chipsetVer } else { 'N/A' }
        'Driver Date'     = if ($chipsetDate) { ([datetime]$chipsetDate).ToString('yyyy-MM-dd') } else { 'N/A' }
    } | Format-List | Out-Host
} else {
    Write-Warning "Chipset SMBus controller not found."
}

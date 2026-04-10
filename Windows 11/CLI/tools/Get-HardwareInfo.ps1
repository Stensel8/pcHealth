#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — CPU / GPU / RAM Info
# Uses modern CIM interfaces. WMIC is deprecated since Windows 11.
# ============================================================================

# --- CPU ---
$cpuData = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
if ($cpuData) {
    Write-Host "`nCPU Information:" -ForegroundColor Cyan
    $cpuData | Select-Object @{N='CPU Name';  E={$_.Name}},
                              @{N='Cores';    E={$_.NumberOfCores}},
                              @{N='Threads';  E={$_.NumberOfLogicalProcessors}},
                              @{N='Base Speed (MHz)'; E={$_.MaxClockSpeed}} |
              Format-Table -AutoSize
} else {
    Write-Warning "CPU information not available."
}

# --- GPU ---
# Use registry for accurate VRAM (handles GPUs with >4 GB VRAM)
$regPath       = "HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*"
$adapterMemory = Get-ItemProperty -Path $regPath `
                    -Name 'HardwareInformation.AdapterString','HardwareInformation.qwMemorySize' `
                    -ErrorAction SilentlyContinue

$gpuData = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
if ($gpuData) {
    Write-Host "GPU Information:" -ForegroundColor Cyan
    $gpuData | ForEach-Object {
        $gpu      = $_
        $regEntry = $adapterMemory | Where-Object { $_.'HardwareInformation.AdapterString' -eq $gpu.Name }
        $vramGB   = if ($regEntry?.'HardwareInformation.qwMemorySize') {
            [Math]::Round($regEntry.'HardwareInformation.qwMemorySize' / 1GB, 2)
        } elseif ($gpu.AdapterRAM) {
            [Math]::Round($gpu.AdapterRAM / 1GB, 2)
        } else { 'N/A' }

        [PSCustomObject]@{
            Name            = $gpu.Name
            'Video Proc.'   = $gpu.VideoProcessor
            'Driver Ver.'   = $gpu.DriverVersion
            'VRAM (GB)'     = $vramGB
        }
    } | Format-Table -AutoSize
} else {
    Write-Warning "GPU information not available."
}

# --- RAM ---
$ramData = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
if ($ramData) {
    Write-Host "Memory (RAM) Modules:" -ForegroundColor Cyan
    $ramData | Select-Object @{N='Slot';         E={$_.BankLabel}},
                              @{N='Capacity(GB)'; E={[Math]::Round($_.Capacity / 1GB, 2)}},
                              @{N='Speed(MHz)';   E={$_.Speed}},
                              @{N='Manufacturer'; E={$_.Manufacturer}} |
               Format-Table -AutoSize

    $totalGB = [Math]::Round(($ramData | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
    Write-Host "Total Installed RAM: $totalGB GB`n" -ForegroundColor Green
} else {
    Write-Warning "RAM information not available."
}

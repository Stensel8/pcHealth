#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — System Information
# ============================================================================

Write-Host "`nGathering system information...`n" -ForegroundColor Cyan

$os  = Get-CimInstance -ClassName Win32_OperatingSystem
$cs  = Get-CimInstance -ClassName Win32_ComputerSystem
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1

[PSCustomObject]@{
    'Computer Name'      = $env:COMPUTERNAME
    'OS Name'            = $os.Caption
    'OS Version'         = $os.Version
    'OS Build'           = $os.BuildNumber
    'Architecture'       = $os.OSArchitecture
    'Manufacturer'       = $cs.Manufacturer
    'Model'              = $cs.Model
    'Processor'          = $cpu.Name
    'Total RAM (GB)'     = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    'Last Boot'          = $os.LastBootUpTime
    'System Directory'   = $os.SystemDirectory
    'Windows Directory'  = $os.WindowsDirectory
} | Format-List

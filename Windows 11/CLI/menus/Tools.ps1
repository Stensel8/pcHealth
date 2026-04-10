# ============================================================================
# pcHealth — Windows 11 — Tools Menu
# ============================================================================

function Show-ToolsMenu {
    $t = Join-Path $Global:pcHealthRoot 'tools'

    while ($true) {
        Clear-Host
        Write-PcHeader 'Tools'

        Write-PcOption  '1'  'System Information'
        Write-PcOption  '2'  'CPU / GPU / RAM Info'
        Write-PcOption  '3'  'System File Scan'                    '(SFC)'
        Write-PcOption  '4'  'DISM Health Check'
        Write-PcOption  '5'  'Scan + Repair'                       '(SFC + DISM combined)'
        Write-PcOption  '6'  'Battery Report'                      '(laptop only)'
        Write-PcOption  '7'  'Windows Update'
        Write-PcOption  '8'  'Disk Optimization'
        Write-PcOption  '9'  'Disk Cleanup'
        Write-PcOption '10'  'Short Ping Test'
        Write-PcOption '11'  'Continuous Ping Test'
        Write-PcOption '12'  'Traceroute to Google'
        Write-PcOption '13'  'Reset Network Stack'
        Write-PcOption '14'  'Update System Programs'              '(winget)'
        Write-PcOption '15'  'Update HP Drivers'                   '(HP only)'
        Write-PcOption '16'  'Restart Audio Drivers'
        Write-PcOption '17'  'Open Battery Report'
        Write-PcOption '18'  'Open CBS Log'
        Write-PcOption '19'  'Get Ninite'                          '(Edge, Chrome, VLC, 7-Zip)'
        Write-PcOption '20'  'Windows License Key'
        Write-PcOption '21'  'BIOS Password Recovery'
        Write-PcOption '22'  'Repair Boot Record'                  '(use with caution!)'
        Write-PcOption '23'  'Shutdown / Reboot / Log Off'
        Write-PcDivider
        Write-PcOption  'B'  'Back to Main Menu'
        Write-PcOption  'X'  'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim().ToUpper()

        # $script starts as $null. The switch sets it to a filename for valid numeric
        # choices, and directly returns/exits for 'B' and 'X'. After the switch,
        # $script still being $null means the input was not recognised.
        $script = $null
        switch ($choice) {
            '1'  { $script = 'Get-SystemInfo.ps1' }
            '2'  { $script = 'Get-HardwareInfo.ps1' }
            '3'  { $script = 'Invoke-SystemScan.ps1' }
            '4'  { $script = 'Invoke-DISMCheck.ps1' }
            '5'  { $script = 'Invoke-ScanAndRepair.ps1' }
            '6'  { $script = 'Get-BatteryReport.ps1' }
            '7'  { $script = 'Invoke-WindowsUpdate.ps1' }
            '8'  { $script = 'Invoke-DiskOptimize.ps1' }
            '9'  { $script = 'Invoke-DiskCleanup.ps1' }
            '10' { $script = 'Test-NetworkShort.ps1' }
            '11' { $script = 'Test-NetworkContinuous.ps1' }
            '12' { $script = 'Test-Traceroute.ps1' }
            '13' { $script = 'Invoke-NetworkReset.ps1' }
            '14' { $script = 'Invoke-SystemUpdate.ps1' }
            '15' { $script = 'Invoke-HPUpdate.ps1' }
            '16' { $script = 'Invoke-AudioRestart.ps1' }
            '17' { $script = 'Open-BatteryReport.ps1' }
            '18' { $script = 'Open-CBSLog.ps1' }
            '19' { $script = 'Get-Ninite.ps1' }
            '20' { $script = 'Get-LicenseKey.ps1' }
            '21' { $script = 'Show-BIOSPasswordTool.ps1' }
            '22' { $script = 'Invoke-BootRepair.ps1' }
            '23' { $script = 'Invoke-PowerOptions.ps1' }
            'B'  { return 'back' }  # Back to Main — Main.ps1 just re-loops, same effect
            'X'  { return 'exit' }  # Tells Main.ps1 to call exit 0
        }

        if ($script) {
            # & is the call operator — runs the script file in the current session
            # so it inherits all dot-sourced functions and the global pcHealthRoot variable.
            & "$t\$script"
            $nav = Read-PcNavChoice 'Back to Tools Menu'
            if ($nav -eq 'M') { return 'main' }
            if ($nav -eq 'X') { return 'exit' }
            # 'B' → fall through to the top of the while loop (stay in Tools menu)
        } elseif ($choice -notin 'B','X') {
            # 'B' and 'X' already returned above, so this branch is purely for
            # inputs that didn't match any case in the switch.
            Write-Host "`n  Invalid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
        }
    }
}

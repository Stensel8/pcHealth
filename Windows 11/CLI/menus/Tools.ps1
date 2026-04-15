# ============================================================================
# pcHealth — Windows 11 — Tools Menu
# ============================================================================

function Show-ToolsMenu {
    $t = Join-Path $Global:pcHealthRoot 'tools'

    while ($true) {
        Set-PcTheme 'Tools'
        Clear-Host
        Write-PcHeader 'Tools'

        Write-PcOption  '1'  'System Information'
        Write-PcOption  '2'  'Hardware Information'
        Write-PcOption  '3'  'Scan + Repair'                       '(SFC + DISM combined)'
        Write-PcOption  '4'  'Battery Report'                      '(laptop only)'
        Write-PcOption  '5'  'Windows Update'
        Write-PcOption  '6'  'Disk Optimization'
        Write-PcOption  '7'  'Disk Cleanup'
        Write-PcOption  '8'  'Short Ping Test'
        Write-PcOption  '9'  'Continuous Ping Test'
        Write-PcOption '10'  'Traceroute to Google'
        Write-PcOption '11'  'Reset Network Stack'
        Write-PcOption '12'  'Update System Programs'              '(winget)'
        Write-PcOption '13'  'Update HP Drivers'                   '(HP only)'
        Write-PcOption '14'  'Restart Audio Drivers'
        Write-PcOption '15'  'Open Battery Report'
        Write-PcOption '16'  'Open CBS Log'
        Write-PcOption '17'  'Get Ninite'                          '(Edge, Chrome, VLC, 7-Zip)'
        Write-PcOption '18'  'Windows License Key'
        Write-PcOption '19'  'BIOS Password Recovery'
        Write-PcOption '20'  'Repair Boot Record'                  '(use with caution!)'
        Write-PcOption '21'  'Shutdown / Reboot / Log Off'
        Write-PcDivider
        Write-PcOption '22' 'Programs Menu'
        Write-PcOption '23' 'Back to Main Menu'
        Write-PcOption '24' 'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim()

        # $script starts as $null. The switch sets it to a filename for valid numeric
        # choices, and directly returns for 22, 23, and 24.
        $script = $null
        switch ($choice) {
            '1'  { $script = 'Get-SystemInfo.ps1' }
            '2'  { $script = 'Get-HardwareInfo.ps1' }
            '3'  { $script = 'Invoke-ScanAndRepair.ps1' }
            '4'  { $script = 'Get-BatteryReport.ps1' }
            '5'  { $script = 'Invoke-WindowsUpdate.ps1' }
            '6'  { $script = 'Invoke-DiskOptimize.ps1' }
            '7'  { $script = 'Invoke-DiskCleanup.ps1' }
            '8'  { $script = 'Test-NetworkShort.ps1' }
            '9'  { $script = 'Test-NetworkContinuous.ps1' }
            '10' { $script = 'Test-Traceroute.ps1' }
            '11' { $script = 'Invoke-NetworkReset.ps1' }
            '12' { $script = 'Invoke-SystemUpdate.ps1' }
            '13' { $script = 'Invoke-HPUpdate.ps1' }
            '14' { $script = 'Invoke-AudioRestart.ps1' }
            '15' { $script = 'Open-BatteryReport.ps1' }
            '16' { $script = 'Open-CBSLog.ps1' }
            '17' { $script = 'Get-Ninite.ps1' }
            '18' { $script = 'Get-LicenseKey.ps1' }
            '19' { $script = 'Open-BIOSPasswordTool.ps1' }
            '20' { $script = 'Invoke-BootRepair.ps1' }
            '21' { $script = 'Invoke-PowerOptions.ps1' }
            '22' { return 'programs' }  # Cross-navigate to Programs menu
            '23' { return 'main' }      # Back to Main
            '24' { return 'exit' }      # Tells Main.ps1 to call exit 0
        }

        if ($script) {
            # Switch to action theme (black bg, green fg) before running the tool —
            # mirrors the BAT file's `color 0A` at the top of each action section.
            # Individual tools (Boot Repair, BIOS PW) override the theme themselves.
            Set-PcTheme 'Action'
            Clear-Host
            # & is the call operator — runs the script in the current session so it
            # inherits all dot-sourced functions including Set-PcTheme.
            & "$t\$script"
            $nav = Read-PcNavChoice 'Back to Tools Menu'
            switch ($nav) {
                '2' { return 'main' }
                '3' { return 'exit' }
                # '1' → fall through to the top of the while loop (stay in Tools)
            }
        } elseif ($choice -notin '22','23','24') {
            Write-Host "`n  Invalid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
        }
    }
}

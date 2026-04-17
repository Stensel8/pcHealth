# ============================================================================
# pcHealth — Shared — Tools Menu
# Data-driven: options are filtered per platform at runtime so option numbers
# are always sequential with no gaps.
# ============================================================================

function Show-ToolsMenu {
    # Each entry: Label, Script (relative to tools/), Note, Platforms.
    # Platforms controls which OS sees the option.
    $toolDefs = @(
        @{ Label = 'System Information';          Script = 'Get-SystemInfo.ps1';          Note = '';                      Platforms = @('Windows10','Windows11','Linux') }
        @{ Label = 'Hardware Information';         Script = 'Get-HardwareInfo.ps1';         Note = '';                      Platforms = @('Windows10','Windows11','Linux') }
        @{ Label = 'System File Scan';             Script = 'Invoke-SystemScan.ps1';         Note = '(SFC /scannow)';        Platforms = @('Windows10','Windows11') }
        @{ Label = 'DISM Health Check';            Script = 'Invoke-DISMCheck.ps1';          Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'Scan + Repair';                Script = 'Invoke-ScanAndRepair.ps1';      Note = '(SFC + DISM combined)'; Platforms = @('Windows10','Windows11') }
        @{ Label = 'Battery Report';               Script = 'Get-BatteryReport.ps1';         Note = '(laptop only)';         Platforms = @('Windows10','Windows11') }
        @{ Label = 'Windows Update';               Script = 'Invoke-WindowsUpdate.ps1';      Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'Disk Optimization';            Script = 'Invoke-DiskOptimize.ps1';       Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'Disk Cleanup';                 Script = 'Invoke-DiskCleanup.ps1';        Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'Short Ping Test';              Script = 'Test-NetworkShort.ps1';         Note = '';                      Platforms = @('Windows10','Windows11','Linux') }
        @{ Label = 'Continuous Ping Test';         Script = 'Test-NetworkContinuous.ps1';    Note = '';                      Platforms = @('Windows10','Windows11','Linux') }
        @{ Label = 'Traceroute to Google';         Script = 'Test-Traceroute.ps1';           Note = '';                      Platforms = @('Windows10','Windows11','Linux') }
        @{ Label = 'Reset Network Stack';          Script = 'Invoke-NetworkReset.ps1';       Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'Update System Programs';       Script = 'Invoke-SystemUpdate.ps1';       Note = '(winget)';              Platforms = @('Windows10','Windows11') }
        @{ Label = 'Update HP Drivers';            Script = 'Invoke-HPUpdate.ps1';           Note = '(HP only)';             Platforms = @('Windows10','Windows11') }
        @{ Label = 'Restart Audio Drivers';        Script = 'Invoke-AudioRestart.ps1';       Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'Open Battery Report';          Script = 'Open-BatteryReport.ps1';        Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'Open CBS Log';                 Script = 'Open-CBSLog.ps1';               Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'Get Ninite';                   Script = 'Get-Ninite.ps1';                Note = '(Edge, Chrome, VLC, 7-Zip)'; Platforms = @('Windows10','Windows11') }
        @{ Label = 'Windows License Key';          Script = 'Get-LicenseKey.ps1';            Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'BIOS Password Recovery';       Script = 'Open-BIOSPasswordTool.ps1';     Note = '';                      Platforms = @('Windows10','Windows11','Linux') }
        @{ Label = 'Repair Boot Record';           Script = 'Invoke-BootRepair.ps1';         Note = '(use with caution!)';   Platforms = @('Windows10','Windows11') }
        @{ Label = 'Shutdown / Reboot / Log Off';  Script = 'Invoke-PowerOptions.ps1';       Note = '';                      Platforms = @('Windows10','Windows11','Linux') }
        @{ Label = 'Repair Winget';                Script = 'Invoke-WingetRepair.ps1';       Note = '';                      Platforms = @('Windows10','Windows11') }
        @{ Label = 'Update Packages';              Script = 'linux/Invoke-PackageUpdate.ps1'; Note = '';                     Platforms = @('Linux') }
        @{ Label = 'View System Logs';             Script = 'linux/Get-SystemLogs.ps1';      Note = '(journalctl)';          Platforms = @('Linux') }
    )

    $active = @($toolDefs | Where-Object { $_.Platforms -contains $Global:PcPlatform })
    $t      = Join-Path $Global:pcHealthRoot 'tools'

    while ($true) {
        Set-PcTheme 'Tools'
        Clear-Host
        Write-PcHeader 'Tools'

        for ($i = 1; $i -le $active.Count; $i++) {
            Write-PcOption "$i" $active[$i - 1].Label $active[$i - 1].Note
        }

        $nav1 = $active.Count + 1
        $nav2 = $active.Count + 2
        $nav3 = $active.Count + 3

        Write-PcDivider
        Write-PcOption "$nav1" 'Programs Menu'
        Write-PcOption "$nav2" 'Back to Main Menu'
        Write-PcOption "$nav3" 'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim()

        $num = 0
        if (-not [int]::TryParse($choice, [ref]$num)) {
            Write-Host "`n  Invalid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
            continue
        }

        if ($num -ge 1 -and $num -le $active.Count) {
            $entry = $active[$num - 1]
            Set-PcTheme 'Action'
            Clear-Host
            & (Join-Path $t $entry.Script)
            $nav = Read-PcNavChoice 'Back to Tools Menu'
            switch ($nav) {
                '2' { return 'main' }
                '3' { return 'exit' }
            }
        } elseif ($num -eq $nav1) { return 'programs'
        } elseif ($num -eq $nav2) { return 'main'
        } elseif ($num -eq $nav3) { return 'exit'
        } else {
            Write-Host "`n  Invalid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
        }
    }
}

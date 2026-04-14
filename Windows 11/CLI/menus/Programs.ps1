# ============================================================================
# pcHealth — Windows 11 — Programs Menu
# ============================================================================

function Show-ProgramsMenu {
    while ($true) {
        Set-PcTheme 'Programs'
        Clear-Host
        Write-PcHeader 'Programs'

        Write-PcOption '1' 'HWiNFO64'
        Write-PcOption '2' 'HWMonitor'
        Write-PcOption '3' 'Malwarebytes ADW Cleaner'
        Write-PcOption '4' 'CrystalDiskInfo'
        Write-PcOption '5' 'CrystalDiskMark'
        Write-PcOption '6' 'Prime95'                  '(opens download page)'
        Write-PcOption '7' 'Windows PowerToys'
        Write-PcDivider
        Write-PcOption '8'  'Tools Menu'
        Write-PcOption '9'  'Back to Main Menu'
        Write-PcOption '10' 'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim()

        switch ($choice) {
            '1' {
                Set-PcTheme 'Action'; Clear-Host
                winget install --id REALix.HWiNFO          --accept-source-agreements --accept-package-agreements
            }
            '2' {
                Set-PcTheme 'Action'; Clear-Host
                winget install --id CPUID.HWMonitor         --accept-source-agreements --accept-package-agreements
            }
            '3' {
                Set-PcTheme 'Action'; Clear-Host
                winget install --id Malwarebytes.AdwCleaner --accept-source-agreements --accept-package-agreements
            }
            '4' {
                Set-PcTheme 'Action'; Clear-Host
                winget install --id CrystalDewWorld.CrystalDiskInfo --accept-source-agreements --accept-package-agreements
            }
            '5' {
                Set-PcTheme 'Action'; Clear-Host
                winget install --id CrystalDewWorld.CrystalDiskMark --accept-source-agreements --accept-package-agreements
            }
            '6' { Start-Process 'https://prime95.net/download/' }
            '7' {
                Set-PcTheme 'Action'; Clear-Host
                winget install --id Microsoft.PowerToys     --accept-source-agreements --accept-package-agreements
            }
            '8'  { return 'tools' }   # Cross-navigate to Tools menu
            '9'  { return 'main' }
            '10' { return 'exit' }
            default {
                Write-Host "`n  Invalid choice." -ForegroundColor Red
                Start-Sleep -Milliseconds 800
                continue
            }
        }

        # Show the navigation footer after an install or download completed.
        # 8, 9, and 10 already returned; 'default' used continue.
        if ($choice -in '1','2','3','4','5','6','7') {
            $nav = Read-PcNavChoice 'Back to Programs Menu'
            switch ($nav) {
                '2' { return 'main' }
                '3' { return 'exit' }
                # '1' → fall through to the top of the while loop (stay in Programs)
            }
        }
    }
}

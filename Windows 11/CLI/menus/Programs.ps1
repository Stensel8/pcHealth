# ============================================================================
# pcHealth — Windows 11 — Programs Menu
# ============================================================================

function Show-ProgramsMenu {
    while ($true) {
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
        Write-PcOption 'B' 'Back to Main Menu'
        Write-PcOption 'X' 'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim().ToUpper()

        switch ($choice) {
            '1' { winget install --id REALix.HWiNFO          --accept-source-agreements --accept-package-agreements }
            '2' { winget install --id CPUID.HWMonitor         --accept-source-agreements --accept-package-agreements }
            '3' { winget install --id Malwarebytes.AdwCleaner --accept-source-agreements --accept-package-agreements }
            '4' { winget install --id CrystalDewWorld.CrystalDiskInfo --accept-source-agreements --accept-package-agreements }
            '5' { winget install --id CrystalDewWorld.CrystalDiskMark --accept-source-agreements --accept-package-agreements }
            '6' { Start-Process 'https://prime95.net/download/' }
            '7' { winget install --id Microsoft.PowerToys     --accept-source-agreements --accept-package-agreements }
            'B' { return 'back' }
            'X' { return 'exit' }
            default {
                Write-Host "`n  Invalid choice." -ForegroundColor Red
                Start-Sleep -Milliseconds 800
                # 'continue' skips the rest of the loop body (the nav block below)
                # and jumps straight back to the top of the while loop.
                continue
            }
        }

        # Only show the navigation footer after an install or download completed.
        # 'B' and 'X' already returned from the function above; 'default' used
        # continue — so reaching this line means choices 1–7 ran successfully.
        if ($choice -in '1','2','3','4','5','6','7') {
            $nav = Read-PcNavChoice 'Back to Programs Menu'
            if ($nav -eq 'M') { return 'main' }
            if ($nav -eq 'X') { return 'exit' }
        }
    }
}

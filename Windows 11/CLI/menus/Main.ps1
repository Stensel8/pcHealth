# ============================================================================
# pcHealth — Windows 11 — Main Menu
# ============================================================================

function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-PcHeader 'Main Menu'

        Write-PcOption '1' 'Tools'
        Write-PcOption '2' 'Programs'
        Write-PcDivider
        Write-PcOption '3' 'Go to repository'
        Write-PcOption '4' 'Check for pre-releases'
        Write-PcDivider
        Write-PcOption 'X' 'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim().ToUpper()

        switch ($choice) {
            '1' {
                # Show-ToolsMenu loops internally and only returns when the user
                # navigates away. It returns 'exit' if X was pressed anywhere inside,
                # or 'back'/'main' to come back here — both of which just re-loop Main.
                $nav = Show-ToolsMenu
                if ($nav -eq 'exit') { exit 0 }
            }
            '2' {
                $nav = Show-ProgramsMenu
                if ($nav -eq 'exit') { exit 0 }
            }
            '3' { Start-Process 'https://github.com/REALSDEALS/pcHealth' }
            '4' { Start-Process 'https://github.com/REALSDEALS/pcHealth/releases' }
            'X' { exit 0 }
            default {
                Write-Host "`n  Invalid choice." -ForegroundColor Red
                Start-Sleep -Milliseconds 800
            }
        }
    }
}

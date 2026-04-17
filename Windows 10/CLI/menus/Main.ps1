# ============================================================================
# pcHealth — Windows 10 — Main Menu
# ============================================================================

function Show-MainMenu {
    # $target drives the routing loop. Show-ToolsMenu / Show-ProgramsMenu return
    # 'main', 'tools', 'programs', or 'exit' so we can cross-navigate without
    # deep call stacks — mirroring the BAT file's GOTO behaviour.
    $target = 'main'

    while ($true) {
        if ($target -eq 'tools') {
            $target = Show-ToolsMenu

        } elseif ($target -eq 'programs') {
            $target = Show-ProgramsMenu

        } elseif ($target -eq 'exit') {
            exit 0

        } else {
            # Default: show main menu
            Set-PcTheme 'Main'
            Clear-Host
            Write-PcHeader 'Main Menu'

            Write-Host "  Thanks for downloading and using pcHealth!"
            Write-Host "  Made by REALSDEALS - Licensed under GNU-3" -ForegroundColor DarkGray
            Write-Host "  You are now using pcHealth - Windows 10 - V$Global:PcVersion`n" -ForegroundColor DarkGray
            Write-PcDivider

            Write-PcOption '1' 'Tools'
            Write-PcOption '2' 'Programs'
            Write-PcDivider
            Write-PcOption '3' 'Go to repository'
            Write-PcOption '4' 'Check for pre-releases'
            Write-PcDivider
            Write-PcOption '5' 'Exit'
            Write-PcDivider

            $choice = (Read-Host "`n  Choice").Trim()

            switch ($choice) {
                '1' { $target = 'tools' }
                '2' { $target = 'programs' }
                '3' { Start-Process 'https://github.com/REALSDEALS/pcHealth' }
                '4' { Start-Process 'https://github.com/REALSDEALS/pcHealth/releases' }
                '5' { $target = 'exit' }
                default {
                    Write-Host "`n  Invalid choice." -ForegroundColor Red
                    Start-Sleep -Milliseconds 800
                }
            }
        }
    }
}

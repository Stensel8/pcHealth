#Requires -Version 7.0
# ============================================================================
# pcHealth — Windows 11 — BIOS Password Recovery
# Credits: @bacher09 — https://github.com/bacher09/pwgen-for-bios
# ============================================================================

# Yellow theme — mirrors the BAT file's `color 0E` for this section.
Set-PcTheme 'Warning'
Clear-Host

Write-Host "`n$('=' * 60)" -ForegroundColor Yellow
Write-Host "  BIOS Password Recovery" -ForegroundColor Yellow
Write-Host "$('=' * 60)`n" -ForegroundColor Yellow
Write-Host "  This tool links to bios-pw.org — a website that generates"
Write-Host "  recovery codes for locked BIOS passwords."
Write-Host "  Credits for this tool go to: @bacher09`n" -ForegroundColor DarkGray

while ($true) {
    Write-Host "  [1]  Visit bios-pw.org  (recovery tool)"
    Write-Host "  [2]  Visit repository  (learn more about how it works)"
    Write-Host "  [B]  Back`n"

    $choice = (Read-Host "  Choice").Trim().ToUpper()

    switch ($choice) {
        '1' { Start-Process 'https://bios-pw.org' }
        '2' { Start-Process 'https://github.com/bacher09/pwgen-for-bios' }
        'B' { return }
        default {
            Write-Host "`n  Invalid choice.`n" -ForegroundColor Red
        }
    }
}

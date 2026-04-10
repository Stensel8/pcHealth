# ============================================================================
# pcHealth — Windows 11 — UI Helpers
# Shared display and navigation utilities used by all menu scripts.
# ============================================================================

function Write-PcHeader {
    param([string]$Title)
    $line = '=' * 60
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "  pcHealth  *  Windows 11  *  $Title" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    # Get-LocalUser returns the display name (e.g. "Sten Tijhuis"). Falls back to the
    # environment username if the account has no full name set, or the query fails.
    $fullName = (Get-LocalUser -Name $env:USERNAME -ErrorAction SilentlyContinue).FullName
    if (-not $fullName) { $fullName = $env:USERNAME }
    $now = Get-Date -Format 'dddd, dd MMMM yyyy  HH:mm'
    Write-Host "  $fullName  *  $now`n" -ForegroundColor DarkGray
}

function Write-PcDivider {
    Write-Host ('-' * 60) -ForegroundColor DarkGray
}

function Write-PcOption {
    param([string]$Key, [string]$Label, [string]$Note = '')
    # Padding aligns all labels to the same column regardless of key length.
    # A 1-char key like [B] gets 3 spaces; a 2-char key like [10] gets 2 spaces.
    # Max(1,...) ensures at least 1 space so the label never glues onto the bracket.
    $pad = ' ' * [Math]::Max(1, 4 - $Key.Length)
    Write-Host '  ' -NoNewline
    Write-Host "[$Key]" -ForegroundColor Yellow -NoNewline
    Write-Host "$pad$Label" -NoNewline
    if ($Note) { Write-Host "  $Note" -ForegroundColor DarkGray -NoNewline }
    Write-Host ''
}

# Shown after every tool finishes. Returns the raw uppercased choice: 'B', 'M', or 'X'.
# The calling menu interprets these:
#   'B' → stay in current submenu (loop)
#   'M' → return to main menu
#   'X' → exit the application
function Read-PcNavChoice {
    param([string]$BackLabel = 'Back to previous menu')
    Write-Host ''
    Write-PcDivider
    Write-PcOption 'B' $BackLabel
    Write-PcOption 'M' 'Main Menu'
    Write-PcOption 'X' 'Exit'
    Write-PcDivider
    return (Read-Host "`n  Choice").Trim().ToUpper()
}

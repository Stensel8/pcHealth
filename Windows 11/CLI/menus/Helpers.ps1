# ============================================================================
# pcHealth — Windows 11 — UI Helpers
# Shared display and navigation utilities used by all menu scripts.
# ============================================================================

# Global theme — set by each menu before it renders.
# Valid values: 'Main', 'Tools', 'Programs', 'Action', 'Danger', 'Warning'
$Global:PcTheme = 'Main'

# Sets the console background and foreground to match the active section,
# mirroring the BAT file's `color` command behaviour.
function Set-PcTheme {
    param([string]$Theme)
    $Global:PcTheme = $Theme
    switch ($Theme) {
        'Main'     { $Host.UI.RawUI.BackgroundColor = 'Black';  $Host.UI.RawUI.ForegroundColor = 'Cyan'      }
        'Tools'    { $Host.UI.RawUI.BackgroundColor = 'Black';  $Host.UI.RawUI.ForegroundColor = 'Red'       }
        'Programs' { $Host.UI.RawUI.BackgroundColor = 'Black';  $Host.UI.RawUI.ForegroundColor = 'Green'     }
        'Action'   { $Host.UI.RawUI.BackgroundColor = 'Black';  $Host.UI.RawUI.ForegroundColor = 'Green'     }
        'Danger'   { $Host.UI.RawUI.BackgroundColor = 'Black';  $Host.UI.RawUI.ForegroundColor = 'Red'       }
        'Warning'  { $Host.UI.RawUI.BackgroundColor = 'Black';  $Host.UI.RawUI.ForegroundColor = 'Yellow'    }
    }
}

function Write-PcHeader {
    param([string]$Title)
    $line = '=' * 60
    # Header accent colour matches the active theme so each section feels distinct.
    $headerColor = switch ($Global:PcTheme) {
        'Main'     { 'Cyan'   }
        'Tools'    { 'Red'    }
        'Programs' { 'Green'  }
        default    { 'Cyan'   }
    }
    Write-Host "`n$line" -ForegroundColor $headerColor
    Write-Host "  pcHealth  *  Windows 11  *  $Title" -ForegroundColor $headerColor
    Write-Host $line -ForegroundColor $headerColor
    # Get-LocalUser returns the display name (e.g. "Sten Tijhuis"). Falls back to the
    # environment username if the account has no full name set, or the query fails.
    $fullName = (Get-LocalUser -Name $env:USERNAME -ErrorAction SilentlyContinue).FullName
    if (-not $fullName) { $fullName = $env:USERNAME }
    $now = Get-Date -Format 'dddd, dd MMMM yyyy  HH:mm'
    Write-Host "  Hello, $fullName!  *  $now`n" -ForegroundColor DarkGray
}

function Write-PcDivider {
    Write-Host ('-' * 60) -ForegroundColor DarkGray
}

function Write-PcOption {
    param([string]$Key, [string]$Label, [string]$Note = '')
    # Padding aligns all labels to the same column regardless of key length.
    $pad = ' ' * [Math]::Max(1, 4 - $Key.Length)
    # Key bracket colour matches the active theme for visual consistency.
    $keyColor = switch ($Global:PcTheme) {
        'Main'     { 'Cyan'   }
        'Tools'    { 'Red'    }
        'Programs' { 'Green'  }
        default    { 'Yellow' }  # Action / Danger / Warning — yellow on black
    }
    Write-Host '  ' -NoNewline
    Write-Host "[$Key]" -ForegroundColor $keyColor -NoNewline
    Write-Host "$pad$Label" -NoNewline
    if ($Note) { Write-Host "  $Note" -ForegroundColor DarkGray -NoNewline }
    Write-Host ''
}

# Shown after every tool finishes. Returns '1', '2', or '3'.
# The calling menu interprets these:
#   '1' → stay in current submenu (loop)
#   '2' → return to main menu
#   '3' → exit the application
function Read-PcNavChoice {
    param([string]$BackLabel = 'Back to previous menu')
    Write-Host ''
    Write-PcDivider
    Write-PcOption '1' $BackLabel
    Write-PcOption '2' 'Main Menu'
    Write-PcOption '3' 'Exit'
    Write-PcDivider
    return (Read-Host "`n  Choice").Trim()
}

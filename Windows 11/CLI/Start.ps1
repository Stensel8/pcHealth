#Requires -Version 7.0
#Requires -RunAsAdministrator

# ============================================================================
# pcHealth — Windows 11 — V2.1.0
# Entry point. Requires PowerShell 7+ and Administrator privileges.
# ============================================================================

$ErrorActionPreference = 'Stop'

# $Global:pcHealthRoot is used by Tools.ps1 to build paths to the tools/ folder.
# It must be set before dot-sourcing the menus so they can reference it at call time.
$Global:pcHealthRoot = $PSScriptRoot

# Dot-sourcing (. operator) loads each file into the current session so all
# functions defined inside them become available here, just like defining them inline.
# Order matters: Helpers must load first because Main/Tools/Programs call its functions.
. "$PSScriptRoot\menus\Helpers.ps1"
. "$PSScriptRoot\menus\Main.ps1"
. "$PSScriptRoot\menus\Tools.ps1"
. "$PSScriptRoot\menus\Programs.ps1"

Show-MainMenu

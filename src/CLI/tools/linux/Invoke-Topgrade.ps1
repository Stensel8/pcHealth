#Requires -Version 7.0
# ============================================================================
# pcHealth -- Topgrade (Linux)
# Runs topgrade to update all managed software in one pass.
# topgrade is interactive (pacnew prompts, etc.) so it opens in a new terminal.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Topgrade -- Full System Upgrade' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

if (-not (Get-Command topgrade -ErrorAction SilentlyContinue)) {
    Write-Host '[!!] topgrade is not installed.' -ForegroundColor Red
    Write-Host ''
    Write-Host '  Install it with your package manager:' -ForegroundColor DarkGray
    Write-Host '    Arch / CachyOS / Manjaro:  sudo pacman -S topgrade' -ForegroundColor DarkGray
    Write-Host '    Debian / Ubuntu:           cargo install topgrade'  -ForegroundColor DarkGray
    Write-Host '    Fedora:                    cargo install topgrade'  -ForegroundColor DarkGray
    Write-Host '    All (cargo):               cargo install topgrade'  -ForegroundColor DarkGray
    Write-Host ''
    return
}

Write-Host '  topgrade will upgrade:' -ForegroundColor DarkGray
Write-Host '    packages, flatpak, VS Code extensions, uv tools,' -ForegroundColor DarkGray
Write-Host '    gcloud, helm, firmware, and more.' -ForegroundColor DarkGray
Write-Host ''

$user   = $env:SUDO_USER ?? $env:USER
$userId = (& id -u $user 2>$null).Trim()

# Reconstruct the session environment so GNOME Shell extensions and
# session-aware tools (gcloud, gdbus) work when topgrade is spawned from
# a sudo context that doesn't inherit the user's graphical session.
$dbusAddr      = $env:DBUS_SESSION_BUS_ADDRESS ?? "unix:path=/run/user/$userId/bus"
$waylandDisplay = $env:WAYLAND_DISPLAY ?? 'wayland-0'
$xDisplay      = $env:DISPLAY ?? ':0'

$envSetup = "export DBUS_SESSION_BUS_ADDRESS='$dbusAddr'; export WAYLAND_DISPLAY='$waylandDisplay'; export DISPLAY='$xDisplay';"
$cmd      = "$envSetup topgrade; echo; read -p 'Press Enter to close...'"

$terminals = @(
    @{ cmd = 'gnome-terminal'; args = @('--wait', '--', 'sudo', '-u', $user, 'bash', '-c', $cmd) }
    @{ cmd = 'konsole';        args = @('--hold', '-e', 'sudo', '-u', $user, 'bash', '-c', $cmd) }
    @{ cmd = 'alacritty';      args = @('-e', 'sudo', '-u', $user, 'bash', '-c', $cmd) }
    @{ cmd = 'kitty';          args = @('sudo', '-u', $user, 'bash', '-c', $cmd) }
    @{ cmd = 'xfce4-terminal'; args = @('--hold', '-e', 'sudo', '-u', $user, 'bash', '-c', $cmd) }
    @{ cmd = 'xterm';          args = @('-hold', '-e', 'sudo', '-u', $user, 'bash', '-c', $cmd) }
)

foreach ($term in $terminals) {
    if (Get-Command $term.cmd -ErrorAction SilentlyContinue) {
        Write-Host "[>>] Opening topgrade in $($term.cmd)..." -ForegroundColor Yellow
        & $term.cmd @($term.args)
        return
    }
}

Write-Host '[!!] No supported terminal emulator found.' -ForegroundColor Red
Write-Host '  Install one of: gnome-terminal, konsole, alacritty, kitty, xterm' -ForegroundColor DarkGray
Write-Host ''

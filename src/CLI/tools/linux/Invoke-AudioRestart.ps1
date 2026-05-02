#Requires -Version 7.0
# ============================================================================
# pcHealth -- Restart Audio (Linux)
# Detects PipeWire or PulseAudio and restarts the relevant user services.
# systemctl --user requires DBUS_SESSION_BUS_ADDRESS forwarded to work
# when pcHealth is invoked via sudo.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Restart Audio' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

$user   = $env:SUDO_USER ?? $env:USER
$userId = (& id -u $user 2>$null).Trim()
$dbus   = $env:DBUS_SESSION_BUS_ADDRESS ?? "unix:path=/run/user/$userId/bus"

function Invoke-UserService {
    param([string]$Label, [string]$Cmd)
    Write-Host "[>>] $Label" -ForegroundColor Yellow
    $out = & sudo -u $user bash -c "export DBUS_SESSION_BUS_ADDRESS='$dbus'; $Cmd" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Done.`n" -ForegroundColor Green
    } else {
        Write-Host "[!!] Exit code $LASTEXITCODE.`n" -ForegroundColor Red
        if ($out) { Write-Host "  $out" -ForegroundColor DarkGray }
    }
}

$isPipeWire = (& sudo -u $user bash -c "export DBUS_SESSION_BUS_ADDRESS='$dbus'; systemctl --user is-active pipewire 2>/dev/null").Trim() -eq 'active'
$hasPulse   = [bool](Get-Command pulseaudio -ErrorAction SilentlyContinue)

if ($isPipeWire) {
    Write-Host "  Detected: PipeWire`n" -ForegroundColor DarkGray
    Invoke-UserService 'Restarting pipewire...'        'systemctl --user restart pipewire'
    Invoke-UserService 'Restarting pipewire-pulse...'  'systemctl --user restart pipewire-pulse'
    Invoke-UserService 'Restarting wireplumber...'     'systemctl --user restart wireplumber'
} elseif ($hasPulse) {
    Write-Host "  Detected: PulseAudio`n" -ForegroundColor DarkGray
    Invoke-UserService 'Restarting PulseAudio...' 'pulseaudio --kill; sleep 0.5; pulseaudio --start'
} else {
    Write-Host "[!!] No supported audio server found (PipeWire or PulseAudio).`n" -ForegroundColor Red
    return
}

Write-Host "  Audio services restarted.`n" -ForegroundColor Green

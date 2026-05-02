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
$userId = (& id -u "$user" 2>$null).Trim()
$dbus   = $env:DBUS_SESSION_BUS_ADDRESS ?? "unix:path=/run/user/$userId/bus"

# Valid DBUS transport prefixes per the D-Bus specification.
$ValidDbusPattern = '^(unix|tcp|nonce-tcp|autolaunch):'

# Validate the DBUS address has the expected format before embedding it in an
# env key=value argument. A well-formed address starts with a known transport prefix.
if ($dbus -notmatch $ValidDbusPattern) {
    Write-Host "[!!] Unexpected DBUS_SESSION_BUS_ADDRESS format: $dbus" -ForegroundColor Red
    Write-Host "     Aborting to avoid passing an untrusted value to env." -ForegroundColor Red
    return
}

# Invoke a systemctl --user command as the target user, forwarding DBUS via the
# environment rather than injecting it into a shell command string.
# systemctl and its arguments are passed as individual tokens — no shell involved.
function Invoke-UserServiceUnit {
    param([string]$Label, [string]$Action, [string]$Unit)
    Write-Host "[>>] $Label" -ForegroundColor Yellow
    $out = & sudo -u "$user" env "DBUS_SESSION_BUS_ADDRESS=$dbus" `
        systemctl --user $Action $Unit 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Done.`n" -ForegroundColor Green
    } else {
        Write-Host "[!!] Exit code $LASTEXITCODE.`n" -ForegroundColor Red
        if ($out) { Write-Host "  $out" -ForegroundColor DarkGray }
    }
}

$isPipeWire = (& sudo -u "$user" env "DBUS_SESSION_BUS_ADDRESS=$dbus" `
    systemctl --user is-active pipewire 2>/dev/null).Trim() -eq 'active'
$hasPulse   = [bool](Get-Command pulseaudio -ErrorAction SilentlyContinue)

if ($isPipeWire) {
    Write-Host "  Detected: PipeWire`n" -ForegroundColor DarkGray
    Invoke-UserServiceUnit 'Restarting pipewire...'        restart pipewire
    Invoke-UserServiceUnit 'Restarting pipewire-pulse...'  restart pipewire-pulse
    Invoke-UserServiceUnit 'Restarting wireplumber...'     restart wireplumber
} elseif ($hasPulse) {
    Write-Host "  Detected: PulseAudio`n" -ForegroundColor DarkGray
    # Kill then start as two separate invocations to avoid a shell compound command.
    Write-Host "[>>] Restarting PulseAudio..." -ForegroundColor Yellow
    & sudo -u "$user" env "DBUS_SESSION_BUS_ADDRESS=$dbus" pulseaudio --kill 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    $out = & sudo -u "$user" env "DBUS_SESSION_BUS_ADDRESS=$dbus" pulseaudio --start 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Done.`n" -ForegroundColor Green
    } else {
        Write-Host "[!!] Exit code $LASTEXITCODE.`n" -ForegroundColor Red
        if ($out) { Write-Host "  $out" -ForegroundColor DarkGray }
    }
} else {
    Write-Host "[!!] No supported audio server found (PipeWire or PulseAudio).`n" -ForegroundColor Red
    return
}

Write-Host "  Audio services restarted.`n" -ForegroundColor Green

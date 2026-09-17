"""Restart the audio server.

PipeWire and PulseAudio live in the user's session, not root's, so every call
is dropped to the desktop user with their session bus forwarded.
"""

from __future__ import annotations

import time

from .. import system
from .base import ToolContext

PIPEWIRE_UNITS = ("pipewire", "pipewire-pulse", "wireplumber")


def audio_restart(ctx: ToolContext) -> None:
    ctx.heading("Restart Audio")

    user = system.desktop_user()
    if not user:
        ctx.line("Could not determine the desktop user.", "error")
        return

    # Exact match: `is-active` answers "inactive" too, which a substring test
    # would happily accept.
    state = system.run_as_user(user, ["systemctl", "--user", "is-active", "pipewire"])
    is_pipewire = state.stdout.strip() == "active"

    if is_pipewire:
        ctx.line("Detected: PipeWire", "muted")
        ctx.line()
        for unit in PIPEWIRE_UNITS:
            ctx.line(f"[>>] Restarting {unit}...", "info")
            result = system.run_as_user(user, ["systemctl", "--user", "restart", unit])
            if result.ok:
                ctx.line("[OK] Done.", "ok")
            else:
                ctx.line(f"[!!] Exit code {result.returncode}.", "error")
                if result.stderr.strip():
                    ctx.line(f"  {result.stderr.strip()}", "muted")
    elif system.has("pulseaudio"):
        ctx.line("Detected: PulseAudio", "muted")
        ctx.line()
        ctx.line("[>>] Restarting PulseAudio...", "info")
        # Kill then start as two invocations to avoid a shell compound command.
        system.run_as_user(user, ["pulseaudio", "--kill"])
        time.sleep(0.5)
        result = system.run_as_user(user, ["pulseaudio", "--start"])
        if result.ok:
            ctx.line("[OK] Done.", "ok")
        else:
            ctx.line(f"[!!] Exit code {result.returncode}.", "error")
    else:
        ctx.line("No supported audio server found (PipeWire or PulseAudio).", "error")
        return

    ctx.line()
    ctx.line("Audio services restarted.", "ok")

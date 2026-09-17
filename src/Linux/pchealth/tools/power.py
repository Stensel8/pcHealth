"""Shutdown, reboot and log off."""

from __future__ import annotations

from .. import system
from .base import ToolContext


def power_options(ctx: ToolContext) -> None:
    ctx.heading("Power Options")
    ctx.line("  [1]  Log Off")
    ctx.line("  [2]  Restart")
    ctx.line("  [3]  Shutdown")
    ctx.line("  [B]  Cancel")
    ctx.line()

    choice = ctx.ask("Choice").strip().upper()

    if choice == "1":
        # Under sudo the environment describes root; log off the human instead.
        user = system.desktop_user()
        if not user:
            ctx.line("Could not determine the desktop user.", "error")
            return
        if not ctx.confirm(f"Log off {user.name}?"):
            ctx.line("Cancelled.", "muted")
            return
        # loginctl ends the session cleanly, unlike killing the processes.
        rc = system.run_root(["loginctl", "terminate-user", user.name]).returncode
        ctx.command_output(rc, ok="[OK] Session ended.")
    elif choice == "2":
        if not ctx.confirm("Restart the system?"):
            ctx.line("Cancelled.", "muted")
            return
        system.run_root(["shutdown", "-r", "now"])
    elif choice == "3":
        if not ctx.confirm("Shut down the system?"):
            ctx.line("Cancelled.", "muted")
            return
        system.run_root(["shutdown", "-h", "now"])
    elif choice == "B":
        ctx.line("Cancelled.", "muted")
    else:
        ctx.line("Invalid choice.", "error")

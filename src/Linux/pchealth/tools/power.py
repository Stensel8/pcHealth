"""Shutdown, reboot and log off."""

from __future__ import annotations

from .. import system
from .base import Choice, ToolContext


def power_options(ctx: ToolContext) -> None:
    ctx.heading("Power Options")

    choice = ctx.choose(
        "What should happen?",
        [
            Choice("logoff", "Log Off", "Ends the desktop session.", destructive=True),
            Choice("restart", "Restart", "Restarts the system immediately.", destructive=True),
            Choice("shutdown", "Shut Down", "Powers the system off immediately.", destructive=True),
        ],
    )

    if choice is None:
        ctx.cancelled()
    elif choice == "logoff":
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
    elif choice == "restart":
        if not ctx.confirm("Restart the system?"):
            ctx.line("Cancelled.", "muted")
            return
        system.run_root(["shutdown", "-r", "now"])
    elif choice == "shutdown":
        if not ctx.confirm("Shut down the system?"):
            ctx.line("Cancelled.", "muted")
            return
        system.run_root(["shutdown", "-h", "now"])

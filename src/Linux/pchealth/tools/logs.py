"""Recent error and warning entries from the systemd journal."""

from __future__ import annotations

from .. import system
from .base import ToolContext

_VIEWS: dict[str, tuple[str, list[str]]] = {
    "1": ("Errors from today", ["journalctl", "--priority=err", "--since=today", "--no-pager"]),
    "2": (
        "Last 100 error/warning entries",
        ["journalctl", "--priority=warning", "-n", "100", "--no-pager"],
    ),
    "3": ("Boot messages (current boot)", ["journalctl", "-b", "--no-pager", "-n", "100"]),
    "4": ("Kernel messages", ["dmesg", "--level=err,warn"]),
}


def system_logs(ctx: ToolContext) -> None:
    ctx.heading("System Logs  (journalctl)")

    if not system.has("journalctl"):
        ctx.line("journalctl not found. This system may not use systemd.", "error")
        return

    for key, (label, _) in _VIEWS.items():
        ctx.line(f"  [{key}]  {label}")
    ctx.line("  [5]  Failed services")
    ctx.line("  [B]  Back")
    ctx.line()

    choice = ctx.ask("Choice").strip().upper()

    if choice == "B":
        return

    if choice == "5":
        ctx.line("[>>] Failed systemd units...", "info")
        ctx.line()
        failed = system.output(["systemctl", "--failed", "--no-legend", "--no-pager"])
        if failed:
            for line in failed.splitlines():
                ctx.line(f"  {line}", "muted")
            ctx.line()
            ctx.line("Inspect one with: journalctl -u <unit> -b", "muted")
        else:
            ctx.line("No failed units.", "ok")
        return

    view = _VIEWS.get(choice)
    if not view:
        ctx.line("Invalid choice.", "error")
        return

    label, argv = view
    ctx.line(f"[>>] {label}...", "info")
    ctx.line()
    # The journal is root-readable only for system messages; a plain user sees
    # their own entries and nothing else, which silently looks like a clean log.
    system.stream_root(
        argv, lambda line: ctx.line(f"  {line}", "muted"), should_stop=ctx.should_stop
    )

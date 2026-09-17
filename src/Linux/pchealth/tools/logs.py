"""Recent error and warning entries from the systemd journal."""

from __future__ import annotations

from .. import system
from .base import Choice, ToolContext

_VIEWS: dict[str, tuple[Choice, list[str]]] = {
    "today": (
        Choice("today", "Errors from today", "Priority err and above, since midnight"),
        ["journalctl", "--priority=err", "--since=today", "--no-pager"],
    ),
    "recent": (
        Choice("recent", "Last 100 warnings and errors", "Priority warning and above"),
        ["journalctl", "--priority=warning", "-n", "100", "--no-pager"],
    ),
    "boot": (
        Choice("boot", "Boot messages", "This boot, last 100 lines"),
        ["journalctl", "-b", "--no-pager", "-n", "100"],
    ),
    "kernel": (
        Choice("kernel", "Kernel messages", "dmesg, errors and warnings"),
        ["dmesg", "--level=err,warn"],
    ),
    "failed": (
        Choice("failed", "Failed services", "systemd units that did not start"),
        ["systemctl", "--failed", "--no-legend", "--no-pager"],
    ),
}


def system_logs(ctx: ToolContext) -> None:
    ctx.heading("System Logs  (journalctl)")

    if not system.has("journalctl"):
        ctx.line("journalctl not found. This system may not use systemd.", "error")
        return

    choice = ctx.choose("Which log?", [view[0] for view in _VIEWS.values()])
    if choice is None:
        ctx.cancelled()
        return

    label, argv = _VIEWS[choice][0].label, _VIEWS[choice][1]
    ctx.line(f"[>>] {label}...", "info")
    ctx.line()

    if choice == "failed":
        failed = system.output(argv)
        if failed:
            for line in failed.splitlines():
                ctx.line(f"  {line}", "muted")
            ctx.line()
            ctx.line("Inspect one with: journalctl -u <unit> -b", "muted")
        else:
            ctx.line("No failed units.", "ok")
        return

    # The journal is root-readable only for system messages; a plain user sees
    # their own entries and nothing else, which silently looks like a clean log.
    system.stream_root(
        argv, lambda line: ctx.line(f"  {line}", "muted"), should_stop=ctx.should_stop
    )

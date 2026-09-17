"""Ping, traceroute and the network stack reset."""

from __future__ import annotations

import contextlib

from .. import system
from .base import ToolContext

PING_TARGET = "8.8.8.8"
TRACE_TARGET = "google.com"


def ping_short(ctx: ToolContext) -> None:
    ctx.heading(f"Short Ping Test  ({PING_TARGET}, 4 packets)")
    # -w caps the total run: without it an unreachable host with a slow DNS
    # path can sit there far longer than four packets suggest.
    rc = system.stream(
        ["ping", "-c", "4", "-W", "2", "-w", "15", PING_TARGET],
        lambda line: ctx.line(f"  {line}", "muted"),
    )
    ctx.line()
    if rc == 0:
        ctx.line("Host is reachable.", "ok")
    else:
        ctx.line("No usable reply. Check your network connection.", "error")


def ping_continuous(ctx: ToolContext) -> None:
    ctx.heading(f"Continuous Ping Test  ({PING_TARGET})")
    ctx.line("Press Ctrl+C to stop.", "muted")
    ctx.line()
    # Ctrl+C is how this tool is meant to end, not a failure.
    with contextlib.suppress(KeyboardInterrupt):
        system.stream(
            ["ping", PING_TARGET],
            lambda line: ctx.line(f"  {line}", "muted"),
            should_stop=ctx.should_stop,
        )
    ctx.line()
    ctx.line("Ping test stopped.", "muted")


def traceroute(ctx: ToolContext) -> None:
    ctx.heading(f"Traceroute to {TRACE_TARGET}  (max 30 hops)")
    command = next((c for c in ("traceroute", "tracepath") if system.has(c)), None)
    if not command:
        ctx.line("Neither traceroute nor tracepath is installed.", "warn")
        ctx.line("Install via: apt install traceroute  (or dnf / pacman / zypper)", "muted")
        return
    system.stream(
        [command, TRACE_TARGET],
        lambda line: ctx.line(f"  {line}", "muted"),
        should_stop=ctx.should_stop,
    )


def network_reset(ctx: ToolContext) -> None:
    ctx.heading("Reset Network Stack")
    if not system.has("systemctl"):
        ctx.line("systemctl not found. This system may not use systemd.", "error")
        return

    ctx.line("Note: the network connection will drop briefly.", "warn")
    ctx.line()
    if not ctx.confirm("Restart networking now?"):
        ctx.line("Cancelled.", "muted")
        return

    manager_active = system.output(["systemctl", "is-active", "NetworkManager"]) == "active"
    unit = "NetworkManager" if manager_active or system.has("nmcli") else "systemd-networkd"

    ctx.line(f"[>>] Restarting {unit}...", "info")
    rc = system.stream_root(
        ["systemctl", "restart", unit], lambda line: ctx.line(f"  {line}", "muted")
    )
    ctx.command_output(rc, ok="[OK] Done.")

    if system.has("resolvectl"):
        flush = ["resolvectl", "flush-caches"]
    elif system.has("systemd-resolve"):
        flush = ["systemd-resolve", "--flush-caches"]
    else:
        flush = []

    if flush:
        ctx.line("[>>] Flushing DNS cache...", "info")
        rc = system.stream_root(flush, lambda line: ctx.line(f"  {line}", "muted"))
        ctx.command_output(rc, ok="[OK] Done.")

    ctx.line()
    ctx.line("Network reset complete.", "ok")

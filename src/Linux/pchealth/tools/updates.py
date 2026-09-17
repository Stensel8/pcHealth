"""Package updates: the distro's own manager, and topgrade."""

from __future__ import annotations

import os
from pathlib import Path

from .. import system
from .base import ProgressFilter, ToolContext

PREVIEW_LINES = 15

# topgrade is interactive (pacnew prompts and the like), so it gets a real
# terminal rather than a captured pipe.
TERMINALS: dict[str, list[str]] = {
    "gnome-terminal": ["--wait", "--"],
    "konsole": ["--hold", "-e"],
    "alacritty": ["-e"],
    "ptyxis": ["--"],
    "kitty": [],
    "xfce4-terminal": ["--hold", "-e"],
    "xterm": ["-hold", "-e"],
}


def _reboot_required() -> bool:
    if system.has("needs-restarting"):
        # Exits non-zero when a reboot is needed.
        return not system.run(["needs-restarting", "-r"]).ok
    return Path("/var/run/reboot-required").exists()


def system_update(ctx: ToolContext) -> None:
    ctx.heading("Update all packages")

    manager = system.package_manager()
    if not manager:
        ctx.line("No supported package manager found (apt/dnf/pacman/zypper).", "error")
        return

    ctx.line(f"Package manager: {manager.cmd}", "muted")
    ctx.line()

    if manager.refresh:
        ctx.line("[>>] Refreshing package index...", "info")
        refresh = system.run_root([manager.cmd, *manager.refresh])
        if not refresh.ok:
            ctx.line(
                f"[!!] Refresh failed (exit code {refresh.returncode}). Check your network.",
                "error",
            )
            return

    ctx.line("[>>] Checking for available updates...", "info")
    ctx.line()
    # dnf check-update exits 100 when updates exist and 0 when there are none;
    # pacman -Qu exits 1 on an empty list. Judge by output, not exit code.
    listing = system.run_root([manager.cmd, *manager.list_updates])
    lines = [
        line.strip()
        for line in listing.stdout.splitlines()
        if line.strip() and not line.startswith(("Listing", "Last metadata"))
    ]

    if not lines:
        ctx.line("Everything is already up to date.", "ok")
        return

    for line in lines[:PREVIEW_LINES]:
        ctx.line(f"  {line}", "muted")
    if len(lines) > PREVIEW_LINES:
        ctx.line(f"  ... and {len(lines) - PREVIEW_LINES} more", "muted")
    ctx.line()
    ctx.line(f"{len(lines)} update(s) available.", "info")
    ctx.line()

    if not ctx.confirm("Proceed with updating all packages?"):
        ctx.line("Update cancelled.", "muted")
        return

    ctx.line()
    ctx.line("[>>] Updating all packages...", "info")
    progress = ProgressFilter(lambda line: ctx.line(f"  {line}", "muted"))
    rc = system.stream_root([manager.cmd, *manager.update], progress)
    progress.flush()
    ctx.line()
    if rc != 0:
        ctx.line(f"[!!] Update exited with code {rc}.", "error")
        return

    ctx.line("[OK] Update complete.", "ok")
    # Kernel and glibc updates only take effect after a restart.
    if _reboot_required():
        ctx.line("[!] A reboot is required to finish this update.", "warn")


def topgrade(ctx: ToolContext) -> None:
    ctx.heading("Topgrade -- Full System Upgrade")

    if not system.has("topgrade"):
        ctx.line("topgrade is not installed.", "error")
        ctx.line()
        ctx.line("Install it with your package manager:", "muted")
        ctx.line("  Arch / CachyOS / Manjaro:  pacman -S topgrade", "muted")
        ctx.line("  Debian / Ubuntu / Fedora:  cargo install topgrade", "muted")
        return

    user = system.desktop_user()
    if not user:
        ctx.line("Could not determine the desktop user.", "error")
        return

    ctx.line("topgrade will upgrade:", "muted")
    ctx.line("  packages, flatpak, VS Code extensions, uv tools,", "muted")
    ctx.line("  gcloud, helm, firmware, and more.", "muted")
    ctx.line()

    # Reconstruct the session environment so GNOME Shell extensions and
    # session-aware tools work when topgrade is spawned from a root context
    # that did not inherit the graphical session. Each value is a separate
    # argv token for `env`, so a hostile DISPLAY cannot become a command.
    session_env = [
        f"DBUS_SESSION_BUS_ADDRESS={user.dbus}",
        f"WAYLAND_DISPLAY={os.environ.get('WAYLAND_DISPLAY', 'wayland-0')}",
        f"DISPLAY={os.environ.get('DISPLAY', ':0')}",
    ]
    # Fixed literal -- the shell is only here to hold the window open after.
    run_command = [
        "sudo",
        "-u",
        user.name,
        "env",
        *session_env,
        "bash",
        "-c",
        'topgrade; echo; read -r -p "Press Enter to close..."',
    ]

    for terminal, args in TERMINALS.items():
        if not system.has(terminal):
            continue
        ctx.line(f"[>>] Opening topgrade in {terminal}...", "info")
        system.run([terminal, *args, *run_command])
        return

    ctx.line("No supported terminal emulator found.", "error")
    ctx.line("Install one of: " + ", ".join(TERMINALS), "muted")

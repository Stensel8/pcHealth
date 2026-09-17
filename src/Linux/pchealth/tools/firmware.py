"""Firmware updates through fwupd / LVFS.

The vendor-neutral counterpart to HP Image Assistant on Windows: fwupd ships
BIOS, dock, SSD and peripheral firmware for most vendors.
"""

from __future__ import annotations

from .. import system
from .base import ToolContext

_INSTALL_HINTS = (
    "  Debian / Ubuntu:  apt install fwupd",
    "  Fedora / RHEL:    dnf install fwupd",
    "  Arch / CachyOS:   pacman -S fwupd",
    "  openSUSE:         zypper install fwupd",
)

# fwupd is a daemon; its CLI still exits having printed nothing useful when it
# is masked or not running. An empty update list must never become an
# invitation to flash firmware.
_DAEMON_DOWN = ("Failed to connect to daemon", "Failed to load daemon", "could not be activated")
_REFRESH_FAILED = ("Failed to download", "transient failure", "Failed to connect")
_NO_UPDATES = (
    "No updatable devices",
    "No updates available",
    "Devices with no available firmware updates",
)


def firmware_update(ctx: ToolContext) -> None:
    ctx.heading("Firmware Update  (fwupd / LVFS)")

    if not system.has("fwupdmgr"):
        ctx.line("fwupdmgr is not installed.", "error")
        ctx.line()
        ctx.line("Install it with your package manager:", "muted")
        for hint in _INSTALL_HINTS:
            ctx.line(hint, "muted")
        return

    ctx.line("[>>] Refreshing firmware metadata from LVFS...", "info")
    # --force refreshes even when the cached metadata is still considered fresh.
    refresh = system.run_root(["fwupdmgr", "refresh", "--force"])
    refresh_text = refresh.stdout + refresh.stderr
    for line in refresh_text.splitlines():
        ctx.line(f"  {line}", "muted")
    # Without fresh metadata the verdict below reflects whatever was cached,
    # which may be months old -- say so rather than reporting "up to date".
    stale = any(marker in refresh_text for marker in _REFRESH_FAILED)

    ctx.line()
    ctx.line("[>>] Checking for firmware updates...", "info")
    ctx.line()
    updates = system.run_root(["fwupdmgr", "get-updates"])
    updates_text = updates.stdout + updates.stderr

    if any(marker in updates_text for marker in _DAEMON_DOWN):
        ctx.line("Could not reach the fwupd daemon.", "error")
        ctx.line("Start it with: systemctl start fwupd", "muted")
        return

    # fwupdmgr exits non-zero when there is simply nothing to do, so read text.
    if not updates_text.strip() or any(marker in updates_text for marker in _NO_UPDATES):
        if stale:
            ctx.line("No updates found, but the LVFS metadata could not be refreshed.", "warn")
            ctx.line(
                "This answer is based on cached data -- check again once you are online.", "muted"
            )
        else:
            ctx.line("All firmware is up to date.", "ok")
        return

    for line in updates_text.splitlines():
        ctx.line(f"  {line}", "muted")

    ctx.line()
    ctx.line("[!] Firmware updates carry real risk. Do not power the machine off", "warn")
    ctx.line("    while one is running, and plug in the charger on a laptop.", "warn")
    ctx.line()

    if not ctx.confirm("Install these firmware updates?"):
        ctx.line("Cancelled.", "muted")
        return

    ctx.line()
    ctx.line("[>>] Installing firmware updates...", "info")
    rc = system.stream_root(["fwupdmgr", "update"], lambda line: ctx.line(f"  {line}", "muted"))
    ctx.line()
    if rc == 0:
        ctx.line("[OK] Firmware update complete.", "ok")
        ctx.line("Some devices only apply the update on the next reboot.", "muted")
    else:
        ctx.line(f"[!!] fwupdmgr exited with code {rc}.", "error")

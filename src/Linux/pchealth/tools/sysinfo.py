"""System information, and the BIOS password link."""

from __future__ import annotations

import os
import socket

from .. import system
from .base import Choice, Level, ToolUI

_SECURE_BOOT_NOTE = (
    "Secure Boot shows the UEFI firmware state only. Actual enforcement "
    "depends on shim/MOK setup and varies per distro."
)


def _meminfo() -> dict[str, int]:
    values: dict[str, int] = {}
    for line in (system.read_text("/proc/meminfo") or "").splitlines():
        key, sep, rest = line.partition(":")
        if not sep:
            continue
        number = rest.strip().split(" ", 1)[0]
        if number.isdigit():
            values[key] = int(number)
    return values


def _cpu_model() -> str:
    for line in (system.read_text("/proc/cpuinfo") or "").splitlines():
        key, sep, value = line.partition(":")
        # x86 reports "model name"; arm64 has no such field and uses "Model".
        if sep and key.strip() in ("model name", "Model"):
            return value.strip()
    return "N/A"


def _machine_model() -> str:
    vendor = system.read_text("/sys/class/dmi/id/sys_vendor")
    model = system.read_text("/sys/class/dmi/id/product_name")
    if vendor and model:
        return f"{vendor} {model}"
    return model or "N/A"


def _secure_boot() -> str:
    state = system.output(["mokutil", "--sb-state"])
    if state:
        lowered = state.lower()
        if "enabled" in lowered:
            return "Enabled"
        if "disabled" in lowered:
            return "Disabled"
        return state

    # No mokutil: read the EFI variable the kernel exposes. The first four
    # bytes are the variable attributes; the fifth is the flag itself.
    efivars = "/sys/firmware/efi/efivars"
    try:
        names = [name for name in os.listdir(efivars) if name.startswith("SecureBoot-")]
    except OSError:
        return "N/A"
    for name in names:
        try:
            with open(os.path.join(efivars, name), "rb") as handle:
                raw = handle.read(5)
        except OSError:
            return "Unknown"
        if len(raw) >= 5:
            return "Enabled" if raw[4] == 1 else "Disabled"
    return "N/A"


def _package_count() -> str:
    for command, argv, label in (
        ("pacman", ["pacman", "-Q"], "pacman"),
        ("dpkg", ["dpkg-query", "-f", "${binary:Package}\n", "-W"], "dpkg"),
        ("rpm", ["rpm", "-qa"], "rpm"),
    ):
        if not system.has(command):
            continue
        listing = system.output(argv)
        if listing is not None:
            return f"{len(listing.splitlines())} ({label})"
    return "N/A"


def _timezone() -> str:
    # timedatectl is unavailable without systemd (containers, WSL, OpenRC).
    zone = system.output(["timedatectl", "show", "--property=Timezone", "--value"])
    if zone:
        return zone
    return os.environ.get("TZ") or system.output(["date", "+%Z"]) or "N/A"


def _session_type() -> str:
    if os.environ.get("WAYLAND_DISPLAY"):
        return "Wayland"
    if os.environ.get("DISPLAY"):
        return "X11"
    return "Unknown"


def system_info(ui: ToolUI) -> None:
    ui.section("System Information")

    memory = _meminfo()
    total_kib = memory.get("MemTotal")
    available_kib = memory.get("MemAvailable")
    uname = os.uname()
    user = system.desktop_user()

    ui.fields(
        [
            ("Computer name", socket.gethostname()),
            ("Machine", _machine_model()),
            ("OS name", system.distro_info()["PRETTY_NAME"]),
            ("Kernel", uname.release),
            ("Architecture", uname.machine),
            ("CPU", _cpu_model()),
            (
                "RAM used",
                f"{(total_kib - available_kib) / 1048576:.2f} GB"
                if total_kib and available_kib is not None
                else "N/A",
            ),
            ("RAM total", f"{total_kib / 1048576:.2f} GB" if total_kib else "N/A"),
            ("Firmware", "UEFI" if os.path.exists("/sys/firmware/efi") else "Legacy BIOS"),
            ("Secure Boot", _secure_boot()),
            ("Uptime", system.output(["uptime", "-p"]) or "N/A"),
            ("Last boot", system.output(["uptime", "-s"]) or "N/A"),
            (
                "Desktop",
                os.environ.get("XDG_CURRENT_DESKTOP")
                or os.environ.get("DESKTOP_SESSION")
                or "Unknown",
            ),
            ("Session", _session_type()),
            ("Shell", os.environ.get("SHELL", "Unknown").rsplit("/", 1)[-1]),
            ("Packages", _package_count()),
            ("Timezone", _timezone()),
            ("User", user.name if user else "N/A"),
        ]
    )
    ui.note(_SECURE_BOOT_NOTE)


def bios_password(ui: ToolUI) -> None:
    """Links to bios-pw.org. Credits: @bacher09 -- pwgen-for-bios."""
    ui.section("BIOS Password Recovery")
    ui.note(
        "bios-pw.org generates recovery codes for locked BIOS passwords. "
        "Credits for this tool go to @bacher09."
    )

    urls = {
        "site": "https://bios-pw.org",
        "repo": "https://github.com/bacher09/pwgen-for-bios",
    }
    choice = ui.choose(
        "Which page should open?",
        [
            Choice("site", "bios-pw.org", "The recovery tool itself"),
            Choice("repo", "pwgen-for-bios on GitHub", "How the codes are generated"),
        ],
    )
    if choice is None:
        return

    if not system.open_url(urls[choice]):
        ui.note(f"Could not open a browser. Visit: {urls[choice]}", Level.WARN)

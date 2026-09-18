"""Hardware information: CPU, GPU, storage (SMART), RAM and temperatures."""

from __future__ import annotations

import re
from pathlib import Path

from .. import smart, system
from .base import Level, ToolUI

GPU_PATTERN = re.compile(
    r"^[\w:.]+\s+(?:VGA compatible controller|Display controller|3D controller):\s*(.+)$"
)


def _lscpu() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in (system.output(["lscpu"]) or "").splitlines():
        key, sep, value = line.partition(":")
        if sep:
            values[key.strip()] = value.strip()
    return values


def _meminfo() -> dict[str, int]:
    values: dict[str, int] = {}
    for line in (system.read_text("/proc/meminfo") or "").splitlines():
        key, sep, rest = line.partition(":")
        number = rest.strip().split(" ", 1)[0] if sep else ""
        if number.isdigit():
            values[key] = int(number)
    return values


def _gb(kib: int) -> str:
    return f"{kib / 1048576:.2f} GB"


def _cpu(ui: ToolUI) -> None:
    ui.section("CPU")
    data = _lscpu()
    if not data:
        ui.note("lscpu not available. Install util-linux.", Level.WARN)
        return

    max_mhz = data.get("CPU max MHz", "")
    try:
        speed = f"{round(float(max_mhz.replace(',', '.')))} MHz" if max_mhz else "N/A"
    except ValueError:
        speed = "N/A"

    ui.fields(
        [
            ("Name", data.get("Model name", "N/A")),
            ("Architecture", data.get("Architecture", "N/A")),
            ("Cores", data.get("Core(s) per socket", "N/A")),
            ("Threads", data.get("CPU(s)", "N/A")),
            ("Max speed", speed),
            ("L1d cache", data.get("L1d cache", "N/A")),
            ("L1i cache", data.get("L1i cache", "N/A")),
            ("L2 cache", data.get("L2 cache", "N/A")),
            ("L3 cache", data.get("L3 cache", "N/A")),
            ("Virtualization", data.get("Virtualization", "N/A")),
        ]
    )


def _gpu(ui: ToolUI) -> None:
    ui.section("GPU")
    listing = system.output(["lspci"])
    if listing is None:
        ui.note("lspci not available. Install pciutils.", Level.WARN)
        return

    found = [
        match.group(1).strip()
        for line in listing.splitlines()
        if (match := GPU_PATTERN.match(line))
    ]
    if found:
        ui.fields([(f"GPU {n}", name) for n, name in enumerate(found, 1)])
    else:
        ui.note("No GPU found via lspci.", Level.WARN)


def _storage(ui: ToolUI) -> None:
    ui.section("Storage")

    if not smart.available():
        listing = system.output(["lsblk", "-d", "-o", "NAME,SIZE,TYPE,MODEL"])
        if listing:
            rows = [line.split(None, 1) for line in listing.splitlines()[1:] if line.strip()]
            ui.fields([(parts[0], parts[1] if len(parts) > 1 else "") for parts in rows])
            ui.note("Install smartmontools for life %, temperature and power-on hours.")
        else:
            ui.note("Neither smartctl nor lsblk is available.", Level.WARN)
        return

    devices = smart.devices()
    if not devices:
        ui.note("smartctl found no devices with usable SMART data.", Level.WARN)
        return

    for device in devices:
        ui.fields(
            [
                ("Model", device.model),
                ("Type", device.media),
                ("Size", f"{device.capacity_gb} GB"),
                ("Temperature", f"{device.temperature_c} C" if device.temperature_c else "N/A"),
                ("Power-on hours", str(device.power_on_hours or "N/A")),
                ("Life left", f"{device.life_left_pct}%" if device.life_left_pct else "N/A"),
                ("Health", device.health_text),
            ]
        )
        if device.passed is False:
            ui.note(f"{device.model} reports SMART failure. Back it up now.", Level.ERROR)


def _memory(ui: ToolUI) -> None:
    ui.section("Memory")
    memory = _meminfo()
    total = memory.get("MemTotal", 0)
    if not total:
        ui.note("RAM information not available.", Level.WARN)
        return

    available = memory.get("MemAvailable", 0)
    cache = memory.get("Buffers", 0) + memory.get("Cached", 0) + memory.get("SReclaimable", 0)
    swap_total = memory.get("SwapTotal", 0)

    ui.fields(
        [
            ("Total", _gb(total)),
            ("Used", _gb(total - available)),
            ("Available", _gb(available)),
            ("Buffers / cache", _gb(cache)),
            ("Swap total", _gb(swap_total)),
            ("Swap used", _gb(swap_total - memory.get("SwapFree", 0))),
        ]
    )


def _sensors(ui: ToolUI) -> None:
    """Straight from the kernel's hwmon class.

    The same source lm-sensors reads, so nothing needs to be installed.
    """
    ui.section("Temperatures")
    root = Path("/sys/class/hwmon")
    try:
        chips = sorted(root.iterdir())
    except OSError:
        chips = []

    readings: list[tuple[str, str]] = []
    for chip in chips:
        chip_name = system.read_text(chip / "name") or chip.name
        for entry in sorted(chip.glob("temp*_input")):
            raw = system.read_text(entry)
            if not raw or not raw.lstrip("-").isdigit():
                continue
            label = system.read_text(entry.with_name(entry.name.replace("_input", "_label")))
            # hwmon reports millidegrees Celsius.
            readings.append((f"{chip_name} {label or entry.stem}", f"{int(raw) / 1000:.1f} C"))

    if readings:
        ui.fields(readings)
    else:
        ui.note("No temperature readings exposed by this kernel.")


def hardware_info(ui: ToolUI) -> None:
    _cpu(ui)
    _gpu(ui)
    _storage(ui)
    _memory(ui)
    _sensors(ui)

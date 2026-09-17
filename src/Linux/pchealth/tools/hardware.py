"""Hardware information: CPU, GPU, storage (SMART), RAM and temperatures."""

from __future__ import annotations

import re
from pathlib import Path

from .. import smart, system
from .base import ToolContext

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
        if not sep:
            continue
        number = rest.strip().split(" ", 1)[0]
        if number.isdigit():
            values[key] = int(number)
    return values


def _gb(kib: int) -> str:
    return f"{kib / 1048576:.2f}"


def _cpu_section(ctx: ToolContext) -> None:
    ctx.heading("CPU")
    data = _lscpu()
    if not data:
        ctx.line("lscpu not available. Install util-linux.", "warn")
        return

    max_mhz = data.get("CPU max MHz", "")
    try:
        speed = f"{round(float(max_mhz.replace(',', '.')))} MHz" if max_mhz else "N/A"
    except ValueError:
        speed = "N/A"

    ctx.rows(
        [
            ("CPU Name", data.get("Model name", "N/A")),
            ("Architecture", data.get("Architecture", "N/A")),
            ("Cores", data.get("Core(s) per socket", "N/A")),
            ("Threads", data.get("CPU(s)", "N/A")),
            ("Max Speed", speed),
            ("L1d Cache", data.get("L1d cache", "N/A")),
            ("L1i Cache", data.get("L1i cache", "N/A")),
            ("L2 Cache", data.get("L2 cache", "N/A")),
            ("L3 Cache", data.get("L3 cache", "N/A")),
            ("Virtualization", data.get("Virtualization", "N/A")),
        ]
    )


def _gpu_section(ctx: ToolContext) -> None:
    ctx.heading("GPU")
    listing = system.output(["lspci"])
    if listing is None:
        ctx.line("lspci not available. Install pciutils.", "warn")
        return

    found = [
        match.group(1).strip()
        for line in listing.splitlines()
        if (match := GPU_PATTERN.match(line))
    ]
    if not found:
        ctx.line("No GPU found via lspci.", "warn")
        return
    for gpu in found:
        ctx.line(f"  {gpu}")


def _storage_section(ctx: ToolContext) -> None:
    ctx.heading("Storage")

    if not smart.available():
        listing = system.output(["lsblk", "-d", "-o", "NAME,SIZE,TYPE,MODEL"])
        if listing:
            for line in listing.splitlines():
                ctx.line(f"  {line}", "muted")
            ctx.line()
            ctx.line("Install smartmontools for life %, temperature and power-on hours.", "muted")
        else:
            ctx.line("Storage section skipped -- neither smartctl nor lsblk available.", "warn")
        return

    found = smart.devices()
    if not found:
        ctx.line("smartctl found no devices with usable SMART data.", "warn")
        return

    ctx.rows(
        [
            (
                device.model,
                f"{device.media}  {device.capacity_gb} GB  "
                f"{device.temperature_c if device.temperature_c is not None else 'N/A'} C  "
                f"{device.power_on_hours if device.power_on_hours is not None else 'N/A'} h  "
                f"life {device.life_left_pct}%"
                if device.life_left_pct is not None
                else f"{device.media}  {device.capacity_gb} GB",
            )
            for device in found
        ]
    )
    ctx.line()
    ctx.rows([(device.model, device.health_text) for device in found], "muted")


def _memory_section(ctx: ToolContext) -> None:
    ctx.heading("Memory (RAM)")
    memory = _meminfo()
    total = memory.get("MemTotal")
    if not total:
        ctx.line("RAM information not available.", "warn")
        return

    available = memory.get("MemAvailable", 0)
    buff_cache = memory.get("Buffers", 0) + memory.get("Cached", 0) + memory.get("SReclaimable", 0)
    swap_total = memory.get("SwapTotal", 0)
    swap_free = memory.get("SwapFree", 0)

    ctx.rows(
        [
            ("Total (GB)", _gb(total)),
            ("Used (GB)", _gb(total - available)),
            ("Available (GB)", _gb(available)),
            ("Buff/Cache (GB)", _gb(buff_cache)),
            ("Swap Total (GB)", _gb(swap_total)),
            ("Swap Used (GB)", _gb(swap_total - swap_free)),
        ]
    )


def _sensors_section(ctx: ToolContext) -> None:
    """Straight from the kernel's hwmon class.

    The same source lm-sensors reads, so nothing needs to be installed.
    """
    ctx.heading("Sensors (Temperatures)")
    root = Path("/sys/class/hwmon")
    if not root.exists():
        ctx.line("No hwmon sensors exposed by this kernel.", "muted")
        return

    readings: list[tuple[str, str]] = []
    try:
        chips = sorted(root.iterdir())
    except OSError:
        chips = []

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
        ctx.rows(readings)
    else:
        ctx.line("No temperature readings available.", "muted")


def hardware_info(ctx: ToolContext) -> None:
    _cpu_section(ctx)
    ctx.line()
    _gpu_section(ctx)
    ctx.line()
    _storage_section(ctx)
    ctx.line()
    _memory_section(ctx)
    ctx.line()
    _sensors_section(ctx)

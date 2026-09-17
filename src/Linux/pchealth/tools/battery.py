"""Battery report, straight from the kernel's power_supply class.

No external tool needed: upower and acpi both read these same sysfs files.
"""

from __future__ import annotations

from pathlib import Path

from .. import system
from .base import ToolContext

SUPPLY_ROOT = Path("/sys/class/power_supply")


def _attribute(directory: Path, *names: str) -> str | None:
    """Read the first attribute that exists.

    Names vary by driver -- energy_* on one laptop, charge_* on the next -- and
    any of them may be absent entirely.
    """
    for name in names:
        value = system.read_text(directory / name)
        if value:
            return value
    return None


def _micro(raw: str | None) -> str:
    """sysfs reports micro-units throughout."""
    if not raw:
        return "N/A"
    try:
        return f"{int(raw) / 1e6:.2f}"
    except ValueError:
        return "N/A"


def _verdict(health: float) -> tuple[str, str]:
    if health >= 80:
        return "Good -- the battery holds most of its design capacity.", "ok"
    if health >= 60:
        return "Worn -- noticeably reduced runtime.", "warn"
    return "Poor -- consider replacing the battery.", "error"


def battery_report(ctx: ToolContext) -> None:
    ctx.heading("Battery Report")

    if not SUPPLY_ROOT.exists():
        ctx.line(f"{SUPPLY_ROOT} not found -- this kernel exposes no power supplies.", "error")
        return

    try:
        candidates = sorted(SUPPLY_ROOT.iterdir())
    except OSError as exc:
        ctx.line(f"Could not read {SUPPLY_ROOT}: {exc}", "error")
        return

    batteries = [d for d in candidates if _attribute(d, "type") == "Battery"]
    if not batteries:
        ctx.line("No battery detected -- this looks like a desktop system.", "warn")
        return

    for battery in batteries:
        # Drivers report either energy (uWh) or charge (uAh); the health ratio
        # holds for both as long as full and design come from the same pair.
        full = _attribute(battery, "energy_full", "charge_full")
        design = _attribute(battery, "energy_full_design", "charge_full_design")
        unit = "Wh" if (battery / "energy_full").exists() else "Ah"

        health: float | None = None
        try:
            if full and design and float(design) > 0:
                health = round(float(full) / float(design) * 100, 1)
        except ValueError:
            health = None

        cycles = _attribute(battery, "cycle_count")
        power = _attribute(battery, "power_now", "current_now")
        capacity = _attribute(battery, "capacity")

        ctx.rows(
            [
                ("Battery", battery.name),
                ("Manufacturer", _attribute(battery, "manufacturer") or "N/A"),
                ("Model", _attribute(battery, "model_name") or "N/A"),
                ("Technology", _attribute(battery, "technology") or "N/A"),
                ("Status", _attribute(battery, "status") or "N/A"),
                ("Charge", f"{capacity}%" if capacity else "N/A"),
                (f"Full ({unit})", _micro(full)),
                (f"Design ({unit})", _micro(design)),
                (f"Now ({unit})", _micro(_attribute(battery, "energy_now", "charge_now"))),
                ("Voltage (V)", _micro(_attribute(battery, "voltage_now"))),
                ("Draw", f"{_micro(power)} {'W' if unit == 'Wh' else 'A'}" if power else "N/A"),
                ("Cycle Count", cycles or "Not reported by driver"),
                ("Health", f"{health}%" if health is not None else "N/A"),
            ]
        )
        ctx.line()

        if health is not None:
            message, style = _verdict(health)
            ctx.line(message, style)
        if not cycles:
            ctx.line(
                "[*] Many laptop batteries do not expose a cycle count to the kernel.", "muted"
            )
        ctx.line()

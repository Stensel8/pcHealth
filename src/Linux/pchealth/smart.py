"""SMART data, read once and shared.

Both Hardware Information and the Health report need this, and smartctl's
JSON is fiddly enough that having two readers of it would mean two sets of
quirks to keep in step.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from . import system

# SSD wear-levelling attributes, in the order vendors actually use them.
_LIFE_ATTRIBUTES = (231, 202, 177)


@dataclass(frozen=True)
class Device:
    name: str
    model: str
    media: str
    capacity_bytes: int | None = None
    temperature_c: int | None = None
    power_on_hours: int | None = None
    life_left_pct: int | None = None
    # True passed, False failing, None not reported.
    passed: bool | None = None

    @property
    def capacity_gb(self) -> str:
        return f"{round(self.capacity_bytes / 1024**3)}" if self.capacity_bytes else "N/A"

    @property
    def health_text(self) -> str:
        if self.passed is True:
            return "Healthy"
        return "FAILING" if self.passed is False else "Unknown"


def _read(argv: list[str]) -> dict[str, Any] | None:
    """smartctl exits non-zero for a disk with warnings, so ignore the code.

    Its JSON is still complete in that case -- which is the whole point of
    asking for JSON rather than parsing the human-readable report.
    """
    result = system.run_root(argv)
    if not result.stdout.strip():
        return None
    try:
        parsed = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def available() -> bool:
    return system.has("smartctl")


def devices() -> list[Device]:
    """Every disk smartctl can see. Empty when smartmontools is not installed."""
    if not available():
        return []

    scan = _read(["smartctl", "--scan", "--json"])
    found: list[Device] = []

    for entry in (scan or {}).get("devices", []):
        name = entry.get("name")
        kind = entry.get("type", "")
        if not name:
            continue

        argv = ["smartctl", "-a", name, "--json"]
        if kind and kind != "auto":
            argv += ["-d", kind]
        data = _read(argv)
        if not data or not data.get("model_name"):
            continue

        is_nvme = kind == "nvme"
        rotation = data.get("rotation_rate", 0) or 0

        life: int | None = None
        if is_nvme:
            used = data.get("nvme_smart_health_information_log", {}).get("percentage_used")
            if used is not None:
                life = max(0, 100 - int(used))
        elif rotation == 0:
            table = data.get("ata_smart_attributes", {}).get("table", [])
            attribute = next((a for a in table if a.get("id") in _LIFE_ATTRIBUTES), None)
            if attribute is not None:
                life = attribute.get("value")

        found.append(
            Device(
                name=name,
                model=str(data["model_name"]),
                media="SSD" if is_nvme or rotation == 0 else "HDD",
                capacity_bytes=data.get("capacity", {}).get("bytes"),
                temperature_c=data.get("temperature", {}).get("current"),
                power_on_hours=data.get("power_on_time", {}).get("hours"),
                life_left_pct=life,
                passed=data.get("smart_status", {}).get("passed"),
            )
        )

    return found

"""Disk cleanup, SSD trim and the package-integrity scan."""

from __future__ import annotations

from pathlib import Path

from .. import system
from .base import ProgressFilter, ToolContext

FS_ERROR_PATTERNS = (
    "EXT4-fs error",
    "XFS",
    "BTRFS error",
    "I/O error",
    "read-only",
)
MAX_FINDINGS_SHOWN = 20


Step = tuple[str, list[str]]


def _run_steps(ctx: ToolContext, steps: list[Step]) -> None:
    """Run every step under a single elevation prompt.

    Cleaning a machine is half a dozen privileged commands. Elevating each one
    separately asked for the password half a dozen times, which is what made
    this tool exhausting to use.
    """
    if not steps:
        return

    progress = ProgressFilter(lambda line: ctx.line(f"  {line}", "muted"))
    current = -1

    def on_line(index: int, line: str) -> None:
        nonlocal current
        if index != current:
            progress.flush()
            current = index
            ctx.line(f"[>>] {steps[index][0]}", "info")
        progress(line)

    results = system.run_root_batch([argv for _, argv in steps], on_line=on_line)
    progress.flush()

    for (label, _), result in zip(steps, results, strict=True):
        if result.ok:
            ctx.line(f"[OK] {label}", "ok")
        else:
            ctx.line(f"[--] {label} exited {result.returncode} (may be non-fatal).", "muted")
    ctx.line()


# -- Disk cleanup -------------------------------------------------------------


def _package_steps(ctx: ToolContext, distro_id: str, distro_like: str) -> list[Step]:
    family = f"{distro_id} {distro_like}"

    if any(
        key in family for key in ("arch", "cachyos", "manjaro", "endeavouros", "artix", "garuda")
    ):
        steps: list[Step] = []
        if system.has("paccache"):
            steps.append(("Clearing pacman cache (keeping last 2 versions)", ["paccache", "-rk2"]))
        # Passing an empty list to pacman -Rns exits non-zero and reads like a
        # failure, so only run it when there is something to remove.
        orphans = system.output(["pacman", "-Qdtq"])
        if orphans:
            steps.append(
                (
                    "Removing unneeded pacman dependencies",
                    ["pacman", "-Rns", *orphans.split(), "--noconfirm"],
                )
            )
        else:
            ctx.line("[--] No unneeded pacman dependencies found, skipping.", "muted")
        return steps

    if any(
        key in family for key in ("debian", "ubuntu", "mint", "pop", "elementary", "zorin", "kali")
    ):
        return [
            ("Removing unneeded apt packages", ["apt", "autoremove", "-y"]),
            ("Cleaning apt cache", ["apt", "autoclean"]),
        ]

    if any(key in family for key in ("fedora", "rhel", "centos", "almalinux", "rocky")):
        return [
            ("Removing unneeded dnf packages", ["dnf", "autoremove", "-y"]),
            ("Cleaning dnf cache", ["dnf", "clean", "all"]),
        ]

    if "suse" in family:
        return [("Cleaning zypper cache", ["zypper", "clean", "--all"])]

    ctx.line("[--] Package cache: distro not recognised, skipping.", "muted")
    return []


def _clear_thumbnails(ctx: ToolContext) -> None:
    """Runs unprivileged: the cache belongs to the user, not to root."""
    user = system.desktop_user()
    if not user:
        return
    thumbnails = Path(user.home) / ".cache" / "thumbnails"
    if not thumbnails.is_dir():
        return

    files = [path for path in thumbnails.rglob("*") if path.is_file()]
    size_mb = sum(path.stat().st_size for path in files) / 1048576 if files else 0.0

    ctx.line(f"[>>] Clearing thumbnail cache ({size_mb:.1f} MB)", "info")
    removed = 0
    for path in files:
        try:
            path.unlink()
            removed += 1
        except OSError:
            continue
    ctx.line(f"[OK] Removed {removed} file(s).", "ok")
    ctx.line()


def disk_cleanup(ctx: ToolContext) -> None:
    ctx.heading("Disk Cleanup")

    info = system.distro_info()
    ctx.line(f"Distro: {info['PRETTY_NAME']}", "muted")
    ctx.line()

    steps = _package_steps(ctx, info["ID"], info["ID_LIKE"])
    if system.has("journalctl"):
        steps.append(
            ("Vacuuming journal logs (keeping last 7 days)", ["journalctl", "--vacuum-time=7d"])
        )
    if system.has("flatpak"):
        steps.append(
            ("Removing unused Flatpak runtimes", ["flatpak", "uninstall", "--unused", "-y"])
        )

    _run_steps(ctx, steps)
    _clear_thumbnails(ctx)

    ctx.line("Disk cleanup complete.", "ok")


# -- Disk optimization --------------------------------------------------------


def _block_devices() -> list[tuple[str, str]]:
    """Real disks and whether they spin, skipping loop/ram/zram/optical."""
    devices: list[tuple[str, str]] = []
    try:
        entries = sorted(Path("/sys/block").iterdir())
    except OSError:
        return devices

    for entry in entries:
        if entry.name.startswith(("loop", "ram", "zram", "sr")):
            continue
        rotational = system.read_text(entry / "queue" / "rotational")
        kind = {"0": "SSD / NVMe", "1": "HDD"}.get(rotational or "", "Unknown")
        devices.append((entry.name, kind))
    return devices


def disk_optimize(ctx: ToolContext) -> None:
    ctx.heading("Disk Optimization")

    # Linux filesystems do not fragment the way NTFS does, so the useful half
    # of what dfrgui does on Windows is discarding unused blocks on an SSD.
    devices = _block_devices()
    if devices:
        ctx.rows(devices)
        ctx.line()
        if not any(kind == "SSD / NVMe" for _, kind in devices):
            ctx.line("No solid-state device detected -- there is nothing to trim.", "warn")
            ctx.line("Linux filesystems do not need defragmenting.", "muted")
            return

    if not system.has("fstrim"):
        ctx.line("fstrim not found. Install util-linux.", "error")
        return

    # Many distros already run fstrim.timer weekly; say so rather than
    # implying the manual run was necessary.
    if system.output(["systemctl", "is-enabled", "fstrim.timer"]) == "enabled":
        ctx.line("Note: fstrim.timer is enabled, so this already runs weekly.", "muted")
        ctx.line()

    ctx.line("[>>] Trimming all mounted filesystems that support it...", "info")
    ctx.line("     This can take a minute on a large or nearly full disk.", "muted")
    ctx.line()

    rc = system.stream_root(
        ["fstrim", "--all", "--verbose"], lambda line: ctx.line(f"  {line}", "muted")
    )
    ctx.line()
    ctx.command_output(rc, ok="[OK] Trim complete.", failed=f"[!!] fstrim exited with code {rc}.")


# -- Scan + repair ------------------------------------------------------------


def scan_repair(ctx: ToolContext) -> None:
    ctx.heading("Scan + Repair  (package integrity)")

    manager = system.package_manager()
    if not manager or not manager.verify:
        ctx.line("No supported package manager found (apt/dnf/pacman/zypper).", "error")
        return

    verify_cmd, *verify_args = manager.verify
    if not system.has(verify_cmd):
        ctx.line(
            f"{verify_cmd} is not installed -- it does the checking, not {manager.cmd}.", "error"
        )
        ctx.line(
            f"Install it with: {manager.cmd} {' '.join(manager.install)} {verify_cmd}", "muted"
        )
        return

    # -- Filesystem errors ----------------------------------------------------
    # Read-only on purpose: fsck cannot safely touch a mounted root, so report
    # what the kernel already saw and let the user repair from a live image.
    ctx.line("[>>] Step 1/2 -- Checking the kernel log for filesystem errors...", "info")
    dmesg = system.run_root(["dmesg", "--level=err,warn"])
    fs_errors = [
        line
        for line in dmesg.stdout.splitlines()
        if any(pattern in line for pattern in FS_ERROR_PATTERNS)
    ]

    if fs_errors:
        ctx.line("[!!] The kernel has logged filesystem errors:", "error")
        ctx.line()
        for line in fs_errors[-10:]:
            ctx.line(f"  {line}", "muted")
        ctx.line()
        ctx.line("Run fsck from a live image -- it cannot repair a mounted root.", "warn")
    else:
        ctx.line("[OK] No filesystem errors in the kernel log.", "ok")
    ctx.line()

    # -- Package integrity ----------------------------------------------------
    ctx.line(f"[>>] Step 2/2 -- Verifying installed packages with {verify_cmd}...", "info")
    ctx.line("     This reads every packaged file and takes several minutes.", "muted")
    ctx.line()

    if not ctx.confirm("Start the verification?"):
        ctx.line("Skipped.", "muted")
        return

    ctx.line()
    # Merge stderr: debsums reports every changed file there, so dropping it
    # would turn a corrupted system into a clean bill of health.
    findings: list[str] = []
    system.stream_root([verify_cmd, *verify_args], findings.append, should_stop=ctx.should_stop)
    findings = [line.strip() for line in findings if line.strip()]

    if not findings:
        ctx.line("[OK] Every packaged file matches the package database.", "ok")
        return

    ctx.line(f"[!!] {len(findings)} file(s) no longer match their package:", "error")
    ctx.line()
    for line in findings[:MAX_FINDINGS_SHOWN]:
        ctx.line(f"  {line}", "muted")
    if len(findings) > MAX_FINDINGS_SHOWN:
        ctx.line(f"  ... and {len(findings) - MAX_FINDINGS_SHOWN} more", "muted")

    ctx.line()
    ctx.line("Config files you edited yourself show up here too -- that is expected.", "muted")
    ctx.line(
        f"Repair a package with: {manager.cmd} {' '.join(manager.install)} --reinstall <package>",
        "muted",
    )

"""Boot repair for UEFI systems.

UEFI only, deliberately. Repairing a legacy BIOS/MBR setup means writing raw
boot code to the disk -- a different and far riskier operation than
reinstalling an EFI binary onto the ESP.

Every repair runs the bootloader's own official command. pcHealth never writes
boot sectors itself and never guesses which loader you use.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from .. import system
from .base import Choice, ToolContext

ESP_CANDIDATES = ("/efi", "/boot/efi", "/boot")


@dataclass(frozen=True)
class Loader:
    name: str
    present: bool
    commands: list[list[str]]

    @property
    def state(self) -> str:
        return "installed on this ESP" if self.present else "tooling present, not installed here"


def _efi_names() -> tuple[str, str]:
    """The EFI binary name and GRUB target for this machine.

    Both follow the firmware's bitness, not the CPU's: a 64-bit CPU can ship
    32-bit UEFI firmware, and BOOTX64 will not boot there.
    """
    machine = os.uname().machine
    if machine.startswith(("aarch64", "arm64")):
        return "BOOTAA64.EFI", "arm64-efi"
    bits = system.read_text("/sys/firmware/efi/fw_platform_size") or "64"
    if bits == "32":
        return "BOOTIA32.EFI", "i386-efi"
    return "BOOTX64.EFI", "x86_64-efi"


def _find_esp() -> str | None:
    """Only trust a mounted vfat partition.

    Mounting one ourselves would mean picking a candidate by guesswork, on the
    one filesystem where a wrong guess is fatal.
    """
    for candidate in ESP_CANDIDATES:
        if system.output(["findmnt", "-rno", "FSTYPE", "--target", candidate]) == "vfat":
            return candidate
    return None


def _detect_loaders(esp: str, efi_name: str, grub_target: str) -> list[Loader]:
    loaders: list[Loader] = []
    esp_path = Path(esp)

    if (esp_path / "EFI/systemd").exists() or system.has("bootctl"):
        loaders.append(
            Loader(
                name="systemd-boot",
                present=(esp_path / "EFI/systemd").exists(),
                commands=[["bootctl", "install", f"--esp-path={esp}"]],
            )
        )

    grub_cmd = next((c for c in ("grub-install", "grub2-install") if system.has(c)), None)
    if grub_cmd:
        # Fedora/RHEL name everything grub2-* and keep the config in /boot/grub2.
        is_grub2 = grub_cmd == "grub2-install"
        mkconfig = "grub2-mkconfig" if is_grub2 else "grub-mkconfig"
        grub_dir = "/boot/grub2" if is_grub2 else "/boot/grub"
        boot_id = system.distro_info()["ID"] or "linux"
        loaders.append(
            Loader(
                name="GRUB",
                present=Path(grub_dir).exists() or (esp_path / "EFI/grub").exists(),
                commands=[
                    [
                        grub_cmd,
                        f"--target={grub_target}",
                        f"--efi-directory={esp}",
                        f"--bootloader-id={boot_id}",
                    ],
                    [mkconfig, "-o", str(Path(grub_dir) / "grub.cfg")],
                ],
            )
        )

    # Limine has no upstream UEFI installer -- the documented procedure is to
    # copy the EFI binary onto the ESP. Distros ship a helper, so prefer that.
    helper = next((c for c in ("limine-update", "limine-install") if system.has(c)), None)
    limine_source = Path("/usr/share/limine") / efi_name
    if helper or limine_source.exists():
        if helper:
            commands = [[helper]]
        else:
            # Never `limine bios-install` here: that writes an MBR stage and is
            # documented as BIOS-only.
            commands = [
                ["mkdir", "-p", str(esp_path / "EFI/BOOT")],
                ["cp", str(limine_source), str(esp_path / "EFI/BOOT" / efi_name)],
            ]
        configs = ("limine.conf", "limine/limine.conf", "boot/limine/limine.conf")
        loaders.append(
            Loader(
                name="Limine",
                present=(esp_path / "EFI/BOOT" / efi_name).exists()
                or any((esp_path / name).exists() for name in configs),
                commands=commands,
            )
        )

    return loaders


def boot_repair(ctx: ToolContext) -> None:
    ctx.heading("Boot Repair  (UEFI)")
    ctx.line("WARNING: This operation modifies boot-critical files.", "warn")
    ctx.line("Incorrect use can render the system unbootable.", "warn")
    ctx.line("Only proceed if you understand what you are doing.", "warn")
    ctx.line()

    # On ostree systems the bootloader entries are generated from the
    # deployments. Reinstalling by hand fights whatever produced them.
    if system.is_image_based():
        ctx.line("This is an image-based system (ostree).", "error")
        ctx.line("Its bootloader is managed by the deployment, not by hand.", "warn")
        ctx.line("Roll back to a working deployment instead:", "warn")
        ctx.line("  rpm-ostree status      # list deployments", "muted")
        ctx.line("  rpm-ostree rollback    # boot the previous one", "muted")
        return

    if not Path("/sys/firmware/efi").exists():
        ctx.line("This system booted in legacy BIOS mode (no /sys/firmware/efi).", "error")
        ctx.line("pcHealth only repairs UEFI bootloaders.", "warn")
        return

    efi_name, grub_target = _efi_names()
    esp = _find_esp()
    if not esp:
        ctx.line("No mounted EFI System Partition found at /efi, /boot/efi or /boot.", "error")
        ctx.line("Mount it first, then run this tool again. Candidates:", "warn")
        listing = system.output(["lsblk", "-o", "NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINT"])
        for line in (listing or "").splitlines():
            if "EFI System" in line or "vfat" in line or line.startswith("NAME"):
                ctx.line(f"  {line}", "muted")
        return

    bits = system.read_text("/sys/firmware/efi/fw_platform_size") or "64"
    ctx.rows(
        [
            ("Firmware:", f"UEFI ({bits}-bit, {os.uname().machine})"),
            ("ESP:", esp),
            ("EFI binary:", efi_name),
        ],
        "muted",
    )
    ctx.line()

    loaders = _detect_loaders(esp, efi_name, grub_target)
    if not loaders:
        ctx.line("No supported bootloader found (systemd-boot, GRUB or Limine).", "error")
        ctx.line("Install your bootloader's package first, then run this tool again.", "warn")
        return

    choice = ctx.choose(
        "Which bootloader should be repaired?",
        [Choice(loader.name, loader.name, loader.state, destructive=True) for loader in loaders],
    )
    if choice is None:
        ctx.cancelled()
        return
    loader = next(candidate for candidate in loaders if candidate.name == choice)

    ctx.line()
    ctx.line("These commands will run as root:", "warn")
    for command in loader.commands:
        ctx.line(f"    {' '.join(command)}")
    ctx.line()

    # Two confirmations, same as the Windows tool: this is the one place where
    # a mistaken click leaves the machine unbootable.
    if not ctx.confirm(f"Reinstall {loader.name} on {esp}?"):
        ctx.cancelled()
        return
    if not ctx.confirm(
        "Last chance. An interrupted repair can leave this machine unbootable. Proceed?"
    ):
        ctx.cancelled()
        return

    ctx.line()
    for command in loader.commands:
        ctx.line(f"[>>] {' '.join(command)}", "info")
        rc = system.stream_root(command, lambda line: ctx.line(f"  {line}", "muted"))
        if rc != 0:
            ctx.line()
            ctx.line(f"[!!] Failed with exit code {rc} -- stopping here.", "error")
            ctx.line("The system may still boot from its existing entry. Do not reboot", "warn")
            ctx.line("until you have resolved this, and keep a live USB to hand.", "warn")
            return

    ctx.line(f"[OK] {loader.name} reinstalled on {esp}.", "ok")
    ctx.line()

    # A copied EFI binary with no firmware boot entry still leaves an
    # unbootable machine, so show the entries before the user reboots.
    if system.has("efibootmgr"):
        ctx.line("Current firmware boot entries:", "info")
        entries = system.run_root(["efibootmgr"]).stdout
        for line in entries.splitlines():
            ctx.line(f"  {line}", "muted")
        ctx.line()

    ctx.line("Verify the entry above before rebooting.", "warn")

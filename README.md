# pcHealth

Check the health of your Windows or Linux installation, drivers, updates, battery health and much more!

![License](https://img.shields.io/github/license/REALSDEALS/pcHealth?label=License)
![Latest Release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?label=Release)
![Pre-release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?include_prereleases&label=Pre-release)
![Repo Size](https://img.shields.io/github/repo-size/REALSDEALS/pcHealth?label=Repo%20Size)

---

## Overview

pcHealth is a cross-platform toolkit for IT technicians and power users. It runs on **Windows and Linux** using a single PowerShell 7 codebase. The goal is to offer the same functionality everywhere: tools are shown or hidden based on the detected OS, and platform-specific actions (like updating packages) automatically use the right method for the current system.

---

## Supported Platforms

| Platform | CLI | GUI | Minimum                       |
|----------|-----|-----|-------------------------------|
| Windows  | ✅  | ✅  | Build 19045 (Windows 10 22H2) |
| Linux    | ✅  | ❌  | Kernel 6.0                    |

### Windows support levels

| Level       | Build   | Windows     | Behaviour                                  |
|-------------|---------|-------------|--------------------------------------------|
| Recommended | ≥ 26200 | 11 25H2     | What every release is tested on            |
| Supported   | ≥ 19045 | 10 22H2, 11 | Runs; a note on start names the recommended build |
| Blocked     | < 19045 | older       | Exits immediately                          |

Build 19045 is where WinUI 3 stops rendering, so the CLI and the GUI share one floor rather than drifting apart. Windows 10 22H2 still runs on plenty of BIOS/MBR machines: Boot Repair detects the firmware type and refuses a legacy install rather than half-repairing it. Tools that need winget say so when App Installer is missing (LTSC and stripped images) instead of failing, and `Repair Winget` can add it.

On image-based systems (Fedora Silverblue, Bazzite, Kinoite, openSUSE MicroOS) the tools that manage packages or boot files are hidden rather than reimplemented: `/usr` is read-only and the bootloader belongs to the deployment, so `bootc` and `rpm-ostree` own that work. The other 14 Linux tools -- all the diagnostics -- run normally.

- Windows 11 release info: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information
- Windows 10 release info: https://learn.microsoft.com/en-us/windows/release-health/release-information
- Linux kernel releases: https://www.kernel.org/

See [SECURITY.md](SECURITY.md) for version and end-of-life details.

---

## Project layout

The two platforms have separate stacks, because neither one can cross over:
WinUI 3 does not run on Linux, and PowerShell 7 is not installed on a Linux
machine until someone installs it -- a poor first step for a tool you reach for
*because* something is broken.

| Path | Stack | Covers |
|------|-------|--------|
| `src/Windows/CLI/` | PowerShell 7 | Windows terminal tools |
| `src/Windows/GUI/` | C# / WinUI 3 | Windows desktop app |
| `src/Linux/` | Python 3.11+ / GTK4 + libadwaita | Linux terminal menu and desktop app |
| `assets/tools.json` | -- | Shared tool catalogue both stacks read, so the menus cannot drift apart |

Each side owns its platform completely: no `$IsLinux` branches in the
PowerShell, no Windows paths in the Python. Every tool the PowerShell CLI used
to run on Linux is now a Python tool -- all 18 of them, same names, same
behaviour, and the originals remain in this repository's git history.

Adding a tool to Linux means three things: an entry in `assets/tools.json`, a
function in `src/Linux/pchealth/tools/`, and a line in that package's registry.
CI fails if the catalogue lists a tool the registry cannot run. See
[src/Linux/README.md](src/Linux/README.md).

---

## Getting Started

**Requirements:** PowerShell 7+, run as Administrator (Windows) or root/sudo (Linux). Minimum: Windows build 19045 (10 22H2) or Linux kernel 6.0. Build 26200 (11 25H2) is what releases are tested on.

### Windows

**Install the desktop app** — download `pcHealth-<version>-win-x64.msi` (or `-win-arm64`) from [Releases](https://github.com/REALSDEALS/pcHealth/releases) and run it. The build is self-contained: the .NET runtime and the Windows App SDK travel inside it, so nothing has to be installed on the machine first. That matters on a PC you are there to repair.

```powershell
# Unattended, for deployment
msiexec /i pcHealth-2.0.0-win-x64.msi /qn
```

A portable ZIP is published alongside the MSI for running straight off a USB stick — same binaries, no installation.

**Run the CLI from source** — from an elevated PowerShell 7 terminal:

```powershell
.\src\Windows\CLI\Start.ps1
```

### Linux

**Requirements:** Python 3.11+, which every supported distro already ships. Nothing else for the terminal app; the desktop app additionally needs PyGObject, GTK 4 and libadwaita.

1. Download or clone this repository.
2. Run it from `src/Linux`:

```bash
cd src/Linux
python3 -m pchealth          # terminal menu
python3 -m pchealth.gui.app  # desktop app
```

Tools elevate one at a time through `pkexec`, so neither front-end needs to run as root. See [src/Linux/README.md](src/Linux/README.md).

### GUI

On Windows, pcHealth includes a native desktop application built with **WinUI 3** (.NET 10). It provides the same functionality as the CLI in a graphical interface. Minimum: build 19045 (Windows 10 22H2) — the build where WinUI 3 stops rendering. Recommended: build 26200 (Windows 11 25H2).
![Health tab](Health-tab.avif)
![Tools tab](Tools-tab.avif)
![Programs tab](Programs-tab.avif)

A Linux GUI is available separately -- WinUI 3 is Windows-only, so the Linux desktop app is built with GTK4 and libadwaita. See [Project layout](#project-layout).

**Build dependencies:**

| Tool | Install |
|------|---------|
| .NET 10 SDK | `winget install Microsoft.DotNet.SDK.10` |
| Visual Studio 2026 | `winget install Microsoft.VisualStudio.Community` |
| Windows App SDK | Included via NuGet on build |
| WiX v6 | `dotnet tool install --global wix` (only needed to build the MSI) |

**Building the release artifacts** (self-contained app, ZIPs and MSI):

```powershell
pwsh -File development/tools/Build-Release.ps1 -Architecture x64
```

```powershell
dotnet build "src/Windows/GUI/pcHealth/pcHealth.csproj" -c Release
```

Or open `src/Windows/GUI/pcHealth/pcHealth.csproj` in Visual Studio 2026.

---

## Menu Reference

All menus and option numbers are identical across platforms. Windows-only tools are hidden on Linux and vice versa, so numbers remain sequential with no gaps.

<details>
<summary><strong>Main Menu</strong></summary>

| Key | Option                 |
|-----|------------------------|
| 1   | Tools Menu             |
| 2   | Programs Menu          |
| 3   | Go to repository       |
| 4   | Check for pre-releases |
| 5   | Exit                   |

</details>

<details>
<summary><strong>Tools Menu</strong></summary>

Option numbers are assigned sequentially at runtime per platform - Windows-only tools are not shown on Linux and vice versa.

| Function                      | Platforms | Notes                                              |
|-------------------------------|-----------|----------------------------------------------------|
| System Information            | All       | OS, kernel, firmware, TPM, RAM                     |
| Hardware Information          | All       | CPU, GPU, Storage (SMART), RAM, Chipset, sensors   |
| Scan + Repair                 | Windows   | SFC + DISM combined                                |
| Battery Report                | Windows   | Laptop only                                        |
| Windows Update                | Windows   | Opens Windows Update settings                      |
| Disk Optimization             | Windows   | Opens dfrgui.exe                                   |
| Disk Cleanup                  | Windows   | Opens cleanmgr.exe                                 |
| Short Ping Test               | All       | 4-packet ping to 8.8.8.8                           |
| Continuous Ping Test          | All       | Continuous ping, Ctrl+C to stop                    |
| Traceroute to Google          | All       | tracert / traceroute                               |
| Reset Network Stack           | Windows   | DNS flush, Winsock reset, IPv4/IPv6 reset          |
| Update all packages           | Windows   | winget                                             |
| Update all packages           | Linux     | apt / dnf / pacman / zypper                        |
| Topgrade                      | Linux     | Full system upgrade: packages, flatpak, VS Code extensions, helm, uv, and more |
| Battery Report                | Linux     | Laptop only - health, cycles, draw from sysfs      |
| Scan + Repair                 | Linux     | Package integrity vs. package database             |
| Disk Optimization             | Linux     | fstrim on SSDs; Linux needs no defragmenting       |
| Firmware Update               | Linux     | fwupd / LVFS - BIOS, dock, SSD firmware            |
| Boot Repair                   | Linux     | systemd-boot / GRUB / Limine, UEFI - **care**      |
| Disk Cleanup                  | Linux     | Package cache, journal logs, unused Flatpak runtimes, thumbnail cache |
| Restart Audio                 | Linux     | Restarts PipeWire or PulseAudio user services      |
| Reset Network Stack           | Linux     | Restarts NetworkManager, flushes DNS cache         |
| Update HP Drivers             | Windows   | HP Image Assistant (HP devices only)               |
| Restart Audio Drivers         | Windows   | Restarts audio services                            |
| Open Battery Report           | Windows   | Opens previously generated report                  |
| Open CBS Log                  | Windows   | Opens C:\Windows\Logs\CBS\CBS.log                  |
| Get Ninite                    | Windows   | Downloads Edge, Chrome, VLC, 7-Zip                 |
| Windows License Key           | Windows   | OA3 + DigitalProductId registry decode             |
| BIOS Password Recovery        | All       | Links to bios-pw.org - credits: @bacher09          |
| Boot Repair                   | Windows   | CHKDSK + SFC + BCDBOOT, UEFI - **use with care**   |
| Shutdown / Reboot / Log Off   | All       |                                                    |
| Repair Winget                 | Windows   | via winget-install by @asheroto                    |
| View System Logs              | Linux     | journalctl errors/warnings, failed units           |

</details>

<details>
<summary><strong>Programs Menu - Windows</strong></summary>

| Key | Program                  | Install method |
|-----|--------------------------|----------------|
| 1   | HWiNFO64                 | winget         |
| 2   | HWMonitor                | winget         |
| 3   | Malwarebytes AdwCleaner  | winget         |
| 4   | CrystalDiskInfo          | winget         |
| 5   | CrystalDiskMark          | winget         |
| 6   | Prime95                  | winget         |
| 7   | Windows PowerToys        | winget         |

</details>

<details>
<summary><strong>Programs Menu - Linux</strong></summary>

Installed packages are marked `[installed]` in the menu.

| Key | Program       | Install method              |
|-----|---------------|-----------------------------|
| 1   | htop          | apt / dnf / pacman / zypper |
| 2   | iotop         | apt / dnf / pacman / zypper |
| 3   | smartmontools | apt / dnf / pacman / zypper |
| 4   | stress-ng     | apt / dnf / pacman / zypper |
| 5   | nmap          | apt / dnf / pacman / zypper |

</details>

---

## Contributing

Contributions are welcome. Follow the conventions of the stack you are in.

- A new tool starts as an entry in `assets/tools.json`, the catalogue both sides read.
- **Windows:** `Verb-Noun.ps1` in `src/Windows/CLI/tools/`, registered in `src/Windows/CLI/menus/Tools.ps1`, using `Write-PcOption` / `Set-PcTheme` for UI.
- **Linux:** a function in `src/Linux/pchealth/tools/`, registered in that package's `REGISTRY`. Emit through the `ToolContext` so the tool works in both the terminal and the GTK app.
- Open an issue before starting larger changes to avoid duplicate work.

See [SECURITY.md](SECURITY.md) for responsible disclosure of vulnerabilities.

---

## Contact

Questions or feedback? Reach out on Discord: **REALSDEALS**

Or open an [issue](https://github.com/REALSDEALS/pcHealth/issues) on GitHub.

---

*Licensed under [GNU GPL v3](LICENSE). You are free to use this project, but you may not remove the attribution or re-license it.*

---

## Inspired by

This repository consolidates and replaces several earlier pcHealth-related projects. `pcHealth` is the original project and is now the canonical repository: related repositories have been migrated back into this repo and are considered deprecated. Functionality from the listed projects has been merged here where appropriate.

- [pcHealth](https://github.com/REALSDEALS/pcHealth) - original project (batch-based)
- [pcHealthPlus](https://github.com/REALSDEALS/pcHealthPlus) - PowerShell-based toolkit (deprecated; migrated)
- [pcHealthPlus-VS](https://github.com/REALSDEALS/pcHealthPlus-VS) - Visual Studio variant (deprecated; migrated)
- [pcHealth-GUI](https://github.com/iRepairzone-NL/pcHealth_GUI) - Python GUI variant (deprecated; migrated)
- [Win_Scan](https://github.com/REALSDEALS/Win_Scan) - standalone Windows scanning utility (deprecated; migrated)

Where that functionality lives today:

| Predecessor | Now in |
|-------------|--------|
| pcHealth (batch) | `src/Windows/CLI/` -- the menu-driven toolkit, rewritten in PowerShell 7 |
| pcHealthPlus, pcHealthPlus-VS | `src/Windows/CLI/tools/` -- the individual repair and reporting tools |
| pcHealth-GUI (Python) | `src/Linux/pchealth/gui/` -- the Python GUI lineage continues on Linux with GTK4 |
| Win_Scan | `src/Windows/CLI/tools/Invoke-ScanAndRepair.ps1` -- SFC and DISM in one pass |

Nothing from those projects has been dropped on the way in. Where a tool was
replaced by a better one, the replacement covers the same job -- and the
history of every migration is in this repository's git log.

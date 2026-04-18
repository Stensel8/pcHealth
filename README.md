# pcHealth

Check the health of your Windows or Linux installation, drivers, updates, battery health and much more!

![License](https://img.shields.io/github/license/REALSDEALS/pcHealth?label=License)
![Latest Release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?label=Release)
![Pre-release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?include_prereleases&label=Pre-release)
![Repo Size](https://img.shields.io/github/repo-size/REALSDEALS/pcHealth?label=Repo%20Size)

---

## Overview

![Preview](Preview.avif)

pcHealth is a cross-platform toolkit for IT technicians and power users. It runs on **Windows and Linux** using a single PowerShell 7 codebase. The goal is to offer the same functionality everywhere: tools are shown or hidden based on the detected OS, and platform-specific actions (like updating packages) automatically use the right method for the current system.

---

## Supported Platforms

| Platform | CLI | GUI | Min. version        |
|----------|-----|-----|---------------------|
| Windows  | ✅  | ✅ | Build 26200 (25H2+) |
| Linux    | ✅  | ✅ | Kernel 7.0          |

See [SECURITY.md](SECURITY.md) for version and end-of-life details.

---

## Getting Started

**Requirements:** PowerShell 7+, run as Administrator (Windows) or root/sudo (Linux). Minimum Windows build 26200 (25H2) / Linux kernel 7.0.

### Windows

1. Download or clone this repository.
2. Run `start.ps1` — it checks for PowerShell 7, installs it via winget if needed, then launches the CLI elevated.

```powershell
.\start.ps1
```

Or launch directly from an elevated PowerShell 7 terminal:

```powershell
.\src\CLI\Start.ps1
```

### Linux

1. Download or clone this repository.
2. Run `start.sh` — it checks for PowerShell 7, installs it for your distro if needed, then launches the CLI via sudo.

```bash
bash start.sh
```

Or launch directly if PowerShell 7 is already installed:

```bash
sudo pwsh ./src/CLI/Start.ps1
```

### GUI

On Windows, pcHealth includes a native desktop application built with **WinUI 3** (.NET 10). It provides the same functionality as the CLI in a graphical interface and requires Windows build 26200 (25H2) or higher.

A Linux GUI is not yet available — WinUI 3 is Windows-only. A cross-platform alternative is in the works.

**Build dependencies:**

| Tool | Install |
|------|---------|
| .NET 10 SDK | `winget install Microsoft.DotNet.SDK.10` |
| Visual Studio 2026 | `winget install Microsoft.VisualStudio.Community` |
| Windows App SDK | Included via NuGet on build |

```powershell
dotnet build "src/GUI/pcHealth/pcHealth.csproj" -c Release
```

Or open `src/GUI/pcHealth/pcHealth.csproj` in Visual Studio 2026.

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

Option numbers are assigned sequentially at runtime per platform — Windows-only tools are not shown on Linux and vice versa.

| Function                      | Platforms | Notes                                              |
|-------------------------------|-----------|----------------------------------------------------|
| System Information            | All       | OS, kernel, firmware, TPM, RAM                     |
| Hardware Information          | All       | CPU, GPU, Storage (SMART), RAM, Chipset            |
| Scan + Repair                 | Windows   | SFC + DISM combined                                |
| Battery Report                | Windows   | Laptop only                                        |
| Windows Update                | Windows   | Opens Windows Update settings                      |
| Disk Optimization             | Windows   | Opens dfrgui.exe                                   |
| Disk Cleanup                  | Windows   | Opens cleanmgr.exe                                 |
| Short Ping Test               | All       | 4-packet ping to 8.8.8.8                           |
| Continuous Ping Test          | All       | Continuous ping, Ctrl+C to stop                    |
| Traceroute to Google          | All       | tracert / traceroute                               |
| Reset Network Stack           | Windows   | DNS flush, Winsock reset, IPv4/IPv6 reset          |
| Update System Programs        | All       | winget (Windows) / distro package manager (Linux)  |
| Update HP Drivers             | Windows   | HP Image Assistant (HP devices only)               |
| Restart Audio Drivers         | Windows   | Restarts audio services                            |
| Open Battery Report           | Windows   | Opens previously generated report                  |
| Open CBS Log                  | Windows   | Opens C:\Windows\Logs\CBS\CBS.log                  |
| Get Ninite                    | Windows   | Downloads Edge, Chrome, VLC, 7-Zip                 |
| Windows License Key           | Windows   | OA3 + DigitalProductId registry decode             |
| BIOS Password Recovery        | All       | Links to bios-pw.org - credits: @bacher09          |
| Repair Boot Record            | Windows   | CHKDSK + SFC + BOOTREC - **use with caution**      |
| Shutdown / Reboot / Log Off   | All       |                                                    |
| Repair Winget                 | Windows   | via winget-install by @asheroto                    |
| Update Packages               | Linux     | cachy-update / apt / dnf / pacman / zypper         |
| View System Logs              | Linux     | journalctl errors/warnings                         |

</details>

<details>
<summary><strong>Programs Menu — Windows</strong></summary>

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
<summary><strong>Programs Menu — Linux</strong></summary>

| Key | Program       | Install method     |
|-----|---------------|--------------------|
| 1   | htop          | apt / dnf / pacman |
| 2   | iotop         | apt / dnf / pacman |
| 3   | smartmontools | apt / dnf / pacman |
| 4   | stress-ng     | apt / dnf / pacman |
| 5   | nmap          | apt / dnf / pacman |

</details>

---

## Contributing

Contributions are welcome. Follow the existing naming conventions: `Verb-Noun.ps1` for tools, consistent `Write-PcOption` / `Set-PcTheme` calls for UI.

- New tool scripts go in `src/CLI/tools/` and must be registered in `src/CLI/menus/Tools.ps1` with appropriate `Platforms` tags.
- Linux-only tools go in `src/CLI/tools/linux/`.
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

pcHealth consolidates and replaces the following earlier projects:

- [pcHealthPlus](https://github.com/REALSDEALS/pcHealthPlus) — original batch-based health toolkit
- [pcHealthPlus-VS](https://github.com/REALSDEALS/pcHealthPlus-VS) — Visual Studio variant of pcHealthPlus
- [Win_Scan](https://github.com/REALSDEALS/Win_Scan) — standalone Windows scanning utility

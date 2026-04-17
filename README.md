# pcHealth

Check the health of your Windows or Linux installation, drivers, updates, battery health and much more!

![License](https://img.shields.io/github/license/REALSDEALS/pcHealth?label=License)
![Latest Release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?label=Release)
![Pre-release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?include_prereleases&label=Pre-release)
![Repo Size](https://img.shields.io/github/repo-size/REALSDEALS/pcHealth?label=Repo%20Size)

---

## Overview

pcHealth is a CLI toolkit for IT technicians and power users to quickly diagnose and repair Windows and Linux systems. It provides system scans, hardware information, network tools, license key retrieval, common program downloads, and more — all from a single menu-driven interface.

The project targets **feature parity across all supported platforms**, with the same option numbers and functionality on every OS. All platforms share a common codebase under `Shared/CLI/`; platform-specific folders contain only thin launchers.

---

## Supported Platforms

| Platform    | Status                  |
|-------------|-------------------------|
| Windows 11  | ✅ Actively maintained   |
| Windows 10  | ✅ Actively maintained   |
| Linux       | ✅ Actively maintained   |

See [SECURITY.md](SECURITY.md) for version and end-of-life details.

---

## Getting Started

**Requirements:** PowerShell 7+, run as Administrator (Windows) or root/sudo (Linux).

### Windows 11 / Windows 10 — CLI

1. Download or clone this repository.
2. Navigate to the platform folder (`Windows 11/CLI/` or `Windows 10/CLI/`).
3. Right-click `Start.ps1` → **Run with PowerShell**, or from an elevated terminal:

```powershell
.\Start.ps1
```

The launcher will prompt for elevation automatically if not already running as Administrator.

### Linux — CLI

1. Download or clone this repository.
2. Install PowerShell 7: [https://aka.ms/powershell](https://aka.ms/powershell)
3. Navigate to `Linux/CLI/` and run:

```bash
sudo pwsh ./Start.ps1
```

### Windows 11 — GUI

The GUI app is a WinUI 3 desktop application that mirrors the full CLI menu in a native Windows 11 interface.

**Build dependencies:**

| Tool | winget install command |
|------|------------------------|
| .NET 10 SDK | `winget install Microsoft.DotNet.SDK.10` |
| Visual Studio 2022 (recommended) | `winget install Microsoft.VisualStudio.2022.Community` |

```powershell
dotnet build "Windows 11/GUI/pcHealth/pcHealth.csproj" -c Release
```

---

## Menu Reference

All menus and option numbers are identical across platforms. Platform-specific options are shown or hidden automatically based on the detected OS.

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

Options are numbered sequentially per platform — Windows-only tools are hidden on Linux and vice versa.

| Option | Function                      | Platforms          | Notes                                         |
|--------|-------------------------------|--------------------|-----------------------------------------------|
| —      | System Information            | All                | OS, kernel, firmware, TPM, RAM                |
| —      | Hardware Information          | All                | CPU, GPU, Storage (SMART), RAM, Chipset       |
| —      | System File Scan              | Windows            | SFC /scannow                                  |
| —      | DISM Health Check             | Windows            | CheckHealth + ScanHealth + optional Restore   |
| —      | Scan + Repair                 | Windows            | SFC + DISM combined                           |
| —      | Battery Report                | Windows            | Laptop only                                   |
| —      | Windows Update                | Windows            | Opens Windows Update settings                 |
| —      | Disk Optimization             | Windows            | Opens dfrgui.exe                              |
| —      | Disk Cleanup                  | Windows            | Opens cleanmgr.exe                            |
| —      | Short Ping Test               | All                | 4-packet ping to 8.8.8.8                      |
| —      | Continuous Ping Test          | All                | Continuous ping, Ctrl+C to stop               |
| —      | Traceroute to Google          | All                | tracert / traceroute                          |
| —      | Reset Network Stack           | Windows            | DNS flush, Winsock reset, IPv4/IPv6 reset     |
| —      | Update System Programs        | Windows            | winget upgrade --all                          |
| —      | Update HP Drivers             | Windows            | HP Image Assistant (HP devices only)          |
| —      | Restart Audio Drivers         | Windows            | Restarts audio services                       |
| —      | Open Battery Report           | Windows            | Opens previously generated report             |
| —      | Open CBS Log                  | Windows            | Opens C:\Windows\Logs\CBS\CBS.log             |
| —      | Get Ninite                    | Windows            | Downloads Edge, Chrome, VLC, 7-Zip            |
| —      | Windows License Key           | Windows            | OA3 + DigitalProductId registry decode        |
| —      | BIOS Password Recovery        | All                | Links to bios-pw.org — credits: @bacher09    |
| —      | Repair Boot Record            | Windows            | CHKDSK + SFC + BOOTREC — **use with caution** |
| —      | Shutdown / Reboot / Log Off   | All                |                                               |
| —      | Repair Winget                 | Windows            | via winget-install by @asheroto               |
| —      | Update Packages               | Linux              | apt / dnf / pacman / zypper                   |
| —      | View System Logs              | Linux              | journalctl errors/warnings                    |

</details>

<details>
<summary><strong>Programs Menu — Windows</strong></summary>

| Key | Program                  | Install method |
|-----|--------------------------|----------------|
| 1   | HWiNFO64                 | winget         |
| 2   | HWMonitor                | winget         |
| 3   | Malwarebytes ADW Cleaner | winget         |
| 4   | CrystalDiskInfo          | winget         |
| 5   | CrystalDiskMark          | winget         |
| 6   | Prime95                  | winget         |
| 7   | Windows PowerToys        | winget         |

</details>

<details>
<summary><strong>Programs Menu — Linux</strong></summary>

| Key | Program       | Install method          |
|-----|---------------|-------------------------|
| 1   | htop          | apt / dnf / pacman      |
| 2   | iotop         | apt / dnf / pacman      |
| 3   | smartmontools | apt / dnf / pacman      |
| 4   | stress-ng     | apt / dnf / pacman      |
| 5   | nmap          | apt / dnf / pacman      |

</details>

---

## Repository Structure

```
Shared/CLI/          ← shared core (all platforms load from here)
  Start.ps1          ← platform auto-detection + menu loader
  menus/             ← Helpers, Main, Tools, Programs
  tools/             ← all tool scripts
    linux/           ← Linux-only tools

Windows 10/CLI/      ← thin launcher → Shared/CLI/
Windows 11/CLI/      ← thin launcher → Shared/CLI/
Windows 11/GUI/      ← WinUI 3 desktop app
Linux/CLI/           ← thin launcher → Shared/CLI/
```

---

## Contributing

Contributions are welcome. Follow the existing naming conventions: `Verb-Noun.ps1` for tools, consistent `Write-PcOption` / `Set-PcTheme` calls for UI. New tool scripts go in `Shared/CLI/tools/` and must be registered in `Shared/CLI/menus/Tools.ps1` with appropriate `Platforms` tags. Open an issue before starting larger changes to avoid duplicate work.

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

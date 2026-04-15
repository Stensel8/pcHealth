# pcHealth

Check the health of your Windows or Linux installation, drivers, updates, battery health and much more!

![License](https://img.shields.io/github/license/REALSDEALS/pcHealth?label=License)
![Latest Release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?label=Release)
![Pre-release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?include_prereleases&label=Pre-release)
![Repo Size](https://img.shields.io/github/repo-size/REALSDEALS/pcHealth?label=Repo%20Size)

---

## Overview

![Preview](Preview.avif)

pcHealth is a CLI toolkit for IT technicians and power users to quickly diagnose and repair Windows systems. It provides system scans, hardware information, network tools, license key retrieval, common program downloads, and more, all from a single menu-driven interface.

The project targets **feature parity across all supported platforms**, with the same option numbers and functionality on every OS.

---

## Supported Versions

| Platform   | Target OS | Status                  |
|------------|-----------|-------------------------|
| Windows 11 | 25H2      | ✅ Actively maintained   |
| Windows 10 | 22H2      | ⛔ No longer maintained  |

See [SECURITY.md](SECURITY.md) for full version, build, and end-of-life details.

---

## Getting Started

### Windows 11 — CLI

Requirements: **PowerShell 7+**, run as **Administrator**.

1. Download or clone this repository.
2. Open an elevated PowerShell terminal.
3. Navigate to `Windows 11/CLI/` and run:

```powershell
.\Start.ps1
```

### Windows 11 — GUI

The GUI app is a WinUI 3 desktop application that mirrors the full CLI menu in a native Windows 11 interface. It provides the same Tools and Programs menus as the CLI, with Mica backdrop, dark/light theme support, and in-app display for the Windows License Key tool. All other tools launch in an elevated PowerShell 7 terminal window.

Requirements: **Windows 11** (build 22000+), **PowerShell 7+**, run as **Administrator**.

The app ships self-contained — no separate Windows App SDK runtime installation is required.

**Build dependencies:**

| Tool | winget install command |
|------|------------------------|
| .NET 10 SDK | `winget install Microsoft.DotNet.SDK.10` |
| Visual Studio 2022 (recommended) | `winget install Microsoft.VisualStudio.2022.Community` |

1. Download or clone this repository.
2. Build with Visual Studio 2022 or the .NET CLI:

```powershell
dotnet build "Windows 11/GUI/pcHealth/pcHealth.csproj" -c Release
```

3. Run the produced `pcHealth.exe` as Administrator.

### Windows 10

1. Download or clone this repository.
2. Open `Windows 10/CLI/`, right-click `pcHealth.bat` and select **Run as administrator**.
3. Enter the number of the desired option and press **Enter**.

---

## Menu Reference

All menus and option numbers are identical across platforms. The underlying implementation differs (CMD/Batch on Windows 10, PowerShell 7 on Windows 11) but the user experience is the same.

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
<summary><strong>Tools Menu (27 options)</strong></summary>

| Key | Function                    | Notes                                          |
|-----|-----------------------------|------------------------------------------------|
| 1   | System Information          | `systeminfo` / `Get-ComputerInfo`              |
| 2   | CPU / GPU / RAM Info        |                                                |
| 3   | System File Scan            | SFC `/scannow`                                 |
| 4   | DISM Health Check           | Check + Scan health                            |
| 5   | Scan + Repair               | SFC + DISM combined                            |
| 6   | Battery Report              | Laptop only                                    |
| 7   | Windows Update              | Opens Windows Update                           |
| 8   | Disk Optimization           | Opens `dfrgui.exe`                             |
| 9   | Disk Cleanup                | Opens `cleanmgr.exe`                           |
| 10  | Short Ping Test             | 4-packet ping to 8.8.8.8                       |
| 11  | Continuous Ping Test        | Continuous ping to 8.8.8.8                     |
| 12  | Traceroute to Google        | `tracert www.google.com`                       |
| 13  | Reset Network Stack         | Flushes DNS, resets Winsock                    |
| 14  | Update System Programs      | `winget upgrade --all`                         |
| 15  | Update HP Drivers           | Installs HP Image Assistant (HP devices only)  |
| 16  | Restart Audio Drivers       | Restarts audio services                        |
| 17  | Open Battery Report         | Opens previously generated report              |
| 18  | Open CBS Log                | Opens `C:\Windows\Logs\CBS\CBS.log`            |
| 19  | Get Ninite                  | Downloads Edge, Chrome, VLC, 7-Zip             |
| 20  | Windows License Key         | Reads key from registry                        |
| 21  | BIOS Password Recovery      | Links to bios-pw.org - credits: @bacher09      |
| 22  | Repair Boot Record          | CHKDSK + SFC + BOOTREC - **use with caution**  |
| 23  | Shutdown / Reboot / Log Off |                                                |
| 24  | Repair Winget               | via winget-install by @asheroto                |
| 25  | Programs Menu               |                                                |
| 26  | Back to Main Menu           |                                                |
| 27  | Exit                        |                                                |

</details>

<details>
<summary><strong>Programs Menu (10 options)</strong></summary>

| Key | Program                  | Install method      |
|-----|--------------------------|---------------------|
| 1   | HWiNFO64                 | winget              |
| 2   | HWMonitor                | winget              |
| 3   | Malwarebytes ADW Cleaner | winget              |
| 4   | CrystalDiskInfo          | winget              |
| 5   | CrystalDiskMark          | winget              |
| 6   | Prime95                  | winget              |
| 7   | Windows PowerToys        | winget              |
| 8   | Tools Menu               |                     |
| 9   | Back to Main Menu        |                     |
| 10  | Exit                     |                     |

</details>

---

## Contributing

Contributions are welcome. Follow the existing naming conventions: `Verb-Noun.ps1` for tools, consistent `Write-PcOption` / `Set-PcTheme` calls for UI. New tool scripts go in `Windows 11/CLI/tools/` and must be registered in `menus/Tools.ps1`. Open an issue before starting larger changes to avoid duplicate work.

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

# pcHealth

Check the health of your Windows or Linux installation, drivers, updates, battery health and much more!

![License](https://img.shields.io/github/license/REALSDEALS/pcHealth?label=License)
![Latest Release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?label=Release)
![Pre-release](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?include_prereleases&label=Pre-release)
![Repo Size](https://img.shields.io/github/repo-size/REALSDEALS/pcHealth?label=Repo%20Size)

---

## Overview

pcHealth is a CLI toolkit for IT technicians and power users to quickly diagnose and repair Windows systems. It provides system scans, hardware information, network tools, license key retrieval, common program downloads, and more, all from a single menu-driven interface.

The project targets **feature parity across all supported platforms**. Windows 11 is the actively maintained reference; Windows 10 is kept for legacy use only.

---

## Supported Versions

| Platform   | Variant          | Target OS | Status                          |
|------------|------------------|-----------|---------------------------------|
| Windows 11 | CLI (PowerShell) | 25H2      | ✅ Actively maintained           |
| Windows 10 | CLI (CMD/Batch)  | 22H2      | ⛔ Legacy - no longer maintained |
| Windows 10 | GUI (WinForms)   | 22H2      | ⛔ Legacy - no longer maintained |

> Windows 10 reached end of support on **October 14, 2025**. The `Windows 10/` folder is kept for reference only. See [SECURITY.md](SECURITY.md) for full version and build details.

---

## Getting Started

### Windows 11 - CLI (actively maintained)

Requirements: **PowerShell 7+**, run as **Administrator**.

1. Download or clone this repository.
2. Open an elevated PowerShell terminal (`Run as Administrator`).
3. Navigate to `Windows 11/CLI/` and run:

```powershell
.\Start.ps1
```

### Windows 10 - CLI (legacy, no longer maintained)

> ⚠️ These scripts are no longer actively developed. Use the Windows 11 version where possible.

1. Download or clone this repository.
2. Open `Windows 10/CLI/` and right-click `pcHealth.bat` → **Run as administrator**.
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
<summary><strong>Tools Menu (26 options)</strong></summary>

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
| 24  | Programs Menu               |                                                |
| 25  | Back to Main Menu           |                                                |
| 26  | Exit                        |                                                |

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
| 6   | Prime95                  | Opens download page |
| 7   | Windows PowerToys        | winget              |
| 8   | Tools Menu               |                     |
| 9   | Back to Main Menu        |                     |
| 10  | Exit                     |                     |

</details>

---

## Repository Structure

```
pcHealth/
├── Windows 11/
│   └── CLI/
│       ├── Start.ps1          # Entry point (PS7+, requires admin)
│       ├── menus/             # Main, Tools, Programs, Helpers
│       └── tools/             # One script per function
├── Windows 10/
│   ├── CLI/
│   │   ├── pcHealth.bat       # Monolithic entry point (legacy)
│   │   └── *.ps1              # Helper scripts called by the BAT
│   └── GUI/                   # WinForms application (legacy)
└── Documentation/
    ├── changelog.md
    └── releases.md
```

---

## Contributing

Contributions are welcome for the **Windows 11** platform. The Windows 10 scripts are in maintenance mode and will not receive new features.

- Follow the existing naming conventions: `Verb-Noun.ps1` for tools, consistent `Write-PcOption` / `Set-PcTheme` calls for UI.
- New tool scripts go in `Windows 11/CLI/tools/` and must be registered in `menus/Tools.ps1`.
- New programs go in `menus/Programs.ps1`.
- Open an issue before starting larger changes to avoid duplicate work.
- See [SECURITY.md](SECURITY.md) for responsible disclosure of vulnerabilities.

---

## Contact

Questions or feedback? Reach out on Discord: **REALSDEALS**

Or open an [issue](https://github.com/REALSDEALS/pcHealth/issues) on GitHub.

---

*Licensed under [GNU GPL v3](LICENSE). You are free to use this project, but you may not remove the attribution or re-license it.*

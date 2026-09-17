# Security Policy

## Supported Versions

The table below lists each supported platform, its recommended and hard minimum OS version, and its current support status within this project.

| Platform          | Minimum                        | Recommended                   | Status                 |
|-------------------|--------------------------------|-------------------------------|------------------------|
| Windows (CLI)     | Build 14393 (Windows 10 1607)  | Build 26200 (Windows 11 25H2) | ✅ Actively maintained |
| Windows (GUI)     | Build 19045 (Windows 10 22H2)  | Build 26200 (Windows 11 25H2) | ✅ Actively maintained |
| Linux             | Kernel 7.0                     | —                             | ✅ Actively maintained |

Each minimum is a technical floor, not a preference: PowerShell 7 does not run below Windows 10 1607, and WinUI 3 does not render below 22H2. Below its floor pcHealth exits immediately; above it, builds older than the recommended one are a legacy tier that warns on start and then continues.

Security fixes are shipped for the recommended tier first. The legacy tier is best-effort and untested — Windows 10 22H2 reached end of life in October 2025, so anything below it receives no OS security updates from Microsoft either, and running pcHealth there does not change that. Pre-UEFI systems remain out of scope: Boot Repair detects BIOS/MBR firmware and refuses rather than carrying MBR/CSM repair paths that cannot be tested on any supported target.

- Windows release info: https://learn.microsoft.com/en-us/windows/release-health/release-information
- Windows 11 release info: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information
- Linux kernel releases: https://www.kernel.org/

---

## Future Platform Support

| Platform    | Status      | Notes                                      |
|-------------|-------------|--------------------------------------------|
| Linux (GUI) | Planned     | Targeting parity with the Windows CLI      |

---

## Reporting a Vulnerability

If you discover a security vulnerability in any part of this project (scripts, documentation, or CI):

1. **Do not open a public issue.**
2. Report it privately via the [GitHub Security Advisory](https://github.com/REALSDEALS/pcHealth/security/advisories/new) feature.
3. Include a clear description of the vulnerability, the affected file(s), and steps to reproduce.

We aim to respond within **7 days** and will coordinate a fix and disclosure timeline with the reporter.

---

## Scope

These scripts run with administrator privileges and interact with the OS directly (SFC, DISM, network stack, UEFI boot files). Please treat any issues that could lead to privilege escalation, data loss, or unintended system modification as security-relevant.

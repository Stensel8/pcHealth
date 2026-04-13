# Security Policy

## Supported Versions

The table below lists each supported platform, the OS build it targets, and its current support status within this project.

| Platform   | Target OS | Last Tested Build | Status                        | Project support ends |
|------------|-----------|-------------------|-------------------------------|----------------------|
| Windows 11 | 25H2      | 26200.8037        | ✅ Actively maintained        | n/a                  |
| Windows 10 | 22H2      | 19045.x           | ⛔ No longer maintained       | October 14, 2025     |

> **Windows 10 reached end of support on October 14, 2025.**
> Microsoft no longer releases feature updates for Windows 10. The `Windows 10/` folder in this repository is kept for reference only. No new features, bug fixes, or security patches will be backported to it.

> **Windows 11** scripts target the current stable branch (25H2) and are validated against build **26200.8037**. Builds older than 22H2 are not tested and may not function correctly.

---

## Future Platform Support

| Platform | Status      | Notes                                      |
|----------|-------------|--------------------------------------------|
| Linux    | Planned     | Targeting parity with the Windows 11 CLI   |

---

## Reporting a Vulnerability

If you discover a security vulnerability in any part of this project (scripts, documentation, or CI):

1. **Do not open a public issue.**
2. Report it privately via the [GitHub Security Advisory](https://github.com/REALSDEALS/pcHealth/security/advisories/new) feature.
3. Include a clear description of the vulnerability, the affected file(s), and steps to reproduce.

We aim to respond within **7 days** and will coordinate a fix and disclosure timeline with the reporter.

---

## Scope

These scripts run with administrator privileges and interact with the OS directly (SFC, DISM, network stack, boot record). Please treat any issues that could lead to privilege escalation, data loss, or unintended system modification as security-relevant.

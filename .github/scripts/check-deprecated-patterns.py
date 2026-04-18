#!/usr/bin/env python3
"""
Scan the repository for deprecated, unsafe, or discouraged patterns and
emit a SARIF 2.1.0 file. Results appear in GitHub Advanced Security →
Code scanning. Never blocks CI — findings are warnings/notes only.
"""
import json
import subprocess
from pathlib import Path

AGENTS_MD_URI = "https://github.com/REALSDEALS/pcHealth/blob/main/AGENTS.md"

RULES = [
    # ════════════════════════════════════════════════════════════════════
    # C# / WinUI 3  (src/GUI/)
    # ════════════════════════════════════════════════════════════════════

    # ── Legacy WMI ──────────────────────────────────────────────────────
    {
        "id": "CS001",
        "name": "LegacySystemManagement",
        "short": "System.Management import — use Microsoft.Management.Infrastructure (CIM) instead",
        "help": "System.Management uses DCOM — slow and discouraged in modern .NET. "
                "Replace with CimSession.QueryInstances() from Microsoft.Management.Infrastructure.",
        "patterns": [r"using\s+System\.Management[^.]"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "warning",
    },
    {
        "id": "CS002",
        "name": "ManagementObjectSearcher",
        "short": "ManagementObjectSearcher / ManagementObject — use CIM instead",
        "help": "Replace with CimSession.QueryInstances() from Microsoft.Management.Infrastructure.",
        "patterns": [r"ManagementObjectSearcher", r"new\s+ManagementObject\b"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "warning",
    },

    # ── Exception handling ───────────────────────────────────────────────
    {
        "id": "CS003",
        "name": "EmptyCatchBlock",
        "short": "Empty catch block swallows exceptions silently",
        "help": "Always log or surface exceptions — never swallow silently. "
                "Use catch (SpecificException ex) { Debug.WriteLine(ex); }.",
        "patterns": [r"^\s*catch\s*\{", r"^\s*catch\s*$"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "error",
    },
    {
        "id": "CS004",
        "name": "BareCatchException",
        "short": "Bare catch(Exception) — catch a specific exception type instead",
        "help": "Use IOException, UnauthorizedAccessException, COMException, etc. "
                "Overly broad catches mask real bugs.",
        "patterns": [r"catch\s*\(\s*Exception\s*\)"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "warning",
    },
    {
        "id": "CS005",
        "name": "ThrowBareException",
        "short": "throw new Exception(...) — throw a specific exception type instead",
        "help": "Use InvalidOperationException, ArgumentException, IOException, etc. "
                "Bare Exception gives callers no useful type to catch.",
        "patterns": [r"throw\s+new\s+Exception\("],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "warning",
    },

    # ── Path handling ────────────────────────────────────────────────────
    {
        "id": "CS006",
        "name": "RawPathConcatenation",
        "short": "Raw backslash path concatenation — use Path.Combine instead",
        "help": r'Replace dir + "\\" + file with Path.Combine(dir, file). '
                "Path.Combine handles separators correctly on all platforms.",
        "patterns": [r'\+\s*"\\\\"', r'\+\s*@"\\"'],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "warning",
    },
    {
        "id": "CS007",
        "name": "HardcodedDrivePath",
        "short": "Hardcoded drive-root path (C:\\, D:\\) — use AppContext.BaseDirectory or Environment",
        "help": "Hardcoded drive paths break on machines with different layouts. "
                "Use AppContext.BaseDirectory, Environment.GetFolderPath, or Path.Combine.",
        "patterns": [r'@"[A-Za-z]:\\', r'"[A-Za-z]:\\\\\\\\"'],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "warning",
    },

    # ── Async / threading ────────────────────────────────────────────────
    {
        "id": "CS008",
        "name": "SyncOverAsync",
        "short": ".Wait() / .GetAwaiter().GetResult() causes deadlock on UI thread",
        "help": "In WinUI 3, blocking the UI thread with .Wait() or .GetAwaiter().GetResult() "
                "deadlocks the app. Use await instead.",
        "patterns": [r"\.Wait\(\)", r"\.GetAwaiter\(\)\.GetResult\(\)"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "error",
    },
    {
        "id": "CS009",
        "name": "ThreadSleep",
        "short": "Thread.Sleep blocks the thread — use await Task.Delay instead",
        "help": "Thread.Sleep blocks the calling thread (including the UI thread). "
                "Use await Task.Delay(ms) in async methods.",
        "patterns": [r"Thread\.Sleep\("],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "warning",
    },
    {
        "id": "CS010",
        "name": "RawThreadCreation",
        "short": "new Thread(...) — use Task.Run or ThreadPool instead",
        "help": "Raw Thread allocation bypasses the thread pool and is harder to manage. "
                "Prefer Task.Run for CPU-bound work.",
        "patterns": [r"new\s+Thread\("],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "note",
    },

    # ── Memory / resources ───────────────────────────────────────────────
    {
        "id": "CS011",
        "name": "ManualGcCollect",
        "short": "GC.Collect() — manual GC is almost always wrong",
        "help": "GC.Collect() disrupts the GC's own heuristics and hurts throughput. "
                "Fix the allocation pattern instead of forcing collection.",
        "patterns": [r"GC\.Collect\("],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "warning",
    },

    # ── Output / logging ─────────────────────────────────────────────────
    {
        "id": "CS012",
        "name": "ConsoleWriteInGui",
        "short": "Console.Write/WriteLine in GUI code — use Debug.WriteLine or a logger",
        "help": "WinUI 3 apps have no console window by default. "
                "Console output is silently dropped. Use Debug.WriteLine or structured logging.",
        "patterns": [r"Console\.Write(Line)?\("],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "warning",
    },

    # ── Time ─────────────────────────────────────────────────────────────
    {
        "id": "CS013",
        "name": "DateTimeNow",
        "short": "DateTime.Now includes local timezone offset — use DateTime.UtcNow for timestamps",
        "help": "DateTime.Now is fine for UI display but wrong for logging, sorting, or storage. "
                "Use DateTime.UtcNow or DateTimeOffset.UtcNow for timestamps.",
        "patterns": [r"DateTime\.Now\b"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "note",
    },

    # ── WinUI 3 / UWP namespace issues ───────────────────────────────────
    {
        "id": "CS014",
        "name": "OldUwpXamlNamespace",
        "short": "Windows.UI.Xaml namespace — WinUI 3 uses Microsoft.UI.Xaml",
        "help": "Windows.UI.Xaml is the UWP namespace. WinUI 3 apps must use "
                "Microsoft.UI.Xaml. Mixing them causes runtime failures.",
        "patterns": [r"Windows\.UI\.Xaml"],
        "globs": ["*.cs", "*.xaml"],
        "exclude_globs": ["obj/**"],
        "severity": "error",
    },
    {
        "id": "CS015",
        "name": "DeprecatedApplicationView",
        "short": "ApplicationView is a deprecated UWP API — not supported in WinUI 3",
        "help": "Use AppWindow (Microsoft.UI.Windowing.AppWindow) for window management in WinUI 3.",
        "patterns": [r"\bApplicationView\b"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "error",
    },
    {
        "id": "CS016",
        "name": "DeprecatedCoreWindow",
        "short": "CoreWindow is a deprecated UWP API — not supported in WinUI 3",
        "help": "CoreWindow does not exist in WinUI 3 Desktop. "
                "Use Microsoft.UI.Xaml.Window or AppWindow instead.",
        "patterns": [r"\bCoreWindow\b"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "error",
    },
    {
        "id": "CS017",
        "name": "DeprecatedDispatcherRunAsync",
        "short": "Dispatcher.RunAsync is UWP — use DispatcherQueue.TryEnqueue in WinUI 3",
        "help": "CoreDispatcher.RunAsync is the UWP API. "
                "In WinUI 3 use DispatcherQueue.TryEnqueue or DispatcherQueue.GetForCurrentThread().",
        "patterns": [r"Dispatcher\.RunAsync\("],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "error",
    },

    # ── Code quality ─────────────────────────────────────────────────────
    {
        "id": "CS018",
        "name": "PragmaWarningDisable",
        "short": "#pragma warning disable suppresses compiler diagnostics",
        "help": "Suppressing warnings hides real problems. Fix the underlying issue instead. "
                "If the suppress is intentional, add a comment explaining why.",
        "patterns": [r"#pragma\s+warning\s+disable"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "note",
    },
    {
        "id": "CS019",
        "name": "DynamicKeyword",
        "short": "dynamic keyword bypasses static type checking",
        "help": "dynamic disables compile-time type safety. "
                "Use specific types, generics, or pattern matching instead.",
        "patterns": [r"\bdynamic\b"],
        "globs": ["*.cs"],
        "exclude_globs": ["obj/**"],
        "severity": "note",
    },

    # ════════════════════════════════════════════════════════════════════
    # PowerShell 7  (src/CLI/)
    # ════════════════════════════════════════════════════════════════════

    # ── Removed / deprecated cmdlets ─────────────────────────────────────
    {
        "id": "PS001",
        "name": "GetWmiObject",
        "short": "Get-WmiObject removed in PowerShell 6+ — use Get-CimInstance",
        "help": "WMI over DCOM is removed from PowerShell 6+. "
                "Replace with Get-CimInstance.",
        "patterns": [r"\bGet-WmiObject\b"],
        "globs": ["*.ps1"],
        "exclude_globs": [],
        "case_insensitive": True,
        "severity": "error",
    },
    {
        "id": "PS002",
        "name": "WmicExe",
        "short": "wmic.exe removed in Windows 11 25H2 — use Get-CimInstance",
        "help": "wmic.exe is removed in Windows 11 25H2. "
                "Replace with Get-CimInstance queries.",
        "patterns": [r"\bwmic\b"],
        "globs": ["*.ps1", "*.sh"],
        "exclude_globs": [],
        "case_insensitive": True,
        "severity": "error",
    },

    # ── Code execution / injection ────────────────────────────────────────
    {
        "id": "PS003",
        "name": "InvokeExpression",
        "short": "Invoke-Expression / iex — use explicit script blocks instead",
        "help": "Invoke-Expression executes arbitrary strings and is hard to audit. "
                "Use explicit script blocks or direct calls.",
        "patterns": [r"Invoke-Expression", r"\biex\b"],
        "globs": ["*.ps1"],
        "exclude_globs": [],
        "severity": "error",
    },

    # ── Error handling ────────────────────────────────────────────────────
    {
        "id": "PS004",
        "name": "GlobalErrorActionPreference",
        "short": "Global $ErrorActionPreference = SilentlyContinue hides real errors",
        "help": "Use -ErrorAction SilentlyContinue per cmdlet instead of setting globally. "
                "Global silencing masks failures in unrelated code.",
        "patterns": [r"\$ErrorActionPreference\s*=\s*[\"']SilentlyContinue[\"']"],
        "globs": ["*.ps1"],
        "exclude_globs": [],
        "severity": "warning",
    },
    {
        "id": "PS005",
        "name": "SetStrictModeOff",
        "short": "Set-StrictMode -Off disables undefined-variable detection",
        "help": "Set-StrictMode -Off removes safety checks that catch typos and "
                "uninitialized variables. Only disable with a documented reason.",
        "patterns": [r"Set-StrictMode\s+-Off"],
        "globs": ["*.ps1"],
        "exclude_globs": [],
        "case_insensitive": True,
        "severity": "warning",
    },

    # ── Output / pipeline ─────────────────────────────────────────────────
    {
        "id": "PS006",
        "name": "WriteHostForData",
        "short": "Write-Host bypasses the PowerShell pipeline",
        "help": "Use Write-Output or return for data. "
                "Write-Host is for user-facing display text only.",
        "patterns": [r"\bWrite-Host\b"],
        "globs": ["*.ps1"],
        "exclude_globs": [],
        "severity": "note",
    },

    # ── Networking / HTTP ─────────────────────────────────────────────────
    {
        "id": "PS007",
        "name": "LegacyWebClient",
        "short": "[System.Net.WebClient] is deprecated — use Invoke-RestMethod or Invoke-WebRequest",
        "help": "WebClient is a legacy .NET class. "
                "Use Invoke-RestMethod (for JSON/XML APIs) or Invoke-WebRequest for HTTP in PowerShell.",
        "patterns": [r"\[System\.Net\.WebClient\]"],
        "globs": ["*.ps1"],
        "exclude_globs": [],
        "severity": "warning",
    },

    # ── Credentials ───────────────────────────────────────────────────────
    {
        "id": "PS008",
        "name": "PlaintextSecureString",
        "short": "ConvertTo-SecureString -AsPlainText stores a credential in plain text",
        "help": "Passing -AsPlainText means the password is visible in the script and process list. "
                "Use Get-Credential, a secrets vault, or environment variables instead.",
        "patterns": [r"ConvertTo-SecureString.{0,80}-AsPlainText", r"-AsPlainText.{0,80}ConvertTo-SecureString"],
        "globs": ["*.ps1"],
        "exclude_globs": [],
        "severity": "warning",
    },

    # ── Process management ────────────────────────────────────────────────
    {
        "id": "PS009",
        "name": "StartProcessWait",
        "short": "Start-Process -Wait without a timeout can hang indefinitely",
        "help": "If the spawned process never exits, the script hangs forever. "
                "Consider a timeout loop or WaitForExit(milliseconds) via the .NET Process API.",
        "patterns": [r"Start-Process\b.{0,120}-Wait\b"],
        "globs": ["*.ps1"],
        "exclude_globs": [],
        "case_insensitive": True,
        "severity": "note",
    },

    # ════════════════════════════════════════════════════════════════════
    # Bash  (src/CLI/)
    # ════════════════════════════════════════════════════════════════════

    {
        "id": "SH001",
        "name": "SingleBracketTest",
        "short": "Single-bracket [ ] — use [[ ]] for safety and regex support",
        "help": "Double brackets [[ ]] are safer and support regex matching in Bash.",
        "patterns": [r"^\s*\[ "],
        "globs": ["*.sh"],
        "exclude_globs": [],
        "severity": "warning",
    },
    {
        "id": "SH002",
        "name": "EvalInBash",
        "short": "eval executes arbitrary strings — same risk as Invoke-Expression",
        "help": "eval is a common injection vector. Use explicit commands or "
                "arrays instead of building strings to evaluate.",
        "patterns": [r"\beval\b"],
        "globs": ["*.sh"],
        "exclude_globs": [],
        "severity": "error",
    },
    {
        "id": "SH003",
        "name": "CurlPipeShell",
        "short": "curl | bash / curl | sh — pipe-to-shell executes untrusted remote code",
        "help": "Piping curl output directly to a shell executes whatever the server returns. "
                "Download to a file, verify integrity, then execute.",
        "patterns": [r"curl.{0,80}\|\s*(ba)?sh\b"],
        "globs": ["*.sh"],
        "exclude_globs": [],
        "severity": "error",
    },
    {
        "id": "SH004",
        "name": "Chmod777",
        "short": "chmod 777 grants world-writable permissions",
        "help": "World-writable files/directories are a security risk. "
                "Use the minimum required permissions (e.g. 755 for executables, 644 for files).",
        "patterns": [r"chmod\s+777\b"],
        "globs": ["*.sh"],
        "exclude_globs": [],
        "severity": "warning",
    },
]


def run_rg(patterns: list[str], globs: list[str], exclude_globs: list[str],
           case_insensitive: bool = False) -> list[dict]:
    cmd = ["rg", "--line-number", "--column", "--no-heading", "--color=never"]
    if case_insensitive:
        cmd.append("--ignore-case")
    for g in globs:
        cmd += ["--glob", g]
    for g in exclude_globs:
        cmd += ["--glob", f"!{g}"]
    for p in patterns:
        cmd += ["-e", p]
    cmd.append(".")

    proc = subprocess.run(cmd, capture_output=True, text=True)
    matches = []
    for line in proc.stdout.splitlines():
        parts = line.split(":", 3)
        if len(parts) >= 3:
            try:
                matches.append({
                    "file": parts[0],
                    "line": int(parts[1]),
                    "column": int(parts[2]) if len(parts) > 3 else 1,
                    "text": parts[3].strip() if len(parts) > 3 else "",
                })
            except ValueError:
                pass
    return matches


def sarif_level(severity: str) -> str:
    return {"error": "error", "warning": "warning"}.get(severity, "note")


def build_sarif(rules_with_matches: list[tuple[dict, list[dict]]]) -> dict:
    sarif_rules = []
    sarif_results = []

    for rule, matches in rules_with_matches:
        sarif_rules.append({
            "id": rule["id"],
            "name": rule["name"],
            "shortDescription": {"text": rule["short"]},
            "fullDescription": {"text": rule["help"]},
            "defaultConfiguration": {"level": sarif_level(rule["severity"])},
            "helpUri": AGENTS_MD_URI,
            "properties": {"tags": ["deprecated", "maintainability"]},
        })

        for m in matches:
            uri = m["file"].replace("\\", "/").lstrip("./")
            sarif_results.append({
                "ruleId": rule["id"],
                "level": sarif_level(rule["severity"]),
                "message": {"text": rule["short"]},
                "locations": [{
                    "physicalLocation": {
                        "artifactLocation": {
                            "uri": uri,
                            "uriBaseId": "%SRCROOT%",
                        },
                        "region": {
                            "startLine": m["line"],
                            "startColumn": m["column"],
                        },
                    }
                }],
            })

    return {
        "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
        "version": "2.1.0",
        "runs": [{
            "tool": {
                "driver": {
                    "name": "deprecated-patterns",
                    "version": "1.0.0",
                    "informationUri": AGENTS_MD_URI,
                    "rules": sarif_rules,
                }
            },
            "results": sarif_results,
        }],
    }


def main() -> None:
    rules_with_matches = []
    total = 0

    for rule in RULES:
        matches = run_rg(
            rule["patterns"],
            rule["globs"],
            rule.get("exclude_globs", []),
            rule.get("case_insensitive", False),
        )
        rules_with_matches.append((rule, matches))
        if matches:
            print(f"[{rule['id']}] {rule['short']}: {len(matches)} match(es)")
            for m in matches:
                print(f"  {m['file']}:{m['line']} — {m['text']}")
        total += len(matches)

    sarif = build_sarif(rules_with_matches)
    out = Path("deprecated-patterns.sarif")
    out.write_text(json.dumps(sarif, indent=2))
    print(f"\n{total} deprecated pattern(s) found. SARIF → {out}")


if __name__ == "__main__":
    main()

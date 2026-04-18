#!/usr/bin/env python3
"""
Scan source files for deprecated/unsafe patterns and emit SARIF 2.1.0.
No external dependencies — stdlib only.
"""
import json
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Pattern definitions
# Each entry: (rule_id, level, message, file_glob, regex_pattern)
# level: "error" | "warning" | "note"
# ---------------------------------------------------------------------------
RULES = [
    # ── C# — Legacy WMI ────────────────────────────────────────────────────
    (
        "CS001", "warning",
        "ManagementObjectSearcher uses DCOM (legacy WMI). Replace with CimSession.QueryInstances() from Microsoft.Management.Infrastructure.",
        "*.cs",
        r"new\s+ManagementObjectSearcher\s*\(",
    ),
    (
        "CS001B", "warning",
        "System.Management import uses DCOM. Replace with Microsoft.Management.Infrastructure (CIM/WSMan).",
        "*.cs",
        r"using\s+System\.Management[^.]",
    ),
    # ── C# — Exception handling ─────────────────────────────────────────────
    (
        "CS003", "error",
        "Empty catch block swallows exceptions silently. Log or surface: catch (SpecificException ex) { Debug.WriteLine(ex); }",
        "*.cs",
        r"^\s*catch\s*\{",
    ),
    (
        "CS005", "warning",
        "throw new Exception(...) — use a specific type (InvalidOperationException, ArgumentException, IOException, etc.).",
        "*.cs",
        r"\bthrow\s+new\s+Exception\s*\(",
    ),
    # ── C# — Path handling ──────────────────────────────────────────────────
    (
        "CS006", "warning",
        "Raw backslash path concatenation. Use Path.Combine(dir, file) instead.",
        "*.cs",
        r'\+\s*"\\\\',
    ),
    (
        "CS007", "warning",
        r'Hardcoded drive-root path (e.g. C:\). Use AppContext.BaseDirectory, Environment.GetFolderPath, or Path.Combine.',
        "*.cs",
        r'@"[A-Za-z]:\\',
    ),
    # ── C# — Async / threading ──────────────────────────────────────────────
    (
        "CS008", "error",
        ".Wait() blocks the calling thread and deadlocks the WinUI 3 UI thread. Use await instead.",
        "*.cs",
        r"\.\s*Wait\s*\(\s*\)",
    ),
    (
        "CS008B", "error",
        ".GetAwaiter().GetResult() is sync-over-async and deadlocks the UI thread. Use await instead.",
        "*.cs",
        r"\.GetAwaiter\s*\(\s*\)\s*\.GetResult\s*\(\s*\)",
    ),
    (
        "CS009", "warning",
        "Thread.Sleep blocks the thread (including the UI thread). Use await Task.Delay(ms) in async methods.",
        "*.cs",
        r"\bThread\s*\.\s*Sleep\s*\(",
    ),
    (
        "CS010", "note",
        "new Thread() bypasses the thread pool. Use Task.Run for CPU-bound work.",
        "*.cs",
        r"\bnew\s+Thread\s*\(",
    ),
    # ── C# — Memory ─────────────────────────────────────────────────────────
    (
        "CS011", "warning",
        "GC.Collect() disrupts GC heuristics and hurts throughput. Fix the allocation pattern instead.",
        "*.cs",
        r"\bGC\s*\.\s*Collect\s*\(\s*\)",
    ),
    # ── C# — Output / logging ───────────────────────────────────────────────
    (
        "CS012", "warning",
        "WinUI 3 apps have no console window — Console output is silently dropped. Use Debug.WriteLine or a structured logger.",
        "*.cs",
        r"\bConsole\s*\.\s*Write(Line)?\s*\(",
    ),
    # ── C# — Time ───────────────────────────────────────────────────────────
    (
        "CS013", "note",
        "DateTime.Now includes local timezone offset. Use DateTime.UtcNow or DateTimeOffset.UtcNow for timestamps and logging.",
        "*.cs",
        r"\bDateTime\s*\.\s*Now\b",
    ),
    # ── C# — WinUI 3 / UWP API issues ──────────────────────────────────────
    (
        "CS014", "error",
        "Windows.UI.Xaml is the UWP namespace. WinUI 3 uses Microsoft.UI.Xaml. Mixing namespaces causes runtime failures.",
        "*.cs",
        r"Windows\.UI\.Xaml",
    ),
    (
        "CS015", "error",
        "ApplicationView is a deprecated UWP API not available in WinUI 3. Use Microsoft.UI.Windowing.AppWindow instead.",
        "*.cs",
        r"\bApplicationView\b",
    ),
    (
        "CS016", "error",
        "CoreWindow does not exist in WinUI 3 Desktop. Use Microsoft.UI.Xaml.Window or AppWindow instead.",
        "*.cs",
        r"\bCoreWindow\b",
    ),
    (
        "CS017", "error",
        "CoreDispatcher.RunAsync is the UWP API. Use DispatcherQueue.TryEnqueue in WinUI 3.",
        "*.cs",
        r"\bRunAsync\s*\(",
    ),
    # ── C# — Code quality ───────────────────────────────────────────────────
    (
        "CS018", "note",
        "#pragma warning disable suppresses compiler diagnostics. Fix the underlying issue instead of silencing the warning.",
        "*.cs",
        r"#pragma\s+warning\s+disable",
    ),
    (
        "CS019", "note",
        "dynamic bypasses static type checking. Use specific types, generics, or pattern matching instead.",
        "*.cs",
        r"\bdynamic\b",
    ),
    # ── C# — Security ───────────────────────────────────────────────────────
    (
        "CS020", "error",
        "String.Format / interpolation used in SQL query — potential SQL injection. Use parameterised queries.",
        "*.cs",
        r'(?i)(SqlCommand|ExecuteQuery|ExecuteNonQuery|ExecuteScalar)\s*\([^)]*(\$"|string\.Format)',
    ),
    (
        "CS022", "warning",
        "Hardcoded credential or secret literal detected. Use environment variables or a secrets manager.",
        "*.cs",
        r'(?i)(password|secret|apikey|api_key|token)\s*=\s*"[^"]{4,}"',
    ),
    # ── PowerShell ──────────────────────────────────────────────────────────
    (
        "PS001", "error",
        "Get-WmiObject is removed in PowerShell 7+ and Windows 11 25H2. Replace with Get-CimInstance.",
        "*.ps1",
        r"\bGet-WmiObject\b",
    ),
    (
        "PS002", "error",
        "wmic.exe is removed in Windows 11 25H2. Replace with Get-CimInstance queries.",
        "*.ps1",
        r"\bwmic\b",
    ),
    (
        "PS003", "error",
        "Invoke-Expression executes arbitrary strings — high injection risk. Avoid or validate strictly.",
        "*.ps1",
        r"\bInvoke-Expression\b|\biex\b",
    ),
    (
        "PS004", "warning",
        "Invoke-WebRequest / Invoke-RestMethod piped directly to Invoke-Expression executes untrusted remote code.",
        "*.ps1",
        r"(?i)(Invoke-WebRequest|Invoke-RestMethod|wget|curl).{0,120}Invoke-Expression",
    ),
    (
        "PS005", "warning",
        "Global $ErrorActionPreference = SilentlyContinue masks real errors. Use -ErrorAction SilentlyContinue per cmdlet.",
        "*.ps1",
        r"\$ErrorActionPreference\s*=\s*['\"]SilentlyContinue['\"]",
    ),
    (
        "PS006", "warning",
        "Set-StrictMode -Off removes undefined-variable detection. Only disable with a documented reason.",
        "*.ps1",
        r"(?i)Set-StrictMode\s+-Off",
    ),
    (
        "PS007", "warning",
        "[System.Net.WebClient] is deprecated. Use Invoke-RestMethod or Invoke-WebRequest instead.",
        "*.ps1",
        r"\[System\.Net\.WebClient\]",
    ),
    (
        "PS008", "warning",
        "ConvertTo-SecureString -AsPlainText stores a credential in plain text. Use Get-Credential or a secrets vault.",
        "*.ps1",
        r"ConvertTo-SecureString.{0,80}-AsPlainText|-AsPlainText.{0,80}ConvertTo-SecureString",
    ),
    (
        "PS009", "warning",
        "Hardcoded credential or secret literal in PowerShell. Use environment variables or a secrets manager.",
        "*.ps1",
        r'(?i)(password|secret|apikey|api_key|token)\s*=\s*["\'][^"\']{4,}["\']',
    ),
    # ── Bash ────────────────────────────────────────────────────────────────
    (
        "SH001", "error",
        "curl | bash executes untrusted remote code directly. Download to a file, verify integrity, then execute.",
        "*.sh",
        r"curl.{0,80}\|\s*(ba)?sh\b",
    ),
    (
        "SH002", "warning",
        "chmod 777 grants world-writable permissions. Use minimum required permissions (755 for executables, 644 for files).",
        "*.sh",
        r"chmod\s+777\b",
    ),
    (
        "SH003", "warning",
        "eval with variable input is an injection risk. Avoid eval or validate input strictly.",
        "*.sh",
        r"\beval\s+[\"'`$]",
    ),
    (
        "SH004", "warning",
        "Hardcoded credential or secret in shell script. Use environment variables or a secrets manager.",
        "*.sh",
        r'(?i)(password|secret|api_key|token)\s*=\s*["\'][^"\']{4,}["\']',
    ),
]

SARIF_SCHEMA = "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json"

# ---------------------------------------------------------------------------

def glob_files(root: Path, pattern: str):
    return [p for p in root.rglob(pattern) if not any(
        part.startswith(".") or part in ("bin", "obj", "node_modules")
        for part in p.parts
    )]


def scan(root: Path):
    findings = []
    compiled = [(rid, level, msg, glob, re.compile(rx, re.MULTILINE))
                for rid, level, msg, glob, rx in RULES]

    for rid, level, msg, glob, pattern in compiled:
        for filepath in glob_files(root, glob):
            try:
                text = filepath.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for m in pattern.finditer(text):
                lineno = text[:m.start()].count("\n") + 1
                col = m.start() - text.rfind("\n", 0, m.start())
                findings.append({
                    "ruleId": rid,
                    "level": level,
                    "message": msg,
                    "uri": filepath.relative_to(root).as_posix(),
                    "line": lineno,
                    "col": col,
                })
    return findings


def build_sarif(findings, rules_meta):
    rules = []
    seen = set()
    for rid, level, msg, *_ in RULES:
        if rid not in seen:
            seen.add(rid)
            rules.append({
                "id": rid,
                "name": rid,
                "shortDescription": {"text": msg},
                "defaultConfiguration": {"level": level},
            })

    results = []
    for f in findings:
        results.append({
            "ruleId": f["ruleId"],
            "level": f["level"],
            "message": {"text": f["message"]},
            "locations": [{"physicalLocation": {
                "artifactLocation": {"uri": f["uri"], "uriBaseId": "%SRCROOT%"},
                "region": {"startLine": f["line"], "startColumn": f["col"]},
            }}],
        })

    return {
        "$schema": SARIF_SCHEMA,
        "version": "2.1.0",
        "runs": [{"tool": {"driver": {"name": "pattern-check", "rules": rules}}, "results": results}],
    }


if __name__ == "__main__":
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    findings = scan(root)
    sarif = build_sarif(findings, RULES)
    out = Path("pattern-check.sarif")
    out.write_text(json.dumps(sarif, indent=2))
    print(f"{len(findings)} finding(s) written to {out}")
    # Exit 0 always — findings go to GitHub Security tab, not CI failure.

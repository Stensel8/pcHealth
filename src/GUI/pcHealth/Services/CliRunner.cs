using System.Diagnostics;

namespace pcHealth;

/// <summary>
/// Launches CLI tools and system applications from the GUI.
/// Because the app runs as Administrator, spawned processes inherit elevation.
/// </summary>
internal static class CliRunner
{
    private static string? _toolsDir;

    // Both 32-bit and 64-bit uninstall hives must be searched on 64-bit Windows.
    private static readonly string[] UninstallPaths =
    {
        @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    };

    /// <summary>
    /// Locates the CLI/tools directory by walking up from the executable
    /// location. Works from bin/Debug|Release output and any ancestor folder.
    /// </summary>
    private static string GetToolsDir()
    {
        if (_toolsDir is not null) return _toolsDir;

        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "src", "CLI", "tools");
            if (Directory.Exists(candidate))
                return _toolsDir = candidate;
            dir = dir.Parent;
        }

        throw new DirectoryNotFoundException(
            "Cannot locate src/CLI/tools.\n" +
            "Make sure the app is run from within the pcHealth repository.");
    }

    /// <summary>Runs a PowerShell 7 script in a new visible terminal window.
    /// The window pauses after the script finishes so the user can read the output.</summary>
    public static void RunScript(string scriptFileName)
    {
        var path = Path.Combine(GetToolsDir(), scriptFileName);
        var cmd = $"& '{path}'; Write-Host ''; Read-Host 'Press Enter to close'";
        Start(new ProcessStartInfo
        {
            FileName = "pwsh.exe",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{cmd}\"",
            UseShellExecute = true,
        });
    }

    /// <summary>Opens a URI (ms-settings:, https://, etc.) via the Windows shell.</summary>
    public static void OpenUri(string uri) =>
        Start(new ProcessStartInfo { FileName = uri, UseShellExecute = true });

    /// <summary>
    /// Launches an installed application. Resolves the full exe path via
    /// Windows App Paths or the Uninstall registry InstallLocation so the
    /// launch works even when the exe is not on PATH.
    /// </summary>
    public static void OpenApp(string exeName, string registryName = "")
    {
        var path = GetAppPathsExe(exeName)
            ?? (!string.IsNullOrEmpty(registryName) ? GetInstallLocationExe(registryName, exeName) : null)
            ?? exeName;
        Start(new ProcessStartInfo { FileName = path, UseShellExecute = true });
    }

    private static string? GetAppPathsExe(string exeName)
    {
        using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
            $@"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{exeName}");
        return key?.GetValue(null) as string;
    }

    private static string? GetInstallLocationExe(string registryName, string exeName)
    {
        foreach (var path in UninstallPaths)
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(path);
            if (key is null) continue;

            foreach (var sub in key.GetSubKeyNames())
            {
                using var entry = key.OpenSubKey(sub);
                if (entry?.GetValue("DisplayName") is not string displayName
                    || !displayName.Contains(registryName, StringComparison.OrdinalIgnoreCase))
                    continue;

                if (entry.GetValue("InstallLocation") is string loc && !string.IsNullOrWhiteSpace(loc))
                {
                    var candidate = Path.Combine(loc.TrimEnd('\\', '/'), exeName);
                    if (File.Exists(candidate)) return candidate;
                }

                if (entry.GetValue("DisplayIcon") is string icon)
                {
                    var iconPath = icon.Split(',')[0].Trim('"');
                    if (iconPath.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) && File.Exists(iconPath))
                        return iconPath;
                }
            }
        }
        return null;
    }

    /// <summary>
    /// Runs a winget command in a new PowerShell 7 window and pauses after
    /// completion so the user can read the output before closing.
    /// </summary>
    public static void RunWinget(string wingetArguments)
    {
        var cmd = $"winget {wingetArguments}; Write-Host ''; Read-Host 'Press Enter to close'";
        Start(new ProcessStartInfo
        {
            FileName = "pwsh.exe",
            Arguments = $"-NoProfile -Command \"{cmd}\"",
            UseShellExecute = true,
        });
    }

    /// <summary>
    /// Checks whether a program is installed by searching the Windows Uninstall
    /// registry keys for a DisplayName that contains <paramref name="registryName"/>.
    /// This is faster and more reliable than invoking winget as a subprocess.
    /// </summary>
    public static bool IsInstalled(string registryName)
    {
        if (string.IsNullOrEmpty(registryName)) return false;
        return SearchUninstallKey(Microsoft.Win32.Registry.LocalMachine, registryName)
            || SearchUninstallKey(Microsoft.Win32.Registry.CurrentUser, registryName);
    }

    private static bool SearchUninstallKey(Microsoft.Win32.RegistryKey hive, string name)
    {
        foreach (var path in UninstallPaths)
        {
            using var key = hive.OpenSubKey(path);
            if (key is null) continue;

            foreach (var sub in key.GetSubKeyNames())
            {
                using var entry = key.OpenSubKey(sub);
                if (entry?.GetValue("DisplayName") is string displayName
                    && displayName.Contains(name, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
        }
        return false;
    }

    // Process.Start with UseShellExecute=true can return null when the OS reuses
    // an existing process window instead of spawning a new one. Throwing here means
    // the caller's catch block can surface a meaningful error rather than silently
    // doing nothing.
    private static Process Start(ProcessStartInfo info)
    {
        return Process.Start(info)
            ?? throw new InvalidOperationException(
                $"Failed to start process: {info.FileName}");
    }
}

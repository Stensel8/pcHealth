using System.Diagnostics;
using System.IO;

namespace pcHealth;

/// <summary>
/// Launches CLI tools and system applications from the GUI.
/// Because the app runs as Administrator, spawned processes inherit elevation.
/// </summary>
internal static class CliRunner
{
    private static string? _toolsDir;

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
        var cmd  = $"& '{path}'; Write-Host ''; Read-Host 'Press Enter to close'";
        Start(new ProcessStartInfo
        {
            FileName        = "pwsh.exe",
            Arguments       = $"-NoProfile -ExecutionPolicy Bypass -Command \"{cmd}\"",
            UseShellExecute = true,
        });
    }

    /// <summary>Opens a URI (ms-settings:, https://, etc.) via the Windows shell.</summary>
    public static void OpenUri(string uri) =>
        Start(new ProcessStartInfo { FileName = uri, UseShellExecute = true });

    /// <summary>Launches a named system application (e.g. dfrgui.exe).</summary>
    public static void OpenApp(string appName) =>
        Start(new ProcessStartInfo { FileName = appName, UseShellExecute = true });

    /// <summary>
    /// Runs a winget command in a new PowerShell 7 window and pauses after
    /// completion so the user can read the output before closing.
    /// </summary>
    public static void RunWinget(string wingetArguments)
    {
        var cmd = $"winget {wingetArguments}; Write-Host ''; Read-Host 'Press Enter to close'";
        Start(new ProcessStartInfo
        {
            FileName        = "pwsh.exe",
            Arguments       = $"-NoProfile -Command \"{cmd}\"",
            UseShellExecute = true,
        });
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

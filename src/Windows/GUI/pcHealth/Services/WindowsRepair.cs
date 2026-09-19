using NLog;
using System.Diagnostics;

namespace pcHealth.Services;

/// <summary>
/// Starts the Windows Update in-place upgrade by running the same command the
/// Settings app runs.
/// </summary>
/// <remarks>
/// Settings has no API for this repair, so pcHealth used to press its button
/// through UI Automation. Watching what the button actually does showed there
/// was no need: it runs
///
///     SystemSettingsAdminFlows.exe RunInPlaceUpgrade Recoverypage
///
/// and the servicing stack picks it up from there. Running the same command
/// removes the dependency on another app's layout, its display language and
/// its element tree, all of which could change under us. The second argument
/// is the page Settings reports as the origin; it is passed exactly as
/// observed rather than invented.
///
/// The verb is undocumented, so a build without it must fail visibly instead
/// of silently doing nothing -- hence the exit code check and IsSupported.
/// </remarks>
internal sealed class WindowsRepair : IWindowsRepair
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private const string Verb = "RunInPlaceUpgrade";
    private const string Origin = "Recoverypage";

    // The host hands off to TrustedInstaller and exits; it does not sit around
    // for the hour the repair itself takes.
    private static readonly TimeSpan HandoffTimeout = TimeSpan.FromSeconds(30);

    private readonly ICliRunner _cli;

    public WindowsRepair(ICliRunner cli) => _cli = cli;

    private static string HostPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.System),
        "SystemSettingsAdminFlows.exe");

    public bool IsSupported => File.Exists(HostPath);

    public void OpenRecovery() => _cli.OpenUri("ms-settings:recovery");

    public void OpenWindowsUpdate() => _cli.OpenUri("ms-settings:windowsupdate");

    public async Task<RepairStart> StartAsync(CancellationToken ct = default)
    {
        if (!IsSupported)
        {
            return new RepairStart(false,
                "This Windows build has no SystemSettingsAdminFlows.exe, so the repair cannot be started from here.");
        }

        var info = new ProcessStartInfo(HostPath)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        info.ArgumentList.Add(Verb);
        info.ArgumentList.Add(Origin);

        try
        {
            using var process = Process.Start(info);
            if (process is null)
            {
                return new RepairStart(false, "Windows would not start the repair host.");
            }

            Log.Info("Started {Host} {Verb} {Origin}", HostPath, Verb, Origin);

            // A quick non-zero exit means the verb was rejected. Still running
            // after the timeout is normal: it has handed off and is tidying up.
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(HandoffTimeout);
            try
            {
                await process.WaitForExitAsync(timeout.Token);
            }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested)
            {
                return new RepairStart(true, "Repair started. Windows Update is fetching the repair build.");
            }

            if (process.ExitCode != 0)
            {
                Log.Warn("Repair host exited with {Code}", process.ExitCode);
                return new RepairStart(false,
                    $"Windows refused the repair (exit code {process.ExitCode}). Check Windows Update for an update already in progress.");
            }

            return new RepairStart(true, "Repair started. Windows Update is fetching the repair build.");
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            Log.Error(ex, "Could not run the repair host");
            return new RepairStart(false, $"Could not run the repair host: {ex.Message}");
        }
    }
}

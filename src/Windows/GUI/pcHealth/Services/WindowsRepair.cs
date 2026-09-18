using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.UIA3;
using NLog;
using System.Diagnostics;

namespace pcHealth.Services;

/// <summary>
/// Drives the "Fix problems using Windows Update" button in the Settings app.
/// </summary>
/// <remarks>
/// Windows exposes no API for this repair. It is not an update you can install
/// through the Windows Update Agent, not a CSP, not a usoclient verb: it is a
/// Settings button that asks the Update Session Orchestrator for a repair build
/// of the running version. UI Automation, the accessibility API that exists to
/// invoke UI, is the only supported way to press it from another process.
///
/// That makes this the one part of pcHealth that depends on another app's
/// layout, so it is written to fail safely rather than cleverly:
///
/// - The button is matched on an exact label from a known list, never on a
///   substring. The same Settings page also carries "Reset PC", and a loose
///   match there would wipe the machine.
/// - Whatever is found is handed back to the caller so the user can confirm the
///   literal button text before it is pressed.
/// - When nothing matches, the page is simply left open. Every button found is
///   written to the log, so an unknown language or a new Windows build can be
///   diagnosed from one run instead of guessed at.
/// </remarks>
internal sealed class WindowsRepair : IWindowsRepair, IDisposable
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    // Exact labels only, per the note above.
    private static readonly string[] RepairLabels =
    [
        "Reinstall now",            // en
        "Nu opnieuw installeren",   // nl
    ];

    private static readonly TimeSpan WindowTimeout = TimeSpan.FromSeconds(20);
    private static readonly TimeSpan PageTimeout = TimeSpan.FromSeconds(15);
    private static readonly TimeSpan Poll = TimeSpan.FromMilliseconds(500);

    private readonly ICliRunner _cli;

    private UIA3Automation? _automation;
    private AutomationElement? _button;

    public WindowsRepair(ICliRunner cli) => _cli = cli;

    public void OpenRecovery() => _cli.OpenUri("ms-settings:recovery");

    public void OpenWindowsUpdate() => _cli.OpenUri("ms-settings:windowsupdate");

    // UI Automation blocks on cross-process calls, so none of it runs on the
    // thread painting our own window.
    public Task<RepairButton?> LocateAsync(CancellationToken ct = default) => Task.Run(() => Locate(ct), ct);

    public Task<bool> PressAsync(CancellationToken ct = default) => Task.Run(Press, ct);

    private RepairButton? Locate(CancellationToken ct)
    {
        Release();
        OpenRecovery();

        _automation = new UIA3Automation();
        var window = WaitForSettings(_automation, ct);
        if (window is null)
        {
            Log.Warn("The Settings window did not appear within {Seconds}s", WindowTimeout.TotalSeconds);
            return null;
        }

        // The Recovery page renders after the window exists, so this keeps
        // looking until the page has settled.
        var deadline = DateTime.UtcNow + PageTimeout;
        while (DateTime.UtcNow < deadline)
        {
            ct.ThrowIfCancellationRequested();
            if (FindRepairButton(window) is { } found) return found;
            Thread.Sleep(Poll);
        }

        Log.Info("No repair button matched a known label; the buttons found are listed above.");
        return null;
    }

    private RepairButton? FindRepairButton(AutomationElement window)
    {
        AutomationElement[] buttons;
        try
        {
            buttons = window.FindAllDescendants(f => f.ByControlType(ControlType.Button));
        }
        catch (Exception ex)
        {
            Log.Debug(ex, "Could not read the Settings window yet");
            return null;
        }

        foreach (var candidate in buttons)
        {
            string name;
            bool enabled;
            try
            {
                name = (candidate.Name ?? "").Trim();
                enabled = candidate.IsEnabled;
            }
            catch (Exception ex)
            {
                // Settings rebuilds its tree as the page loads; a stale element
                // is normal rather than a failure.
                Log.Trace(ex, "Skipped a stale element");
                continue;
            }

            Log.Debug("Recovery page button: id={Id} name={Name} enabled={Enabled}",
                candidate.AutomationId, name, enabled);

            if (!RepairLabels.Contains(name, StringComparer.OrdinalIgnoreCase)) continue;

            _button = candidate;
            return new RepairButton(name, enabled);
        }

        return null;
    }

    private bool Press()
    {
        if (_button is null) return false;
        try
        {
            _button.AsButton().Invoke();
            Log.Info("Pressed the Windows repair button");
            return true;
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Could not press the repair button");
            return false;
        }
    }

    private static AutomationElement? WaitForSettings(UIA3Automation automation, CancellationToken ct)
    {
        var deadline = DateTime.UtcNow + WindowTimeout;
        while (DateTime.UtcNow < deadline)
        {
            ct.ThrowIfCancellationRequested();

            // Scoped to the Settings window by handle rather than searched for
            // across the desktop: faster, and it cannot wander into another app.
            foreach (var process in Process.GetProcessesByName("SystemSettings"))
            {
                using (process)
                {
                    if (process.MainWindowHandle == IntPtr.Zero) continue;
                    try
                    {
                        return automation.FromHandle(process.MainWindowHandle);
                    }
                    catch (Exception ex)
                    {
                        Log.Debug(ex, "Settings window is not ready yet");
                    }
                }
            }

            Thread.Sleep(Poll);
        }
        return null;
    }

    private void Release()
    {
        _button = null;
        _automation?.Dispose();
        _automation = null;
    }

    public void Dispose() => Release();
}

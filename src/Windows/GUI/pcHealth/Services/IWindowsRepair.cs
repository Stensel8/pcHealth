namespace pcHealth.Services;

/// <summary>The repair button as the Settings app currently presents it.</summary>
/// <param name="Text">The exact label, shown to the user before anything is pressed.</param>
/// <param name="IsEnabled">False when Windows shows the option but cannot start it yet.</param>
public sealed record RepairButton(string Text, bool IsEnabled);

/// <summary>
/// Starts the "Fix problems using Windows Update" repair from inside pcHealth.
/// </summary>
public interface IWindowsRepair
{
    /// <summary>Opens Settings on the Recovery page and locates the repair button.</summary>
    /// <returns>The button, or null when nothing on the page matched.</returns>
    Task<RepairButton?> LocateAsync(CancellationToken ct = default);

    /// <summary>Presses the button found by the last <see cref="LocateAsync"/> call.</summary>
    Task<bool> PressAsync(CancellationToken ct = default);

    /// <summary>Shows Windows Update, where the repair build then downloads.</summary>
    void OpenWindowsUpdate();

    /// <summary>Shows the Recovery page without touching anything.</summary>
    void OpenRecovery();
}

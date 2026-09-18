using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Helpers;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class WindowsRepairViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private const string NotFound =
        "Could not find the repair button. The Recovery page is open in Settings: scroll to "
        + "\"Fix problems using Windows Update\" and press Reinstall now there. Every button that "
        + "was found is written to the pcHealth log, which is what a new Windows build or a "
        + "different display language needs to be supported.";

    private const string Unavailable =
        "Windows shows the option but has greyed it out. That happens while another update is "
        + "installing, on PCs managed by work or school, and on builds older than Windows 11 22H2 "
        + "with the February 2024 update.";

    private readonly IWindowsRepair _repair;

    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial bool IsBusy { get; set; }

    /// <summary>Set by the page: a ContentDialog needs somewhere to render.</summary>
    public XamlRoot? XamlRoot { get; set; }

    public WindowsRepairViewModel(IWindowsRepair repair) => _repair = repair;

    [RelayCommand]
    public void OpenRecovery() => _repair.OpenRecovery();

    [RelayCommand(CanExecute = nameof(CanStart))]
    public async Task StartAsync(CancellationToken ct)
    {
        IsBusy = true;
        try
        {
            Status = "Opening Recovery in Settings...";
            var button = await _repair.LocateAsync(ct);

            if (button is null)
            {
                Status = NotFound;
                return;
            }

            if (!button.IsEnabled)
            {
                Status = Unavailable;
                return;
            }

            if (XamlRoot is null)
            {
                Status = "The page is not ready to ask for confirmation. Try again.";
                return;
            }

            // The literal button text goes in front of the user before anything
            // is pressed. It is the last check that the right control was found.
            bool confirmed = await DialogHelper.ShowConfirmAsync(
                XamlRoot,
                "Repair Windows",
                $"pcHealth found the button \"{button.Text}\" on the Recovery page and is about to "
                + "press it.\n\nWindows downloads a repair build of the version you are running and "
                + "reinstalls it over itself. Your files, apps and settings are kept. It takes "
                + "roughly half an hour to an hour and ends in a restart.",
                $"Press \"{button.Text}\"");

            if (!confirmed)
            {
                Status = "Cancelled.";
                return;
            }

            if (await _repair.PressAsync(ct))
            {
                Status = "Repair started. Windows Update is downloading the repair build.";
                _repair.OpenWindowsUpdate();
            }
            else
            {
                Status = "The button was found but would not respond. Press it yourself in Settings.";
            }
        }
        catch (OperationCanceledException)
        {
            Status = "Cancelled.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Windows repair failed");
            Status = ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    private bool CanStart() => !IsBusy;
}

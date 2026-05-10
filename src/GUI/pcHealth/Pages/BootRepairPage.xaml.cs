using pcHealth.Helpers;

namespace pcHealth.Pages;

public sealed partial class BootRepairPage : Page
{
    private CancellationTokenSource? _cts;

    public BootRepairPage()
    {
        InitializeComponent();
    }

    private async void RunBtn_Click(object sender, RoutedEventArgs e)
    {
        var confirm = new ContentDialog
        {
            Title = "Repair Boot Record",
            Content = "This will run bootrec /fixmbr, /fixboot, /scanos and /rebuildbcd.\n\n" +
                      "This modifies boot-critical files. Incorrect use can make the system unbootable.\n\n" +
                      "Type 'CONFIRM' to proceed.",
            PrimaryButtonText = "Proceed",
            CloseButtonText = "Cancel",
            XamlRoot = XamlRoot,
        };

        if (await confirm.ShowAsync() != ContentDialogResult.Primary) return;

        RunBtn.IsEnabled = false;
        Progress.IsActive = true;
        OutputText.Text = "";
        StatusText.Text = "Running boot repair…";

        _cts = new CancellationTokenSource();

        try
        {
            var Append = UiHelper.CreateAppendHandler(OutputText, OutputScroller, DispatcherQueue);

            var bootrec = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "bootrec.exe");

            Append("[>>] bootrec /fixmbr");
            await ProcessRunner.RunAsync(bootrec, "/fixmbr", Append, _cts.Token);

            Append("\n[>>] bootrec /fixboot");
            await ProcessRunner.RunAsync(bootrec, "/fixboot", Append, _cts.Token);

            Append("\n[>>] bootrec /scanos");
            await ProcessRunner.RunAsync(bootrec, "/scanos", Append, _cts.Token);

            Append("\n[>>] bootrec /rebuildbcd");
            await ProcessRunner.RunAsync(bootrec, "/rebuildbcd", Append, _cts.Token);

            Append("\n[OK] Boot repair complete. Reboot the system to verify.");
            StatusText.Text = "Done — reboot required.";
        }
        catch (OperationCanceledException)
        {
            OutputText.Text += "\n[Cancelled]";
            StatusText.Text = "Cancelled.";
        }
        catch (Exception ex)
        {
            OutputText.Text += $"\n[Error] {ex.Message}";
            StatusText.Text = "Error.";
        }
        finally
        {
            Progress.IsActive = false;
            RunBtn.IsEnabled = true;
            _cts?.Dispose();
            _cts = null;
        }
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        _cts?.Cancel();
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

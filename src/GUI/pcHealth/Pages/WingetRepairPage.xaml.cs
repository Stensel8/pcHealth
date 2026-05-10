using pcHealth.Helpers;

namespace pcHealth.Pages;

public sealed partial class WingetRepairPage : Page
{
    private CancellationTokenSource? _cts;

    public WingetRepairPage()
    {
        InitializeComponent();
    }

    private async void RunBtn_Click(object sender, RoutedEventArgs e)
    {
        RunBtn.IsEnabled = false;
        Progress.IsActive = true;
        OutputText.Text = "";
        StatusText.Text = "Repairing winget…";

        _cts = new CancellationTokenSource();

        try
        {
            var Append = UiHelper.CreateAppendHandler(OutputText, OutputScroller, DispatcherQueue);

            Append("[>>] Installing winget-install script from PSGallery…");
            await ProcessRunner.RunAsync(
                "pwsh.exe",
                "-NoProfile -ExecutionPolicy Bypass -Command \"Install-Script -Name winget-install -Force -Scope CurrentUser\"",
                Append, _cts.Token);

            Append("\n[>>] Running winget-install…");
            await ProcessRunner.RunAsync(
                "pwsh.exe",
                "-NoProfile -ExecutionPolicy Bypass -Command \"winget-install -Force\"",
                Append, _cts.Token);

            Append("\n[OK] Winget repair complete.");
            StatusText.Text = "Done.";
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

using pcHealth.Helpers;

namespace pcHealth.Pages;

public sealed partial class ScanRepairPage : Page
{
    private CancellationTokenSource? _cts;

    public ScanRepairPage()
    {
        InitializeComponent();
    }

    private async void RunBtn_Click(object sender, RoutedEventArgs e)
    {
        RunBtn.IsEnabled = false;
        Progress.IsActive = true;
        OutputText.Text = "";
        StatusText.Text = "Running — this may take several minutes…";

        _cts = new CancellationTokenSource();

        try
        {
            var Append = UiHelper.CreateAppendHandler(OutputText, OutputScroller, DispatcherQueue);

            // Step 1: SFC
            Append("=== Step 1/5 — SFC (initial scan) ===");
            await ProcessRunner.RunAsync(
                Path.Combine(Environment.SystemDirectory, "sfc.exe"),
                "/scannow", Append, _cts.Token);

            // Step 2: DISM CheckHealth
            Append("\n=== Step 2/5 — DISM CheckHealth ===");
            await ProcessRunner.RunAsync(
                Path.Combine(Environment.SystemDirectory, "Dism.exe"),
                "/Online /Cleanup-Image /CheckHealth", Append, _cts.Token);

            // Step 3: DISM ScanHealth
            Append("\n=== Step 3/5 — DISM ScanHealth ===");
            await ProcessRunner.RunAsync(
                Path.Combine(Environment.SystemDirectory, "Dism.exe"),
                "/Online /Cleanup-Image /ScanHealth", Append, _cts.Token);

            // Step 4: DISM RestoreHealth
            Append("\n=== Step 4/5 — DISM RestoreHealth ===");
            await ProcessRunner.RunAsync(
                Path.Combine(Environment.SystemDirectory, "Dism.exe"),
                "/Online /Cleanup-Image /RestoreHealth", Append, _cts.Token);

            // Step 5: SFC final pass
            Append("\n=== Step 5/5 — SFC (final pass) ===");
            await ProcessRunner.RunAsync(
                Path.Combine(Environment.SystemDirectory, "sfc.exe"),
                "/scannow", Append, _cts.Token);

            Append($"\n=== Complete. Full log: {Environment.GetEnvironmentVariable("SystemRoot")}\\Logs\\CBS\\CBS.log ===");
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
            StatusText.Text = "Error — see output.";
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

namespace pcHealth.Pages;

public sealed partial class SystemUpdatePage : Page
{
    private CancellationTokenSource? _cts;

    public SystemUpdatePage()
    {
        InitializeComponent();
    }

    private async void RunBtn_Click(object sender, RoutedEventArgs e)
    {
        RunBtn.IsEnabled = false;
        Progress.IsActive = true;
        OutputText.Text = "";
        StatusText.Text = "Updating packages…";

        _cts = new CancellationTokenSource();

        try
        {
            void Append(string line) =>
                DispatcherQueue.TryEnqueue(() =>
                {
                    OutputText.Text += line + "\n";
                    OutputScroller.ScrollToVerticalOffset(double.MaxValue);
                });

            await ProcessRunner.RunAsync(
                "winget.exe",
                "upgrade --all --accept-source-agreements --accept-package-agreements",
                Append, _cts.Token);

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

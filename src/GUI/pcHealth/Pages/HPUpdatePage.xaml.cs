using pcHealth.Helpers;

namespace pcHealth.Pages;

public sealed partial class HPUpdatePage : Page
{
    private CancellationTokenSource? _cts;

    public HPUpdatePage()
    {
        InitializeComponent();
    }

    private async void InstallBtn_Click(object sender, RoutedEventArgs e)
    {
        InstallBtn.IsEnabled = false;
        Progress.IsActive = true;
        OutputText.Text = "";
        OutputBorder.Visibility = Visibility.Visible;
        StatusText.Text = "Installing…";

        _cts = new CancellationTokenSource();

        try
        {
            var Append = UiHelper.CreateAppendHandler(OutputText, OutputScroller, DispatcherQueue);

            await ProcessRunner.RunAsync(
                "winget.exe",
                "install --id HP.ImageAssistant --accept-source-agreements --accept-package-agreements",
                Append, _cts.Token);

            StatusText.Text = "Done. Launch HP Image Assistant to update drivers.";
        }
        catch (OperationCanceledException)
        {
            StatusText.Text = "Cancelled.";
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Error: {ex.Message}";
        }
        finally
        {
            Progress.IsActive = false;
            InstallBtn.IsEnabled = true;
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

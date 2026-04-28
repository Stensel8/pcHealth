namespace pcHealth.Pages;

public sealed partial class AudioRestartPage : Page
{
    public AudioRestartPage()
    {
        InitializeComponent();
        Loaded += async (_, _) => await RefreshStatusAsync();
    }

    private async Task RefreshStatusAsync()
    {
        try
        {
            var aebRunning   = await IsServiceRunningAsync("AudioEndpointBuilder");
            var audioRunning = await IsServiceRunningAsync("Audiosrv");
            SetStatus(AebIcon,   AebStatus,   aebRunning);
            SetStatus(AudioIcon, AudioStatus, audioRunning);
        }
        catch (Exception ex)
        {
            AebStatus.Text = ex.Message;
        }
    }

    private static async Task<bool> IsServiceRunningAsync(string name)
    {
        var output = new System.Text.StringBuilder();
        await ProcessRunner.RunAsync("sc.exe", $"query {name}", line => output.AppendLine(line));
        return output.ToString().Contains("RUNNING", StringComparison.OrdinalIgnoreCase);
    }

    private void SetStatus(FontIcon icon, TextBlock label, bool running)
    {
        label.Text = running ? "Running" : "Stopped";
        icon.Glyph = running ? "\uE930" : "\uE711";
        icon.Foreground = running
            ? new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58))
            : (Brush)Application.Current.Resources["TextFillColorTertiaryBrush"];
    }

    private async void RestartBtn_Click(object sender, RoutedEventArgs e)
    {
        RestartBtn.IsEnabled = false;
        Progress.IsActive = true;
        ResultBar.IsOpen = false;

        try
        {
            await ProcessRunner.RunAsync("net.exe", "stop Audiosrv /yes",              _ => { });
            await ProcessRunner.RunAsync("net.exe", "stop AudioEndpointBuilder /yes",  _ => { });
            await Task.Delay(1000);
            await ProcessRunner.RunAsync("net.exe", "start AudioEndpointBuilder",      _ => { });
            await ProcessRunner.RunAsync("net.exe", "start Audiosrv",                  _ => { });

            await RefreshStatusAsync();
            ResultBar.Severity = InfoBarSeverity.Success;
            ResultBar.Title = "Audio services restarted. Test your audio now.";
            ResultBar.IsOpen = true;
        }
        catch (Exception ex)
        {
            ResultBar.Severity = InfoBarSeverity.Error;
            ResultBar.Title = "Failed to restart audio services";
            ResultBar.Message = ex.Message;
            ResultBar.IsOpen = true;
        }
        finally
        {
            Progress.IsActive = false;
            RestartBtn.IsEnabled = true;
        }
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

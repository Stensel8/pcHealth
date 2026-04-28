using System.Diagnostics;

namespace pcHealth.Pages;

public sealed partial class PowerOptionsPage : Page
{
    public PowerOptionsPage()
    {
        InitializeComponent();
    }

    private async void LogOffBtn_Click(object sender, RoutedEventArgs e)
    {
        if (!await ConfirmAsync("Log Off", "Sign out the current Windows session?")) return;
        Process.Start(new ProcessStartInfo("shutdown.exe", "/l") { CreateNoWindow = true });
    }

    private async void RestartBtn_Click(object sender, RoutedEventArgs e)
    {
        if (!await ConfirmAsync("Restart", "Restart the PC immediately?")) return;
        Process.Start(new ProcessStartInfo("shutdown.exe", "/r /t 0") { CreateNoWindow = true });
    }

    private async void ShutdownBtn_Click(object sender, RoutedEventArgs e)
    {
        if (!await ConfirmAsync("Shutdown", "Shut down the PC immediately?")) return;
        Process.Start(new ProcessStartInfo("shutdown.exe", "/s /t 0") { CreateNoWindow = true });
    }

    private async Task<bool> ConfirmAsync(string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            PrimaryButtonText = title,
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot,
        };
        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

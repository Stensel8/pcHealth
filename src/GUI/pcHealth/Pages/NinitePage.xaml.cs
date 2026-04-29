using System.Diagnostics;
using System.Net.Http;

namespace pcHealth.Pages;

public sealed partial class NinitePage : Page
{
    private const string NiniteUrl = "https://ninite.com/7zip-chrome-edge-vlc/ninite.exe";
    private static readonly HttpClient _http = new();

    public NinitePage()
    {
        InitializeComponent();
    }

    private async void DownloadBtn_Click(object sender, RoutedEventArgs e)
    {
        DownloadBtn.IsEnabled = false;
        Progress.IsActive = true;
        ErrorBar.IsOpen = false;
        StatusText.Text = "Downloading…";

        try
        {
            var dest = Path.Combine(Path.GetTempPath(), "pcHealth-ninite.exe");
            var bytes = await _http.GetByteArrayAsync(NiniteUrl);
            await File.WriteAllBytesAsync(dest, bytes);

            StatusText.Text = "Launching installer…";
            Process.Start(new ProcessStartInfo(dest) { UseShellExecute = true });
            StatusText.Text = "Installer launched.";
        }
        catch (Exception ex)
        {
            StatusText.Text = "";
            ErrorBar.Message = ex.Message;
            ErrorBar.IsOpen = true;
        }
        finally
        {
            Progress.IsActive = false;
            DownloadBtn.IsEnabled = true;
        }
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

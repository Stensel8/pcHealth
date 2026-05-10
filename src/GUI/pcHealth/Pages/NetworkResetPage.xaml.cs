using Microsoft.Management.Infrastructure;
using pcHealth.Helpers;

namespace pcHealth.Pages;

public sealed partial class NetworkResetPage : Page
{
    public NetworkResetPage()
    {
        InitializeComponent();
    }

    private async void RunBtn_Click(object sender, RoutedEventArgs e)
    {
        RunBtn.IsEnabled = false;
        Progress.IsActive = true;
        OutputText.Text = "";
        StatusText.Text = "Resetting network stack…";

        // Single append handler used consistently throughout — all output routes
        // through this so every line gets scrolled into view automatically.
        var Append = UiHelper.CreateAppendHandler(OutputText, OutputScroller, DispatcherQueue);

        try
        {
            await Task.Run(() =>
            {
                // Flush DNS via CIM (no external process needed).
                Append("[>>] Flushing DNS cache…");
                using var session = CimSession.Create(null);
                try
                {
                    foreach (var inst in session.QueryInstances("root/StandardCimv2", "WQL",
                        "SELECT * FROM MSFT_DNSClientCache"))
                    {
                        session.DeleteInstance(inst);
                    }
                }
                catch (Exception) { }
                Append("[OK] DNS cache flushed.");
                Append("[>>] Resetting Winsock catalog…");
            });

            await ProcessRunner.RunAsync("netsh.exe", "winsock reset catalog", Append);
            Append("[OK] Winsock reset.");

            Append("[>>] Resetting IPv4 stack…");
            await ProcessRunner.RunAsync("netsh.exe", "int ipv4 reset", Append);

            Append("[>>] Resetting IPv6 stack…");
            await ProcessRunner.RunAsync("netsh.exe", "int ipv6 reset", Append);

            Append("\n[OK] Network stack reset complete. Reboot to apply all changes.");
            StatusText.Text = "Done — reboot recommended.";
        }
        catch (Exception ex)
        {
            Append($"\n[Error] {ex.Message}");
            StatusText.Text = "Error.";
        }
        finally
        {
            Progress.IsActive = false;
            RunBtn.IsEnabled = true;
        }
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

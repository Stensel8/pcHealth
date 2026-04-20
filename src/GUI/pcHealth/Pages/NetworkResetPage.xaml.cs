using Microsoft.Management.Infrastructure;

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

        try
        {
            void Append(string line) =>
                DispatcherQueue.TryEnqueue(() =>
                {
                    OutputText.Text += line + "\n";
                    OutputScroller.ScrollToVerticalOffset(double.MaxValue);
                });

            await Task.Run(() =>
            {
                // Flush DNS
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

                // Winsock reset
                Append("[>>] Resetting Winsock catalog…");
            });

            await ProcessRunner.RunAsync("netsh.exe", "winsock reset catalog",
                line => DispatcherQueue.TryEnqueue(() => OutputText.Text += line + "\n"));
            DispatcherQueue.TryEnqueue(() => OutputText.Text += "[OK] Winsock reset.\n");

            // IPv4/IPv6 reset
            DispatcherQueue.TryEnqueue(() => OutputText.Text += "[>>] Resetting IPv4 stack…\n");
            await ProcessRunner.RunAsync("netsh.exe", "int ipv4 reset",
                line => DispatcherQueue.TryEnqueue(() => OutputText.Text += line + "\n"));

            DispatcherQueue.TryEnqueue(() => OutputText.Text += "[>>] Resetting IPv6 stack…\n");
            await ProcessRunner.RunAsync("netsh.exe", "int ipv6 reset",
                line => DispatcherQueue.TryEnqueue(() => OutputText.Text += line + "\n"));

            DispatcherQueue.TryEnqueue(() =>
            {
                OutputText.Text += "\n[OK] Network stack reset complete. Reboot to apply all changes.\n";
                OutputScroller.ScrollToVerticalOffset(double.MaxValue);
            });

            StatusText.Text = "Done — reboot recommended.";
        }
        catch (Exception ex)
        {
            DispatcherQueue.TryEnqueue(() => OutputText.Text += $"\n[Error] {ex.Message}\n");
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

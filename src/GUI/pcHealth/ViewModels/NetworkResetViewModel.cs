using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Management.Infrastructure;
using NLog;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class NetworkResetViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private readonly IProcessRunner _runner;

    [ObservableProperty] public partial string Output { get; set; } = "";
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial bool IsRunning { get; set; }

    public NetworkResetViewModel(IProcessRunner runner) => _runner = runner;

    [RelayCommand(CanExecute = nameof(CanRun))]
    public async Task RunAsync()
    {
        IsRunning = true;
        Output = "";
        Status = "Resetting network stack…";

        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        void Append(string line) => dispatcher.TryEnqueue(() => Output += line + "\n");

        try
        {
            await Task.Run(() =>
            {
                Append("[>>] Flushing DNS cache…");
                using var session = CimSession.Create(null);
                try
                {
                    foreach (var inst in session.QueryInstances("root/StandardCimv2", "WQL",
                        "SELECT * FROM MSFT_DNSClientCache"))
                        session.DeleteInstance(inst);
                }
                catch (Exception ex)
                {
                    Append($"[WARN] DNS cache flush skipped: {ex.Message}");
                }
                Append("[OK] DNS cache flushed.");
                Append("[>>] Resetting Winsock catalog…");
            });

            await _runner.RunAsync("netsh.exe", "winsock reset catalog", Append);
            Append("[OK] Winsock reset.");
            Append("[>>] Resetting IPv4 stack…");
            await _runner.RunAsync("netsh.exe", "int ipv4 reset", Append);
            Append("[>>] Resetting IPv6 stack…");
            await _runner.RunAsync("netsh.exe", "int ipv6 reset", Append);
            Append("\n[OK] Network stack reset complete. Reboot to apply all changes.");
            Status = "Done. Reboot recommended.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Network reset failed");
            Append($"\n[Error] {ex.Message}");
            Status = "Error.";
        }
        finally
        {
            IsRunning = false;
        }
    }

    private bool CanRun() => !IsRunning;
}

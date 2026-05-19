using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Services;

namespace pcHealth.ViewModels;

public partial class WingetRepairViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private readonly IProcessRunner _runner;

    [ObservableProperty] public partial string Output { get; set; } = "";
    [ObservableProperty] public partial string Status { get; set; } = "";
    [ObservableProperty] public partial bool IsRunning { get; set; }

    public WingetRepairViewModel(IProcessRunner runner) => _runner = runner;

    [RelayCommand(CanExecute = nameof(CanRun), IncludeCancelCommand = true)]
    public async Task RunAsync(CancellationToken ct)
    {
        IsRunning = true;
        Output = "";
        Status = "Repairing winget…";

        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        void Append(string line) => dispatcher.TryEnqueue(() => Output += line + "\n");

        try
        {
            Append("[>>] Installing winget-install script from PSGallery…");
            await _runner.RunAsync("pwsh.exe",
                "-NoProfile -ExecutionPolicy Bypass -Command \"Install-Script -Name winget-install -Force -Scope CurrentUser\"",
                Append, ct);

            Append("\n[>>] Running winget-install…");
            await _runner.RunAsync("pwsh.exe",
                "-NoProfile -ExecutionPolicy Bypass -Command \"winget-install -Force\"",
                Append, ct);

            Append("\n[OK] Winget repair complete.");
            Status = "Done.";
        }
        catch (OperationCanceledException)
        {
            Output += "\n[Cancelled]";
            Status = "Cancelled.";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Winget repair failed");
            Output += $"\n[Error] {ex.Message}";
            Status = "Error.";
        }
        finally
        {
            IsRunning = false;
        }
    }

    private bool CanRun() => !IsRunning;
}

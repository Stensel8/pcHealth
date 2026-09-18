using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NLog;
using pcHealth.Models;
using pcHealth.Services;
using System.Collections.ObjectModel;

namespace pcHealth.ViewModels;

public partial class ProgramsViewModel : ObservableObject
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();
    private static readonly ProgramItem[] AllPrograms =
    [
        new ProgramItem { Name = "HWiNFO64",              Glyph = "", Note = "Hardware information and real-time monitoring", WingetId = "REALix.HWiNFO",                   ExeName = "HWiNFO64.exe",    RegistryName = "HWiNFO",          Category = "Hardware"  },
        new ProgramItem { Name = "HWMonitor",             Glyph = "", Note = "Voltage, temperature, and fan speed monitor",   WingetId = "CPUID.HWMonitor",                  ExeName = "HWMonitor.exe",   RegistryName = "HWMonitor",       Category = "Hardware"  },
        new ProgramItem { Name = "Prime95",               Glyph = "", Note = "CPU stress test and stability checker",          WingetId = "mersenne.prime95",                 ExeName = "prime95.exe",     RegistryName = "Prime95",         Category = "Hardware"  },
        new ProgramItem { Name = "CrystalDiskInfo",       Glyph = "", Note = "HDD/SSD S.M.A.R.T. health viewer",              WingetId = "CrystalDewWorld.CrystalDiskInfo",  ExeName = "DiskInfo64.exe",  RegistryName = "CrystalDiskInfo", Category = "Disk"      },
        new ProgramItem { Name = "CrystalDiskMark",       Glyph = "", Note = "Disk read/write benchmark tool",                 WingetId = "CrystalDewWorld.CrystalDiskMark", ExeName = "DiskMark64.exe",  RegistryName = "CrystalDiskMark", Category = "Disk"      },
        new ProgramItem { Name = "Malwarebytes AdwCleaner",Glyph = "",Note = "Removes adware, PUPs, and browser hijackers",   WingetId = "Malwarebytes.AdwCleaner",          ExeName = "AdwCleaner.exe",  RegistryName = "AdwCleaner",      Category = "Security"  },
        new ProgramItem { Name = "Windows PowerToys",     Glyph = "", Note = "Power-user utilities by Microsoft",              WingetId = "Microsoft.PowerToys",              ExeName = "PowerToys.exe",   RegistryName = "PowerToys",       Category = "Utilities" },
    ];

    private readonly ICliRunner _cli;
    private readonly IProcessRunner _runner;

    public ObservableCollection<ItemGroup<ProgramItem>> GroupedPrograms { get; } = new();

    public ProgramsViewModel(ICliRunner cli, IProcessRunner runner)
    {
        _cli = cli;
        _runner = runner;
        var categoryOrder = new[] { "Hardware", "Disk", "Security", "Utilities" };
        var groups = AllPrograms
            .GroupBy(p => p.Category)
            .OrderBy(g => { int i = Array.IndexOf(categoryOrder, g.Key); return i < 0 ? 999 : i; });
        foreach (var g in groups)
            GroupedPrograms.Add(new ItemGroup<ProgramItem>(g.Key, g));
    }

    [RelayCommand]
    public async Task CheckInstalledAsync()
    {
        var dispatcher = Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread();
        var tasks = AllPrograms
            .Where(p => !string.IsNullOrEmpty(p.RegistryName))
            .Select(p => Task.Run(() =>
            {
                try
                {
                    bool installed = _cli.IsInstalled(p.RegistryName);
                    dispatcher.TryEnqueue(() => p.IsInstalled = installed);
                }
                catch (Exception ex)
                {
                    Log.Debug(ex, "IsInstalled check failed for {Name}", p.Name);
                }
            }));
        await Task.WhenAll(tasks);
    }

    public void InstallOrOpen(ProgramItem item) => _ = InstallOrOpenCoreAsync(item);

    // Open if installed, install otherwise. Throws on error so callers can show feedback.
    public async Task InstallOrOpenAsync(ProgramItem item)
    {
        if (item.IsInstalled)
        {
            if (!string.IsNullOrEmpty(item.ExeName))
                _cli.OpenApp(item.ExeName, item.RegistryName);
        }
        else if (!string.IsNullOrEmpty(item.WingetId))
        {
            await RunWingetAsync(item, "install", "Installed");
        }
        else if (!string.IsNullOrEmpty(item.BrowserUrl))
        {
            _cli.OpenUri(item.BrowserUrl);
        }
    }

    public Task UpdateAsync(ProgramItem item) => RunWingetAsync(item, "upgrade", "Updated");

    public Task ForceInstallAsync(ProgramItem item) =>
        RunWingetAsync(item, "install", "Installed", force: true);

    // winget used to run in a console window that popped up over the app and
    // waited for a keypress. Its output goes to the card and the log instead:
    // a GUI should not hand you a terminal to read.
    private async Task RunWingetAsync(ProgramItem item, string verb, string done, bool force = false)
    {
        if (string.IsNullOrEmpty(item.WingetId) || item.IsBusy) return;

        var arguments =
            $"{verb} --id {item.WingetId} --accept-source-agreements --accept-package-agreements"
            + (force ? " --force" : "");

        item.IsBusy = true;
        item.Status = $"Starting {verb}...";
        try
        {
            var exitCode = await _runner.RunAsync("winget", arguments, line =>
            {
                Log.Debug("winget {Name}: {Line}", item.Name, line);
                // Progress bars redraw themselves into noise through a pipe;
                // only keep lines that read as a sentence.
                if (line.Length > 3 && !line.TrimStart().StartsWith('\u2588'))
                    item.Status = line.Trim();
            });

            item.Status = exitCode == 0 ? done : $"winget exited with code {exitCode}";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "winget {Verb} failed for {Name}", verb, item.Name);
            item.Status = "Could not run winget. Is App Installer present?";
        }
        finally
        {
            item.IsBusy = false;
            await CheckInstalledAsync();
        }
    }

    private async Task InstallOrOpenCoreAsync(ProgramItem item)
    {
        try { await InstallOrOpenAsync(item); }
        catch (Exception ex) { Log.Error(ex, "Could not install/open {Name}", item.Name); }
    }
}

namespace pcHealth.Pages;

public sealed partial class ProgramsPage : Page
{
    // All 7 program entries that mirror the CLI Programs Menu (options 1-7).
    // Options 8 (Tools), 9 (Main Menu), and 10 (Exit) are handled by
    // the NavigationView and are therefore not included here.
    //
    // The backing array is static (allocated once). The instance property
    // is required because x:Bind only works with instance members.
    private static readonly ProgramItem[] _programs = new[]
    {
        new ProgramItem
        {
            Name         = "HWiNFO64",
            Glyph        = "\uE950",
            Note         = "Hardware information and real-time monitoring",
            WingetId     = "REALix.HWiNFO",
            ExeName      = "HWiNFO64.exe",
            RegistryName = "HWiNFO",
        },
        new ProgramItem
        {
            Name         = "HWMonitor",
            Glyph        = "\uE950",
            Note         = "Voltage, temperature, and fan speed monitor",
            WingetId     = "CPUID.HWMonitor",
            ExeName      = "HWMonitor.exe",
            RegistryName = "HWMonitor",
        },
        new ProgramItem
        {
            Name         = "Malwarebytes AdwCleaner",
            Glyph        = "\uE9F5",
            Note         = "Removes adware, PUPs, and browser hijackers",
            WingetId     = "Malwarebytes.AdwCleaner",
            ExeName      = "AdwCleaner.exe",
            RegistryName = "AdwCleaner",
        },
        new ProgramItem
        {
            Name         = "CrystalDiskInfo",
            Glyph        = "\uEDA2",
            Note         = "HDD/SSD S.M.A.R.T. health viewer",
            WingetId     = "CrystalDewWorld.CrystalDiskInfo",
            ExeName      = "DiskInfo64.exe",
            RegistryName = "CrystalDiskInfo",
        },
        new ProgramItem
        {
            Name         = "CrystalDiskMark",
            Glyph        = "\uEDA2",
            Note         = "Disk read/write benchmark tool",
            WingetId     = "CrystalDewWorld.CrystalDiskMark",
            ExeName      = "DiskMark64.exe",
            RegistryName = "CrystalDiskMark",
        },
        new ProgramItem
        {
            Name         = "Prime95",
            Glyph        = "\uE9E9",
            Note         = "CPU stress test and stability checker",
            WingetId     = "mersenne.prime95",
            ExeName      = "prime95.exe",
            RegistryName = "Prime95",
        },
        new ProgramItem
        {
            Name         = "Windows PowerToys",
            Glyph        = "\uE90F",
            Note         = "Power-user utilities by Microsoft",
            WingetId     = "Microsoft.PowerToys",
            ExeName      = "PowerToys.exe",
            RegistryName = "PowerToys",
        },
    };

    // Instance property so x:Bind in ProgramsPage.xaml can reach it.
    public IReadOnlyList<ProgramItem> Programs => _programs;

    public ProgramsPage()
    {
        InitializeComponent();
    }

    protected override void OnNavigatedTo(Microsoft.UI.Xaml.Navigation.NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _ = CheckInstalledAsync(DispatcherQueue);
    }

    private static async Task CheckInstalledAsync(Microsoft.UI.Dispatching.DispatcherQueue dispatcher)
    {
        // Registry checks run in parallel on background threads.
        // Results are marshalled back to the UI thread via DispatcherQueue
        // because PropertyChanged must fire on the UI thread in WinUI 3.
        var tasks = _programs
            .Where(p => !string.IsNullOrEmpty(p.RegistryName))
            .Select(p => Task.Run(() =>
            {
                try
                {
                    bool installed = CliRunner.IsInstalled(p.RegistryName);
                    dispatcher.TryEnqueue(() => p.IsInstalled = installed);
                }
                catch (Exception ex)
                {
                    // Registry check failed for this entry; leave IsInstalled = false
                    // so the UI shows "Install" rather than crashing the whole scan.
                    System.Diagnostics.Debug.WriteLine(
                        $"[ProgramsPage] IsInstalled check failed for {p.Name}: {ex.Message}");
                }
            }));

        await Task.WhenAll(tasks);
    }

    private async void InstallBtn_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not ProgramItem item) return;

        if (item.IsInstalled)
        {
            var dialog = new ContentDialog
            {
                Title = item.Name,
                Content = $"{item.Name} is already installed.",
                PrimaryButtonText = "Open",
                SecondaryButtonText = "Update",
                CloseButtonText = "Cancel",
                DefaultButton = ContentDialogButton.Primary,
                XamlRoot = XamlRoot,
            };

            var result = await dialog.ShowAsync();

            try
            {
                if (result == ContentDialogResult.Primary && !string.IsNullOrEmpty(item.ExeName))
                    CliRunner.OpenApp(item.ExeName, item.RegistryName);
                else if (result == ContentDialogResult.Secondary && !string.IsNullOrEmpty(item.WingetId))
                    CliRunner.RunWinget(
                        $"upgrade --id {item.WingetId} " +
                        "--accept-source-agreements --accept-package-agreements");
            }
            catch (Exception ex)
            {
                _ = ShowErrorAsync(result == ContentDialogResult.Primary ? "Could not open program" : "Could not launch updater", ex.Message);
            }
            return;
        }

        try
        {
            if (!string.IsNullOrEmpty(item.WingetId))
            {
                CliRunner.RunWinget(
                    $"install --id {item.WingetId} " +
                    "--accept-source-agreements --accept-package-agreements");
            }
            else if (!string.IsNullOrEmpty(item.BrowserUrl))
            {
                CliRunner.OpenUri(item.BrowserUrl);
            }
        }
        catch (Exception ex)
        {
            _ = ShowErrorAsync("Could not launch installer", ex.Message);
        }
    }

    private async Task ShowErrorAsync(string title, string message)
    {
        var dialog = new ContentDialog
        {
            Title = title,
            Content = message,
            CloseButtonText = "OK",
            XamlRoot = XamlRoot,
        };
        await dialog.ShowAsync();
    }
}

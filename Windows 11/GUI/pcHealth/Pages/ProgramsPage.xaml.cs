using Microsoft.UI.Xaml;

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
            Name     = "HWiNFO64",
            Glyph    = "\uE950",
            Note     = "Hardware information and real-time monitoring",
            WingetId = "REALix.HWiNFO",
        },
        new ProgramItem
        {
            Name     = "HWMonitor",
            Glyph    = "\uE950",
            Note     = "Voltage, temperature, and fan speed monitor",
            WingetId = "CPUID.HWMonitor",
        },
        new ProgramItem
        {
            Name     = "Malwarebytes AdwCleaner",
            Glyph    = "\uE9F5",
            Note     = "Removes adware, PUPs, and browser hijackers",
            WingetId = "Malwarebytes.AdwCleaner",
        },
        new ProgramItem
        {
            Name     = "CrystalDiskInfo",
            Glyph    = "\uEDA2",
            Note     = "HDD/SSD S.M.A.R.T. health viewer",
            WingetId = "CrystalDewWorld.CrystalDiskInfo",
        },
        new ProgramItem
        {
            Name     = "CrystalDiskMark",
            Glyph    = "\uEDA2",
            Note     = "Disk read/write benchmark tool",
            WingetId = "CrystalDewWorld.CrystalDiskMark",
        },
        new ProgramItem
        {
            Name       = "Prime95",
            Glyph      = "\uE9E9",
            Note       = "CPU stress test and stability checker",
            BrowserUrl = "https://prime95.net/download/",
        },
        new ProgramItem
        {
            Name     = "Windows PowerToys",
            Glyph    = "\uE90F",
            Note     = "Power-user utilities by Microsoft",
            WingetId = "Microsoft.PowerToys",
        },
    };

    // Instance property so x:Bind in ProgramsPage.xaml can reach it.
    public IReadOnlyList<ProgramItem> Programs => _programs;

    public ProgramsPage()
    {
        InitializeComponent();
    }

    private void InstallBtn_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not ProgramItem item) return;

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
            _ = ShowErrorAsync(ex.Message);
        }
    }

    private async Task ShowErrorAsync(string message)
    {
        var dialog = new ContentDialog
        {
            Title           = "Could not launch installer",
            Content         = message,
            CloseButtonText = "OK",
            XamlRoot        = XamlRoot,
        };
        await dialog.ShowAsync();
    }
}

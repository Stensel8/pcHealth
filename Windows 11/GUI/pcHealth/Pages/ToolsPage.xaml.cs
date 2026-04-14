namespace pcHealth.Pages;

public sealed partial class ToolsPage : Page
{
    // All 23 tool entries that mirror the CLI Tools Menu (options 1-23).
    // Options 24 (Programs), 25 (Main Menu), and 26 (Exit) are handled
    // by the NavigationView and are therefore not included here.
    //
    // The backing array is static (allocated once). The instance property
    // is required because x:Bind only works with instance members.
    private static readonly ToolItem[] _tools = new[]
    {
        new ToolItem { Name = "System Information",          Glyph = "\uE7F4", Kind = ToolActionKind.Script,   Param = "Get-SystemInfo.ps1"       },
        new ToolItem { Name = "CPU / GPU / RAM Info",        Glyph = "\uE950", Kind = ToolActionKind.Script,   Param = "Get-HardwareInfo.ps1"     },
        new ToolItem { Name = "System File Scan",            Glyph = "\uE9F5", Note = "SFC",                   Kind = ToolActionKind.Script,   Param = "Invoke-SystemScan.ps1"    },
        new ToolItem { Name = "DISM Health Check",           Glyph = "\uE9F5", Kind = ToolActionKind.Script,   Param = "Invoke-DISMCheck.ps1"     },
        new ToolItem { Name = "Scan + Repair",               Glyph = "\uE9F5", Note = "SFC + DISM",            Kind = ToolActionKind.Script,   Param = "Invoke-ScanAndRepair.ps1" },
        new ToolItem { Name = "Battery Report",              Glyph = "\uE83F", Note = "laptop only",           Kind = ToolActionKind.Script,   Param = "Get-BatteryReport.ps1"    },
        new ToolItem { Name = "Windows Update",              Glyph = "\uE895", Kind = ToolActionKind.OpenUri,  Param = "ms-settings:windowsupdate"},
        new ToolItem { Name = "Disk Optimization",           Glyph = "\uEDA2", Kind = ToolActionKind.OpenApp,  Param = "dfrgui.exe"               },
        new ToolItem { Name = "Disk Cleanup",                Glyph = "\uE74D", Kind = ToolActionKind.OpenApp,  Param = "cleanmgr.exe"             },
        new ToolItem { Name = "Short Ping Test",             Glyph = "\uE877", Kind = ToolActionKind.Script,   Param = "Test-NetworkShort.ps1"    },
        new ToolItem { Name = "Continuous Ping Test",        Glyph = "\uE877", Kind = ToolActionKind.Script,   Param = "Test-NetworkContinuous.ps1"},
        new ToolItem { Name = "Traceroute to Google",        Glyph = "\uE8F4", Kind = ToolActionKind.Script,   Param = "Test-Traceroute.ps1"      },
        new ToolItem { Name = "Reset Network Stack",         Glyph = "\uE72C", Kind = ToolActionKind.Script,   Param = "Invoke-NetworkReset.ps1"  },
        new ToolItem { Name = "Update System Programs",      Glyph = "\uE895", Note = "winget",                Kind = ToolActionKind.Script,   Param = "Invoke-SystemUpdate.ps1"  },
        new ToolItem { Name = "Update HP Drivers",           Glyph = "\uE7F7", Note = "HP only",               Kind = ToolActionKind.Script,   Param = "Invoke-HPUpdate.ps1"      },
        new ToolItem { Name = "Restart Audio Drivers",       Glyph = "\uE767", Kind = ToolActionKind.Script,   Param = "Invoke-AudioRestart.ps1"  },
        new ToolItem { Name = "Open Battery Report",         Glyph = "\uE8A5", Kind = ToolActionKind.Script,   Param = "Open-BatteryReport.ps1"   },
        new ToolItem { Name = "Open CBS Log",                Glyph = "\uE8A5", Kind = ToolActionKind.Script,   Param = "Open-CBSLog.ps1"          },
        new ToolItem { Name = "Get Ninite",                  Glyph = "\uE896", Note = "Edge, Chrome, VLC, 7-Zip", Kind = ToolActionKind.Script, Param = "Get-Ninite.ps1"         },
        new ToolItem { Name = "Windows License Key",         Glyph = "\uE8D7", Kind = ToolActionKind.Navigate                                     },
        new ToolItem { Name = "BIOS Password Recovery",      Glyph = "\uE72E", Kind = ToolActionKind.Script,   Param = "Show-BIOSPasswordTool.ps1"},
        new ToolItem { Name = "Repair Boot Record",          Glyph = "\uE8E4", Note = "use with caution!",     Kind = ToolActionKind.Script,   Param = "Invoke-BootRepair.ps1"    },
        new ToolItem { Name = "Shutdown / Reboot / Log Off", Glyph = "\uE7E8", Kind = ToolActionKind.Script,   Param = "Invoke-PowerOptions.ps1"  },
    };

    // Instance property so x:Bind in ToolsPage.xaml can reach it.
    public IReadOnlyList<ToolItem> Tools => _tools;

    public ToolsPage()
    {
        InitializeComponent();
    }

    private void ToolsGrid_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not ToolItem item) return;

        try
        {
            switch (item.Kind)
            {
                case ToolActionKind.Script:
                    CliRunner.RunScript(item.Param);
                    break;

                case ToolActionKind.OpenApp:
                    CliRunner.OpenApp(item.Param);
                    break;

                case ToolActionKind.OpenUri:
                    CliRunner.OpenUri(item.Param);
                    break;

                case ToolActionKind.Navigate:
                    // Push LicenseKeyPage onto the frame's back stack so the
                    // NavigationView back button works without extra logic.
                    Frame.Navigate(typeof(LicenseKeyPage));
                    break;
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
            Title           = "Could not launch tool",
            Content         = message,
            CloseButtonText = "OK",
            XamlRoot        = XamlRoot,
        };
        await dialog.ShowAsync();
    }
}

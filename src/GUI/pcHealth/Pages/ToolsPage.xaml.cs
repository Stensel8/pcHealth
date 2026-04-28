namespace pcHealth.Pages;

public sealed partial class ToolsPage : Page
{
    private static readonly ToolItem[] _tools =
    [
        new ToolItem { Name = "System Information",          Glyph = "\uE7F4",                                   PageType = typeof(SystemInfoPage)        },
        new ToolItem { Name = "Hardware Information",         Glyph = "\uE950",                                   PageType = typeof(HardwareInfoPage)      },
        new ToolItem { Name = "Scan + Repair",               Glyph = "\uE9F5", Note = "SFC + DISM combined",     PageType = typeof(ScanRepairPage)         },
        new ToolItem { Name = "Battery Report",              Glyph = "\uE83F", Note = "laptop only",             PageType = typeof(BatteryReportPage)      },
        new ToolItem { Name = "Windows Update",              Glyph = "\uE895",                                   PageType = typeof(WindowsUpdatePage)     },
        new ToolItem { Name = "Disk Optimization",           Glyph = "\uEDA2",                                   PageType = typeof(DiskOptimizationPage)  },
        new ToolItem { Name = "Disk Cleanup",                Glyph = "\uE74D",                                   PageType = typeof(DiskCleanupPage)       },
        new ToolItem { Name = "Short Ping Test",             Glyph = "\uE877",                                   PageType = typeof(NetworkPingPage)       },
        new ToolItem { Name = "Continuous Ping Test",        Glyph = "\uE877",                                   PageType = typeof(NetworkContinuousPage) },
        new ToolItem { Name = "Traceroute to Google",        Glyph = "\uE8F4",                                   PageType = typeof(TraceroutePage)        },
        new ToolItem { Name = "Reset Network Stack",         Glyph = "\uE72C",                                   PageType = typeof(NetworkResetPage)      },
        new ToolItem { Name = "Update all packages",         Glyph = "\uE895", Note = "winget",                  PageType = typeof(SystemUpdatePage)      },
        new ToolItem { Name = "Update HP Drivers",           Glyph = "\uE7F7", Note = "HP only",                 PageType = typeof(HPUpdatePage)          },
        new ToolItem { Name = "Restart Audio Drivers",       Glyph = "\uE767",                                   PageType = typeof(AudioRestartPage)      },
        new ToolItem { Name = "Open Battery Report",         Glyph = "\uE8A5",                                   PageType = typeof(OpenBatteryReportPage) },
        new ToolItem { Name = "Open CBS Log",                Glyph = "\uE8A5",                                   PageType = typeof(CBSLogPage)            },
        new ToolItem { Name = "Get Ninite",                  Glyph = "\uE896", Note = "Edge, Chrome, VLC, 7-Zip",PageType = typeof(NinitePage)            },
        new ToolItem { Name = "Windows License Key",         Glyph = "\uE8D7",                                   PageType = typeof(LicenseKeyPage)        },
        new ToolItem { Name = "BIOS Password Recovery",      Glyph = "\uE72E",                                   PageType = typeof(BIOSPasswordPage)      },
        new ToolItem { Name = "Repair Boot Record",          Glyph = "\uE8E4", Note = "use with caution!",       PageType = typeof(BootRepairPage)         },
        new ToolItem { Name = "Shutdown / Reboot / Log Off", Glyph = "\uE7E8",                                   PageType = typeof(PowerOptionsPage)      },
        new ToolItem { Name = "Repair Winget",               Glyph = "\uE90F",                                   PageType = typeof(WingetRepairPage)      },
        new ToolItem { Name = "Security Status",             Glyph = "", Note = "Defender, BitLocker, TPM", PageType = typeof(SecurityCheckPage) },
    ];

    public IReadOnlyList<ToolItem> Tools => _tools;

    public ToolsPage()
    {
        InitializeComponent();
    }

    private void ToolsGrid_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not ToolItem item) return;
        Frame.Navigate(item.PageType);
    }
}

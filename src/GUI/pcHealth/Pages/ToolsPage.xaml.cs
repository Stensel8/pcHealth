namespace pcHealth.Pages;

public sealed partial class ToolsPage : Page
{
    private static readonly ToolItem[] _tools =
    [
        // ── Information ──────────────────────────────────────────────────────────
        new ToolItem { Name = "System Information",          Glyph = "",                                    PageType = typeof(SystemInfoPage),        Category = "Information", Platforms = new[] { "Windows", "Linux" } },
        new ToolItem { Name = "Hardware Information",         Glyph = "",                                    PageType = typeof(HardwareInfoPage),      Category = "Information", Platforms = new[] { "Windows", "Linux" } },
        new ToolItem { Name = "Windows License Key",          Glyph = "",                                    PageType = typeof(LicenseKeyPage),        Category = "Information", Platforms = new[] { "Windows" } },
        // ── Network ──────────────────────────────────────────────────────────────
        new ToolItem { Name = "Short Ping Test",              Glyph = "",                                    PageType = typeof(NetworkPingPage),       Category = "Network",     Platforms = new[] { "Windows", "Linux" } },
        new ToolItem { Name = "Continuous Ping Test",         Glyph = "",                                    PageType = typeof(NetworkContinuousPage), Category = "Network",     Platforms = new[] { "Windows", "Linux" } },
        new ToolItem { Name = "Traceroute to Google",         Glyph = "",                                    PageType = typeof(TraceroutePage),        Category = "Network",     Platforms = new[] { "Windows", "Linux" } },
        new ToolItem { Name = "Reset Network Stack",          Glyph = "",                                    PageType = typeof(NetworkResetPage),      Category = "Network",     Platforms = new[] { "Windows" } },
        // ── Disk ─────────────────────────────────────────────────────────────────
        new ToolItem { Name = "Disk Optimization",            Glyph = "",                                    PageType = typeof(DiskOptimizationPage),  Category = "Disk",        Platforms = new[] { "Windows" } },
        new ToolItem { Name = "Disk Cleanup",                 Glyph = "",                                    PageType = typeof(DiskCleanupPage),       Category = "Disk",        Platforms = new[] { "Windows", "Linux" } },
        // ── Updates ──────────────────────────────────────────────────────────────
        new ToolItem { Name = "Windows Update",               Glyph = "",                                    PageType = typeof(WindowsUpdatePage),     Category = "Updates",     Platforms = new[] { "Windows" } },
        new ToolItem { Name = "Update all packages",          Glyph = "",  Note = "winget",                  PageType = typeof(SystemUpdatePage),      Category = "Updates",     Platforms = new[] { "Windows" } },
        new ToolItem { Name = "Update HP Drivers",            Glyph = "",  Note = "HP only",                 PageType = typeof(HPUpdatePage),          Category = "Updates",     Platforms = new[] { "Windows" } },
        new ToolItem { Name = "Get Ninite",                   Glyph = "",  Note = "Edge, Chrome, VLC, 7-Zip",PageType = typeof(NinitePage),            Category = "Updates",     Platforms = new[] { "Windows" } },
        // ── Maintenance ──────────────────────────────────────────────────────────
        new ToolItem { Name = "Scan + Repair",                Glyph = "",  Note = "SFC + DISM combined",     PageType = typeof(ScanRepairPage),        Category = "Maintenance", Platforms = new[] { "Windows" } },
        new ToolItem { Name = "Repair Boot Record",           Glyph = "",  Note = "use with caution!",       PageType = typeof(BootRepairPage),        Category = "Maintenance", Platforms = new[] { "Windows" } },
        new ToolItem { Name = "Open CBS Log",                 Glyph = "",                                    PageType = typeof(CBSLogPage),            Category = "Maintenance", Platforms = new[] { "Windows" } },
        new ToolItem { Name = "Repair Winget",                Glyph = "",                                    PageType = typeof(WingetRepairPage),      Category = "Maintenance", Platforms = new[] { "Windows" } },
        // ── Security ─────────────────────────────────────────────────────────────
        new ToolItem { Name = "BIOS Password Recovery",       Glyph = "",                                    PageType = typeof(BIOSPasswordPage),      Category = "Security",    Platforms = new[] { "Windows", "Linux" } },
        // ── Hardware ─────────────────────────────────────────────────────────────
        new ToolItem { Name = "Battery Report",               Glyph = "",  Note = "laptop only",             PageType = typeof(BatteryReportPage),     Category = "Hardware",    Platforms = new[] { "Windows" } },
        new ToolItem { Name = "Open Battery Report",          Glyph = "",                                    PageType = typeof(OpenBatteryReportPage), Category = "Hardware",    Platforms = new[] { "Windows" } },
        new ToolItem { Name = "Restart Audio Drivers",        Glyph = "",                                    PageType = typeof(AudioRestartPage),      Category = "Hardware",    Platforms = new[] { "Windows" } },
        // ── System ───────────────────────────────────────────────────────────────
        new ToolItem { Name = "Shutdown / Reboot / Log Off",  Glyph = "",                                    PageType = typeof(PowerOptionsPage),      Category = "System",      Platforms = new[] { "Windows", "Linux" } },
    ];

    public System.Collections.ObjectModel.ObservableCollection<pcHealth.Models.ItemGroup<ToolItem>> GroupedTools { get; } = new();

    public ToolsPage()
    {
        InitializeComponent();

        bool isWindows = System.OperatingSystem.IsWindows();
        var categoryOrder = new[] { "Information", "Network", "Disk", "Updates", "Maintenance", "Security", "Hardware", "System" };
        var groups = _tools
            .Where(t => isWindows ? t.Platforms.Contains("Windows") : t.Platforms.Contains("Linux"))
            .GroupBy(t => t.Category)
            .OrderBy(g => { int i = Array.IndexOf(categoryOrder, g.Key); return i < 0 ? 999 : i; });

        foreach (var g in groups)
            GroupedTools.Add(new pcHealth.Models.ItemGroup<ToolItem>(g.Key, g));

        var cvs = new Microsoft.UI.Xaml.Data.CollectionViewSource
        {
            IsSourceGrouped = true,
            Source = GroupedTools
        };
        ToolsGrid.ItemsSource = cvs.View;
    }

    private void ToolsGrid_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not ToolItem item) return;
        Frame.Navigate(item.PageType);
    }
}

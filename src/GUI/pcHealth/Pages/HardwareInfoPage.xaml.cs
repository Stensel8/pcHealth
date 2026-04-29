using Microsoft.Management.Infrastructure;
using System.Text;

namespace pcHealth.Pages;

public sealed partial class HardwareInfoPage : Page
{
    private string _copyText = "";

    public HardwareInfoPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            var data = await Task.Run(GatherData);
            PopulateUi(data);
        }
        catch (Exception ex)
        {
            LoadingPanel.Visibility = Visibility.Collapsed;
            ErrorBar.Message = ex.Message;
            ErrorBar.IsOpen = true;
        }
    }

    private static (
        List<(string, string)> Cpu,
        List<(string, string)> Gpu,
        List<(string, string)> Ram,
        List<(string, string)> Storage,
        List<(string, string)> Chipset
    ) GatherData()
    {
        var cpu = new List<(string, string)>();
        var gpu = new List<(string, string)>();
        var ram = new List<(string, string)>();
        var storage = new List<(string, string)>();
        var chipset = new List<(string, string)>();

        using var session = CimSession.Create(null);

        // CPU
        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed FROM Win32_Processor"))
        {
            cpu.Add(("Name", inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim() ?? "Unknown"));
            cpu.Add(("Cores", inst.CimInstanceProperties["NumberOfCores"]?.Value?.ToString() ?? "?"));
            cpu.Add(("Threads", inst.CimInstanceProperties["NumberOfLogicalProcessors"]?.Value?.ToString() ?? "?"));
            if (inst.CimInstanceProperties["MaxClockSpeed"]?.Value is uint mhz)
                cpu.Add(("Base Speed", $"{mhz} MHz"));
        }

        // GPU — VRAM from registry (64-bit value), fallback to AdapterRAM
        var regVram = ReadGpuVramFromRegistry();

        int gpuIdx = 0;
        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Name, VideoProcessor, DriverVersion, DriverDate, AdapterRAM FROM Win32_VideoController"))
        {
            var name = inst.CimInstanceProperties["Name"]?.Value?.ToString() ?? "Unknown";
            var prefix = gpuIdx > 0 ? $"GPU {gpuIdx + 1} - " : "";

            gpu.Add(($"{prefix}Name", name));
            gpu.Add(($"{prefix}Video Processor", inst.CimInstanceProperties["VideoProcessor"]?.Value?.ToString() ?? "N/A"));
            gpu.Add(($"{prefix}Driver Version", inst.CimInstanceProperties["DriverVersion"]?.Value?.ToString() ?? "N/A"));

            if (inst.CimInstanceProperties["DriverDate"]?.Value is DateTime drvDate)
                gpu.Add(($"{prefix}Driver Date", drvDate.ToString("yyyy-MM-dd")));

            // VRAM: try registry first, then AdapterRAM
            string vramStr = "Shared / Unknown";
            if (regVram.TryGetValue(name, out var regBytes) && regBytes > 0)
                vramStr = $"{Math.Round(regBytes / 1073741824.0, 2)} GB";
            else if (inst.CimInstanceProperties["AdapterRAM"]?.Value is uint adapterRam && adapterRam >= 1073741824u)
                vramStr = $"{Math.Round(adapterRam / 1073741824.0, 2)} GB";

            gpu.Add(($"{prefix}VRAM", vramStr));

            if (gpuIdx > 0) gpu.Add(("", ""));
            gpuIdx++;
        }

        // RAM modules
        ulong totalRam = 0;
        int slotIdx = 1;
        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT BankLabel, Capacity, Speed, PartNumber, Manufacturer FROM Win32_PhysicalMemory"))
        {
            var slot = inst.CimInstanceProperties["BankLabel"]?.Value?.ToString() ?? $"Slot {slotIdx}";
            var cap = inst.CimInstanceProperties["Capacity"]?.Value is ulong c ? c : 0UL;
            var speed = inst.CimInstanceProperties["Speed"]?.Value?.ToString() ?? "?";
            var part = inst.CimInstanceProperties["PartNumber"]?.Value?.ToString()?.Trim() ?? "Unknown";
            var mfr = inst.CimInstanceProperties["Manufacturer"]?.Value?.ToString()?.Trim() ?? "Unknown";

            totalRam += cap;
            var prefix = slotIdx > 1 ? $"Slot {slotIdx} - " : "Slot 1 - ";
            ram.Add(($"{prefix}Slot", slot));
            ram.Add(($"{prefix}Capacity", $"{Math.Round(cap / 1073741824.0, 0)} GB"));
            ram.Add(($"{prefix}Speed", $"{speed} MT/s"));
            ram.Add(($"{prefix}Part Number", part));
            ram.Add(($"{prefix}Manufacturer", ResolveRamManufacturer(mfr, part)));
            slotIdx++;
        }
        if (totalRam > 0)
            ram.Add(("Total Installed", $"{Math.Round(totalRam / 1073741824.0, 0)} GB"));

        // Storage
        int diskIdx = 1;
        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Model, Size, InterfaceType FROM Win32_DiskDrive"))
        {
            var model = inst.CimInstanceProperties["Model"]?.Value?.ToString() ?? "Unknown";
            var iface = inst.CimInstanceProperties["InterfaceType"]?.Value?.ToString() ?? "Unknown";
            var prefix = diskIdx > 1 ? $"Disk {diskIdx} - " : "Disk 1 - ";

            storage.Add(($"{prefix}Model", model));
            if (inst.CimInstanceProperties["Size"]?.Value is ulong sz && sz > 0)
                storage.Add(($"{prefix}Size", $"{Math.Round(sz / 1073741824.0, 0)} GB"));
            storage.Add(($"{prefix}Interface", iface));
            diskIdx++;
        }

        // Chipset — SMBus controller via PnP
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name, Status FROM Win32_PnPEntity WHERE Name LIKE '%SMBus%'"))
            {
                var name = inst.CimInstanceProperties["Name"]?.Value?.ToString() ?? "Unknown";
                var status = inst.CimInstanceProperties["Status"]?.Value?.ToString() ?? "Unknown";
                chipset.Add(("Device", name));
                chipset.Add(("Status", status));
                break;
            }
        }
        catch (Exception) { }

        if (chipset.Count == 0)
            chipset.Add(("Status", "SMBus controller not found"));

        return (cpu, gpu, ram, storage, chipset);
    }

    private static Dictionary<string, long> ReadGpuVramFromRegistry()
    {
        var result = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
        try
        {
            const string classPath = @"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}";
            using var classKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(classPath);
            if (classKey is null) return result;

            foreach (var subName in classKey.GetSubKeyNames())
            {
                if (!int.TryParse(subName, out _)) continue;
                using var sub = classKey.OpenSubKey(subName);
                if (sub is null) continue;

                var adapterName = sub.GetValue("HardwareInformation.AdapterString") as string;
                var vramBytes = sub.GetValue("HardwareInformation.qwMemorySize") as byte[];
                if (adapterName is not null && vramBytes is { Length: >= 8 })
                    result[adapterName] = BitConverter.ToInt64(vramBytes, 0);
            }
        }
        catch (Exception) { }
        return result;
    }

    private static string ResolveRamManufacturer(string manufacturer, string partNumber)
    {
        if (!string.IsNullOrEmpty(manufacturer) && manufacturer != "Unknown" && manufacturer != " ")
            return manufacturer;

        return partNumber switch
        {
            var p when p.StartsWith("CM", StringComparison.Ordinal) => "Corsair",
            var p when p.StartsWith("CT", StringComparison.Ordinal) || p.StartsWith("BL", StringComparison.Ordinal) => "Crucial",
            var p when p.StartsWith("KVR", StringComparison.Ordinal) || p.StartsWith("HX", StringComparison.Ordinal) => "Kingston",
            var p when p.StartsWith("F4-", StringComparison.Ordinal) || p.StartsWith("F5-", StringComparison.Ordinal) => "G.Skill",
            var p when p.StartsWith("MTA", StringComparison.Ordinal) || p.StartsWith("MT", StringComparison.Ordinal) => "Micron",
            var p when p.StartsWith("M378", StringComparison.Ordinal) || p.StartsWith("M471", StringComparison.Ordinal) => "Samsung",
            var p when p.StartsWith("AD4", StringComparison.Ordinal) || p.StartsWith("AX4", StringComparison.Ordinal) => "ADATA",
            _ => "Unknown",
        };
    }

    private void PopulateUi((
        List<(string, string)> Cpu,
        List<(string, string)> Gpu,
        List<(string, string)> Ram,
        List<(string, string)> Storage,
        List<(string, string)> Chipset) data)
    {
        LoadingPanel.Visibility = Visibility.Collapsed;

        PopulateCard(CpuRows, data.Cpu, CpuCard);
        if (data.Gpu.Count > 0) PopulateCard(GpuRows, data.Gpu, GpuCard);
        PopulateCard(RamRows, data.Ram, RamCard);
        PopulateCard(StorageRows, data.Storage, StorageCard);
        PopulateCard(ChipsetRows, data.Chipset, ChipsetCard);

        var sb = new StringBuilder();
        sb.AppendLine("pcHealth - Hardware Information");
        sb.AppendLine($"Generated: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
        sb.AppendLine();
        AppendSection(sb, "CPU", data.Cpu);
        AppendSection(sb, "GPU", data.Gpu);
        AppendSection(sb, "Memory (RAM)", data.Ram);
        AppendSection(sb, "Storage", data.Storage);
        AppendSection(sb, "Chipset", data.Chipset);
        _copyText = sb.ToString();
        CopyBtn.IsEnabled = true;
    }

    private void PopulateCard(StackPanel panel, List<(string Label, string Value)> rows, Border card)
    {
        foreach (var (label, value) in rows)
            AddRow(panel, label, value);
        card.Visibility = Visibility.Visible;
    }

    private static void AppendSection(StringBuilder sb, string title, List<(string Label, string Value)> rows)
    {
        sb.AppendLine(title);
        foreach (var (label, value) in rows)
            sb.AppendLine($"  {label,-22}: {value}");
        sb.AppendLine();
    }

    private void AddRow(StackPanel panel, string label, string value)
    {
        if (string.IsNullOrEmpty(label) && string.IsNullOrEmpty(value))
        {
            panel.Children.Add(new Border { Height = 8 });
            return;
        }

        var grid = new Grid { ColumnSpacing = 12, Margin = new Thickness(0, 1, 0, 1) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(180) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var lbl = new TextBlock
        {
            Text = label,
            Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            VerticalAlignment = VerticalAlignment.Top,
        };
        var val = new TextBlock
        {
            Text = value,
            IsTextSelectionEnabled = true,
            TextWrapping = TextWrapping.Wrap,
        };

        Grid.SetColumn(val, 1);
        grid.Children.Add(lbl);
        grid.Children.Add(val);
        panel.Children.Add(grid);
    }

    private void CopyBtn_Click(object sender, RoutedEventArgs e)
    {
        var pkg = new DataPackage();
        pkg.SetText(_copyText);
        Clipboard.SetContent(pkg);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

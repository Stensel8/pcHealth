using Microsoft.Management.Infrastructure;
using System.Text;

namespace pcHealth.Pages;

public sealed partial class SystemInfoPage : Page
{
    private string _copyText = "";

    public SystemInfoPage()
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
        List<(string, string)> Os,
        List<(string, string)> Machine,
        List<(string, string)> Firmware,
        List<(string, string)> Hardware
    ) GatherData()
    {
        var os = new List<(string, string)>();
        var machine = new List<(string, string)>();
        var firmware = new List<(string, string)>();
        var hardware = new List<(string, string)>();

        using var session = CimSession.Create(null);

        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Caption, BuildNumber, OSArchitecture, LastBootUpTime, InstallDate, SystemDirectory " +
            "FROM Win32_OperatingSystem"))
        {
            os.Add(("OS Name", inst.CimInstanceProperties["Caption"]?.Value?.ToString() ?? "Unknown"));

            var buildNum = inst.CimInstanceProperties["BuildNumber"]?.Value?.ToString() ?? "";
            try
            {
                using var ntKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                    @"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
                var displayVer = ntKey?.GetValue("DisplayVersion") as string;
                var ubr = ntKey?.GetValue("UBR");
                var fullBuild = ubr is not null ? $"{buildNum}.{ubr}" : buildNum;
                if (!string.IsNullOrEmpty(displayVer))
                    os.Add(("Windows Version", displayVer));
                os.Add(("OS Build", fullBuild));
            }
            catch (Exception)
            {
                os.Add(("OS Build", buildNum));
            }

            os.Add(("Architecture", inst.CimInstanceProperties["OSArchitecture"]?.Value?.ToString() ?? "Unknown"));

            if (inst.CimInstanceProperties["LastBootUpTime"]?.Value is DateTime lastBoot)
                os.Add(("Last Boot", lastBoot.ToString("yyyy-MM-dd HH:mm:ss")));
            if (inst.CimInstanceProperties["InstallDate"]?.Value is DateTime installDate)
                os.Add(("Install Date", installDate.ToString("yyyy-MM-dd")));

            os.Add(("System Directory", inst.CimInstanceProperties["SystemDirectory"]?.Value?.ToString() ?? "Unknown"));
            break;
        }

        machine.Add(("Computer Name", Environment.MachineName));
        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Manufacturer, Model, TotalPhysicalMemory FROM Win32_ComputerSystem"))
        {
            machine.Add(("Manufacturer", inst.CimInstanceProperties["Manufacturer"]?.Value?.ToString() ?? "Unknown"));
            machine.Add(("Model", inst.CimInstanceProperties["Model"]?.Value?.ToString() ?? "Unknown"));

            if (inst.CimInstanceProperties["TotalPhysicalMemory"]?.Value is ulong ram)
                hardware.Add(("Total RAM", $"{Math.Round(ram / 1073741824.0, 2)} GB"));
            break;
        }

        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Name FROM Win32_Processor"))
        {
            hardware.Add(("Processor", inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim() ?? "Unknown"));
            break;
        }

        // Firmware type from registry
        try
        {
            using var ctrlKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SYSTEM\CurrentControlSet\Control");
            firmware.Add(("Firmware Type", ctrlKey?.GetValue("PEFirmwareType") is int t
                ? (t == 2 ? "UEFI" : t == 1 ? "BIOS" : "Unknown") : "Unknown"));
        }
        catch (Exception)
        {
            firmware.Add(("Firmware Type", "Unknown"));
        }

        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT SMBIOSBIOSVersion, ReleaseDate FROM Win32_BIOS"))
        {
            firmware.Add(("Firmware Version", inst.CimInstanceProperties["SMBIOSBIOSVersion"]?.Value?.ToString() ?? "Unknown"));
            if (inst.CimInstanceProperties["ReleaseDate"]?.Value is DateTime fwDate)
                firmware.Add(("Firmware Date", fwDate.ToString("yyyy-MM-dd")));
            break;
        }

        try
        {
            using var sbKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SYSTEM\CurrentControlSet\Control\SecureBoot\State");
            firmware.Add(("Secure Boot", sbKey?.GetValue("UEFISecureBootEnabled") is int sb
                ? (sb == 1 ? "Enabled" : "Disabled") : "N/A"));
        }
        catch (Exception)
        {
            firmware.Add(("Secure Boot", "N/A"));
        }

        try
        {
            foreach (var inst in session.QueryInstances(
                "root/cimv2/security/microsofttpm", "WQL", "SELECT SpecVersion FROM Win32_Tpm"))
            {
                var spec = inst.CimInstanceProperties["SpecVersion"]?.Value?.ToString();
                firmware.Add(("TPM Version", !string.IsNullOrEmpty(spec)
                    ? spec.Split(',')[0].Trim() : "N/A"));
                break;
            }
        }
        catch (Exception)
        {
            firmware.Add(("TPM Version", "N/A"));
        }

        return (os, machine, firmware, hardware);
    }

    private void PopulateUi((
        List<(string, string)> Os,
        List<(string, string)> Machine,
        List<(string, string)> Firmware,
        List<(string, string)> Hardware) data)
    {
        LoadingPanel.Visibility = Visibility.Collapsed;

        PopulateCard(OsRows, data.Os, OsCard);
        PopulateCard(MachineRows, data.Machine, MachineCard);
        PopulateCard(FirmwareRows, data.Firmware, FirmwareCard);
        PopulateCard(HardwareRows, data.Hardware, HardwareCard);

        var sb = new StringBuilder();
        sb.AppendLine("pcHealth - System Information");
        sb.AppendLine($"Generated: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
        sb.AppendLine();
        AppendSection(sb, "Operating System", data.Os);
        AppendSection(sb, "Machine", data.Machine);
        AppendSection(sb, "Firmware & Security", data.Firmware);
        AppendSection(sb, "Hardware Summary", data.Hardware);
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

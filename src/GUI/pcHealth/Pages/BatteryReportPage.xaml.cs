using Microsoft.Management.Infrastructure;
using System.Diagnostics;

namespace pcHealth.Pages;

public sealed partial class BatteryReportPage : Page
{
    public BatteryReportPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            var rows = await Task.Run(GatherBatteryData);
            LoadingPanel.Visibility = Visibility.Collapsed;

            if (rows is null)
            {
                NoBatteryBar.IsOpen = true;
                return;
            }

            foreach (var (label, value) in rows)
                AddRow(StatusRows, label, value);

            StatusCard.Visibility = Visibility.Visible;
            ReportCard.Visibility = Visibility.Visible;
        }
        catch (Exception ex)
        {
            LoadingPanel.Visibility = Visibility.Collapsed;
            ErrorBar.Message = ex.Message;
            ErrorBar.IsOpen = true;
        }
    }

    private static List<(string, string)>? GatherBatteryData()
    {
        using var session = CimSession.Create(null);
        var rows = new List<(string, string)>();
        bool found = false;

        foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
            "SELECT Name, BatteryStatus, EstimatedChargeRemaining, EstimatedRunTime, Chemistry " +
            "FROM Win32_Battery"))
        {
            found = true;
            rows.Add(("Name", inst.CimInstanceProperties["Name"]?.Value?.ToString() ?? "Unknown"));

            var statusCode = inst.CimInstanceProperties["BatteryStatus"]?.Value;
            rows.Add(("Status", statusCode is ushort s ? DecodeBatteryStatus(s) : "Unknown"));

            if (inst.CimInstanceProperties["EstimatedChargeRemaining"]?.Value is ushort charge)
                rows.Add(("Charge", $"{charge}%"));

            if (inst.CimInstanceProperties["EstimatedRunTime"]?.Value is uint runtime && runtime < 71582)
                rows.Add(("Estimated Run Time", $"{runtime} min"));

            if (inst.CimInstanceProperties["Chemistry"]?.Value is ushort chem)
                rows.Add(("Chemistry", DecodeChemistry(chem)));

            break;
        }

        return found ? rows : null;
    }

    private static string DecodeBatteryStatus(ushort code) => code switch
    {
        1  => "Discharging",
        2  => "On AC power",
        3  => "Fully charged",
        4  => "Low",
        5  => "Critical",
        6  => "Charging",
        7  => "Charging (High)",
        8  => "Charging (Low)",
        9  => "Charging (Critical)",
        11 => "Partially charged",
        _  => $"Unknown ({code})",
    };

    private static string DecodeChemistry(ushort code) => code switch
    {
        3 => "Lead Acid",
        4 => "Nickel Cadmium",
        5 => "Nickel Metal Hydride",
        6 => "Lithium-ion",
        7 => "Zinc Air",
        8 => "Lithium Polymer",
        _ => "Unknown",
    };

    private async void GenerateBtn_Click(object sender, RoutedEventArgs e)
    {
        GenerateBtn.IsEnabled = false;
        GenerateProgress.IsActive = true;
        GenerateStatusText.Text = "Generating report…";

        try
        {
            var reportPath = Path.Combine(Path.GetTempPath(), "pcHealth-battery-report.html");

            await Task.Run(() =>
            {
                using var proc = Process.Start(new ProcessStartInfo
                {
                    FileName = "powercfg.exe",
                    Arguments = $"/batteryreport /output \"{reportPath}\" /quiet",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                });
                proc?.WaitForExit(30_000);
            });

            if (File.Exists(reportPath))
            {
                GenerateStatusText.Text = "Report generated.";
                Process.Start(new ProcessStartInfo(reportPath) { UseShellExecute = true });
            }
            else
            {
                GenerateStatusText.Text = "No battery report generated — battery may not be present.";
            }
        }
        catch (Exception ex)
        {
            GenerateStatusText.Text = $"Failed: {ex.Message}";
        }
        finally
        {
            GenerateProgress.IsActive = false;
            GenerateBtn.IsEnabled = true;
        }
    }

    private void AddRow(StackPanel panel, string label, string value)
    {
        var grid = new Grid { ColumnSpacing = 12, Margin = new Thickness(0, 1, 0, 1) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(180) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        grid.Children.Add(new TextBlock
        {
            Text = label,
            Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            VerticalAlignment = VerticalAlignment.Top,
        });

        var val = new TextBlock { Text = value, IsTextSelectionEnabled = true };
        Grid.SetColumn(val, 1);
        grid.Children.Add(val);
        panel.Children.Add(grid);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

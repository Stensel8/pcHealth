using Microsoft.Management.Infrastructure;
using Microsoft.UI.Xaml.Media;
using System.Diagnostics;
using System.Text;

namespace pcHealth.Pages;

public sealed partial class SecurityCheckPage : Page
{
    private string _copyText = "";

    public SecurityCheckPage()
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

    private enum CheckStatus { Good, Warning, Bad, Unknown }

    private record SecurityRow(string Label, string Value, CheckStatus Status);

    private static (
        List<SecurityRow> Defender,
        List<SecurityRow> BitLocker,
        List<SecurityRow> SecureBoot,
        List<SecurityRow> Tpm
    ) GatherData()
    {
        var defender = new List<SecurityRow>();
        var bitlocker = new List<SecurityRow>();
        var secureBoot = new List<SecurityRow>();
        var tpm = new List<SecurityRow>();

        using var session = CimSession.Create(null);

        // Windows Defender via MSFT_MpComputerStatus (modern Defender API, no deprecated WMI)
        try
        {
            foreach (var inst in session.QueryInstances(
                @"root\Microsoft\Windows\Defender", "WQL",
                "SELECT AMServiceEnabled, RealTimeProtectionEnabled, AntivirusEnabled, AntispywareEnabled FROM MSFT_MpComputerStatus"))
            {
                bool svc    = inst.CimInstanceProperties["AMServiceEnabled"]?.Value is bool b1 && b1;
                bool rt     = inst.CimInstanceProperties["RealTimeProtectionEnabled"]?.Value is bool b2 && b2;
                bool av     = inst.CimInstanceProperties["AntivirusEnabled"]?.Value is bool b3 && b3;
                bool asp    = inst.CimInstanceProperties["AntispywareEnabled"]?.Value is bool b4 && b4;

                defender.Add(new SecurityRow("Service",               svc ? "Running"  : "Stopped",  svc ? CheckStatus.Good : CheckStatus.Bad));
                defender.Add(new SecurityRow("Real-time Protection",  rt  ? "Enabled"  : "Disabled", rt  ? CheckStatus.Good : CheckStatus.Bad));
                defender.Add(new SecurityRow("Antivirus",             av  ? "Enabled"  : "Disabled", av  ? CheckStatus.Good : CheckStatus.Bad));
                defender.Add(new SecurityRow("Antispyware",           asp ? "Enabled"  : "Disabled", asp ? CheckStatus.Good : CheckStatus.Bad));
                break;
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[SecurityCheck] Defender query failed: {ex.Message}");
            defender.Add(new SecurityRow("Status", "Query failed", CheckStatus.Unknown));
        }

        if (defender.Count == 0)
            defender.Add(new SecurityRow("Status", "Not available", CheckStatus.Unknown));

        // BitLocker via Win32_EncryptableVolume
        try
        {
            bool anyDrive = false;
            foreach (var inst in session.QueryInstances(
                @"ROOT\cimv2\Security\MicrosoftVolumeEncryption", "WQL",
                "SELECT DriveLetter, ProtectionStatus FROM Win32_EncryptableVolume"))
            {
                var drive = inst.CimInstanceProperties["DriveLetter"]?.Value?.ToString() ?? "?";
                var raw   = inst.CimInstanceProperties["ProtectionStatus"]?.Value;
                // ProtectionStatus is uint32: 0 = Unprotected, 1 = Protected, 2 = Unknown
                int ps = raw is uint u ? (int)u : raw is int i ? i : -1;
                var (label, status) = ps switch
                {
                    1 => ("Encrypted",     CheckStatus.Good),
                    0 => ("Not encrypted", CheckStatus.Warning),
                    _ => ("Unknown",       CheckStatus.Unknown),
                };
                bitlocker.Add(new SecurityRow(drive, label, status));
                anyDrive = true;
            }
            if (!anyDrive)
                bitlocker.Add(new SecurityRow("Status", "No encryptable drives found", CheckStatus.Unknown));
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[SecurityCheck] BitLocker query failed: {ex.Message}");
            bitlocker.Add(new SecurityRow("Status", "Query failed (requires elevation)", CheckStatus.Unknown));
        }

        // Secure Boot via registry (reliable, no deprecated API)
        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SYSTEM\CurrentControlSet\Control\SecureBoot\State");
            bool on = key?.GetValue("UEFISecureBootEnabled") is int v && v == 1;
            secureBoot.Add(new SecurityRow("Secure Boot", on ? "Enabled" : "Disabled",
                on ? CheckStatus.Good : CheckStatus.Warning));
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[SecurityCheck] Secure Boot query failed: {ex.Message}");
            secureBoot.Add(new SecurityRow("Secure Boot", "N/A (legacy BIOS?)", CheckStatus.Unknown));
        }

        // TPM via Win32_Tpm
        try
        {
            bool found = false;
            foreach (var inst in session.QueryInstances(
                "root/cimv2/security/microsofttpm", "WQL",
                "SELECT IsActivated_InitialValue, IsEnabled_InitialValue, SpecVersion FROM Win32_Tpm"))
            {
                bool activated = inst.CimInstanceProperties["IsActivated_InitialValue"]?.Value is bool a && a;
                bool enabled   = inst.CimInstanceProperties["IsEnabled_InitialValue"]?.Value is bool en && en;
                var spec       = inst.CimInstanceProperties["SpecVersion"]?.Value?.ToString();
                var version    = !string.IsNullOrEmpty(spec) ? spec.Split(',')[0].Trim() : "Unknown";

                tpm.Add(new SecurityRow("Version",   version,                   version != "Unknown" ? CheckStatus.Good : CheckStatus.Unknown));
                tpm.Add(new SecurityRow("Enabled",   enabled   ? "Yes" : "No",  enabled   ? CheckStatus.Good : CheckStatus.Bad));
                tpm.Add(new SecurityRow("Activated", activated ? "Yes" : "No",  activated ? CheckStatus.Good : CheckStatus.Bad));
                found = true;
                break;
            }
            if (!found)
                tpm.Add(new SecurityRow("Status", "TPM not found or not accessible", CheckStatus.Bad));
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[SecurityCheck] TPM query failed: {ex.Message}");
            tpm.Add(new SecurityRow("Status", "Query failed", CheckStatus.Unknown));
        }

        return (defender, bitlocker, secureBoot, tpm);
    }

    private void PopulateUi((
        List<SecurityRow> Defender,
        List<SecurityRow> BitLocker,
        List<SecurityRow> SecureBoot,
        List<SecurityRow> Tpm) data)
    {
        LoadingPanel.Visibility = Visibility.Collapsed;

        PopulateCard(DefenderRows,   data.Defender,   DefenderCard);
        PopulateCard(BitLockerRows,  data.BitLocker,  BitLockerCard);
        PopulateCard(SecureBootRows, data.SecureBoot, SecureBootCard);
        PopulateCard(TpmRows,        data.Tpm,        TpmCard);

        var sb = new StringBuilder();
        sb.AppendLine("pcHealth - Security Status");
        sb.AppendLine($"Generated: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
        sb.AppendLine();
        AppendSection(sb, "Windows Defender", data.Defender);
        AppendSection(sb, "BitLocker",        data.BitLocker);
        AppendSection(sb, "Secure Boot",      data.SecureBoot);
        AppendSection(sb, "TPM",              data.Tpm);
        _copyText = sb.ToString();
        CopyBtn.IsEnabled = true;
    }

    private void PopulateCard(StackPanel panel, List<SecurityRow> rows, Border card)
    {
        foreach (var row in rows)
            AddStatusRow(panel, row.Label, row.Value, row.Status);
        card.Visibility = Visibility.Visible;
    }

    private static void AppendSection(StringBuilder sb, string title, List<SecurityRow> rows)
    {
        sb.AppendLine(title);
        foreach (var r in rows)
            sb.AppendLine($"  {r.Label,-22}: {r.Value}");
        sb.AppendLine();
    }

    private void AddStatusRow(StackPanel panel, string label, string value, CheckStatus status)
    {
        var grid = new Grid { ColumnSpacing = 10, Margin = new Thickness(0, 1, 0, 1) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(180) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var lbl = new TextBlock
        {
            Text = label,
            Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            VerticalAlignment = VerticalAlignment.Center,
        };

        var (glyph, brushKey) = status switch
        {
            CheckStatus.Good    => ("", "SystemFillColorSuccessBrush"),
            CheckStatus.Bad     => ("", "SystemFillColorCriticalBrush"),
            CheckStatus.Warning => ("", "SystemFillColorCautionBrush"),
            _                   => ("", "TextFillColorSecondaryBrush"),
        };

        var icon = new FontIcon
        {
            Glyph = glyph,
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center,
            Foreground = Application.Current.Resources.TryGetValue(brushKey, out var b)
                ? (Brush)b
                : (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        };

        var val = new TextBlock
        {
            Text = value,
            IsTextSelectionEnabled = true,
            TextWrapping = TextWrapping.Wrap,
            VerticalAlignment = VerticalAlignment.Center,
        };

        Grid.SetColumn(icon, 1);
        Grid.SetColumn(val,  2);
        grid.Children.Add(lbl);
        grid.Children.Add(icon);
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

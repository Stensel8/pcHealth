using System.Net.NetworkInformation;

namespace pcHealth.Pages;

public sealed partial class NetworkPingPage : Page
{
    private const string Target = "8.8.8.8";
    private const int Count = 4;

    public NetworkPingPage()
    {
        InitializeComponent();
    }

    private async void RunBtn_Click(object sender, RoutedEventArgs e)
    {
        RunBtn.IsEnabled = false;
        Progress.IsActive = true;
        PingResultRows.Children.Clear();
        SummaryRows.Children.Clear();
        ResultsCard.Visibility = Visibility.Collapsed;
        SummaryCard.Visibility = Visibility.Collapsed;

        try
        {
            var results = await Task.Run(() =>
            {
                var list = new List<(bool Success, string Address, long Latency, string Status)>();
                using var ping = new Ping();
                for (int i = 0; i < Count; i++)
                {
                    try
                    {
                        var reply = ping.Send(Target, 4000);
                        list.Add(reply.Status == IPStatus.Success
                            ? (true, reply.Address.ToString(), reply.RoundtripTime, "Reply")
                            : (false, Target, 0, reply.Status.ToString()));
                    }
                    catch (Exception ex)
                    {
                        list.Add((false, Target, 0, ex.Message));
                    }
                }
                return list;
            });

            ResultsCard.Visibility = Visibility.Visible;

            var successLatencies = new List<long>();
            for (int i = 0; i < results.Count; i++)
            {
                var (success, address, latency, status) = results[i];
                var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };

                var statusIcon = new FontIcon
                {
                    Glyph = success ? "\uE930" : "\uE711",
                    FontSize = 14,
                    VerticalAlignment = VerticalAlignment.Center,
                    Foreground = success
                        ? new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58))
                        : (Brush)Application.Current.Resources["SystemFillColorCriticalBrush"],
                };

                var text = new TextBlock
                {
                    Text = success
                        ? $"Reply from {address}: {latency} ms"
                        : $"Timeout / {status}",
                    VerticalAlignment = VerticalAlignment.Center,
                };

                row.Children.Add(statusIcon);
                row.Children.Add(text);
                PingResultRows.Children.Add(row);

                if (success) successLatencies.Add(latency);
            }

            // Summary
            SummaryCard.Visibility = Visibility.Visible;
            AddSummaryRow("Packets sent", $"{Count}");
            AddSummaryRow("Packets received", $"{successLatencies.Count}");
            AddSummaryRow("Packet loss", $"{(Count - successLatencies.Count) * 100 / Count}%");

            if (successLatencies.Count > 0)
            {
                AddSummaryRow("Min latency", $"{successLatencies.Min()} ms");
                AddSummaryRow("Max latency", $"{successLatencies.Max()} ms");
                AddSummaryRow("Average latency", $"{successLatencies.Average():0.0} ms");
            }
        }
        catch (Exception ex)
        {
            var errText = new TextBlock { Text = $"Error: {ex.Message}" };
            PingResultRows.Children.Add(errText);
            ResultsCard.Visibility = Visibility.Visible;
        }
        finally
        {
            Progress.IsActive = false;
            RunBtn.IsEnabled = true;
        }
    }

    private void AddSummaryRow(string label, string value)
    {
        var grid = new Grid { ColumnSpacing = 12, Margin = new Thickness(0, 1, 0, 1) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        grid.Children.Add(new TextBlock
        {
            Text = label,
            Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        });

        var val = new TextBlock { Text = value, IsTextSelectionEnabled = true };
        Grid.SetColumn(val, 1);
        grid.Children.Add(val);
        SummaryRows.Children.Add(grid);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

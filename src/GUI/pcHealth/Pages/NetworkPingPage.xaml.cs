using System.Net.NetworkInformation;
using pcHealth.Helpers;

namespace pcHealth.Pages;

public sealed partial class NetworkPingPage : Page
{
    private const string Target = "8.8.8.8";
    private const int Count = 4;

    private CancellationTokenSource? _cts;

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

        _cts = new CancellationTokenSource();

        try
        {
            // Run pings on a background thread so the UI stays responsive.
            // The cancellation token is checked at the start of each iteration so the loop
            // stops promptly when the user navigates away rather than waiting for all pings.
            var results = await Task.Run(() =>
            {
                var list = new List<(bool Success, string Address, long Latency, string Status)>();
                using var ping = new Ping();
                for (int i = 0; i < Count; i++)
                {
                    _cts.Token.ThrowIfCancellationRequested();
                    try
                    {
                        var reply = ping.Send(Target, 4000);
                        list.Add(reply.Status == IPStatus.Success
                            ? (true, reply.Address.ToString(), reply.RoundtripTime, "Reply")
                            : (false, Target, 0, reply.Status.ToString()));
                    }
                    catch (OperationCanceledException) { throw; }
                    catch (Exception ex)
                    {
                        list.Add((false, Target, 0, ex.Message));
                    }
                }
                return list;
            }, _cts.Token);

            ResultsCard.Visibility = Visibility.Visible;

            var successLatencies = new List<long>();
            for (int i = 0; i < results.Count; i++)
            {
                var (success, address, latency, status) = results[i];
                var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };

                var statusIcon = new FontIcon
                {
                    Glyph = success ? "" : "",
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

            SummaryCard.Visibility = Visibility.Visible;
            UiHelper.AddLabelValueRow(SummaryRows, "Packets sent",     $"{Count}");
            UiHelper.AddLabelValueRow(SummaryRows, "Packets received", $"{successLatencies.Count}");
            UiHelper.AddLabelValueRow(SummaryRows, "Packet loss",      $"{(Count - successLatencies.Count) * 100 / Count}%");

            if (successLatencies.Count > 0)
            {
                UiHelper.AddLabelValueRow(SummaryRows, "Min latency",     $"{successLatencies.Min()} ms");
                UiHelper.AddLabelValueRow(SummaryRows, "Max latency",     $"{successLatencies.Max()} ms");
                UiHelper.AddLabelValueRow(SummaryRows, "Average latency", $"{successLatencies.Average():0.0} ms");
            }
        }
        catch (OperationCanceledException)
        {
            // User navigated away — discard results silently.
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
            _cts?.Dispose();
            _cts = null;
        }
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        _cts?.Cancel();
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace pcHealth.Pages;

public sealed partial class TraceroutePage : Page
{
    private const string Target = "google.com";
    private const int MaxHops = 30;
    private const int Timeout = 4000;
    private CancellationTokenSource? _cts;

    public TraceroutePage()
    {
        InitializeComponent();
    }

    private async void RunBtn_Click(object sender, RoutedEventArgs e)
    {
        RunBtn.IsEnabled = false;
        Progress.IsActive = true;
        HopRows.Children.Clear();
        ResultsCard.Visibility = Visibility.Visible;
        StatusText.Text = $"Tracing route to {Target}…";

        _cts = new CancellationTokenSource();

        try
        {
            IPAddress? targetAddress = null;
            try
            {
                var addresses = await Dns.GetHostAddressesAsync(Target);
                targetAddress = addresses.FirstOrDefault(a => a.AddressFamily == AddressFamily.InterNetwork)
                    ?? addresses.FirstOrDefault();
            }
            catch (Exception)
            {
                targetAddress = null;
            }

            await Task.Run(async () =>
            {
                using var ping = new Ping();
                for (int ttl = 1; ttl <= MaxHops && !_cts.Token.IsCancellationRequested; ttl++)
                {
                    var options = new PingOptions(ttl, dontFragment: true);
                    var buffer = new byte[32];

                    PingReply? reply = null;
                    try
                    {
                        reply = await ping.SendPingAsync(Target, Timeout, buffer, options);
                    }
                    catch (Exception ex)
                    {
                        var errMsg = ex.Message;
                        var hopNum = ttl;
                        DispatcherQueue.TryEnqueue(() =>
                            AddHopRow(hopNum, "*", $"Error: {errMsg}", false));
                        continue;
                    }

                    var address = reply.Address?.ToString() ?? "*";
                    var latency = reply.Status == IPStatus.Success || reply.Status == IPStatus.TtlExpired
                        ? $"{reply.RoundtripTime} ms" : "*";
                    var hopTtl = ttl;

                    DispatcherQueue.TryEnqueue(() =>
                        AddHopRow(hopTtl, address, latency, reply.Status == IPStatus.Success));

                    if (reply.Status == IPStatus.Success) break;
                    if (reply.Status == IPStatus.TimedOut && ttl > 5) continue;
                }
            }, _cts.Token);

            StatusText.Text = targetAddress is not null
                ? $"Destination: {targetAddress}"
                : "Done.";
        }
        catch (OperationCanceledException)
        {
            StatusText.Text = "Cancelled.";
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Error: {ex.Message}";
        }
        finally
        {
            Progress.IsActive = false;
            RunBtn.IsEnabled = true;
            _cts?.Dispose();
            _cts = null;
        }
    }

    private static readonly Microsoft.UI.Xaml.Media.FontFamily MonoFont = new("Cascadia Code, Consolas, Courier New");

    private void AddHopRow(int hop, string address, string latency, bool reached)
    {
        var row = new Grid { ColumnSpacing = 16 };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(30) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var hopNum = new TextBlock
        {
            Text = $"{hop,2}",
            FontFamily = MonoFont,
            FontSize = 13,
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            IsTextSelectionEnabled = true,
        };

        var addrText = new TextBlock
        {
            Text = address,
            FontFamily = MonoFont,
            FontSize = 13,
            IsTextSelectionEnabled = true,
            Foreground = reached
                ? new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58))
                : (Brush)Application.Current.Resources["TextFillColorPrimaryBrush"],
        };

        var latText = new TextBlock
        {
            Text = latency,
            FontFamily = MonoFont,
            FontSize = 13,
            IsTextSelectionEnabled = true,
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        };

        Grid.SetColumn(addrText, 1);
        Grid.SetColumn(latText, 2);
        row.Children.Add(hopNum);
        row.Children.Add(addrText);
        row.Children.Add(latText);
        HopRows.Children.Add(row);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        _cts?.Cancel();
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

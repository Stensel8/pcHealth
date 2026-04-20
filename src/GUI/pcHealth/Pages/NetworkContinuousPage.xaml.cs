using System.Net.NetworkInformation;

namespace pcHealth.Pages;

public sealed partial class NetworkContinuousPage : Page
{
    private const string Target = "8.8.8.8";
    private CancellationTokenSource? _cts;
    private int _sent, _received;

    public NetworkContinuousPage()
    {
        InitializeComponent();
    }

    private async void StartBtn_Click(object sender, RoutedEventArgs e)
    {
        _cts = new CancellationTokenSource();
        _sent = 0;
        _received = 0;

        StartBtn.IsEnabled = false;
        StopBtn.IsEnabled = true;
        OutputText.Text = $"Pinging {Target} continuously…\n\n";

        try
        {
            await Task.Run(async () =>
            {
                using var ping = new Ping();
                while (!_cts.Token.IsCancellationRequested)
                {
                    PingReply? reply = null;
                    try
                    {
                        reply = await ping.SendPingAsync(Target, 4000);
                    }
                    catch (Exception ex)
                    {
                        DispatcherQueue.TryEnqueue(() =>
                            OutputText.Text += $"Error: {ex.Message}\n");
                    }

                    if (reply is not null)
                    {
                        var seq = ++_sent;
                        var success = reply.Status == IPStatus.Success;
                        if (success) _received++;

                        var line = success
                            ? $"[{seq,4}]  Reply from {reply.Address}: {reply.RoundtripTime} ms"
                            : $"[{seq,4}]  Timeout ({reply.Status})";

                        var loss = (int)((_sent - _received) * 100.0 / _sent);
                        var stats = $"Sent: {_sent}  Received: {_received}  Loss: {loss}%";

                        DispatcherQueue.TryEnqueue(() =>
                        {
                            OutputText.Text += line + "\n";
                            StatsText.Text = stats;
                            OutputScroller.ScrollToVerticalOffset(double.MaxValue);
                        });
                    }

                    await Task.Delay(1000, _cts.Token).ConfigureAwait(false);
                }
            }, _cts.Token);
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            DispatcherQueue.TryEnqueue(() => OutputText.Text += $"\nError: {ex.Message}\n");
        }
        finally
        {
            DispatcherQueue.TryEnqueue(() =>
            {
                OutputText.Text += "\n[Stopped]";
                StartBtn.IsEnabled = true;
                StopBtn.IsEnabled = false;
            });
        }
    }

    private void StopBtn_Click(object sender, RoutedEventArgs e)
    {
        _cts?.Cancel();
        StopBtn.IsEnabled = false;
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        _cts?.Cancel();
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

using System.Diagnostics;

namespace pcHealth.Pages;

public sealed partial class OpenBatteryReportPage : Page
{
    private readonly string _reportPath =
        Path.Combine(Path.GetTempPath(), "pcHealth-battery-report.html");

    public OpenBatteryReportPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        ReportPathText.Text = $"Report location: {_reportPath}";

        if (File.Exists(_reportPath))
        {
            var info = new FileInfo(_reportPath);
            ReportPathText.Text += $"\nLast generated: {info.LastWriteTime:yyyy-MM-dd HH:mm:ss}";
            OpenBtn.IsEnabled = true;
            NotFoundBar.IsOpen = false;
        }
        else
        {
            OpenBtn.IsEnabled = false;
            NotFoundBar.IsOpen = true;
        }
    }

    private void OpenBtn_Click(object sender, RoutedEventArgs e)
    {
        if (!File.Exists(_reportPath))
        {
            NotFoundBar.IsOpen = true;
            OpenBtn.IsEnabled = false;
            return;
        }
        Process.Start(new ProcessStartInfo(_reportPath) { UseShellExecute = true });
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

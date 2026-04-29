using System.Diagnostics;

namespace pcHealth.Pages;

public sealed partial class CBSLogPage : Page
{
    private readonly string _logPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.Windows),
        "Logs", "CBS", "CBS.log");

    public CBSLogPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        PathText.Text = _logPath;

        if (!File.Exists(_logPath))
        {
            LogText.Text = "CBS.log not found.";
            OpenBtn.IsEnabled = false;
            return;
        }

        // Show the last 200 lines — the full log can be hundreds of MB.
        LogText.Text = "Loading last 200 lines…";
        try
        {
            var lines = await Task.Run(() =>
            {
                using var stream = new FileStream(_logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                using var reader = new StreamReader(stream, System.Text.Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
                var allLines = new List<string>();
                string? line;
                while ((line = reader.ReadLine()) is not null)
                    allLines.Add(line);
                return allLines.TakeLast(200).ToList();
            });

            LogText.Text = string.Join("\n", lines);
            LogScroller.ScrollToVerticalOffset(double.MaxValue);
        }
        catch (Exception ex)
        {
            LogText.Text = $"Could not read log: {ex.Message}";
        }
    }

    private void OpenBtn_Click(object sender, RoutedEventArgs e)
    {
        if (!File.Exists(_logPath)) return;
        Process.Start(new ProcessStartInfo("notepad.exe", $"\"{_logPath}\"")
        {
            UseShellExecute = true,
        });
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

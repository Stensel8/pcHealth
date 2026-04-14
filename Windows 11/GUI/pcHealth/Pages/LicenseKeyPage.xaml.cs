using Microsoft.UI.Xaml.Media;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage.Pickers;
using WinRT.Interop;

namespace pcHealth.Pages;

public sealed partial class LicenseKeyPage : Page
{
    private LicenseResult? _result;

    public LicenseKeyPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    // Run key extraction when the page is first shown.
    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            // WMI queries can block for a short time, so run them on a thread pool thread.
            // The continuation back on the UI thread is guaranteed by the captured
            // SynchronizationContext from the async/await machinery.
            _result = await Task.Run(KeyExtractor.Extract);
            PopulateUi();
        }
        catch (Exception ex)
        {
            PrimaryKeyText.Text       = "Key extraction failed.";
            PrimaryKeyText.Foreground = (Brush)App.Current.Resources["SystemFillColorCriticalBrush"];
            KeySourceText.Text        = ex.Message;
        }
    }

    // Fill all UI elements with the extraction results.
    private void PopulateUi()
    {
        if (_result is null) return;

        OsInfoText.Text = _result.OsCaption;

        SetMethodCard(
            statusText:  Oa3StatusText,
            keyText:     Oa3KeyText,
            icon:        Oa3Icon,
            key:         _result.Oa3Key,
            notFoundMsg: "Not found - key not embedded in firmware");

        SetMethodCard(
            statusText:  RegStatusText,
            keyText:     RegKeyText,
            icon:        RegIcon,
            key:         _result.RegKey,
            notFoundMsg: "Not found - DigitalProductId registry value unavailable");

        if (_result.BestKey is not null)
        {
            PrimaryKeyText.Text = _result.BestKey;
            KeySourceText.Text  = $"Source: {_result.BestSource}";

            // Green for a genuine key, amber-ish for a generic/KMS placeholder.
            PrimaryKeyText.Foreground = _result.IsGeneric
                ? (Brush)App.Current.Resources["SystemFillColorCautionBrush"]
                : new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58));

            GenericWarning.IsOpen = _result.IsGeneric;

            CopyBtn.IsEnabled = true;
            SaveBtn.IsEnabled = true;
        }
        else
        {
            PrimaryKeyText.Text       = "No product key found.";
            PrimaryKeyText.Foreground = (Brush)App.Current.Resources["SystemFillColorCriticalBrush"];
            KeySourceText.Text        =
                "Your system may use a digital licence linked to your Microsoft account, " +
                "or was activated via volume licensing (KMS/MAK).";
        }
    }

    // Update a single method card to show either a found key or a not-found message.
    private static void SetMethodCard(
        TextBlock statusText,
        TextBlock keyText,
        FontIcon  icon,
        string?   key,
        string    notFoundMsg)
    {
        if (key is not null)
        {
            statusText.Text = "Found";
            keyText.Text    = key;
            icon.Glyph      = "\uE930"; // CheckMark
            icon.Foreground = new SolidColorBrush(
                Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x0F, 0x9D, 0x58));
        }
        else
        {
            statusText.Text = notFoundMsg;
            icon.Glyph      = "\uE8BB"; // Cancel
            icon.Foreground = (Brush)App.Current.Resources["TextFillColorTertiaryBrush"];
        }
    }

    private void CopyBtn_Click(object sender, RoutedEventArgs e)
    {
        if (_result?.BestKey is null) return;

        var pkg = new DataPackage();
        pkg.SetText(_result.BestKey);
        Clipboard.SetContent(pkg);

        // Show brief visual feedback on the button before reverting the label.
        CopyBtn.Content = "Copied!";
        var timer = DispatcherQueue.CreateTimer();
        timer.Interval = TimeSpan.FromSeconds(1.5);
        timer.Tick += (_, _) => { CopyBtn.Content = "Copy Key"; timer.Stop(); };
        timer.Start();
    }

    private async void SaveBtn_Click(object sender, RoutedEventArgs e)
    {
        if (_result?.BestKey is null) return;

        var picker = new FileSavePicker
        {
            SuggestedStartLocation = PickerLocationId.Desktop,
            SuggestedFileName      = "windows-license-key",
        };
        picker.FileTypeChoices.Add("Text file", ["txt"]);

        // Unpackaged WinUI 3 apps must associate pickers with a window handle.
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(App.MainWindow!));

        var file = await picker.PickSaveFileAsync();
        if (file is null) return;

        var lines = new[]
        {
            "pcHealth - Windows License Key Report",
            $"Generated : {DateTime.Now:yyyy-MM-dd HH:mm:ss}",
            "",
            $"OS        : {_result.OsCaption}",
            "",
            "Method 1 - OA3 (UEFI/BIOS Firmware):",
            $"  {_result.Oa3Key ?? "Not found"}",
            "",
            "Method 2 - Registry (DigitalProductId):",
            $"  {_result.RegKey ?? "Not found"}",
            "",
            $"Primary Key : {_result.BestKey}",
            $"Source      : {_result.BestSource}",
            _result.IsGeneric
                ? $"\nWARNING: Generic placeholder key ({_result.GenericEdition})." +
                  " This key will not activate Windows."
                : "",
        };

        await Windows.Storage.FileIO.WriteLinesAsync(file, lines);
    }

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack)
            Frame.GoBack();
    }
}

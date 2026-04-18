using pcHealth.Pages;

namespace pcHealth;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        // MicaBackdrop requires Windows 11. Fall back gracefully on older builds
        // so the app still runs without crashing on unsupported hardware.
        try
        {
            SystemBackdrop = new MicaBackdrop();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[MainWindow] Mica backdrop unavailable: {ex.Message}");
        }

        AppWindow.Resize(new SizeInt32(1100, 720));

        // Hand the title bar over to WinUI 3 so it automatically follows the
        // system dark/light theme and blends with the Mica backdrop.
        ExtendsContentIntoTitleBar = true;

        // Set the window icon (AppWindow.SetIcon = title bar corner icon;
        // ApplicationIcon in csproj covers taskbar / File Explorer).
        var iconPath = Path.Combine(AppContext.BaseDirectory, "pcplushealthpluspluslogo.ico");
        if (File.Exists(iconPath))
            AppWindow.SetIcon(iconPath);

        // Keep the NavigationView back button in sync with the frame's back stack.
        ContentFrame.Navigated += ContentFrame_Navigated;
    }

    private void NavView_Loaded(object sender, RoutedEventArgs e)
    {
        // Open the Tools page on first launch.
        if (NavView.MenuItems.Count > 0)
            NavView.SelectedItem = NavView.MenuItems[0];
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItemContainer is NavigationViewItem item)
            NavigateTo(item.Tag?.ToString());
    }

    private void NavView_BackRequested(NavigationView sender, NavigationViewBackRequestedEventArgs args)
    {
        if (ContentFrame.CanGoBack)
            ContentFrame.GoBack();
    }

    // Update back-button visibility whenever the frame navigates.
    private void ContentFrame_Navigated(object sender, NavigationEventArgs args)
    {
        NavView.IsBackEnabled = ContentFrame.CanGoBack;
    }

    // Navigate the content frame to a named destination.
    // Called both from SelectionChanged and from pages that push sub-pages.
    internal void NavigateTo(string? tag)
    {
        Type? target = tag switch
        {
            "tools" => typeof(ToolsPage),
            "programs" => typeof(ProgramsPage),
            "licensekey" => typeof(LicenseKeyPage),
            _ => null
        };

        if (target is not null && ContentFrame.CurrentSourcePageType != target)
            ContentFrame.Navigate(target);
    }
}

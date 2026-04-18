namespace pcHealth.Pages;

public sealed partial class SettingsPage : Page
{
    // Prevents event handlers from saving during the initial LoadSettings() pass.
    private bool _isLoaded;

    public SettingsPage()
    {
        InitializeComponent();
        LoadSettings();
        _isLoaded = true;
    }

    private void LoadSettings()
    {
        var theme = AppSettings.Get("AppTheme", "Default");
        ThemeCombo.SelectedIndex = theme switch
        {
            "Light" => 1,
            "Dark"  => 2,
            _       => 0,
        };

        ElevatedToggle.IsOn = AppSettings.GetBool("RunElevated", fallback: true);
    }

    private void ThemeCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!_isLoaded) return;
        if (ThemeCombo.SelectedItem is not ComboBoxItem item) return;

        var tag = item.Tag?.ToString() ?? "Default";
        AppSettings.Set("AppTheme", tag);

        var requestedTheme = tag switch
        {
            "Light" => ElementTheme.Light,
            "Dark"  => ElementTheme.Dark,
            _       => ElementTheme.Default,
        };

        if (XamlRoot?.Content is FrameworkElement root)
            root.RequestedTheme = requestedTheme;
    }

    private void ElevatedToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (!_isLoaded) return;
        AppSettings.Set("RunElevated", ElevatedToggle.IsOn ? "true" : "false");
    }
}

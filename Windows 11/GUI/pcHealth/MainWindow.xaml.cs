using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using Windows.Graphics;
using pcHealth.Pages;

namespace pcHealth;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        SystemBackdrop = new MicaBackdrop();
        AppWindow.Resize(new SizeInt32(1100, 720));

        // Keep the NavigationView back button in sync with the frame's back stack.
        ContentFrame.Navigated += ContentFrame_Navigated;
    }

    private void NavView_Loaded(object sender, RoutedEventArgs e)
    {
        // Open the Tools page on first launch.
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
            "tools"      => typeof(ToolsPage),
            "programs"   => typeof(ProgramsPage),
            "licensekey" => typeof(LicenseKeyPage),
            _ => null
        };

        if (target is not null && ContentFrame.CurrentSourcePageType != target)
            ContentFrame.Navigate(target);
    }
}

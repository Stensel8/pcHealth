namespace pcHealth.Pages;

public sealed partial class WindowsUpdatePage : Page
{
    public WindowsUpdatePage()
    {
        InitializeComponent();
    }

    private void OpenBtn_Click(object sender, RoutedEventArgs e) =>
        CliRunner.OpenUri("ms-settings:windowsupdate");

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

namespace pcHealth.Pages;

public sealed partial class DiskCleanupPage : Page
{
    public DiskCleanupPage()
    {
        InitializeComponent();
    }

    private void OpenBtn_Click(object sender, RoutedEventArgs e) =>
        CliRunner.OpenApp("cleanmgr.exe");

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

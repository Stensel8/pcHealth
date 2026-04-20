namespace pcHealth.Pages;

public sealed partial class DiskOptimizationPage : Page
{
    public DiskOptimizationPage()
    {
        InitializeComponent();
    }

    private void OpenBtn_Click(object sender, RoutedEventArgs e) =>
        CliRunner.OpenApp("dfrgui.exe");

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

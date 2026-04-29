namespace pcHealth.Pages;

public sealed partial class BIOSPasswordPage : Page
{
    public BIOSPasswordPage()
    {
        InitializeComponent();
    }

    private void BiosPwBtn_Click(object sender, RoutedEventArgs e) =>
        CliRunner.OpenUri("https://bios-pw.org");

    private void RepoBtn_Click(object sender, RoutedEventArgs e) =>
        CliRunner.OpenUri("https://github.com/bacher09/pwgen-for-bios");

    private void BackBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack) Frame.GoBack();
    }
}

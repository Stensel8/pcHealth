using System.Reflection;
using Microsoft.UI.Xaml.Media.Imaging;

namespace pcHealth.Pages;

public sealed partial class InfoPage : Page
{
    public InfoPage()
    {
        InitializeComponent();

        // Version is baked into the assembly at build time from the repo-root VERSION file.
        var v = Assembly.GetExecutingAssembly().GetName().Version;
        VersionText.Text = v is not null ? $"Version {v.Major}.{v.Minor}.{v.Build}" : "Version unknown";

        // WinUI 3 SvgImageSource doesn't support SVG <mask>, so use the pre-rendered PNG.
        var pngPath = Path.Combine(AppContext.BaseDirectory, "Assets", "pcHealth.png");
        if (File.Exists(pngPath))
            AppLogo.Source = new BitmapImage(new Uri(pngPath));
    }
}

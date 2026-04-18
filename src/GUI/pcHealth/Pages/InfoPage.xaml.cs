using System.Reflection;

namespace pcHealth.Pages;

public sealed partial class InfoPage : Page
{
    public InfoPage()
    {
        InitializeComponent();

        // Version is baked into the assembly at build time from the repo-root VERSION file.
        var v = Assembly.GetExecutingAssembly().GetName().Version;
        VersionText.Text = v is not null ? $"Version {v.Major}.{v.Minor}.{v.Build}" : "Version unknown";
    }
}

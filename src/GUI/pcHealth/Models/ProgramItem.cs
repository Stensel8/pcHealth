using System.ComponentModel;

namespace pcHealth;

public sealed class ProgramItem : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    public required string Name { get; init; }
    public required string Glyph { get; init; }
    public string Note { get; init; } = "";
    /// <summary>winget package ID. Empty string means open a browser URL instead.</summary>
    public string WingetId { get; init; } = "";
    /// <summary>Browser URL used when WingetId is empty.</summary>
    public string BrowserUrl { get; init; } = "";
    /// <summary>Executable name used to open the program when it is already installed.</summary>
    public string ExeName { get; init; } = "";
    /// <summary>
    /// Substring to match against the registry DisplayName in the Uninstall keys.
    /// Used to detect whether the program is already installed.
    /// </summary>
    public string RegistryName { get; init; } = "";

    private void Notify(string name) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    private bool _isInstalled;
    public bool IsInstalled
    {
        get => _isInstalled;
        set
        {
            if (_isInstalled == value) return;
            _isInstalled = value;
            Notify(nameof(IsInstalled));
            Notify(nameof(ButtonLabel));
        }
    }

    public string ButtonLabel =>
        IsInstalled ? "Installed" :
        string.IsNullOrEmpty(WingetId) ? "Open Download Page" :
                               "Install";

    public Microsoft.UI.Xaml.Visibility NoteVisibility =>
        string.IsNullOrEmpty(Note)
            ? Microsoft.UI.Xaml.Visibility.Collapsed
            : Microsoft.UI.Xaml.Visibility.Visible;
}

namespace pcHealth;

public sealed class ProgramItem
{
    public required string Name      { get; init; }
    public required string Glyph    { get; init; }
    public          string Note     { get; init; } = "";
    /// <summary>winget package ID. Empty string means open a browser URL instead.</summary>
    public          string WingetId  { get; init; } = "";
    /// <summary>Browser URL used when WingetId is empty.</summary>
    public          string BrowserUrl { get; init; } = "";

    public string ButtonLabel => string.IsNullOrEmpty(WingetId) ? "Open Download Page" : "Install";

    public Microsoft.UI.Xaml.Visibility NoteVisibility =>
        string.IsNullOrEmpty(Note)
            ? Microsoft.UI.Xaml.Visibility.Collapsed
            : Microsoft.UI.Xaml.Visibility.Visible;
}

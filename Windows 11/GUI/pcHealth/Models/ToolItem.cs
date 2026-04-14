using Microsoft.UI.Xaml;

namespace pcHealth;

public enum ToolActionKind
{
    Script,    // Run a CLI .ps1 script in a new PowerShell 7 window
    OpenApp,   // Launch a system executable (dfrgui.exe, cleanmgr.exe, ...)
    OpenUri,   // Open a URI via the shell (ms-settings:, https://, ...)
    Navigate,  // Navigate to an in-app Page
}

public sealed class ToolItem
{
    public required string         Name   { get; init; }
    public required string         Glyph  { get; init; }
    public          string         Note   { get; init; } = "";
    public required ToolActionKind Kind   { get; init; }
    public          string         Param  { get; init; } = "";

    // Returned directly so x:Bind can use it without a converter in XAML.
    public Visibility NoteVisibility =>
        string.IsNullOrEmpty(Note) ? Visibility.Collapsed : Visibility.Visible;
}

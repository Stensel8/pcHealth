namespace pcHealth;

public sealed class ToolItem
{
    public required string Name { get; init; }
    public required string Glyph { get; init; }
    public string Note { get; init; } = "";
    public required Type PageType { get; init; }

    public Visibility NoteVisibility =>
        string.IsNullOrEmpty(Note) ? Visibility.Collapsed : Visibility.Visible;
}

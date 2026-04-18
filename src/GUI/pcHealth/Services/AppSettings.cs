using System.Diagnostics;
using System.Text.Json;

namespace pcHealth;

// File-based settings for unpackaged WinUI 3 apps.
// ApplicationData.Current is only available in packaged (MSIX) apps.
internal static class AppSettings
{
    private static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "pcHealth", "settings.json");

    private static Dictionary<string, string> _cache = new();
    private static bool _loaded;

    public static string Get(string key, string fallback = "")
    {
        EnsureLoaded();
        return _cache.TryGetValue(key, out var v) ? v : fallback;
    }

    public static bool GetBool(string key, bool fallback = true)
    {
        var raw = Get(key);
        return raw == "" ? fallback : raw == "true";
    }

    public static void Set(string key, string value)
    {
        EnsureLoaded();
        _cache[key] = value;
        Persist();
    }

    private static void EnsureLoaded()
    {
        if (_loaded) return;
        _loaded = true;
        try
        {
            if (File.Exists(FilePath))
                _cache = JsonSerializer.Deserialize<Dictionary<string, string>>(
                    File.ReadAllText(FilePath)) ?? new();
        }
        catch (IOException ex)
        {
            Debug.WriteLine($"[AppSettings] Load failed: {ex.Message}");
        }
        catch (JsonException ex)
        {
            Debug.WriteLine($"[AppSettings] JSON corrupt, using defaults: {ex.Message}");
        }
    }

    private static void Persist()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath,
                JsonSerializer.Serialize(_cache, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (IOException ex)
        {
            Debug.WriteLine($"[AppSettings] Save failed: {ex.Message}");
        }
    }
}

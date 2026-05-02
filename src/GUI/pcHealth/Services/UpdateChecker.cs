using System.Diagnostics;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Reflection;
using System.Text.Json;

namespace pcHealth;

internal static class UpdateChecker
{
    private const string ReleasesApi =
        "https://api.github.com/repos/Stensel8/pcHealth/releases/latest";

    // Reuse one HttpClient for the lifetime of the app — creating a new instance
    // per call exhausts sockets and is flagged by static analysis.
    private static readonly HttpClient _http = new();

    static UpdateChecker()
    {
        _http.DefaultRequestHeaders.UserAgent.Add(
            new ProductInfoHeaderValue("pcHealth", GetCurrentVersion()));
    }

    // Returns the latest tag from GitHub, or null on any failure.
    public static async Task<string?> GetLatestTagAsync()
    {
        try
        {
            using var response = await _http.GetAsync(ReleasesApi);
            if (!response.IsSuccessStatusCode) return null;

            using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            return doc.RootElement.GetProperty("tag_name").GetString();
        }
        catch (HttpRequestException ex)
        {
            Debug.WriteLine($"[UpdateChecker] Network error: {ex.Message}");
            return null;
        }
        catch (JsonException ex)
        {
            Debug.WriteLine($"[UpdateChecker] JSON parse error: {ex.Message}");
            return null;
        }
    }

    // Returns true when the remote tag is a higher version than the running assembly.
    public static bool IsNewer(string remoteTag)
    {
        var current = Assembly.GetExecutingAssembly().GetName().Version;
        if (current is null) return false;

        // Strip leading 'v'/'V' and any pre-release suffix before parsing.
        var clean = remoteTag.TrimStart('v', 'V').Trim();
        // Version.TryParse requires dot-separated numbers; drop anything after a hyphen
        // (e.g. "2.1.0-rc1" → "2.1.0") so the comparison works correctly.
        var dashIdx = clean.IndexOf('-');
        if (dashIdx > 0) clean = clean[..dashIdx];
        return Version.TryParse(clean, out var remote) && remote > current;
    }

    public static string GetCurrentVersion()
    {
        var v = Assembly.GetExecutingAssembly().GetName().Version;
        return v is not null ? $"{v.Major}.{v.Minor}.{v.Build}" : "unknown";
    }
}

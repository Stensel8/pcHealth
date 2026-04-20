using System.Diagnostics;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Reflection;
using System.Text.Json;

namespace pcHealth;

internal static class UpdateChecker
{
    private const string ReleasesApi =
        "https://api.github.com/repos/REALSDEALS/pcHealth/releases/latest";

    // Returns the latest tag from GitHub, or null on any failure.
    public static async Task<string?> GetLatestTagAsync()
    {
        try
        {
            using var client = new HttpClient();
            // GitHub API requires a User-Agent header.
            client.DefaultRequestHeaders.UserAgent.Add(
                new ProductInfoHeaderValue("pcHealth", GetCurrentVersion()));

            using var response = await client.GetAsync(ReleasesApi);
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

        var clean = remoteTag.TrimStart('v', 'V').Trim();
        return Version.TryParse(clean, out var remote) && remote > current;
    }

    public static string GetCurrentVersion()
    {
        var v = Assembly.GetExecutingAssembly().GetName().Version;
        return v is not null ? $"{v.Major}.{v.Minor}.{v.Build}" : "unknown";
    }
}

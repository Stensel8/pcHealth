namespace pcHealth.Services;

/// <summary>
/// Picks the COM API when the server answers and winget.exe when it does not.
/// </summary>
/// <remarks>
/// The choice cannot be made at startup: probing the COM server is the
/// expensive part, so <see cref="WinGetComClient"/> does it once on first use
/// and caches the answer. Every call routes through that same cached decision.
/// </remarks>
internal sealed class WinGetClient : IWinGet
{
    private readonly WinGetComClient _com;
    private readonly WinGetCliClient _cli;

    public WinGetClient(WinGetComClient com, WinGetCliClient cli)
    {
        _com = com;
        _cli = cli;
    }

    public bool IsNative => _com.IsNative;

    private IWinGet Active => _com.IsNative ? _com : _cli;

    // Each call starts on the thread pool: reading Active is what triggers the
    // one-off CoCreateInstance probe, and reaching an out-of-process COM server
    // is not something to do on the thread painting the window.
    public Task<WinGetResult> InstallAsync(
        string packageId,
        IProgress<WinGetProgress>? progress = null,
        bool force = false,
        CancellationToken ct = default) =>
        Task.Run(() => Active.InstallAsync(packageId, progress, force, ct), ct);

    public Task<WinGetResult> UpgradeAsync(
        string packageId,
        IProgress<WinGetProgress>? progress = null,
        CancellationToken ct = default) =>
        Task.Run(() => Active.UpgradeAsync(packageId, progress, ct), ct);

    public Task<WinGetResult> UpgradeAllAsync(
        IProgress<WinGetProgress>? progress = null,
        CancellationToken ct = default) =>
        Task.Run(() => Active.UpgradeAllAsync(progress, ct), ct);
}

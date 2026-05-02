using System.Diagnostics;

namespace pcHealth;

/// <summary>
/// Runs a process and streams stdout/stderr lines to a callback.
/// Used by tool pages that display process output in-app.
/// </summary>
internal static class ProcessRunner
{
    /// <summary>
    /// Default wall-clock timeout applied when the caller does not specify one.
    /// Prevents a hung process from blocking the UI indefinitely.
    /// </summary>
    private static readonly TimeSpan DefaultTimeout = TimeSpan.FromMinutes(10);

    /// <param name="timeout">
    /// Optional upper bound on how long to wait for the process.
    /// Defaults to <see cref="DefaultTimeout"/> (10 min). Pass <see cref="TimeSpan.Zero"/> for no timeout.
    /// </param>
    public static async Task RunAsync(
        string fileName,
        string arguments,
        Action<string> onLine,
        CancellationToken ct = default,
        TimeSpan timeout = default)
    {
        if (timeout == default) timeout = DefaultTimeout;

        var psi = new ProcessStartInfo(fileName, arguments)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = System.Text.Encoding.UTF8,
            StandardErrorEncoding = System.Text.Encoding.UTF8,
        };

        using var proc = new Process { StartInfo = psi };
        proc.OutputDataReceived += (_, e) => { if (e.Data is not null) onLine(e.Data); };
        proc.ErrorDataReceived += (_, e) => { if (e.Data is not null) onLine(e.Data); };

        proc.Start();
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();

        // Build an effective CancellationToken that fires when either the caller
        // cancels OR the timeout elapses, whichever comes first.
        CancellationToken effectiveCt;
        CancellationTokenSource? timeoutSource = null;
        CancellationTokenSource? linkedCts = null;
        try
        {
            if (timeout > TimeSpan.Zero)
            {
                timeoutSource = new CancellationTokenSource(timeout);
                linkedCts     = CancellationTokenSource.CreateLinkedTokenSource(ct, timeoutSource.Token);
                effectiveCt   = linkedCts.Token;
            }
            else
            {
                effectiveCt = ct;
            }

            await proc.WaitForExitAsync(effectiveCt);
        }
        catch (OperationCanceledException)
        {
            proc.Kill(entireProcessTree: true);
            throw;
        }
        finally
        {
            linkedCts?.Dispose();
            timeoutSource?.Dispose();
        }
    }
}

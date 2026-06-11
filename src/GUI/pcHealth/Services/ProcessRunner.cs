using System.Diagnostics;

namespace pcHealth.Services;

internal sealed class ProcessRunner : IProcessRunner
{
    public async Task RunAsync(
        string fileName,
        string arguments,
        Action<string> onLine,
        CancellationToken ct = default,
        TimeSpan timeout = default)
    {
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

        CancellationTokenSource? timeoutCts = null;
        try
        {
            CancellationToken effectiveCt = ct;
            if (timeout > TimeSpan.Zero)
            {
                timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
                timeoutCts.CancelAfter(timeout);
                effectiveCt = timeoutCts.Token;
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
            timeoutCts?.Dispose();
        }
    }
}

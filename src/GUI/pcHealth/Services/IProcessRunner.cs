namespace pcHealth.Services;

public interface IProcessRunner
{
    Task RunAsync(
        string fileName,
        string arguments,
        Action<string> onLine,
        CancellationToken ct = default,
        TimeSpan timeout = default);
}

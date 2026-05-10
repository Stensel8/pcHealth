using System;
using System.IO;

namespace pcHealth.Services
{
    internal static class Logger
    {
        private static readonly object _lock = new();
        private static readonly string _logPath;

        static Logger()
        {
            var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "pcHealth");
            try { Directory.CreateDirectory(dir); } catch { }
            _logPath = Path.Combine(dir, "pcHealth.log");
        }

        public static void LogInfo(string message) => Log("INFO", message);
        public static void LogError(string message) => Log("ERR ", message);
        public static void LogException(Exception ex, string? context = null)
        {
            var msg = $"{ex.GetType()}: {ex.Message}\n{ex.StackTrace}";
            if (!string.IsNullOrEmpty(context)) msg = context + " - " + msg;
            Log("EXC ", msg);
        }

        private static void Log(string level, string message)
        {
            try
            {
                lock (_lock)
                {
                    File.AppendAllText(_logPath, $"[{DateTime.UtcNow:yyyy-MM-dd HH:mm:ssZ}] {level} {message}{Environment.NewLine}");
                }
            }
            catch { /* best-effort logging */ }
        }
    }
}

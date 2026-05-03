using Microsoft.Management.Infrastructure;
using Microsoft.UI.Xaml.Media;
using System.Diagnostics;
using System.Diagnostics.Eventing.Reader;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Xml.Linq;
using Windows.Devices.Power;
using Windows.System.Power;

namespace pcHealth.Pages;

public sealed partial class HealthPage : Page
{
    // Live battery update state
    private TextBlock? _battChargeLevelText;
    private TextBlock? _battPowerDrawText;
    private ProgressBar? _battProgressBar;
    private int? _battFullCapacityMwh;
    private DispatcherTimer? _battTimer;

    public HealthPage()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        Unloaded += (_, _) => { _battTimer?.Stop(); _battTimer = null; };
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        try
        {
            var data = await Task.Run(GatherData);
            // Guard: don't populate UI (or start the battery timer) if the page was
            // navigated away before GatherData completed.
            if (!IsLoaded) return;
            PopulateUi(data);
        }
        catch (Exception ex)
        {
            LoadingPanel.Visibility = Visibility.Collapsed;
            ErrorBar.Message = ex.Message;
            ErrorBar.IsOpen = true;
        }
    }

    private enum CheckStatus { Good, Warning, Bad, Unknown, Info }

    private record HealthRow(string Label, string Value, CheckStatus Status);
    private record DriveRow(string Drive, long UsedBytes, long TotalBytes, CheckStatus Status);

    private record GpuInfo(
        string Name,
        int? DriverAgeMonths,
        int? ReleaseYear,
        string? SeriesName);

    private record RamModule(
        string Slot,
        double CapacityGb,
        int SpeedMts,
        int MemoryType,   // SMBIOSMemoryType: 24=DDR3, 26=DDR4, 34=DDR5
        string PartNumber,
        string Manufacturer);

    private record DiskHealthInfo(
        string Name,
        string MediaType,
        CheckStatus HealthStatus,
        string HealthText,
        byte? Wear,
        ushort? Temperature,
        ulong? PowerOnHours,
        string? SpeedFlag
    );

    private record BatteryInfo(
        string? Name,
        string? Chemistry,
        int? DesignCapacityMwh,
        int? FullChargeCapacityMwh,
        int? RemainingCapacityMwh,
        int? ChargeRateMw,
        string StatusText,
        int? EstimatedRuntimeMin,
        int? CycleCount,
        bool CycleCountQueried,   // true even when CycleCount == 0 (driver reported it)
        int? BatteryAgeMonths
    );

    private record SecurityInfo(
        List<HealthRow> Defender,
        List<HealthRow> BitLocker,
        List<HealthRow> SecureBoot,
        List<HealthRow> Tpm
    );

    private record HealthData(
        List<HealthRow> Cpu,
        List<GpuInfo> Gpu,
        List<RamModule> Ram,
        List<DiskHealthInfo> Smart,
        bool SmartUsedSmartctl,
        List<DriveRow> DiskSpace,
        List<HealthRow> WinVer,
        List<HealthRow> Boot,
        BatteryInfo? Battery,
        SecurityInfo Security,
        List<HealthRow> LegacyFeatures
    );

    private static readonly Dictionary<string, DateTime> _winReleaseDates = new()
    {
        { "21H1", new DateTime(2021, 5,  18) },
        { "21H2", new DateTime(2021, 11, 16) },
        { "22H2", new DateTime(2022, 10, 18) },
        { "23H2", new DateTime(2023, 10, 31) },
        { "24H2", new DateTime(2024, 10,  1) },
        { "25H2", new DateTime(2025, 11,  1) },
    };

    // ── Hardware DB ───────────────────────────────────────────────────────────

    private sealed class HardwareDb
    {
        [JsonPropertyName("gpu_series")] public List<GpuSeriesEntry> GpuSeries { get; init; } = [];
        [JsonPropertyName("gpu_models")] public List<GpuModelEntry> GpuModels { get; init; } = [];
        [JsonPropertyName("chipsets")] public List<ChipsetEntry> Chipsets { get; init; } = [];
    }

    private sealed class GpuSeriesEntry
    {
        [JsonPropertyName("pattern")] public string Pattern { get; init; } = "";
        [JsonPropertyName("vendor")] public string Vendor { get; init; } = "";
        [JsonPropertyName("series")] public string Series { get; init; } = "";
        [JsonPropertyName("year")] public int Year { get; init; }
    }

    private sealed class GpuModelEntry
    {
        [JsonPropertyName("name")] public string Name { get; init; } = "";
        [JsonPropertyName("year")] public int Year { get; init; }
    }

    private sealed class ChipsetEntry
    {
        [JsonPropertyName("pattern")] public string Pattern { get; init; } = "";
        [JsonPropertyName("vendor")] public string Vendor { get; init; } = "";
        [JsonPropertyName("name")] public string Name { get; init; } = "";
        [JsonPropertyName("platform")] public string Platform { get; init; } = "";
        [JsonPropertyName("year")] public int Year { get; init; }
        [JsonPropertyName("note")] public string? Note { get; init; }
    }

    private static HardwareDb? _hardwareDb;
    private static readonly object _dbLock = new();

    private static HardwareDb GetHardwareDb()
    {
        if (_hardwareDb != null) return _hardwareDb;
        lock (_dbLock)
        {
            if (_hardwareDb != null) return _hardwareDb;
            var path = Path.Combine(AppContext.BaseDirectory, "assets", "hardware-db.json");
            if (!File.Exists(path))
            {
                Debug.WriteLine("[Health] hardware-db.json not found");
                return _hardwareDb = new HardwareDb();
            }
            try
            {
                var json = File.ReadAllText(path, System.Text.Encoding.UTF8);
                _hardwareDb = JsonSerializer.Deserialize<HardwareDb>(json) ?? new HardwareDb();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[Health] hardware-db.json load failed: {ex.Message}");
                _hardwareDb = new HardwareDb();
            }
            return _hardwareDb;
        }
    }

    // ── Data gathering ────────────────────────────────────────────────────────

    private static HealthData GatherData()
    {
        // Start slow independent tasks immediately so they run alongside the CIM hardware queries.
        var legacyTask   = Task.Run(GatherLegacyFeatures);
        var securityTask = Task.Run(static () => { using var s = CimSession.Create(null); return GatherSecurityInfo(s); });

        var cpu = new List<HealthRow>();
        var gpu = new List<GpuInfo>();
        var ram = new List<RamModule>();
        var diskSpace = new List<DriveRow>();
        var winVer = new List<HealthRow>();
        var boot = new List<HealthRow>();

        using var session = CimSession.Create(null);

        // --- Processor ---
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name FROM Win32_Processor"))
            {
                var name = inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim() ?? "Unknown";
                cpu.Add(new HealthRow("Model", name, CheckStatus.Info));
                var (year, genLabel) = TryGetCpuReleaseYear(name);
                if (year > 0)
                {
                    int age = DateTime.Today.Year - year;
                    var s = age >= 10 ? CheckStatus.Bad : age >= 7 ? CheckStatus.Warning : CheckStatus.Good;
                    cpu.Add(new HealthRow("Generation", genLabel, CheckStatus.Info));
                    cpu.Add(new HealthRow("Release year", year.ToString(), s));
                }
                else
                {
                    cpu.Add(new HealthRow("Release year", "Unknown", CheckStatus.Unknown));
                }
                break;
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] CPU query failed: {ex.Message}");
            cpu.Add(new HealthRow("CPU", "Query failed", CheckStatus.Unknown));
        }
        if (cpu.Count == 0)
            cpu.Add(new HealthRow("CPU", "Not found", CheckStatus.Unknown));

        // --- Motherboard + Chipset (Win32_BaseBoard + hardware-db.json) ---
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Manufacturer, Product FROM Win32_BaseBoard"))
            {
                var mfr = (inst.CimInstanceProperties["Manufacturer"]?.Value?.ToString() ?? "").Trim();
                var prod = (inst.CimInstanceProperties["Product"]?.Value?.ToString() ?? "").Trim();
                if (string.IsNullOrEmpty(prod)) break;

                // Avoid redundant "ASUS ASUS …" prefix
                var moboDisplay = (!string.IsNullOrEmpty(mfr)
                    && !prod.StartsWith(mfr, StringComparison.OrdinalIgnoreCase))
                    ? $"{mfr} {prod}" : prod;
                cpu.Add(new HealthRow("Motherboard", moboDisplay, CheckStatus.Info));

                var cs = LookupChipset(prod);
                if (cs.Name != null && cs.Year > 0)
                {
                    int age = DateTime.Today.Year - cs.Year;
                    var st = age >= 10 ? CheckStatus.Bad : age >= 7 ? CheckStatus.Warning : CheckStatus.Good;
                    var label = cs.Platform != null ? $"{cs.Name} ({cs.Platform})" : cs.Name;
                    cpu.Add(new HealthRow("Chipset", label, CheckStatus.Info));
                    cpu.Add(new HealthRow("Chipset release", cs.Year.ToString(), st));
                }
                break;
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] BaseBoard query failed: {ex.Message}"); }

        // --- Chipset driver date (registry, fast — supplements BaseBoard) ---
        try
        {
            var (chipDevice, chipDate, chipVer) = GatherChipsetDriverInfo();
            if (chipDate.HasValue)
            {
                int months = (int)((DateTime.Today - chipDate.Value).TotalDays / 30.44);
                var s = months > 24 ? CheckStatus.Warning : CheckStatus.Good;
                cpu.Add(new HealthRow("Chipset driver", chipDate.Value.ToString("yyyy-MM-dd"), s));
                if (chipVer != null)
                    cpu.Add(new HealthRow("Chipset version", chipVer, CheckStatus.Info));
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] Chipset driver info failed: {ex.Message}"); }

        // --- Graphics ---
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name, DriverDate FROM Win32_VideoController"))
            {
                var name = inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim() ?? "Unknown";
                int? driverMonths = null;
                if (inst.CimInstanceProperties["DriverDate"]?.Value is DateTime dd)
                    driverMonths = (int)((DateTime.Today - dd).TotalDays / 30.44);

                var (releaseYear, seriesName) = LookupGpuYear(name);
                gpu.Add(new GpuInfo(name, driverMonths, releaseYear, seriesName));
            }
            if (gpu.Count == 0)
                gpu.Add(new GpuInfo("Not found", null, null, null));
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] GPU query failed: {ex.Message}");
            gpu.Add(new GpuInfo("Query failed", null, null, null));
        }

        // --- RAM ---
        try
        {
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT BankLabel, Capacity, Speed, ConfiguredClockSpeed, SMBIOSMemoryType, PartNumber, Manufacturer FROM Win32_PhysicalMemory"))
            {
                var slot = inst.CimInstanceProperties["BankLabel"]?.Value?.ToString()?.Trim() ?? "?";
                var capRaw = inst.CimInstanceProperties["Capacity"]?.Value;
                double capGb = capRaw is ulong ul ? ul / 1_073_741_824.0
                             : capRaw is uint u ? u / 1_073_741_824.0 : 0;

                // ConfiguredClockSpeed is more accurate than Speed
                var cfgRaw = inst.CimInstanceProperties["ConfiguredClockSpeed"]?.Value;
                int speed = cfgRaw is uint cu ? (int)cu : cfgRaw is int ci ? ci : 0;
                if (speed <= 0)
                {
                    var spdRaw = inst.CimInstanceProperties["Speed"]?.Value;
                    speed = spdRaw is uint su ? (int)su : spdRaw is int si ? si : 0;
                }

                var mtRaw = inst.CimInstanceProperties["SMBIOSMemoryType"]?.Value;
                int memType = mtRaw is ushort us ? us : mtRaw is uint um ? (int)um : 0;

                var pn = inst.CimInstanceProperties["PartNumber"]?.Value?.ToString()?.Trim() ?? "";
                var mfr = inst.CimInstanceProperties["Manufacturer"]?.Value?.ToString()?.Trim() ?? "";
                ram.Add(new RamModule(slot, capGb, speed, memType, pn, ResolveRamManufacturer(mfr, pn)));
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] RAM query failed: {ex.Message}"); }

        // --- SMART ---
        var smartctlPath = FindSmartctl();
        List<DiskHealthInfo> smart;
        bool usedSmartctl;
        if (smartctlPath != null)
        {
            smart = GatherSmartViaSmartctl(smartctlPath);
            usedSmartctl = true;
        }
        else
        {
            smart = GatherSmartViaCim(session);
            usedSmartctl = false;
        }

        // --- Disk space ---
        try
        {
            foreach (var drive in DriveInfo.GetDrives()
                .Where(d => d.DriveType == DriveType.Fixed && d.IsReady))
            {
                long total = drive.TotalSize;
                long free = drive.AvailableFreeSpace;
                long used = total - free;
                double pct = total > 0 ? (double)used / total * 100 : 0;
                var s = pct > 90 ? CheckStatus.Bad : pct > 75 ? CheckStatus.Warning : CheckStatus.Good;
                diskSpace.Add(new DriveRow(drive.Name.TrimEnd('\\'), used, total, s));
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] Disk space failed: {ex.Message}"); }

        // --- Windows version ---
        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
            var displayVer = key?.GetValue("DisplayVersion") as string;
            var buildStr = key?.GetValue("CurrentBuild") as string;
            bool isWin11 = int.TryParse(buildStr, out int build) && build >= 22000;
            var edition = isWin11 ? "Windows 11" : "Windows 10";

            winVer.Add(new HealthRow("Version",
                string.IsNullOrEmpty(displayVer) ? edition : $"{edition} {displayVer}",
                CheckStatus.Info));

            if (!string.IsNullOrEmpty(displayVer) && _winReleaseDates.TryGetValue(displayVer, out var released))
            {
                int months = (int)((DateTime.Today - released).TotalDays / 30.44);
                var s = months > 24 ? CheckStatus.Bad : months > 18 ? CheckStatus.Warning : CheckStatus.Good;
                winVer.Add(new HealthRow("Released", released.ToString("MMM yyyy"), s));
            }
            else if (!string.IsNullOrEmpty(displayVer))
            {
                winVer.Add(new HealthRow("Released", "Unknown", CheckStatus.Unknown));
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] Windows version failed: {ex.Message}");
            winVer.Add(new HealthRow("Version", "Query failed", CheckStatus.Unknown));
        }

        // --- Boot performance ---
        try
        {
            var query = new EventLogQuery(
                "Microsoft-Windows-Diagnostics-Performance/Operational",
                PathType.LogName, "*[System/EventID=100]")
            { ReverseDirection = true };

            using var reader = new EventLogReader(query);
            if (reader.ReadEvent() is { } rec)
            {
                XNamespace ns = "http://schemas.microsoft.com/win/2004/08/events/event"; // DevSkim: ignore DS137138
                var map = XDocument.Parse(rec.ToXml())
                    .Descendants(ns + "Data")
                    .Where(d => d.Attribute("Name") != null)
                    .ToDictionary(d => d.Attribute("Name")!.Value, d => d.Value);

                long? fwMs = TryGetLongMs(map, "FirmwareDuration", "FirmwareBootTime");
                if (fwMs.HasValue)
                {
                    double s = fwMs.Value / 1000.0;
                    var st = s > 30 ? CheckStatus.Bad : s > 10 ? CheckStatus.Warning : CheckStatus.Good;
                    boot.Add(new HealthRow("UEFI/firmware time",
                        s.ToString("F1", CultureInfo.InvariantCulture) + "s", st));
                }

                long? bdMs = TryGetLongMs(map, "BootDuration", "BootTime", "TotalBootTime", "MainPathBootTime");
                if (bdMs.HasValue)
                {
                    double s = bdMs.Value / 1000.0;
                    var st = s > 120 ? CheckStatus.Bad : s > 60 ? CheckStatus.Warning : CheckStatus.Good;
                    boot.Add(new HealthRow("Total boot time",
                        s.ToString("F1", CultureInfo.InvariantCulture) + "s", st));
                }
                rec.Dispose();
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] Boot event log failed: {ex.Message}"); }

        var uptime = TimeSpan.FromMilliseconds(Environment.TickCount64);
        boot.Add(new HealthRow("System uptime",
            uptime.TotalDays >= 1
                ? $"{(int)uptime.TotalDays}d {uptime.Hours}h {uptime.Minutes}m"
                : $"{uptime.Hours}h {uptime.Minutes}m",
            CheckStatus.Info));

        try
        {
            int count = 0;
            foreach (var _ in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name FROM Win32_StartupCommand"))
                count++;
            var s = count > 20 ? CheckStatus.Bad : count > 12 ? CheckStatus.Warning : CheckStatus.Good;
            boot.Add(new HealthRow("Startup programs", count.ToString(), s));
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] Startup programs failed: {ex.Message}"); }

        var battery        = GatherBatteryInfo(session);
        var security       = securityTask.GetAwaiter().GetResult();
        var legacyFeatures = legacyTask.GetAwaiter().GetResult();

        return new HealthData(cpu, gpu, ram, smart, usedSmartctl, diskSpace, winVer, boot, battery, security, legacyFeatures);
    }

    // ── Hardware DB lookups ───────────────────────────────────────────────────

    // Returns (year, seriesName). Checks gpu_models (exact) → gpu_series (pattern) → regex fallback.
    private static (int? year, string? seriesName) LookupGpuYear(string gpuName)
    {
        var db = GetHardwareDb();

        foreach (var model in db.GpuModels)
            if (gpuName.Contains(model.Name, StringComparison.OrdinalIgnoreCase))
                return (model.Year, null);

        foreach (var series in db.GpuSeries)
            if (gpuName.Contains(series.Pattern, StringComparison.OrdinalIgnoreCase))
                return (series.Year, series.Series);

        var fallback = TryGetGpuReleaseYearRegex(gpuName);
        return (fallback, null);
    }

    // Matches chipset pattern against motherboard product name (not followed by a digit).
    private static (string? Name, string? Platform, int Year, string? Note) LookupChipset(string moboProduct)
    {
        var db = GetHardwareDb();
        foreach (var cs in db.Chipsets)
        {
            int idx = moboProduct.IndexOf(cs.Pattern, StringComparison.OrdinalIgnoreCase);
            if (idx < 0) continue;
            int after = idx + cs.Pattern.Length;
            if (after < moboProduct.Length && char.IsDigit(moboProduct[after])) continue;
            return (cs.Name, cs.Platform, cs.Year, cs.Note);
        }
        return (null, null, 0, null);
    }

    // ── Chipset driver date (registry) ────────────────────────────────────────

    private static (string? device, DateTime? driverDate, string? driverVersion) GatherChipsetDriverInfo()
    {
        const string classKey = @"SYSTEM\CurrentControlSet\Control\Class\{4D36E97D-E325-11CE-BFC1-08002BE10318}";
        using var cls = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(classKey);
        if (cls == null) return (null, null, null);

        foreach (var subName in cls.GetSubKeyNames())
        {
            if (!int.TryParse(subName, out _)) continue;
            using var sub = cls.OpenSubKey(subName);
            if (sub == null) continue;

            var desc = sub.GetValue("DriverDesc") as string ?? "";
            if (!desc.Contains("SMBus", StringComparison.OrdinalIgnoreCase)) continue;

            var dateStr = sub.GetValue("DriverDate") as string;
            var verStr = sub.GetValue("DriverVersion") as string;

            DateTime? driverDate = null;
            if (!string.IsNullOrEmpty(dateStr)
                && DateTime.TryParse(dateStr, CultureInfo.InvariantCulture, DateTimeStyles.None, out var dt))
                driverDate = dt;

            return (desc, driverDate, verStr);
        }
        return (null, null, null);
    }

    // ── smartctl helpers ──────────────────────────────────────────────────────

    private static string? FindSmartctl()
    {
        var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var known = Path.Combine(pf, "smartmontools", "bin", "smartctl.exe");
        if (File.Exists(known)) return known;

        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            var c = Path.Combine(dir.Trim(), "smartctl.exe");
            if (File.Exists(c)) return c;
        }
        return null;
    }

    private static string? RunCapture(string exe, string args)
    {
        try
        {
            using var proc = new Process();
            proc.StartInfo = new ProcessStartInfo
            {
                FileName = exe,
                Arguments = args,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            };

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            proc.Start();
            // Read stdout and stderr concurrently so a full stderr buffer cannot
            // block the process and prevent stdout from ever reaching EOF.
            var stderrTask = proc.StandardError.ReadToEndAsync(cts.Token);
            string output;
            try
            {
                output = proc.StandardOutput.ReadToEndAsync(cts.Token).GetAwaiter().GetResult();
            }
            catch (OperationCanceledException)
            {
                proc.Kill(entireProcessTree: true);
                Debug.WriteLine($"[Health] RunCapture '{exe} {args}' timed out after 30s");
                return null;
            }
            try { stderrTask.GetAwaiter().GetResult(); } catch { /* drain only */ }
            proc.WaitForExit();
            return output;
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] RunCapture '{exe} {args}' failed: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Like <see cref="RunCapture"/> but accepts a device path and extra flags separately
    /// so the device path is added via <see cref="ProcessStartInfo.ArgumentList"/> and is
    /// correctly quoted by the OS, even when it contains spaces or special characters.
    /// </summary>
    private static string? RunCaptureWithArgs(string exe, string devicePath, IReadOnlyList<string> extraArgs)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = exe,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            };
            // Each argument is already tokenised by the caller — no space-splitting needed.
            foreach (var arg in extraArgs)
                psi.ArgumentList.Add(arg);
            psi.ArgumentList.Add(devicePath);

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            using var proc = new Process { StartInfo = psi };
            proc.Start();
            var stderrTask = proc.StandardError.ReadToEndAsync(cts.Token);
            string output;
            try
            {
                output = proc.StandardOutput.ReadToEndAsync(cts.Token).GetAwaiter().GetResult();
            }
            catch (OperationCanceledException)
            {
                proc.Kill(entireProcessTree: true);
                Debug.WriteLine($"[Health] RunCaptureWithArgs '{exe} {devicePath}' timed out after 30s");
                return null;
            }
            try { stderrTask.GetAwaiter().GetResult(); } catch { /* drain only */ }
            proc.WaitForExit();
            return output;
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] RunCaptureWithArgs '{exe} {devicePath}' failed: {ex.Message}");
            return null;
        }
    }

    private static List<DiskHealthInfo> GatherSmartViaSmartctl(string smartctlPath)
    {
        var result = new List<DiskHealthInfo>();
        try
        {
            var scanJson = RunCapture(smartctlPath, "--scan --json");
            if (string.IsNullOrWhiteSpace(scanJson)) return result;

            using var scanDoc = JsonDocument.Parse(scanJson);
            if (!scanDoc.RootElement.TryGetProperty("devices", out var devices)) return result;

            foreach (var dev in devices.EnumerateArray())
            {
                var devName = dev.TryGetProperty("name", out var n) ? n.GetString() : null;
                var devType = dev.TryGetProperty("type", out var t) ? t.GetString() : null;
                if (string.IsNullOrEmpty(devName)) continue;

                // Build per-device arguments via ArgumentList so device paths with
                // spaces or special characters are quoted correctly by the OS.
                // Pass each flag as its own element so no space-splitting is needed.
                var scanArgs = (!string.IsNullOrEmpty(devType) && devType != "auto")
                    ? new List<string> { "-a", "-d", devType, "--json" }
                    : new List<string> { "-a", "--json" };

                var dataJson = RunCaptureWithArgs(smartctlPath, devName!, scanArgs);
                if (string.IsNullOrWhiteSpace(dataJson)) continue;

                using var dataDoc = JsonDocument.Parse(dataJson);
                var root = dataDoc.RootElement;

                var model = root.TryGetProperty("model_name", out var mn)
                    ? mn.GetString() ?? devName : devName;

                bool? passed = null;
                if (root.TryGetProperty("smart_status", out var ss) && ss.TryGetProperty("passed", out var p))
                    passed = p.ValueKind == JsonValueKind.True ? true
                           : p.ValueKind == JsonValueKind.False ? false : (bool?)null;
                var (healthText, healthStatus) = passed switch
                {
                    true => ("Healthy", CheckStatus.Good),
                    false => ("FAILING", CheckStatus.Bad),
                    _ => ("Unknown", CheckStatus.Unknown),
                };

                byte? wear = null;
                if (devType == "nvme"
                    && root.TryGetProperty("nvme_smart_health_information_log", out var nvmeLog)
                    && nvmeLog.TryGetProperty("percentage_used", out var pu))
                {
                    wear = (byte)Math.Min(100, Math.Max(0, pu.GetInt32()));
                }
                else if (devType == "sat"
                    && root.TryGetProperty("ata_smart_attributes", out var ata)
                    && ata.TryGetProperty("table", out var table))
                {
                    foreach (var attr in table.EnumerateArray())
                    {
                        if (!attr.TryGetProperty("id", out var idEl)) continue;
                        if (idEl.GetInt32() is 231 or 202 or 177
                            && attr.TryGetProperty("value", out var val))
                        {
                            wear = (byte)(100 - Math.Min(100, Math.Max(0, val.GetInt32())));
                            break;
                        }
                    }
                }

                ushort? temp = null;
                if (root.TryGetProperty("temperature", out var tempNode)
                    && tempNode.TryGetProperty("current", out var tc))
                    temp = (ushort)tc.GetInt32();

                ulong? poh = null;
                if (root.TryGetProperty("power_on_time", out var pot)
                    && pot.TryGetProperty("hours", out var h))
                    poh = (ulong)h.GetInt64();

                int rotRate = root.TryGetProperty("rotation_rate", out var rr) ? rr.GetInt32() : 0;
                var mediaType = devType == "nvme" ? "NVMe SSD"
                    : rotRate > 0 ? "HDD" : "SATA SSD";

                string? speedFlag = null;
                if (devType == "sat")
                {
                    speedFlag = rotRate > 0
                        ? "HDD — mechanical, much slower than SSD"
                        : "SATA — significantly slower than NVMe, consider upgrading";
                }
                else if (devType == "nvme"
                    && root.TryGetProperty("nvme_pcie_link_info", out var pcie)
                    && pcie.TryGetProperty("current_speed", out var cs))
                {
                    var speedStr = cs.GetString() ?? "";
                    if (double.TryParse(speedStr.Replace(" GT/s", ""),
                        NumberStyles.Any, CultureInfo.InvariantCulture, out double gts))
                    {
                        if (gts <= 5.0)
                            speedFlag = "PCIe Gen 1 — old interface, consider upgrading";
                        else if (gts <= 8.0)
                            speedFlag = "PCIe Gen 2 — older interface, consider upgrading";
                    }
                }

                result.Add(new DiskHealthInfo(model!, mediaType, healthStatus, healthText,
                    wear, temp, poh, speedFlag));
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] smartctl parsing failed: {ex.Message}");
        }
        return result;
    }

    private static List<DiskHealthInfo> GatherSmartViaCim(CimSession session)
    {
        var result = new List<DiskHealthInfo>();

        var relMap = new Dictionary<string, (byte? wear, ushort? temp, ulong? poh)>(
            StringComparer.OrdinalIgnoreCase);
        try
        {
            foreach (var rel in session.QueryInstances("root/Microsoft/Windows/Storage", "WQL",
                "SELECT DeviceId, Wear, Temperature, PowerOnHours FROM MSFT_StorageReliabilityCounter"))
            {
                var rid = rel.CimInstanceProperties["DeviceId"]?.Value?.ToString() ?? "";
                var w = rel.CimInstanceProperties["Wear"]?.Value as byte?;
                var rt = rel.CimInstanceProperties["Temperature"]?.Value;
                var t = rt is ushort us ? us : rt is byte bt ? (ushort?)bt : null;
                var rp = rel.CimInstanceProperties["PowerOnHours"]?.Value;
                var p = rp is ulong ul ? ul : rp is uint ui ? (ulong?)ui : null;
                relMap[rid] = (w, t, p);
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] ReliabilityCounter failed: {ex.Message}"); }

        try
        {
            bool any = false;
            foreach (var disk in session.QueryInstances("root/Microsoft/Windows/Storage", "WQL",
                "SELECT DeviceId, FriendlyName, HealthStatus, MediaType, BusType FROM MSFT_PhysicalDisk"))
            {
                var name = disk.CimInstanceProperties["FriendlyName"]?.Value?.ToString() ?? "Unknown";
                var deviceId = disk.CimInstanceProperties["DeviceId"]?.Value?.ToString() ?? "";

                var rawHealth = disk.CimInstanceProperties["HealthStatus"]?.Value;
                int hs = rawHealth is ushort ush ? ush : rawHealth is uint u2 ? (int)u2
                       : rawHealth is int i2 ? i2 : -1;
                var (healthText, healthStatus) = hs switch
                {
                    0 => ("Healthy", CheckStatus.Good),
                    1 => ("Warning", CheckStatus.Warning),
                    2 => ("Unhealthy", CheckStatus.Bad),
                    _ => ("Unknown", CheckStatus.Unknown),
                };

                var rawMedia = disk.CimInstanceProperties["MediaType"]?.Value;
                int mt = rawMedia is ushort umt ? umt : rawMedia is uint umu ? (int)umu : 0;
                var rawBus = disk.CimInstanceProperties["BusType"]?.Value;
                int bt = rawBus is ushort ubt ? ubt : rawBus is uint ubu ? (int)ubu : 0;

                var mediaType = (bt, mt) switch
                {
                    (17, _) => "NVMe SSD",
                    (11, 4) => "SATA SSD",
                    (_, 3) => "HDD",
                    (11, _) => "SATA",
                    _ => mt == 4 ? "SSD" : "Disk",
                };

                string? speedFlag = (bt, mt) switch
                {
                    (11, 4) => "SATA SSD — significantly slower than NVMe, consider upgrading",
                    (11, 3) => "SATA HDD — mechanical, much slower than SSD",
                    (_, 3) => "HDD — mechanical, much slower than SSD",
                    (3, _) => "ATA — very old interface",
                    _ => null,
                };

                relMap.TryGetValue(deviceId, out var rc);
                result.Add(new DiskHealthInfo(name, mediaType, healthStatus, healthText,
                    rc.wear, rc.temp, rc.poh, speedFlag));
                any = true;
            }
            if (!any)
                result.Add(new DiskHealthInfo("No physical disks found", "", CheckStatus.Unknown, "N/A", null, null, null, null));
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] SMART CIM failed: {ex.Message}");
            result.Add(new DiskHealthInfo("Query failed", "", CheckStatus.Unknown, ex.Message, null, null, null, null));
        }
        return result;
    }

    // ── Battery helpers ───────────────────────────────────────────────────────

    private static BatteryInfo? GatherBatteryInfo(CimSession session)
    {
        string? name = null;
        string? chemistry = null;
        int? estimatedRuntimeMin = null;
        int? cycleCount = null;
        bool cycleCountQueried = false;
        int? batteryAgeMonths = null;

        // Check battery presence and get basic data via Win32_Battery
        try
        {
            bool found = false;
            foreach (var inst in session.QueryInstances("root/cimv2", "WQL",
                "SELECT Name, Chemistry, EstimatedRunTime FROM Win32_Battery"))
            {
                found = true;
                name = inst.CimInstanceProperties["Name"]?.Value?.ToString()?.Trim();
                if (inst.CimInstanceProperties["Chemistry"]?.Value is ushort chem)
                    chemistry = DecodeBatteryChemistry(chem);
                if (inst.CimInstanceProperties["EstimatedRunTime"]?.Value is uint rt && rt < 71582)
                    estimatedRuntimeMin = (int)rt;
                break;
            }
            if (!found) return null;
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] Battery CIM failed: {ex.Message}");
            return null;
        }

        // Cycle count via WMI root/WMI — track whether query succeeded (even if value is 0)
        try
        {
            foreach (var inst in session.QueryInstances("root/WMI", "WQL",
                "SELECT CycleCount FROM BatteryCycleCount"))
            {
                cycleCountQueried = true;
                var cc = inst.CimInstanceProperties["CycleCount"]?.Value;
                cycleCount = cc is uint u ? (int)u : cc is int i ? i : (int?)null;
                break;
            }
            if (!cycleCountQueried) cycleCountQueried = true; // class exists but no rows
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] BatteryCycleCount WMI failed: {ex.Message}"); }

        // Battery manufacture date → age in months (FAT date encoding: bits[15:9]=year-1980, [8:5]=month, [4:0]=day)
        try
        {
            foreach (var inst in session.QueryInstances("root/WMI", "WQL",
                "SELECT ManufactureDate FROM BatteryStaticData"))
            {
                var rawDate = inst.CimInstanceProperties["ManufactureDate"]?.Value;
                uint dateVal = rawDate is uint u ? u : rawDate is ushort us ? (uint)us : 0;
                if (dateVal > 0)
                {
                    int day = (int)(dateVal & 0x1F);
                    int month = (int)((dateVal >> 5) & 0x0F);
                    int year = (int)((dateVal >> 9) & 0x7F) + 1980;
                    if (month is >= 1 and <= 12 && day is >= 1 and <= 31 && year >= 2000)
                    {
                        var mfgDate = new DateTime(year, month, day);
                        batteryAgeMonths = (int)((DateTime.Today - mfgDate).TotalDays / 30.44);
                    }
                }
                break;
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] BatteryStaticData WMI failed: {ex.Message}"); }

        // WinRT Battery API for capacity and live power draw
        try
        {
            var report = Battery.AggregateBattery.GetReport();
            if (report.Status == BatteryStatus.NotPresent) return null;

            var statusText = report.Status switch
            {
                BatteryStatus.Charging => "Charging",
                BatteryStatus.Discharging => "Discharging",
                BatteryStatus.Idle => "Idle",
                _ => "Unknown",
            };

            return new BatteryInfo(
                name, chemistry,
                report.DesignCapacityInMilliwattHours,
                report.FullChargeCapacityInMilliwattHours,
                report.RemainingCapacityInMilliwattHours,
                report.ChargeRateInMilliwatts,
                statusText,
                estimatedRuntimeMin,
                cycleCount, cycleCountQueried,
                batteryAgeMonths
            );
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] Battery WinRT API failed: {ex.Message}"); }

        // Fallback: return basic info without capacity data
        return new BatteryInfo(name, chemistry, null, null, null, null, "Unknown",
            estimatedRuntimeMin, cycleCount, cycleCountQueried, batteryAgeMonths);
    }

    private static string DecodeBatteryChemistry(ushort code) => code switch
    {
        3 => "Lead Acid",
        4 => "Nickel Cadmium",
        5 => "Nickel Metal Hydride",
        6 => "Lithium-ion",
        7 => "Zinc Air",
        8 => "Lithium Polymer",
        _ => "Unknown",
    };

    // ── CPU helpers ───────────────────────────────────────────────────────────

    private static (int year, string label) TryGetCpuReleaseYear(string name)
    {
        if (Regex.IsMatch(name, @"Ryzen AI"))
            return (2024, "AMD Ryzen AI");

        var m = Regex.Match(name, @"Core i\d+-(\d{4,5})");
        if (m.Success)
        {
            var model = m.Groups[1].Value;
            int gen = model.Length == 4 ? (model[0] - '0') : int.Parse(model[..2]);
            int year = gen switch
            {
                1 => 2010,
                2 => 2011,
                3 => 2012,
                4 => 2013,
                5 => 2015,
                6 => 2015,
                7 => 2017,
                8 => 2018,
                9 => 2019,
                10 => 2020,
                11 => 2021,
                12 => 2022,
                13 => 2023,
                14 => 2023,
                15 => 2024,
                _ => -1
            };
            if (year > 0) return (year, $"Intel {gen}{Ordinal(gen)} gen");
        }

        var mu = Regex.Match(name, @"Core Ultra \d+ (\d{3,4})");
        if (mu.Success)
        {
            int series = mu.Groups[1].Value[0] - '0';
            int year = series switch { 1 => 2023, 2 => 2024, _ => 2024 };
            return (year, $"Intel Core Ultra Series {series}");
        }

        var mr = Regex.Match(name, @"Ryzen \d+ (\d)\d{3}");
        if (mr.Success)
        {
            int series = mr.Groups[1].Value[0] - '0';
            int year = series switch
            {
                1 => 2017,
                2 => 2018,
                3 => 2019,
                4 => 2020,
                5 => 2021,
                6 => 2022,
                7 => 2023,
                8 => 2024,
                9 => 2024,
                _ => -1
            };
            if (year > 0) return (year, $"AMD Ryzen {series}000 series");
        }

        return (-1, "");
    }

    // ── GPU helpers ───────────────────────────────────────────────────────────

    // Regex fallback — used when hardware-db.json has no match.
    private static int? TryGetGpuReleaseYearRegex(string name)
    {
        var m = Regex.Match(name, @"RTX\s*(\d{2})\d{2}", RegexOptions.IgnoreCase);
        if (m.Success && int.TryParse(m.Groups[1].Value, out int rtxSeries))
            return rtxSeries switch { 50 => 2025, 40 => 2022, 30 => 2020, 20 => 2018, _ => null };

        if (Regex.IsMatch(name, @"GTX\s*16\d{2}", RegexOptions.IgnoreCase)) return 2019;
        if (Regex.IsMatch(name, @"GTX\s*10\d{2}", RegexOptions.IgnoreCase)) return 2016;
        if (Regex.IsMatch(name, @"GTX\s*9\d{2}\b", RegexOptions.IgnoreCase)) return 2014;

        if (Regex.IsMatch(name, @"RX\s*9\d{3}\b", RegexOptions.IgnoreCase)) return 2025;
        if (Regex.IsMatch(name, @"RX\s*7\d{3}\b", RegexOptions.IgnoreCase)) return 2022;
        if (Regex.IsMatch(name, @"RX\s*6\d{3}\b", RegexOptions.IgnoreCase)) return 2020;
        if (Regex.IsMatch(name, @"RX\s*5\d{3}\b", RegexOptions.IgnoreCase)) return 2019;
        if (Regex.IsMatch(name, @"RX\s*[45]\d{2}\b", RegexOptions.IgnoreCase)) return 2017;

        if (Regex.IsMatch(name, @"Arc\s*B\d{3}", RegexOptions.IgnoreCase)) return 2024;
        if (Regex.IsMatch(name, @"Arc\s*A\d{3}", RegexOptions.IgnoreCase)) return 2022;

        return null;
    }

    // ── RAM helpers ───────────────────────────────────────────────────────────

    private static string ResolveRamManufacturer(string mfr, string pn)
    {
        if (!string.IsNullOrEmpty(mfr) && mfr != "Unknown" && mfr.Length > 2) return mfr;
        return pn switch
        {
            var p when p.StartsWith("CM", StringComparison.OrdinalIgnoreCase) => "Corsair",
            var p when p.StartsWith("CT", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("BL", StringComparison.OrdinalIgnoreCase) => "Crucial",
            var p when p.StartsWith("KVR", StringComparison.OrdinalIgnoreCase) => "Kingston",
            var p when p.StartsWith("HX", StringComparison.OrdinalIgnoreCase) => "HyperX / Kingston",
            var p when p.StartsWith("F4-", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("F5-", StringComparison.OrdinalIgnoreCase) => "G.Skill",
            var p when p.StartsWith("TED", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("TEAMGROUP", StringComparison.OrdinalIgnoreCase) => "TeamGroup",
            var p when p.StartsWith("MTA", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("MT", StringComparison.OrdinalIgnoreCase) => "Micron",
            var p when p.StartsWith("M378", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("M471", StringComparison.OrdinalIgnoreCase) => "Samsung",
            var p when p.StartsWith("AD4", StringComparison.OrdinalIgnoreCase)
                    || p.StartsWith("AX4", StringComparison.OrdinalIgnoreCase) => "ADATA",
            _ => mfr.Length > 0 ? mfr : "Unknown"
        };
    }

    private static string Ordinal(int n) => (n % 100) switch
    {
        11 or 12 or 13 => "th",
        _ => (n % 10) switch { 1 => "st", 2 => "nd", 3 => "rd", _ => "th" }
    };

    private static long? TryGetLongMs(Dictionary<string, string> map, params string[] keys)
    {
        foreach (var key in keys)
            if (map.TryGetValue(key, out var v) && long.TryParse(v, out long ms))
                return ms;
        return null;
    }

    // ── UI population ─────────────────────────────────────────────────────────

    private static CheckStatus WorstStatus(IEnumerable<CheckStatus> statuses)
    {
        var worst = CheckStatus.Info;
        foreach (var s in statuses)
        {
            if (s == CheckStatus.Bad) return CheckStatus.Bad;
            if (s == CheckStatus.Warning && worst != CheckStatus.Bad) worst = CheckStatus.Warning;
            if (s == CheckStatus.Good && worst is CheckStatus.Info or CheckStatus.Unknown) worst = CheckStatus.Good;
            if (s == CheckStatus.Unknown && worst == CheckStatus.Info) worst = CheckStatus.Unknown;
        }
        return worst;
    }

    private void SetStatusDot(Microsoft.UI.Xaml.Shapes.Ellipse dot, CheckStatus status)
    {
        var key = status switch
        {
            CheckStatus.Good => "SystemFillColorSuccessBrush",
            CheckStatus.Warning => "SystemFillColorCautionBrush",
            CheckStatus.Bad => "SystemFillColorCriticalBrush",
            _ => "TextFillColorSecondaryBrush",
        };
        if (Application.Current.Resources.TryGetValue(key, out var b))
            dot.Fill = (Brush)b;
    }

    private void PopulateUi(HealthData data)
    {
        LoadingPanel.Visibility = Visibility.Collapsed;

        SetStatusDot(CpuStatusDot, PopulateCard(CpuRows, data.Cpu, CpuExpander));
        SetStatusDot(GpuStatusDot, PopulateGpuCard(GpuRows, data.Gpu, GpuExpander));
        SetStatusDot(RamStatusDot, PopulateRamCard(RamRows, data.Ram, RamExpander));
        SetStatusDot(SmartStatusDot, PopulateDiskHealthCard(SmartRows, data.Smart, data.SmartUsedSmartctl, SmartExpander));
        SetStatusDot(DiskStatusDot, PopulateDriveCard(DiskSpaceRows, data.DiskSpace, DiskExpander));
        SetStatusDot(WinVerStatusDot, PopulateCard(WinVerRows, data.WinVer, WinVerExpander));
        SetStatusDot(BootStatusDot, PopulateCard(BootRows, data.Boot, BootExpander));

        if (data.Battery != null)
            SetStatusDot(BatteryStatusDot, PopulateBatteryCard(BatteryRows, data.Battery, BatteryExpander));

        SetStatusDot(SecurityStatusDot, PopulateSecurityCard(SecurityRows, data.Security, SecurityExpander));
        SetStatusDot(LegacyStatusDot,   PopulateLegacyFeaturesCard(LegacyRows, data.LegacyFeatures, LegacyExpander));
    }

    private CheckStatus PopulateCard(StackPanel panel, List<HealthRow> rows, Expander expander)
    {
        foreach (var row in rows)
            AddStatusRow(panel, row.Label, row.Value, row.Status);
        expander.Visibility = Visibility.Visible;
        return WorstStatus(rows.Select(r => r.Status));
    }

    private CheckStatus PopulateGpuCard(StackPanel panel, List<GpuInfo> gpus, Expander expander)
    {
        bool first = true;
        var statuses = new List<CheckStatus>();
        foreach (var g in gpus)
        {
            if (!first) AddSeparator(panel);
            first = false;

            panel.Children.Add(new TextBlock
            {
                Text = g.Name,
                Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 4),
            });

            if (g.ReleaseYear.HasValue)
            {
                int age = DateTime.Today.Year - g.ReleaseYear.Value;
                var s = age >= 10 ? CheckStatus.Bad : age >= 5 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                if (g.SeriesName != null)
                    AddStatusRow(panel, "Generation", g.SeriesName, CheckStatus.Info);
                AddStatusRow(panel, "Release year", g.ReleaseYear.Value.ToString(), s);
            }
            else
            {
                AddStatusRow(panel, "Release year", "Unknown", CheckStatus.Unknown);
                statuses.Add(CheckStatus.Unknown);
            }

            if (g.DriverAgeMonths.HasValue)
            {
                int months = g.DriverAgeMonths.Value;
                var s = months > 18 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                var txt = months < 12
                    ? $"{months} month{(months == 1 ? "" : "s")}"
                    : $"~{months / 12} year{(months / 12 > 1 ? "s" : "")}";
                AddStatusRow(panel, "Driver age", txt, s);
            }
            else
            {
                AddStatusRow(panel, "Driver age", "Unknown", CheckStatus.Unknown);
                statuses.Add(CheckStatus.Unknown);
            }
        }
        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses);
    }

    private CheckStatus PopulateRamCard(StackPanel panel, List<RamModule> modules, Expander expander)
    {
        var statuses = new List<CheckStatus>();
        if (modules.Count == 0)
        {
            AddStatusRow(panel, "RAM", "No modules found", CheckStatus.Unknown);
            expander.Visibility = Visibility.Visible;
            return CheckStatus.Unknown;
        }

        double totalGb = modules.Sum(m => m.CapacityGb);
        int minSpeed = modules.Where(m => m.SpeedMts > 0).Select(m => m.SpeedMts).DefaultIfEmpty(0).Min();

        var totalStatus = totalGb >= 16 ? CheckStatus.Good
                        : totalGb >= 12 ? CheckStatus.Warning
                        : CheckStatus.Bad;
        statuses.Add(totalStatus);
        AddStatusRow(panel, "Total installed", totalGb > 0 ? $"{totalGb:F0} GB" : "Unknown total", totalStatus);
        if (totalStatus == CheckStatus.Bad)
            AddStatusRow(panel, "RAM note", "Under 12 GB — below 2026 minimum (≥16 GB recommended)", CheckStatus.Bad);
        else if (totalStatus == CheckStatus.Warning)
            AddStatusRow(panel, "RAM note", "12–15 GB — at minimum; 16 GB+ recommended for 2026", CheckStatus.Warning);

        if (minSpeed > 0)
        {
            var ddrType = modules.FirstOrDefault(m => m.MemoryType > 0)?.MemoryType switch
            {
                24 => "DDR3",
                26 => "DDR4",
                34 => "DDR5",
                _ => null
            };
            var speedStatus = ddrType switch
            {
                "DDR3" => CheckStatus.Bad,
                "DDR4" => CheckStatus.Warning,
                "DDR5" => CheckStatus.Good,
                _ => minSpeed < 5200 ? CheckStatus.Warning : CheckStatus.Good,
            };
            statuses.Add(speedStatus);
            var speedLabel = ddrType != null ? $"{minSpeed} MT/s ({ddrType})" : $"{minSpeed} MT/s";
            AddStatusRow(panel, "Speed", speedLabel, speedStatus);
            if (speedStatus == CheckStatus.Bad)
                AddStatusRow(panel, "Speed note", "DDR3 — very old, significantly slower than DDR4/DDR5", CheckStatus.Bad);
            else if (speedStatus == CheckStatus.Warning)
                AddStatusRow(panel, "Speed note",
                    ddrType == "DDR4"
                        ? "DDR4 — functional but not future-proof; DDR5 recommended"
                        : "Below 5200 MT/s — slower than modern DDR5",
                    CheckStatus.Warning);
        }

        AddSeparator(panel);

        bool first = true;
        foreach (var mod in modules)
        {
            if (!first) AddSeparator(panel);
            first = false;

            var capStr = mod.CapacityGb > 0 ? $"{mod.CapacityGb:F0} GB" : "?";
            var speedStr = mod.SpeedMts > 0 ? $"{mod.SpeedMts} MT/s" : "Unknown speed";
            panel.Children.Add(new TextBlock
            {
                Text = $"{mod.Slot}   {capStr}  {speedStr}",
                Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 4),
            });

            if (!string.IsNullOrEmpty(mod.PartNumber))
                AddStatusRow(panel, "Part number", mod.PartNumber, CheckStatus.Info);
            if (mod.Manufacturer != "Unknown" && !string.IsNullOrEmpty(mod.Manufacturer))
                AddStatusRow(panel, "Manufacturer", mod.Manufacturer, CheckStatus.Info);
        }

        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses);
    }

    private CheckStatus PopulateDiskHealthCard(StackPanel panel, List<DiskHealthInfo> disks,
        bool usedSmartctl, Expander expander)
    {
        var statuses = new List<CheckStatus>();
        if (!usedSmartctl)
            AddStatusRow(panel, "Data source", "Install smartmontools for life % data", CheckStatus.Info);

        bool first = true;
        foreach (var d in disks)
        {
            if (!first) AddSeparator(panel);
            first = false;

            panel.Children.Add(new TextBlock
            {
                Text = $"{d.Name}  ({d.MediaType})",
                Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 0, 0, 4),
            });

            statuses.Add(d.HealthStatus);
            AddStatusRow(panel, "Health", d.HealthText, d.HealthStatus);

            if (d.SpeedFlag != null)
            {
                statuses.Add(CheckStatus.Warning);
                AddStatusRow(panel, "Interface note", d.SpeedFlag, CheckStatus.Warning);
            }

            bool hasExtended = false;

            if (d.Wear.HasValue && d.Wear.Value > 0)
            {
                byte used = d.Wear.Value;
                byte rem = (byte)(100 - Math.Min(used, (byte)100));
                var s = used > 80 ? CheckStatus.Bad : used > 50 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                AddStatusRow(panel, "Life remaining", $"{rem}%  ({used}% used)", s);
                hasExtended = true;
            }
            if (d.Temperature.HasValue && d.Temperature.Value > 0)
            {
                ushort t = d.Temperature.Value;
                var s = t > 60 ? CheckStatus.Bad : t > 45 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                AddStatusRow(panel, "Temperature", $"{t}°C", s);
                hasExtended = true;
            }
            if (d.PowerOnHours.HasValue && d.PowerOnHours.Value > 0)
            {
                ulong h = d.PowerOnHours.Value;
                AddStatusRow(panel, "Power-on hours", $"{h:N0}h", CheckStatus.Info);
                hasExtended = true;
            }

            if (!hasExtended && usedSmartctl)
                AddStatusRow(panel, "Extended data", "Not reported by drive", CheckStatus.Info);
        }
        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses);
    }

    private CheckStatus PopulateDriveCard(StackPanel panel, List<DriveRow> rows, Expander expander)
    {
        var statuses = new List<CheckStatus>();
        if (rows.Count == 0)
        {
            AddStatusRow(panel, "Status", "No fixed drives found", CheckStatus.Unknown);
            statuses.Add(CheckStatus.Unknown);
        }

        foreach (var r in rows)
        {
            double pct = r.TotalBytes > 0 ? (double)r.UsedBytes / r.TotalBytes * 100 : 0;
            string used = $"{r.UsedBytes / 1_073_741_824.0:F0} GB";
            string total = $"{r.TotalBytes / 1_073_741_824.0:F0} GB";
            string free = $"{(r.TotalBytes - r.UsedBytes) / 1_073_741_824.0:F0} GB free";
            statuses.Add(r.Status);
            AddStatusRow(panel, r.Drive, $"{used} / {total}  ({pct:F0}%, {free} free)", r.Status);
            panel.Children.Add(new ProgressBar { Value = pct, Maximum = 100, Margin = new Thickness(0, 0, 0, 6) });
        }
        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses);
    }

    private CheckStatus PopulateBatteryCard(StackPanel panel, BatteryInfo bat, Expander expander)
    {
        var statuses = new List<CheckStatus>();

        // Health % — based on current full-charge vs design capacity
        if (bat.DesignCapacityMwh is > 0 && bat.FullChargeCapacityMwh.HasValue)
        {
            double health = (double)bat.FullChargeCapacityMwh.Value / bat.DesignCapacityMwh.Value * 100;
            var s = health >= 80 ? CheckStatus.Good : health >= 50 ? CheckStatus.Warning : CheckStatus.Bad;
            statuses.Add(s);
            double designWh = bat.DesignCapacityMwh.Value / 1000.0;
            double fullWh = bat.FullChargeCapacityMwh.Value / 1000.0;
            AddStatusRow(panel, "Battery health", $"{health:F0}%  ({fullWh:F1} Wh / {designWh:F1} Wh design)", s);

            // Explicit health status label
            var healthLabel = s switch
            {
                CheckStatus.Good => "Good",
                CheckStatus.Warning => "Aging — monitor regularly",
                _ => "Poor — consider replacing",
            };
            AddStatusRow(panel, "Health status", healthLabel, s);
        }

        // Current charge level with progress bar — capture ref for live updates
        if (bat.RemainingCapacityMwh.HasValue && bat.FullChargeCapacityMwh is > 0)
        {
            _battFullCapacityMwh = bat.FullChargeCapacityMwh.Value;
            double chargeOfMax = (double)bat.RemainingCapacityMwh.Value / bat.FullChargeCapacityMwh.Value * 100;
            double remWh = bat.RemainingCapacityMwh.Value / 1000.0;
            _battChargeLevelText = AddStatusRowRef(panel, "Charge level",
                $"{chargeOfMax:F0}%  ({remWh:F1} Wh remaining)", CheckStatus.Info);
            var pb = new ProgressBar { Value = chargeOfMax, Maximum = 100, Margin = new Thickness(0, 2, 0, 4) };
            panel.Children.Add(pb);
            _battProgressBar = pb;
        }

        // Live power draw / status — capture ref for live updates
        if (bat.ChargeRateMw.HasValue)
        {
            int mw = bat.ChargeRateMw.Value;
            string powerText = mw < 0 ? $"Discharging  ({Math.Abs(mw) / 1000.0:F1} W)"
                             : mw > 0 ? $"Charging  ({mw / 1000.0:F1} W)"
                             : "Idle  (plugged in, not charging)";
            _battPowerDrawText = AddStatusRowRef(panel, "Power draw", powerText, CheckStatus.Info);
        }
        else
        {
            AddStatusRow(panel, "Status", bat.StatusText, CheckStatus.Info);
        }

        // Estimated runtime (only meaningful when discharging)
        if (bat.EstimatedRuntimeMin is > 0)
        {
            int mins = bat.EstimatedRuntimeMin.Value;
            string runtimeText = mins >= 60 ? $"{mins / 60}h {mins % 60}min" : $"{mins} min";
            AddStatusRow(panel, "Estimated runtime", runtimeText, CheckStatus.Info);
        }

        // Cycle count — always show when driver reports it, even if value is 0
        if (bat.CycleCountQueried)
        {
            int cc = bat.CycleCount ?? 0;
            if (cc > 0 && cc < 9999)
            {
                var s = cc > 1000 ? CheckStatus.Bad : cc > 500 ? CheckStatus.Warning : CheckStatus.Good;
                statuses.Add(s);
                AddStatusRow(panel, "Cycle count", cc.ToString(), s);
            }
            else
            {
                AddStatusRow(panel, "Cycle count", "Not reported by driver", CheckStatus.Unknown);
            }
        }

        // Battery age from manufacture date
        if (bat.BatteryAgeMonths is > 0)
        {
            int months = bat.BatteryAgeMonths.Value;
            string ageText = months >= 12
                ? $"~{months / 12} year{(months / 12 > 1 ? "s" : "")}  ({months} months)"
                : $"{months} month{(months == 1 ? "" : "s")}";
            var s = months > 48 ? CheckStatus.Warning : CheckStatus.Info;
            if (s == CheckStatus.Warning) statuses.Add(s);
            AddStatusRow(panel, "Battery age", ageText, s);
        }

        // Chemistry
        if (!string.IsNullOrEmpty(bat.Chemistry) && bat.Chemistry != "Unknown")
            AddStatusRow(panel, "Chemistry", bat.Chemistry, CheckStatus.Info);

        expander.Visibility = Visibility.Visible;

        // Start live update timer
        _battTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(3) };
        _battTimer.Tick += OnBatteryTimerTick;
        _battTimer.Start();

        return WorstStatus(statuses.Count > 0 ? statuses : [CheckStatus.Info]);
    }

    private void OnBatteryTimerTick(object? sender, object e)
    {
        try
        {
            var report = Battery.AggregateBattery.GetReport();

            if (_battChargeLevelText != null && _battFullCapacityMwh is > 0
                && report.RemainingCapacityInMilliwattHours.HasValue)
            {
                double chargeOfMax = (double)report.RemainingCapacityInMilliwattHours.Value / _battFullCapacityMwh.Value * 100;
                double remWh = report.RemainingCapacityInMilliwattHours.Value / 1000.0;
                _battChargeLevelText.Text = $"{chargeOfMax:F0}%  ({remWh:F1} Wh remaining)";
                if (_battProgressBar != null)
                    _battProgressBar.Value = chargeOfMax;
            }

            if (_battPowerDrawText != null && report.ChargeRateInMilliwatts.HasValue)
            {
                int mw = report.ChargeRateInMilliwatts.Value;
                _battPowerDrawText.Text = mw < 0 ? $"Discharging  ({Math.Abs(mw) / 1000.0:F1} W)"
                                        : mw > 0 ? $"Charging  ({mw / 1000.0:F1} W)"
                                        : "Idle  (plugged in, not charging)";
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] Battery timer tick failed: {ex.Message}"); }
    }

    // ── Security gathering ────────────────────────────────────────────────────

    private static SecurityInfo GatherSecurityInfo(CimSession session)
    {
        var defender   = new List<HealthRow>();
        var bitlocker  = new List<HealthRow>();
        var secureBoot = new List<HealthRow>();
        var tpm        = new List<HealthRow>();

        // SecurityCenter2: all registered AV products (determines 3rd-party AV context)
        bool hasActiveThirdPartyAv = false;
        try
        {
            foreach (var inst in session.QueryInstances(
                @"ROOT\SecurityCenter2", "WQL",
                "SELECT displayName, productState FROM AntiVirusProduct"))
            {
                var avName = inst.CimInstanceProperties["displayName"]?.Value?.ToString()?.Trim() ?? "Unknown";
                var psRaw  = inst.CimInstanceProperties["productState"]?.Value;
                uint ps    = psRaw is uint u ? u : 0;
                bool avActive = (ps & 0x1000) != 0 && (ps & 0x0100) == 0;
                // Match only Microsoft's own AV — not 3rd-party products that happen to
                // contain "Defender" in their name (e.g. Bitdefender, Total Defense, etc.)
                bool isDefender = avName.StartsWith("Windows Defender",   StringComparison.OrdinalIgnoreCase)
                               || avName.StartsWith("Microsoft Defender", StringComparison.OrdinalIgnoreCase)
                               || avName.Equals("Windows Security",       StringComparison.OrdinalIgnoreCase);
                if (!isDefender)
                {
                    if (avActive) hasActiveThirdPartyAv = true;
                    defender.Add(new HealthRow("Registered AV", avName, avActive ? CheckStatus.Good : CheckStatus.Info));
                }
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] SecurityCenter2: {ex.Message}"); }

        try
        {
            foreach (var inst in session.QueryInstances(
                @"root\Microsoft\Windows\Defender", "WQL",
                "SELECT AMServiceEnabled, RealTimeProtectionEnabled, AntivirusEnabled, AntispywareEnabled FROM MSFT_MpComputerStatus"))
            {
                bool svc = inst.CimInstanceProperties["AMServiceEnabled"]?.Value is bool b1 && b1;
                bool rt  = inst.CimInstanceProperties["RealTimeProtectionEnabled"]?.Value is bool b2 && b2;
                bool av  = inst.CimInstanceProperties["AntivirusEnabled"]?.Value is bool b3 && b3;
                bool asp = inst.CimInstanceProperties["AntispywareEnabled"]?.Value is bool b4 && b4;
                var  off = hasActiveThirdPartyAv ? CheckStatus.Info : CheckStatus.Bad;
                var  rtLabel = rt ? "Enabled" : hasActiveThirdPartyAv ? "Disabled (passive mode)" : "Disabled";
                defender.Add(new HealthRow("Defender Service",     svc ? "Running"  : "Stopped",  svc ? CheckStatus.Good : off));
                defender.Add(new HealthRow("Real-time Protection", rtLabel,                        rt  ? CheckStatus.Good : off));
                defender.Add(new HealthRow("Antivirus",            av  ? "Enabled"  : "Disabled",  av  ? CheckStatus.Good : off));
                defender.Add(new HealthRow("Antispyware",          asp ? "Enabled"  : "Disabled",  asp ? CheckStatus.Good : off));
                break;
            }
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] Defender: {ex.Message}"); }
        if (defender.Count == 0) defender.Add(new HealthRow("Status", "Not available", CheckStatus.Unknown));

        try
        {
            bool any = false;
            foreach (var inst in session.QueryInstances(
                @"ROOT\cimv2\Security\MicrosoftVolumeEncryption", "WQL",
                "SELECT DriveLetter, ProtectionStatus FROM Win32_EncryptableVolume"))
            {
                var drive = inst.CimInstanceProperties["DriveLetter"]?.Value?.ToString() ?? "?";
                var raw   = inst.CimInstanceProperties["ProtectionStatus"]?.Value;
                int ps    = raw is uint u ? (int)u : raw is int i ? i : -1;
                var (label, status) = ps switch
                {
                    1 => ("Encrypted",     CheckStatus.Good),
                    0 => ("Not encrypted", CheckStatus.Warning),
                    _ => ("Unknown",       CheckStatus.Unknown),
                };
                bitlocker.Add(new HealthRow(drive, label, status));
                any = true;
            }
            if (!any) bitlocker.Add(new HealthRow("Status", "No encryptable drives found", CheckStatus.Unknown));
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] BitLocker: {ex.Message}");
            bitlocker.Add(new HealthRow("Status", "Query failed (requires elevation)", CheckStatus.Unknown));
        }

        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SYSTEM\CurrentControlSet\Control\SecureBoot\State");
            bool on = key?.GetValue("UEFISecureBootEnabled") is int v && v == 1;
            secureBoot.Add(new HealthRow("Secure Boot", on ? "Enabled" : "Disabled",
                on ? CheckStatus.Good : CheckStatus.Warning));
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] Secure Boot: {ex.Message}");
            secureBoot.Add(new HealthRow("Secure Boot", "N/A (legacy BIOS?)", CheckStatus.Unknown));
        }

        try
        {
            bool found = false;
            foreach (var inst in session.QueryInstances(
                "root/cimv2/security/microsofttpm", "WQL",
                "SELECT IsActivated_InitialValue, IsEnabled_InitialValue, SpecVersion FROM Win32_Tpm"))
            {
                bool activated = inst.CimInstanceProperties["IsActivated_InitialValue"]?.Value is bool a && a;
                bool enabled   = inst.CimInstanceProperties["IsEnabled_InitialValue"]?.Value  is bool en && en;
                var  spec      = inst.CimInstanceProperties["SpecVersion"]?.Value?.ToString();
                var  version   = !string.IsNullOrEmpty(spec) ? spec.Split(',')[0].Trim() : "Unknown";
                tpm.Add(new HealthRow("Version",   version,              version != "Unknown" ? CheckStatus.Good : CheckStatus.Unknown));
                tpm.Add(new HealthRow("Enabled",   enabled   ? "Yes" : "No", enabled   ? CheckStatus.Good : CheckStatus.Bad));
                tpm.Add(new HealthRow("Activated", activated ? "Yes" : "No", activated ? CheckStatus.Good : CheckStatus.Bad));
                found = true;
                break;
            }
            if (!found) tpm.Add(new HealthRow("Status", "TPM not found or not accessible", CheckStatus.Bad));
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] TPM: {ex.Message}");
            tpm.Add(new HealthRow("Status", "Query failed", CheckStatus.Unknown));
        }

        return new SecurityInfo(defender, bitlocker, secureBoot, tpm);
    }

    private static List<HealthRow> GatherLegacyFeatures()
    {
        var rows = new List<HealthRow>();

        // SMBv1 via registry — absent = disabled on Windows 10 1709+
        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(
                @"SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters");
            var val   = key?.GetValue("SMB1");
            bool smb1 = val is int i && i != 0;
            rows.Add(new HealthRow("SMBv1 Protocol",
                smb1 ? "Enabled — disable immediately" : "Disabled",
                smb1 ? CheckStatus.Bad : CheckStatus.Good));
        }
        catch (Exception ex) { Debug.WriteLine($"[Health] SMBv1: {ex.Message}"); }

        // Check each optional feature via DISM — more reliable than PowerShell for this,
        // and running them in parallel hides the per-call overhead.
        var featureMap = new Dictionary<string, (string Label, bool IsCritical)>(StringComparer.OrdinalIgnoreCase)
        {
            ["VBScript"]                         = ("VBScript",                    true),
            ["WindowsMediaPlayer"]               = ("Legacy Windows Media Player", false),
            ["MicrosoftWindowsPowerShellV2Root"] = ("PowerShell v2",               false),
            ["TelnetClient"]                     = ("Telnet Client",               false),
            ["TFTP"]                             = ("TFTP Client",                 false),
            ["DirectPlay"]                       = ("DirectPlay",                  false),
        };

        var dismPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System), "dism.exe");

        if (File.Exists(dismPath))
        {
            var tasks = featureMap
                .Select(kvp => Task.Run(() => (kvp.Key, kvp.Value, CheckDismFeature(dismPath, kvp.Key))))
                .ToArray();
            Task.WaitAll(tasks, TimeSpan.FromSeconds(30));

            foreach (var t in tasks.Where(t => t.IsCompletedSuccessfully))
            {
                var (key, info, (found, enabled)) = t.Result;
                if (!found)
                    rows.Add(new HealthRow(info.Label, "Removed from OS", CheckStatus.Good));
                else
                {
                    var s = enabled ? (info.IsCritical ? CheckStatus.Bad : CheckStatus.Warning) : CheckStatus.Good;
                    rows.Add(new HealthRow(info.Label, enabled ? "Enabled" : "Disabled", s));
                }
            }
        }
        else
        {
            rows.Add(new HealthRow("Optional features", "dism.exe not found", CheckStatus.Unknown));
        }

        return rows;
    }

    private static readonly Regex _dismStateRegex = new(@"State\s*:\s*(\w[\w ]*)", RegexOptions.Multiline | RegexOptions.Compiled);

    private static (bool Found, bool Enabled) CheckDismFeature(string dismPath, string featureName)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName               = dismPath,
                UseShellExecute        = false,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
                CreateNoWindow         = true,
            };
            psi.ArgumentList.Add("/Online");
            psi.ArgumentList.Add("/Get-FeatureInfo");
            psi.ArgumentList.Add($"/FeatureName:{featureName}");

            using var cts  = new System.Threading.CancellationTokenSource(TimeSpan.FromSeconds(15));
            using var proc = new Process { StartInfo = psi };
            proc.Start();
            string output;
            try   { output = proc.StandardOutput.ReadToEndAsync(cts.Token).GetAwaiter().GetResult(); }
            catch (OperationCanceledException) { proc.Kill(entireProcessTree: true); return (false, false); }
            try   { proc.StandardError.ReadToEndAsync(cts.Token).GetAwaiter().GetResult(); } catch { }
            proc.WaitForExit();

            if (proc.ExitCode != 0) return (false, false); // feature not found on this OS

            var m = _dismStateRegex.Match(output);
            if (!m.Success) return (false, false);
            bool enabled = m.Groups[1].Value.Trim().StartsWith("Enabled", StringComparison.OrdinalIgnoreCase);
            return (true, enabled);
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Health] DISM {featureName}: {ex.Message}");
            return (false, false);
        }
    }

    private CheckStatus PopulateSecurityCard(StackPanel panel, SecurityInfo data, Expander expander)
    {
        var statuses = new List<CheckStatus>();

        void AddSection(string title, List<HealthRow> rows)
        {
            panel.Children.Add(new TextBlock
            {
                Text   = title,
                Style  = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
                Margin = new Thickness(0, 0, 0, 4),
            });
            foreach (var r in rows)
            {
                AddStatusRow(panel, r.Label, r.Value, r.Status);
                if (r.Status != CheckStatus.Info) statuses.Add(r.Status);
            }
        }

        AddSection("Windows Defender", data.Defender);
        AddSeparator(panel);
        AddSection("BitLocker", data.BitLocker);
        AddSeparator(panel);
        AddSection("Secure Boot", data.SecureBoot);
        AddSeparator(panel);
        AddSection("TPM", data.Tpm);

        expander.Visibility = Visibility.Visible;
        return WorstStatus(statuses.Count > 0 ? statuses : [CheckStatus.Info]);
    }

    private CheckStatus PopulateLegacyFeaturesCard(StackPanel panel, List<HealthRow> rows, Expander expander)
    {
        if (rows.Count == 0)
        {
            AddStatusRow(panel, "Status", "No checks available", CheckStatus.Unknown);
            expander.Visibility = Visibility.Visible;
            return CheckStatus.Unknown;
        }
        foreach (var r in rows)
            AddStatusRow(panel, r.Label, r.Value, r.Status);
        expander.Visibility = Visibility.Visible;
        return WorstStatus(rows.Select(r => r.Status));
    }

    private void AddSeparator(StackPanel panel) =>
        panel.Children.Add(new Border
        {
            Height = 1,
            Margin = new Thickness(0, 8, 0, 8),
            Background = (Brush)Application.Current.Resources["CardStrokeColorDefaultBrush"],
        });

    private TextBlock AddStatusRowRef(StackPanel panel, string label, string value, CheckStatus status)
    {
        AddStatusRow(panel, label, value, status);
        var grid = (Grid)panel.Children[panel.Children.Count - 1];
        return (TextBlock)grid.Children[2];
    }

    private void AddStatusRow(StackPanel panel, string label, string value, CheckStatus status)
    {
        var grid = new Grid { ColumnSpacing = 10, Margin = new Thickness(0, 1, 0, 1) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var lbl = new TextBlock
        {
            Text = label,
            Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            VerticalAlignment = VerticalAlignment.Center,
        };

        var (glyph, brushKey) = status switch
        {
            CheckStatus.Good => ("", "SystemFillColorSuccessBrush"),
            CheckStatus.Bad => ("", "SystemFillColorCriticalBrush"),
            CheckStatus.Warning => ("", "SystemFillColorCautionBrush"),
            CheckStatus.Info => ("", "TextFillColorSecondaryBrush"),
            _ => ("", "TextFillColorSecondaryBrush"),
        };

        var icon = new FontIcon
        {
            Glyph = glyph,
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center,
            Foreground = Application.Current.Resources.TryGetValue(brushKey, out var b)
                                    ? (Brush)b
                                    : (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        };

        var val = new TextBlock
        {
            Text = value,
            IsTextSelectionEnabled = true,
            TextWrapping = TextWrapping.Wrap,
            VerticalAlignment = VerticalAlignment.Center,
        };

        Grid.SetColumn(icon, 1);
        Grid.SetColumn(val, 2);
        grid.Children.Add(lbl);
        grid.Children.Add(icon);
        grid.Children.Add(val);
        panel.Children.Add(grid);
    }
}

using NLog;
using System.Runtime.InteropServices;

namespace pcHealth.Helpers;

/// <summary>
/// Reads the Features on Demand catalogue through the DISM API.
/// </summary>
/// <remarks>
/// Win32_OptionalFeature only covers the "Turn Windows features on or off"
/// dialog. Everything under Settings > System > Optional features is a
/// capability instead -- VBScript, Internet Explorer mode, the old Media
/// Player, system Notepad, PowerShell ISE -- and asking the optional feature
/// class about those reports them absent whether or not they are installed.
///
/// dism.exe would answer as well, but that means a process, a timeout and a
/// regex over localised prose. The API behind it uses the same servicing
/// stack and hands back the names and states directly.
/// </remarks>
internal static class DismCapabilities
{
    private static readonly Logger Log = LogManager.GetCurrentClassLogger();

    private const string OnlineImage = "DISM_{53BFAE52-B167-4E2F-A258-0A37B57FF845}";

    // DismPackageFeatureState: what counts as present on this machine.
    private const uint StateInstalled = 4;
    private const uint StateInstallPending = 5;

    private const int AlreadyInitialized = unchecked((int)0xC0040001);

    private static readonly object InitLock = new();
    private static bool _initialised;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct DismCapability
    {
        [MarshalAs(UnmanagedType.LPWStr)] public string? Name;
        public uint State;
    }

    [DllImport("DismApi.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern int DismInitialize(int logLevel, string? logFilePath, string? scratchDirectory);

    [DllImport("DismApi.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern int DismOpenSession(string imagePath, string? windowsDirectory,
        string? systemDrive, out uint session);

    [DllImport("DismApi.dll", ExactSpelling = true)]
    private static extern int DismGetCapabilities(uint session, out IntPtr capabilities, out uint count);

    [DllImport("DismApi.dll", ExactSpelling = true)]
    private static extern int DismDelete(IntPtr dismStructure);

    [DllImport("DismApi.dll", ExactSpelling = true)]
    private static extern int DismCloseSession(uint session);

    /// <summary>
    /// The capabilities present on this machine, or null when DISM would not
    /// answer -- which is not the same as none being installed.
    /// </summary>
    public static HashSet<string>? GetInstalled()
    {
        if (!EnsureInitialised()) return null;

        uint session = 0;
        bool opened = false;
        IntPtr list = IntPtr.Zero;

        try
        {
            int hr = DismOpenSession(OnlineImage, null, null, out session);
            if (hr < 0)
            {
                Log.Debug("DismOpenSession failed: 0x{Hr:X8}", hr);
                return null;
            }
            opened = true;

            hr = DismGetCapabilities(session, out list, out uint count);
            if (hr < 0)
            {
                // Nothing was allocated, so the pointer is not ours to delete.
                list = IntPtr.Zero;
                Log.Debug("DismGetCapabilities failed: 0x{Hr:X8}", hr);
                return null;
            }

            var installed = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            int stride = Marshal.SizeOf<DismCapability>();
            for (uint i = 0; i < count; i++)
            {
                var cap = Marshal.PtrToStructure<DismCapability>(
                    IntPtr.Add(list, checked((int)(i * stride))));
                if ((cap.State == StateInstalled || cap.State == StateInstallPending)
                    && !string.IsNullOrEmpty(cap.Name))
                    installed.Add(cap.Name);
            }
            return installed;
        }
        catch (DllNotFoundException ex) { Log.Debug(ex, "DismApi.dll is not present"); return null; }
        catch (EntryPointNotFoundException ex) { Log.Debug(ex, "DismApi.dll is too old"); return null; }
        finally
        {
            if (list != IntPtr.Zero) DismDelete(list);
            if (opened) DismCloseSession(session);
        }
    }

    /// <summary>
    /// DismInitialize is per process, so this never calls DismShutdown: the
    /// health page rescans, and a second initialise is not an error.
    /// </summary>
    private static bool EnsureInitialised()
    {
        lock (InitLock)
        {
            if (_initialised) return true;

            try
            {
                int hr = DismInitialize(0, null, null);
                if (hr >= 0 || hr == AlreadyInitialized)
                {
                    _initialised = true;
                    return true;
                }
                Log.Debug("DismInitialize failed: 0x{Hr:X8}", hr);
            }
            catch (DllNotFoundException ex) { Log.Debug(ex, "DismApi.dll is not present"); }
            catch (EntryPointNotFoundException ex) { Log.Debug(ex, "DismApi.dll is too old"); }
            return false;
        }
    }
}

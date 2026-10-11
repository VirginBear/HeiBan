using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;

namespace HeiBan.Windows.Updating;

public sealed record UpdateJob(UpdatePackage Package, string InstallDirectory, string CurrentVersion, int ParentId, long ParentStartTicks);
public sealed record UpdateResult(bool Success, string Version, string Message);

public sealed class UpdateInstallation : IDisposable
{
    private readonly FileStream _running;
    public static string Key(string installation) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Path.GetFullPath(installation).TrimEnd('\\', '/').ToUpperInvariant())))[..24];
    public static string Cache(string installation) => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "HeiBan", "Updates", Key(installation));
    public static Mutex Gate(string installation) => new(false, @"Local\HeiBan.Update." + Key(installation));
    public UpdateInstallation(string installation)
    {
        Directory.CreateDirectory(Cache(installation));
        using var gate = Gate(installation);
        var entered = false;
        try
        {
            try { entered = gate.WaitOne(0); } catch (AbandonedMutexException) { entered = true; }
            if (!entered) throw new IOException("黑板正在完成更新，請稍後重新開啟。");
            _running = new FileStream(Path.Combine(Cache(installation), $"running-{Environment.ProcessId}.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        }
        finally { if (entered) gate.ReleaseMutex(); }
    }
    public static bool HasRunningInstance(string installation)
    {
        foreach (var path in Directory.EnumerateFiles(Cache(installation), "running-*.lock"))
        {
            try { using var stale = new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.None); }
            catch (IOException) { return true; }
        }
        // Older builds do not hold a lease. Never ask Inno to terminate them or replace their open files.
        foreach (var process in Process.GetProcessesByName("HeiBan"))
        {
            using (process)
            {
                try
                {
                    if (string.Equals(process.MainModule?.FileName, Path.Combine(installation, "HeiBan.exe"), StringComparison.OrdinalIgnoreCase)) return true;
                }
                catch (System.ComponentModel.Win32Exception) { return true; }
                catch (InvalidOperationException) { }
            }
        }
        return false;
    }
    public void Dispose() => _running.Dispose();
}

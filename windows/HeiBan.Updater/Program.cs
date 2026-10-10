using System.Diagnostics;
using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Updating;

if (args.Length != 1) return 2;
UpdateJob? job = null;
string? cache = null;
try
{
    job = JsonSerializer.Deserialize<UpdateJob>(await File.ReadAllTextAsync(args[0])) ?? throw new InvalidDataException("缺少更新工作。");
    UpdatePolicy.Validate(job.Package);
    var current = ReleaseVersion.Parse(job.CurrentVersion) ?? throw new InvalidDataException("目前版本無效。");
    if (ReleaseVersion.Parse(job.Package.Version)!.CompareTo(current) <= 0) throw new InvalidDataException("不執行降版更新。");
    cache = UpdateInstallation.Cache(job.InstallDirectory);
    if (!Path.GetFullPath(args[0]).Equals(Path.Combine(cache, "job.json"), StringComparison.OrdinalIgnoreCase) ||
        !File.Exists(UpdateFiles.Under(job.InstallDirectory, "HeiBan.exe")) ||
        File.Exists(UpdateFiles.Under(job.InstallDirectory, "portable.dat")) != job.Package.Portable)
        throw new InvalidDataException("更新工作與安裝位置不符。");
    using var workLock = await AcquireWorkLockAsync(Path.Combine(cache, "update.lock"));
    try
    {
        using var parent = Process.GetProcessById(job.ParentId);
        if (parent.StartTime.ToUniversalTime().Ticks == job.ParentStartTicks)
            await parent.WaitForExitAsync().WaitAsync(TimeSpan.FromMinutes(2));
    }
    catch (ArgumentException) { /* The saved parent has already exited. A reused PID must never be terminated. */ }
    using var gate = UpdateInstallation.Gate(job.InstallDirectory);
    var entered = false;
    try
    {
        try { entered = gate.WaitOne(0); } catch (AbandonedMutexException) { entered = true; }
        if (!entered || UpdateInstallation.HasRunningInstance(job.InstallDirectory))
            throw new IOException("仍有黑板視窗開啟，更新保留到下次正常關閉。");
        // The named mutex belongs to this thread. All apply work stays on it until ReleaseMutex.
        Apply(job, cache).GetAwaiter().GetResult();
    }
    finally { if (entered) gate.ReleaseMutex(); }
    await DocumentSessionManager.WriteAtomicAsync(Path.Combine(cache, "result.json"), JsonSerializer.Serialize(new UpdateResult(true, job.Package.Version, "更新完成，下次啟動使用新版。")));
    File.Delete(Path.Combine(cache, "pending.json"));
    return 0;
}
catch (Exception ex)
{
    if (cache is not null && job is not null)
        try { await DocumentSessionManager.WriteAtomicAsync(Path.Combine(cache, "result.json"), JsonSerializer.Serialize(new UpdateResult(false, job.Package.Version,
            ex is TimeoutException ? "等待程式退出逾時，保留更新供下次重試。" : ex.Message))); } catch { }
    return 1;
}

static async Task Apply(UpdateJob job, string cache)
{
    UpdateFiles.RequireArchitecture(UpdateFiles.Under(job.InstallDirectory, "HeiBan.exe"), job.Package.Architecture);
    var packagePath = UpdateFiles.Under(cache, job.Package.Name);
    await UpdateFiles.VerifyAsync(packagePath, job.Package.Size, job.Package.Sha256);
    var appliedVersion = FileVersionInfo.GetVersionInfo(UpdateFiles.Under(job.InstallDirectory, "HeiBan.exe"));
    var installed = new Version(appliedVersion.FileMajorPart, appliedVersion.FileMinorPart, appliedVersion.FileBuildPart, appliedVersion.FilePrivatePart);
    // Stable 1.0.12 sorts after preview.6 even though its fourth FileVersion component is 0.
    // ProductVersion preserves release semantics; numeric FileVersion alone would incorrectly skip promotion to stable.
    var installedRelease = ReleaseVersion.Parse(appliedVersion.ProductVersion?.Split('+')[0] ?? "");
    if (installedRelease is not null && installedRelease.CompareTo(ReleaseVersion.Parse(job.Package.Version)) >= 0) return;
    if (installed != ReleaseVersion.Parse(job.CurrentVersion)!.FileVersion) throw new IOException("安裝版本已改變，請重新檢查更新。");
    var payload = Path.Combine(cache, "payload-" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(payload);
    if (job.Package.Name.EndsWith(".zip", StringComparison.Ordinal)) UpdateFiles.Extract(packagePath, payload);
    if (job.Package.Portable)
    {
        UpdateFiles.RequireArchitecture(UpdateFiles.Under(payload, "HeiBan.exe"), job.Package.Architecture);
        var backup = Path.Combine(cache, "backup-" + Guid.NewGuid().ToString("N"));
        await UpdateFiles.ApplyPortableAsync(job.InstallDirectory, payload, backup, job.CurrentVersion, job.Package.Version);
    }
    else
    {
        if (!File.Exists(UpdateFiles.Under(job.InstallDirectory, "unins000.exe"))) throw new IOException("不是 Inno 安裝版，請從官方下載手動更新。");
        var installer = job.Package.Name.EndsWith(".exe", StringComparison.Ordinal) ? packagePath : UpdateFiles.Under(payload, job.Package.InstallerName);
        var start = new ProcessStartInfo(installer) { UseShellExecute = false, CreateNoWindow = true };
        foreach (var argument in new[] { "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-", "/NOCLOSEAPPLICATIONS", "/NORESTARTAPPLICATIONS", "/DIR=" + job.InstallDirectory, "/LOG=" + Path.Combine(cache, "installer.log") }) start.ArgumentList.Add(argument);
        using var process = Process.Start(start) ?? throw new IOException("無法啟動安裝程式。");
        await process.WaitForExitAsync();
        if (process.ExitCode != 0) throw new IOException($"安裝未完成（代碼 {process.ExitCode}），請使用官方安裝包修復。");
    }
    var result = FileVersionInfo.GetVersionInfo(UpdateFiles.Under(job.InstallDirectory, "HeiBan.exe"));
    UpdateFiles.RequireArchitecture(UpdateFiles.Under(job.InstallDirectory, "HeiBan.exe"), job.Package.Architecture);
    if (new Version(result.FileMajorPart, result.FileMinorPart, result.FileBuildPart, result.FilePrivatePart) != ReleaseVersion.Parse(job.Package.Version)!.FileVersion)
        throw new IOException("安裝後版本不符，請使用官方安裝包修復。");
}

static async Task<FileStream> AcquireWorkLockAsync(string path)
{
    // The app starts this helper just before disposing its handoff lock. Startup speed must not turn that into a failed update.
    for (var attempt = 0; ; attempt++)
    {
        try { return new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
        catch (IOException) when (attempt < 100) { await Task.Delay(100); }
    }
}

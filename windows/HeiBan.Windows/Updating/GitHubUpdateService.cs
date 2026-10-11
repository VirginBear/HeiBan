using static HeiBan.Windows.Localization.Strings;
using System.Diagnostics;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using HeiBan.Windows.Engine;

namespace HeiBan.Windows.Updating;

public sealed class UpdateSettings
{
    public bool Enabled { get; set; } = true;
    public bool IncludePreview { get; set; } = ReleaseVersion.Parse(GitHubUpdateService.CurrentVersion)?.Preview is not null;
    [JsonExtensionData] public Dictionary<string, JsonElement>? Other { get; set; }
}

public sealed class GitHubUpdateService : IDisposable
{
    public static string CurrentVersion => typeof(GitHubUpdateService).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()!.InformationalVersion.Split('+')[0];
    public static bool IsPackaged { get { uint length = 0; return GetCurrentPackageFullName(ref length, IntPtr.Zero) != 15700; } }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern int GetCurrentPackageFullName(ref uint length, IntPtr name);
    private readonly string _installation = AppContext.BaseDirectory;
    private readonly string _cache;
    private readonly bool _portable;
    private readonly CancellationTokenSource _stop = new();
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly HttpClient _http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromMinutes(15) };
    private Task? _background;
    public UpdateSettings Settings { get; private set; } = new();
    private Func<string> _status = () => "";
    public string Status => _status();
    public event Action? Changed;
    public bool Available { get; }
    public bool Busy { get; private set; }

    public GitHubUpdateService(bool portable) : this(portable, AppContext.BaseDirectory, null, false) { }
    // Internal transport injection exercises the real download/cancellation flow without publishing a test Release.
    internal GitHubUpdateService(bool portable, string installation, HttpClient? transport, bool isolatedTest)
    {
        _installation = installation;
        if (transport is not null) _http = transport;
        _portable = portable; _cache = UpdateInstallation.Cache(_installation);
        Available = isolatedTest || (!IsPackaged && string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY")) &&
            !Environment.GetCommandLineArgs().Any(a => a.StartsWith("--validation-output=", StringComparison.Ordinal)));
        _status = () => IsPackaged ? T("此版本由 Microsoft Store 管理更新。") : !Available ? T("隔離驗證模式不連線更新。") : T("啟用背景更新；下載完成後於正常關閉時安裝。");
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("HeiBan-Windows/" + CurrentVersion);
        _http.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        if (!Available) return;
        Directory.CreateDirectory(_cache);
        try { Settings = JsonSerializer.Deserialize<UpdateSettings>(File.ReadAllText(Path.Combine(_cache, "settings.json"))) ?? new(); } catch { }
        try { var result = JsonSerializer.Deserialize<UpdateResult>(File.ReadAllText(Path.Combine(_cache, "result.json"))); if (result is not null) _status = () => T(result.Message); } catch { }
        if (!Settings.Enabled) _status = () => T("自動更新已關閉。");
    }
    private void Report(Func<string> value) { _status = value; Changed?.Invoke(); }
    public void Start()
    {
        if (!Available || _background is not null) return;
        _background = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(TimeSpan.FromSeconds(10), _stop.Token);
                while (!_stop.IsCancellationRequested)
                { if (Settings.Enabled) await CheckAsync(); await Task.Delay(TimeSpan.FromHours(6), _stop.Token); }
            }
            catch (OperationCanceledException) { }
        });
    }
    public async Task SaveSettingsAsync(bool enabled, bool includePreview)
    {
        if (!Available) return;
        Settings.Enabled = enabled; Settings.IncludePreview = includePreview;
        await DocumentSessionManager.WriteAtomicAsync(Path.Combine(_cache, "settings.json"), JsonSerializer.Serialize(Settings));
        Report(() => enabled ? T("已啟用背景更新。") : T("自動更新已關閉；暫存更新不會自動安裝。"));
    }
    public async Task CheckAsync()
    {
        if (!Available || !await _gate.WaitAsync(0)) return;
        Busy = true;
        try
        {
            using var workLock = new FileStream(Path.Combine(_cache, "update.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            Report(() => T("正在檢查 GitHub 更新…"));
            UpdatePackage? candidate = null;
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(_stop.Token); timeout.CancelAfter(TimeSpan.FromSeconds(45));
            var arch = RuntimeInformation.ProcessArchitecture switch { Architecture.Arm64 => "arm64", Architecture.X64 => "x64", _ => throw new InvalidDataException("不支援此處理器架構。") };
            for (var page = 1; page <= 10; page++)
            {
                using var response = await _http.GetAsync($"https://api.github.com/repos/{UpdatePolicy.Repository}/releases?per_page=100&page={page}", HttpCompletionOption.ResponseHeadersRead, timeout.Token).ConfigureAwait(false);
                response.EnsureSuccessStatusCode();
                using var document = JsonDocument.Parse(await ReadBoundedAsync(response.Content, 4 * 1024 * 1024, timeout.Token));
                var found = UpdatePolicy.Select(document.RootElement, CurrentVersion, arch, _portable, Settings.IncludePreview);
                if (found is not null && (candidate is null || ReleaseVersion.Parse(found.Version)!.CompareTo(ReleaseVersion.Parse(candidate.Version)) > 0)) candidate = found;
                if (document.RootElement.GetArrayLength() < 100) break;
            }
            if (candidate is null) { Report(() => T("目前已是所選更新管道的最新版本。")); return; }
            var target = UpdateFiles.Under(_cache, candidate.Name);
            var downloaded = false;
            if (File.Exists(target)) try { await UpdateFiles.VerifyAsync(target, candidate.Size, candidate.Sha256, _stop.Token); downloaded = true; } catch (InvalidDataException) { }
            if (!downloaded)
            {
                Report(() => F($"正在背景下載 {candidate.Version}，可繼續使用黑板…"));
                var temporary = target + ".partial";
                using var downloadTimeout = CancellationTokenSource.CreateLinkedTokenSource(_stop.Token); downloadTimeout.CancelAfter(TimeSpan.FromMinutes(15));
                try
                {
                    using var response = await DownloadResponseAsync(new Uri(candidate.Url), downloadTimeout.Token);
                    if (response.Content.Headers.ContentLength is { } length && length != candidate.Size) throw new InvalidDataException("伺服器更新包大小不符。");
                    await using (var output = new FileStream(temporary, FileMode.Create, FileAccess.Write, FileShare.None, 81920, true))
                    await using (var input = await response.Content.ReadAsStreamAsync(downloadTimeout.Token))
                    {
                        var buffer = new byte[81920]; long total = 0; int count;
                        while ((count = await input.ReadAsync(buffer, downloadTimeout.Token)) > 0)
                        { total += count; if (total > candidate.Size) throw new InvalidDataException("更新下載超過預期大小。"); await output.WriteAsync(buffer.AsMemory(0, count), downloadTimeout.Token); }
                    }
                    await UpdateFiles.VerifyAsync(temporary, candidate.Size, candidate.Sha256, downloadTimeout.Token);
                    File.Move(temporary, target, true);
                }
                finally { if (File.Exists(temporary)) File.Delete(temporary); }
            }
            await DocumentSessionManager.WriteAtomicAsync(Path.Combine(_cache, "pending.json"), JsonSerializer.Serialize(candidate), _stop.Token);
            Report(() => F($"{candidate.Version} 已準備完成，正常關閉後更新，下次啟動使用新版。") + (Settings.Enabled ? "" : T("請啟用自動更新以套用。")));
        }
        catch (OperationCanceledException) { if (!_stop.IsCancellationRequested) Report(() => T("更新連線逾時，下次再試；可繼續使用目前版本。")); }
        catch (HttpRequestException) { Report(() => T("目前無法連線到 GitHub，下次再試；可繼續使用目前版本。")); }
        catch (Exception ex)
        { Report(() => T("這次更新未準備完成：") + ex.Message); }
        finally { Busy = false; _gate.Release(); Changed?.Invoke(); }
    }
    private async Task<HttpResponseMessage> DownloadResponseAsync(Uri uri, CancellationToken token)
    {
        for (var redirect = 0; redirect < 6; redirect++)
        {
            if (uri.Scheme != "https" || !uri.IsDefaultPort || uri.UserInfo.Length != 0 || uri.Host is not ("github.com" or "release-assets.githubusercontent.com" or "objects.githubusercontent.com"))
                throw new InvalidDataException("更新下載被轉到不可信任的位置。");
            var response = await _http.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, token).ConfigureAwait(false);
            if (response.StatusCode is HttpStatusCode.MovedPermanently or HttpStatusCode.Redirect or HttpStatusCode.RedirectMethod or HttpStatusCode.TemporaryRedirect or HttpStatusCode.PermanentRedirect)
            { var location = response.Headers.Location; response.Dispose(); if (location is null) throw new InvalidDataException("更新下載缺少轉址。"); uri = new Uri(uri, location); continue; }
            try { response.EnsureSuccessStatusCode(); return response; } catch { response.Dispose(); throw; }
        }
        throw new InvalidDataException("更新下載轉址次數過多。");
    }
    private static async Task<byte[]> ReadBoundedAsync(HttpContent content, int maximum, CancellationToken token)
    {
        await using var input = await content.ReadAsStreamAsync(token); using var output = new MemoryStream(); var buffer = new byte[81920]; int count;
        while ((count = await input.ReadAsync(buffer, token)) > 0)
        { if (output.Length + count > maximum) throw new InvalidDataException("更新資訊過大。"); output.Write(buffer, 0, count); }
        return output.ToArray();
    }
    public async Task PrepareExitAsync()
    {
        _stop.Cancel(); if (!Available) return;
        await _gate.WaitAsync();
        try
        {
            // Another window may have changed preferences while this instance was open.
            if (File.Exists(Path.Combine(_cache, "settings.json")))
                Settings = JsonSerializer.Deserialize<UpdateSettings>(await File.ReadAllTextAsync(Path.Combine(_cache, "settings.json"))) ?? Settings;
            if (!Settings.Enabled || !File.Exists(Path.Combine(_cache, "pending.json"))) return;
            using var workLock = new FileStream(Path.Combine(_cache, "update.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            var pending = JsonSerializer.Deserialize<UpdatePackage>(await File.ReadAllTextAsync(Path.Combine(_cache, "pending.json"))) ?? throw new InvalidDataException("更新資訊缺失。");
            UpdatePolicy.Validate(pending);
            var architecture = RuntimeInformation.ProcessArchitecture == Architecture.Arm64 ? "arm64" : "x64";
            if (pending.Architecture != architecture || pending.Portable != _portable || (!Settings.IncludePreview && ReleaseVersion.Parse(pending.Version)!.Preview is not null) || ReleaseVersion.Parse(pending.Version)!.CompareTo(ReleaseVersion.Parse(CurrentVersion)) <= 0) return;
            var worker = Path.Combine(_cache, "worker.exe");
            File.Copy(UpdateFiles.Under(_installation, "Updater/HeiBan.Updater.exe"), worker, true);
            using var process = Process.GetCurrentProcess();
            var jobFile = Path.Combine(_cache, "job.json");
            await DocumentSessionManager.WriteAtomicAsync(jobFile, JsonSerializer.Serialize(new UpdateJob(pending, _installation, CurrentVersion, process.Id, process.StartTime.ToUniversalTime().Ticks)));
            var start = new ProcessStartInfo(worker) { UseShellExecute = false, CreateNoWindow = true }; start.ArgumentList.Add(jobFile);
            using var launched = Process.Start(start) ?? throw new IOException("無法啟動更新程式。");
        }
        catch (Exception ex)
        { Report(() => T("更新保留到下次重試：") + ex.Message); }
        finally { _gate.Release(); }
    }
    public void Dispose() => _stop.Cancel();
}

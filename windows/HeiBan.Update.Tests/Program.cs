using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;
using HeiBan.Windows.Updating;

var checks = 0;
void Check(bool value, string label) { if (!value) throw new Exception(label); checks++; }
async Task Reject(Func<Task> action, string label)
{ try { await action(); } catch (Exception e) when (e is IOException or InvalidDataException or UnauthorizedAccessException) { checks++; return; } throw new Exception(label); }
var root = Path.Combine(Path.GetTempPath(), "HeiBan-Update-Tests", Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);
string Hash(string text) => Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(text)));
var versions = new[] { "1.0.12-preview.5", "1.0.12-preview.6", "1.0.12-preview.10", "1.0.12", "1.0.13-preview.1", "2.0.0" };
for (var i = 0; i < versions.Length - 1; i++) Check(ReleaseVersion.Parse(versions[i])!.CompareTo(ReleaseVersion.Parse(versions[i + 1])) < 0, "numeric preview and stable ordering");
foreach (var invalid in new[] { "v1.0.0", "1.0", "1.0.0-beta.1", "01.0.0", "1.0.0-preview.-1", "999999999999.0.0", "1.0.0\n" }) Check(ReleaseVersion.Parse(invalid) is null, "reject invalid version " + invalid);
UpdatePackage Package(string version = "1.0.12-preview.7", string arch = "x64", bool portable = true) => new(version, arch, portable,
    $"HeiBan-Windows-{(portable ? "Portable" : "Installer")}-{version}-win-{arch}.zip",
    $"https://github.com/VirginBear/HeiBan/releases/download/windows-v{version}/HeiBan-Windows-{(portable ? "Portable" : "Installer")}-{version}-win-{arch}.zip", 100, Hash("fixture"));
object Release(UpdatePackage p, bool draft = false, string? tag = null) => new { draft, prerelease = p.Version.Contains("preview"), tag_name = tag ?? p.Tag,
    assets = new[] { new { name = p.Name, browser_download_url = p.Url, size = p.Size, digest = "sha256:" + p.Sha256 } } };
using (var releases = JsonDocument.Parse(JsonSerializer.Serialize(new[] { Release(Package("1.0.12-preview.10")), Release(Package("1.0.13", "arm64")), Release(Package("1.0.14"), true), Release(Package("2.0.0"), false, "macos-v2.0.0"), Release(Package("1.0.12")) })))
{
    Check(UpdatePolicy.Select(releases.RootElement, "1.0.12-preview.6", "x64", true, true)?.Version == "1.0.12", "highest version not release list order");
    Check(UpdatePolicy.Select(releases.RootElement, "1.0.12", "x64", true, true) is null, "do not downgrade");
    Check(UpdatePolicy.Select(releases.RootElement, "1.0.12-preview.6", "arm64", true, false)?.Version == "1.0.13", "architecture and stable channel");
    Check(UpdatePolicy.Select(releases.RootElement, "1.0.12-preview.6", "x64", false, true) is null, "installation type");
}
foreach (var malformed in new[] { Package() with { Url = "http://github.com/x" }, Package() with { Url = Package().Url.Replace("VirginBear", "attacker") }, Package() with { Sha256 = "bad" }, Package() with { Size = UpdatePolicy.MaxPackageBytes + 1 }, Package() with { Name = "../bad.exe" } })
    await Reject(() => { UpdatePolicy.Validate(malformed); return Task.CompletedTask; }, "reject unsafe release metadata");
foreach (var bad in new[] { "../outside", "a/../../b", "/rooted", "C:/file", "folder/file:ads", "AUX.txt", "COM1.txt", "foo./bar", "a//b", "a\\..\\b", "trailing " })
    await Reject(() => { UpdateFiles.Relative(bad); return Task.CompletedTask; }, "reject unsafe ZIP path " + bad);
var fixture = Path.Combine(root, "fixture.bin"); await File.WriteAllTextAsync(fixture, "fixture");
await UpdateFiles.VerifyAsync(fixture, new FileInfo(fixture).Length, Hash("fixture")); checks++;
await Reject(() => UpdateFiles.VerifyAsync(fixture, new FileInfo(fixture).Length, Hash("other")), "hash mismatch");
await Reject(() => UpdateFiles.VerifyAsync(fixture, 100, Hash("fixture")), "size mismatch");
var pe = new byte[128]; pe[0] = 0x4D; pe[1] = 0x5A; pe[0x3C] = 64; pe[64] = 0x50; pe[65] = 0x45; pe[68] = 0x64; pe[69] = 0x86;
var pePath = Path.Combine(root, "machine.exe"); await File.WriteAllBytesAsync(pePath, pe);
UpdateFiles.RequireArchitecture(pePath, "x64"); checks++;
await Reject(() => { UpdateFiles.RequireArchitecture(pePath, "arm64"); return Task.CompletedTask; }, "PE architecture mismatch");
await Reject(() => { UpdateFiles.RequireArchitecture(fixture, "x64"); return Task.CompletedTask; }, "non-PE executable");
foreach (var entries in new[] { new[] { "../escaped" }, new[] { "safe", "SAFE" }, new[] { "Data/private.txt" }, new[] { "folder/file:ads" } })
{
    var zip = Path.Combine(root, Guid.NewGuid() + ".zip");
    using (var archive = ZipFile.Open(zip, ZipArchiveMode.Create)) foreach (var name in entries) { var entry = archive.CreateEntry(name); using var stream = new StreamWriter(entry.Open()); stream.Write("fixture"); }
    await Reject(() => { UpdateFiles.Extract(zip, Path.Combine(root, Guid.NewGuid().ToString())); return Task.CompletedTask; }, "unsafe archive");
}
var symlinkZip = Path.Combine(root, "symlink.zip");
using (var archive = ZipFile.Open(symlinkZip, ZipArchiveMode.Create)) { var entry = archive.CreateEntry("link"); entry.ExternalAttributes = unchecked((int)0xA1FF0000); }
await Reject(() => { UpdateFiles.Extract(symlinkZip, Path.Combine(root, "symlink")); return Task.CompletedTask; }, "symlink archive");

async Task Inventory(string directory, string version, string contents)
{
    var files = new Dictionary<string, string>();
    foreach (var path in new[] { "HeiBan.exe", "HeiBan.pri", "coreclr.dll", "Updater/HeiBan.Updater.exe", "Assets/guide.txt" })
    { var full = UpdateFiles.Under(directory, path); Directory.CreateDirectory(Path.GetDirectoryName(full)!); await File.WriteAllTextAsync(full, contents); files[path] = Hash(contents); }
    await File.WriteAllTextAsync(Path.Combine(directory, UpdateFiles.InventoryName), JsonSerializer.Serialize(new UpdateInventory(version, files)));
}
var install = Path.Combine(root, "portable"); var payload = Path.Combine(root, "next");
await Inventory(install, "1.0.12-preview.6", "old"); await Inventory(payload, "1.0.12-preview.7", "new");
Directory.CreateDirectory(Path.Combine(install, "Data")); await File.WriteAllTextAsync(Path.Combine(install, "Data", "work.txt"), "private fixture");
await File.WriteAllTextAsync(Path.Combine(install, "custom.txt"), "unknown fixture"); await File.WriteAllTextAsync(Path.Combine(install, "portable.dat"), "");
await UpdateFiles.ApplyPortableAsync(install, payload, Path.Combine(root, "backup"), "1.0.12-preview.6", "1.0.12-preview.7");
Check(await File.ReadAllTextAsync(Path.Combine(install, "HeiBan.exe")) == "new", "portable upgraded");
Check(await File.ReadAllTextAsync(Path.Combine(install, "Data", "work.txt")) == "private fixture", "Data preserved");
Check(await File.ReadAllTextAsync(Path.Combine(install, "custom.txt")) == "unknown fixture", "unknown file preserved");
Check(File.Exists(Path.Combine(install, "portable.dat")), "portable marker preserved");
Check(await File.ReadAllTextAsync(Path.Combine(root, "backup", "HeiBan.exe")) == "old", "old payload backed up");

await Inventory(install, "1.0.12-preview.6", "old");
using (var locked = new FileStream(Path.Combine(install, "coreclr.dll"), FileMode.Open, FileAccess.ReadWrite, FileShare.None))
    await Reject(() => UpdateFiles.ApplyPortableAsync(install, payload, Path.Combine(root, "locked-backup"), "1.0.12-preview.6", "1.0.12-preview.7"), "occupied files defer update");
Check(await File.ReadAllTextAsync(Path.Combine(install, "HeiBan.exe")) == "old", "preflight leaves old version intact");
// Force a failure after the first file was moved to exercise rollback rather than only preflight rejection.
var blockedBackup = Path.Combine(root, "blocked-backup"); Directory.CreateDirectory(blockedBackup); await File.WriteAllTextAsync(Path.Combine(blockedBackup, "HeiBan.pri"), "occupied backup");
await Reject(() => UpdateFiles.ApplyPortableAsync(install, payload, blockedBackup, "1.0.12-preview.6", "1.0.12-preview.7"), "rollback on mid-transaction failure");
Check(await File.ReadAllTextAsync(Path.Combine(install, "HeiBan.exe")) == "old", "rollback restored moved executable");
Check(await File.ReadAllTextAsync(Path.Combine(install, "Data", "work.txt")) == "private fixture", "rollback did not touch Data");
await File.WriteAllTextAsync(Path.Combine(install, "Assets", "guide.txt"), "user changed owned file");
await Reject(() => UpdateFiles.ApplyPortableAsync(install, payload, Path.Combine(root, "modified-backup"), "1.0.12-preview.6", "1.0.12-preview.7"), "modified owned file preserved");
Check(await File.ReadAllTextAsync(Path.Combine(install, "Assets", "guide.txt")) == "user changed owned file", "modified file not lost");
foreach (var scenario in new[] { "ok", "corrupt", "unsafe-redirect", "offline", "old", "cancel" })
{
    var testInstallation = Path.Combine(root, "http-" + scenario); Directory.CreateDirectory(testInstallation);
    var handler = new UpdateHttpFixture(scenario);
    using var http = new HttpClient(handler);
    using var service = new GitHubUpdateService(true, testInstallation, http, true);
    var pending = Path.Combine(UpdateInstallation.Cache(testInstallation), "pending.json");
    var checkTask = service.CheckAsync();
    if (scenario == "cancel")
    {
        await handler.DownloadStarted.Task.WaitAsync(TimeSpan.FromSeconds(10));
        await service.PrepareExitAsync().WaitAsync(TimeSpan.FromSeconds(10)); await checkTask;
        Check(!File.Exists(pending), "exit cancels download without publishing pending job");
        Check(!Directory.EnumerateFiles(UpdateInstallation.Cache(testInstallation), "*.partial").Any(), "cancel removes incomplete package");
    }
    else
    {
        await checkTask;
        Check(File.Exists(pending) == (scenario == "ok"), "only verified complete download becomes pending: " + scenario);
        Check(!service.Busy, "check always releases busy state: " + scenario);
        if (scenario == "ok")
        {
            var before = handler.Downloads; await service.CheckAsync(); Check(handler.Downloads == before, "verified package reused on recheck");
            await service.SaveSettingsAsync(false, true); await service.PrepareExitAsync();
            Check(!File.Exists(Path.Combine(UpdateInstallation.Cache(testInstallation), "job.json")), "disabled updates never launch helper");
            Check(File.Exists(pending), "disabled updates preserve downloaded package");
            var wrongArchitecture = JsonSerializer.Deserialize<UpdatePackage>(await File.ReadAllTextAsync(pending))!;
            wrongArchitecture = wrongArchitecture with { Architecture = "arm64", Name = wrongArchitecture.Name.Replace("win-x64", "win-arm64"), Url = wrongArchitecture.Url.Replace("win-x64", "win-arm64") };
            await File.WriteAllTextAsync(pending, JsonSerializer.Serialize(wrongArchitecture));
            Directory.CreateDirectory(Path.Combine(testInstallation, "Updater")); await File.WriteAllBytesAsync(Path.Combine(testInstallation, "Updater", "HeiBan.Updater.exe"), []);
            await service.SaveSettingsAsync(true, true); await service.PrepareExitAsync();
            Check(!File.Exists(Path.Combine(UpdateInstallation.Cache(testInstallation), "worker.exe")), "architecture change rejects stale pending before helper handoff");
        }
        if (scenario == "unsafe-redirect") Check(handler.Requests.All(u => u.Host != "attacker.example"), "never follow unsafe redirect");
        if (scenario == "old") Check(handler.Downloads == 0, "older release never downloaded");
    }
}
Console.WriteLine($"{checks} update checks passed. Synthetic fixtures: {root}");

sealed class UpdateHttpFixture(string scenario) : HttpMessageHandler
{
    public List<Uri> Requests { get; } = [];
    public int Downloads { get; private set; }
    public TaskCompletionSource DownloadStarted { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token)
    {
        var uri = request.RequestUri!; Requests.Add(uri);
        if (uri.Host == "api.github.com")
        {
            if (scenario == "offline") throw new HttpRequestException("offline fixture");
            var version = scenario == "old" ? "1.0.12-preview.5" : "1.0.12-preview.7";
            var name = $"HeiBan-Windows-Portable-{version}-win-x64.zip";
            var payload = System.Text.Encoding.UTF8.GetBytes("download fixture");
            var releases = new[] { new { draft = false, prerelease = true, tag_name = "windows-v" + version, assets = new[] { new {
                name, browser_download_url = $"https://github.com/VirginBear/HeiBan/releases/download/windows-v{version}/{name}",
                size = payload.Length, digest = "sha256:" + Convert.ToHexString(SHA256.HashData(payload)) } } } };
            return new(System.Net.HttpStatusCode.OK) { Content = new StringContent(JsonSerializer.Serialize(releases)) };
        }
        if (uri.Host == "github.com")
        {
            var response = new HttpResponseMessage(System.Net.HttpStatusCode.Redirect);
            response.Headers.Location = new Uri(scenario == "unsafe-redirect" ? "https://attacker.example/payload" : "https://release-assets.githubusercontent.com/fixture");
            return response;
        }
        Downloads++; DownloadStarted.TrySetResult();
        if (scenario == "cancel") await Task.Delay(Timeout.Infinite, token);
        return new(System.Net.HttpStatusCode.OK) { Content = new ByteArrayContent(System.Text.Encoding.UTF8.GetBytes(scenario == "corrupt" ? "corrupt! fixture" : "download fixture")) };
    }
}

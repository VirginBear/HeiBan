using System.Security.Cryptography;
using System.Text.Json;
using System.Xml.Linq;
using HeiBan.Windows.Diagnostics;

if (args.Length != 2) throw new ArgumentException("Supply the Windows source root and a new JSON evidence path.");
var windows = Path.GetFullPath(args[0]);
var evidence = Path.GetFullPath(args[1]);
if (File.Exists(evidence)) throw new IOException("Keep earlier evidence. Choose a new output path.");
var findings = new List<Violation>();
var sources = new SortedDictionary<string, string>(StringComparer.Ordinal);
foreach (var project in new[] { "HeiBan.Windows.Core", "HeiBan.Windows" })
{
    var root = Path.Combine(windows, project);
    foreach (var file in Directory.EnumerateFiles(root, "*.cs", SearchOption.AllDirectories))
    {
        var relative = Path.GetRelativePath(windows, file).Replace('\\', '/');
        if (relative.Split('/').Any(part => part is "obj" or "bin") ||
            relative.StartsWith("HeiBan.Windows/Updating/", StringComparison.Ordinal)) continue;
        var content = await File.ReadAllTextAsync(file);
        findings.AddRange(ArchitecturePolicy.Inspect(relative, content, project == "HeiBan.Windows.Core"));
        sources[relative] = Convert.ToHexStringLower(SHA256.HashData(await File.ReadAllBytesAsync(file)));
    }
}

var corePath = Path.Combine(windows, "HeiBan.Windows.Core/HeiBan.Windows.Core.csproj");
var coreProject = XDocument.Load(corePath);
foreach (var reference in coreProject.Descendants().Where(e => e.Name.LocalName is "ProjectReference" or "PackageReference" or "FrameworkReference"))
{
    var include = (string?)reference.Attribute("Include") ?? "";
    if (include.Contains("WindowsAppSDK", StringComparison.OrdinalIgnoreCase) ||
        include.Contains("Win2D", StringComparison.OrdinalIgnoreCase) ||
        include.Contains("HeiBan.Windows.csproj", StringComparison.OrdinalIgnoreCase) ||
        include.Contains("WindowsDesktop", StringComparison.OrdinalIgnoreCase))
        findings.Add(new("HB001", "HeiBan.Windows.Core/HeiBan.Windows.Core.csproj", 1, "Core must not reference the UI host or a platform UI framework."));
}

var projectFile = Path.Combine(windows, "HeiBan.Windows/HeiBan.Windows.csproj");
var packageFile = Path.Combine(windows, "HeiBan.Windows/Packaging/Store/Package.appxmanifest");
var identityFile = Path.Combine(windows, "HeiBan.Windows/Packaging/Store/StoreIdentity.json");
var properties = XDocument.Load(projectFile).Descendants().Where(e => e.Name.LocalName is "Version" or "FileVersion" or "AssemblyVersion")
    .ToDictionary(e => e.Name.LocalName, e => e.Value);
using var identity = JsonDocument.Parse(await File.ReadAllTextAsync(identityFile));
var package = XDocument.Load(packageFile).Descendants().Single(e => e.Name.LocalName == "Identity");
var packageVersion = properties["Version"] + ".0";
if (properties["FileVersion"] != packageVersion || properties["AssemblyVersion"] != packageVersion ||
    (string?)package.Attribute("Version") != packageVersion || identity.RootElement.GetProperty("packageVersion").GetString() != packageVersion ||
    (string?)package.Attribute("Name") != identity.RootElement.GetProperty("name").GetString() ||
    (string?)package.Attribute("Publisher") != identity.RootElement.GetProperty("publisher").GetString())
    findings.Add(new("HB005", "HeiBan.Windows/Packaging/Store", 1, "Application version and Store identity must agree."));

var selfChecks = 0;
void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
    selfChecks++;
}
foreach (var (source, rule, core) in new[]
{
    ("using Microsoft.UI.Xaml; class Bad {}", "HB001", true),
    ("class Bad { Microsoft.Graphics.Canvas.CanvasBitmap value; }", "HB001", true),
    ("class Bad { void Run() { Thread.Sleep(1); } }", "HB002", false),
    ("class Bad { void Run() { CanvasBitmap.LoadAsync(device, stream); } }", "HB003", false),
    ("class MainWindow { void CanvasSurface_PointerMoved() { JsonSerializer.Serialize(document); } }", "HB004", false),
    ("class WindowsInkCoordinator { void Append() { _session.Commit(); } }", "HB004", false)
})
    Check(ArchitecturePolicy.Inspect("fixture.cs", source, core).Any(v => v.Rule == rule), "The checker failed to reject " + rule);
Check(ArchitecturePolicy.Inspect("fixture.cs",
    "class MainWindow { void CanvasSurface_PointerMoved() { var text = \"File.ReadAllText(path)\"; /* _session.Commit(); */ PresentInteraction(); } }", false).Count == 0,
    "Comments or strings must not trigger checks.");
Check(ArchitecturePolicy.Inspect("Engine/Direct2DCanvasRenderer.ToolArt.cs",
    "class Art { void Load() { CanvasBitmap.LoadAsync(device, stream); } }", false).Count == 0, "Bundled tool art must be allowed.");
foreach (var name in DiagnosticLaunchOptions.Names)
{
    var launch = DiagnosticLaunchOptions.Parse(["--" + name + "=evidence"]);
    Check(launch?.Name == name && Path.IsPathFullyQualified(launch.Output), "Diagnostic mode parsing failed.");
}
Check(DiagnosticLaunchOptions.Parse(["--screen-canvas"]) is null, "Normal startup changed.");
foreach (var invalid in new[] { new[] { "--validation-output=" }, new[] { "--validation-output=a", "--performance-output=b" } })
{
    try { DiagnosticLaunchOptions.Parse(invalid); throw new InvalidOperationException("Invalid diagnostic arguments were accepted."); }
    catch (ArgumentException) { selfChecks++; }
}
foreach (var directory in new string?[] { null, windows, evidence })
{
    // The evidence file does not exist yet. Use an existing file to cover the file collision.
    var candidate = directory == evidence ? projectFile : directory;
    try { DiagnosticLaunchOptions.RequireFreshDataDirectory(candidate); throw new InvalidOperationException("Unsafe data directory accepted."); }
    catch (InvalidOperationException error) when (error.Message.StartsWith("Diagnostics require", StringComparison.Ordinal)) { selfChecks++; }
}

Directory.CreateDirectory(Path.GetDirectoryName(evidence)!);
await File.WriteAllTextAsync(evidence, JsonSerializer.Serialize(new
{
    schema = 1, passed = findings.Count == 0, selfChecks, inspectedFiles = sources.Count, sources, findings,
    scope = "C# syntax policies and project metadata. Does not prove transitive call behavior, GUI interaction or input latency."
}, new JsonSerializerOptions { WriteIndented = true }));
foreach (var finding in findings) Console.Error.WriteLine($"{finding.File}({finding.Line}): {finding.Rule} {finding.Message}");
Console.WriteLine($"Architecture checks: {sources.Count} files, {findings.Count} violations, {selfChecks} checker checks.");
return findings.Count == 0 ? 0 : 1;

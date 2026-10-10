using System.Runtime.InteropServices;
using System.Text.Json;
using HeiBan.Windows.Diagnostics;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

if (args.Length != 2) throw new ArgumentException("Usage: HeiBan.Windows.Performance <output.json> <label>");
var cases = new List<object>(); long checksum = 0;
foreach (var count in new[] { 0, 300, 1000, 10000 })
{
    var document = new HeiBanDocument { Objects = Enumerable.Range(0, count).Select(i => new BoardObject
    {
        Id = "synthetic-" + i, Type = "rect", X = i % 100 * 10, Y = i / 100 * 10,
        Width = 8, Height = 8, FillColor = "#39735A", ZIndex = (i * 7919) % 101, IsVisible = i % 31 != 0
    }).ToList() };
    var session = new EditorSession(); session.Open(document);
    var drawOrder = PerformanceMeasurement.Measure(() =>
    {
        foreach (var item in session.DrawingObjects) checksum += item.ZIndex;
    }, 80, 5);
    var hit = PerformanceMeasurement.Measure(() => { checksum += session.Hit(new(11, 1), 0)?.ZIndex ?? -1; }, 80, 5);
    var miss = PerformanceMeasurement.Measure(() => { checksum += session.Hit(new(-100, -100), 0)?.ZIndex ?? -1; }, 80, 5);
    cases.Add(new { objects = count, drawOrder, hit, miss });
}
var output = new
{
    schemaVersion = 1, label = args[1], sourceCommit = Environment.GetEnvironmentVariable("HEIBAN_PERFORMANCE_SOURCE"),
    architecture = RuntimeInformation.ProcessArchitecture.ToString(), runtime = RuntimeInformation.FrameworkDescription,
    os = RuntimeInformation.OSDescription, scope = "Synthetic CPU ordering and hit testing; warm samples; not hardware input latency",
    capturedUtc = DateTime.UtcNow, workingSetBytes = Environment.WorkingSet, checksum, cases
};
Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(args[0]))!);
await File.WriteAllTextAsync(args[0], JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine($"Saved {cases.Count} CPU scenarios: {args[0]}");

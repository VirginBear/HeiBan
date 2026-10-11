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
var spatialCases=new List<object>();
foreach(var count in new[]{0,300,1000,10000})
{
 var doc=new HeiBanDocument{Objects=Enumerable.Range(0,count).Select(i=>new BoardObject
 {Id="spatial-"+i,Type="rect",X=i%100*100,Y=i/100*100,Width=20,Height=20,ZIndex=i%11}).ToList()};
 var session=new EditorSession();session.Open(doc);var cache=new ObjectViewportCache();
 var world=new VectorMath.RectBounds(0,0,1024,640);
 bool Intersects(BoardObject item)
 {
  var radius=Math.Sqrt(item.Width*item.Width+item.Height*item.Height)/2+item.StrokeWidth+32;
  var cx=item.X+item.Width/2;var cy=item.Y+item.Height/2;
  return world.Intersects(new(cx-radius,cy-radius,cx+radius,cy+radius));
 }
 var ordered=session.DrawingObjects;
 var flat=ordered.Select(item=>
 {
  var radius=Math.Sqrt(item.Width*item.Width+item.Height*item.Height)/2+item.StrokeWidth+32;
  var cx=item.X+item.Width/2;var cy=item.Y+item.Height/2;
  return (item,bounds:new VectorMath.RectBounds(cx-radius,cy-radius,cx+radius,cy+radius));
 }).ToArray();
 var coldBytes=GC.GetAllocatedBytesForCurrentThread();var coldStart=System.Diagnostics.Stopwatch.GetTimestamp();
 var initial=cache.Query(ordered,world).Count();var coldMs=System.Diagnostics.Stopwatch.GetElapsedTime(coldStart).TotalMilliseconds;
 var coldAllocatedBytes=GC.GetAllocatedBytesForCurrentThread()-coldBytes;
 var scan=PerformanceMeasurement.Measure(()=>{foreach(var item in session.DrawingObjects)if(Intersects(item))checksum+=item.ZIndex;},80,5);
 // Frozen synthetic bounds only: lower-bound alternative, without geometry mutation validation.
 var frozenFlat=PerformanceMeasurement.Measure(()=>{_ = session.DrawingObjects;foreach(var entry in flat)if(world.Intersects(entry.bounds))checksum+=entry.item.ZIndex;},80,5);
 var grid=PerformanceMeasurement.Measure(()=>{foreach(var item in cache.Query(session.DrawingObjects,world))if(Intersects(item))checksum+=item.ZIndex;},80,5);
 var singleMove=PerformanceMeasurement.Measure(()=>
 {
  if(count>0)doc.Objects[0].X=doc.Objects[0].X==0?10:0;
  foreach(var item in cache.Query(session.DrawingObjects,world))if(Intersects(item))checksum+=item.ZIndex;
 },80,5);
 spatialCases.Add(new{objects=count,spacingWorld=100,candidates=initial,gridCells=cache.CellCount,memberships=cache.MembershipCount,global=cache.GlobalCount,updates=cache.Updates,coldMs,coldAllocatedBytes,scan,frozenFlat,grid,singleMove});
}
var output = new
{
    schemaVersion = 1, label = args[1], sourceCommit = Environment.GetEnvironmentVariable("HEIBAN_PERFORMANCE_SOURCE"),
    architecture = RuntimeInformation.ProcessArchitecture.ToString(), runtime = RuntimeInformation.FrameworkDescription,
    os = RuntimeInformation.OSDescription, scope = "Synthetic CPU ordering and hit testing; warm samples; not hardware input latency",
    capturedUtc = DateTime.UtcNow, workingSetBytes = Environment.WorkingSet, checksum, cases,spatialCases
};
Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(args[0]))!);
await File.WriteAllTextAsync(args[0], JsonSerializer.Serialize(output, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine($"Saved {cases.Count} CPU scenarios: {args[0]}");

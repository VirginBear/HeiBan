using System.Diagnostics;
using System.Text.Json;

namespace HeiBan.Windows.Diagnostics;

public enum InputStage { PointerDown,PointerMove,InkCommit,CanvasDraw,SceneRender,MagnetRebuild,ToolSwitch,BrushPanel,LayersRefresh,UiHeartbeat,ScreenRender,EraserMove,EraserApply,EraserCommit,SceneRebuild,WetInkRender,InkEncode,InkSnapshot,WetRasterAppend,ScreenReadback,PointerBatchToDraw,PointerBatchToPresent,SwapChainPresent,LaserRender }

/// <summary>
/// Opt-in local timings of real user interaction, never synthetic input. The
/// fixed rings contain durations/allocation counts only: no text, coordinates,
/// document names or contents. CPU timings do not measure GPU/display latency.
/// </summary>
public static class InputLatencyTrace
{
    private const int Capacity=2048;
    private static readonly string? Destination=Environment.GetEnvironmentVariable("HEIBAN_INPUT_TRACE");
    public static bool Enabled=>!string.IsNullOrWhiteSpace(Destination);
    private sealed class Samples
    {
        internal readonly double[] Milliseconds=new double[Capacity];
        internal long Count,Allocated;internal double Maximum;
    }
    private static readonly Samples[] Rings=Enabled?Enum.GetValues<InputStage>().Select(_=>new Samples()).ToArray():[];
    private static readonly int[] InitialCollections=[GC.CollectionCount(0),GC.CollectionCount(1),GC.CollectionCount(2)];
    private static readonly long Started=Stopwatch.GetTimestamp();
    private static readonly long InitialAllocated=Enabled?GC.GetTotalAllocatedBytes(false):0;
    private static readonly TimeSpan InitialPause=Enabled?GC.GetTotalPauseDuration():TimeSpan.Zero;
    public readonly struct Scope:IDisposable
    {
        private readonly InputStage _stage;private readonly long _start,_allocated;
        internal Scope(InputStage stage){_stage=stage;_start=Enabled?Stopwatch.GetTimestamp():0;_allocated=_start==0?0:GC.GetAllocatedBytesForCurrentThread();}
        public void Dispose(){if(_start!=0)Record(_stage,Stopwatch.GetElapsedTime(_start).TotalMilliseconds,GC.GetAllocatedBytesForCurrentThread()-_allocated);}
    }
    public static Scope Measure(InputStage stage)=>new(stage);
    public static void Record(InputStage stage,double milliseconds,long allocated=0)
    {
        if(!Enabled)return;var ring=Rings[(int)stage];
        lock(ring){ring.Milliseconds[ring.Count%Capacity]=milliseconds;ring.Count++;ring.Allocated+=Math.Max(0,allocated);ring.Maximum=Math.Max(ring.Maximum,milliseconds);}
    }
    public static async Task SaveAsync()
    {
        if(!Enabled)return;
        var stages=Enum.GetValues<InputStage>().Select(stage=>
        {
            var ring=Rings[(int)stage];
            lock(ring)
            {
                var retained=(int)Math.Min(Capacity,ring.Count);var values=ring.Milliseconds.Take(retained).Order().ToArray();
                double Rank(double rank)=>retained==0?0:values[Math.Clamp((int)Math.Ceiling(retained*rank)-1,0,retained-1)];
                return new{stage=stage.ToString(),count=ring.Count,retained,p50Ms=Rank(.5),p95Ms=Rank(.95),p99Ms=Rank(.99),maxMs=ring.Maximum,totalAllocatedBytes=ring.Allocated};
            }
        }).ToArray();
        var memory=GC.GetGCMemoryInfo();
        var report=new{schema=3,presentation=InputPresentationTrace.Summary(),scope="Real user CPU handler/drawing submission durations; nested stages overlap. Not GPU execution or end-to-end input/display latency. UI heartbeat includes OS scheduling and inactive periods. EraserApply runs on a worker thread.",
            recordedUtc=DateTime.UtcNow,elapsedSeconds=Stopwatch.GetElapsedTime(Started).TotalSeconds,
            processWorkingSetBytes=Environment.WorkingSet,collections=Enumerable.Range(0,3).Select(i=>GC.CollectionCount(i)-InitialCollections[i]).ToArray(),
            totalManagedAllocatedBytes=GC.GetTotalAllocatedBytes(false)-InitialAllocated,gcPauseMs=(GC.GetTotalPauseDuration()-InitialPause).TotalMilliseconds,
            lastGcHeapBytes=memory.HeapSizeBytes,lastGcFragmentedBytes=memory.FragmentedBytes,lastGcPromotedBytes=memory.PromotedBytes,stages};
        var path=Path.GetFullPath(Destination!);Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        await File.WriteAllTextAsync(path,JsonSerializer.Serialize(report,new JsonSerializerOptions{WriteIndented=true}));
    }
}

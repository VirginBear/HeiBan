using System.Diagnostics;

namespace HeiBan.Windows.Diagnostics;

/// <summary>Opt-in aggregate timings/distances only. No pointer coordinates are retained.</summary>
public static class InputPresentationTrace
{
    private static long _arrival,_sequence,_drawnSequence,_drawingArrival;
    private static long _compared,_projected;
    private static double _maxEndpointGapDips,_maxTimestampGapMs;
    private static string _path="not-drawn";
    private static int _fallbackHresult;
    private static int _wetBatch;
    public static void SetWetBatch(int size){if(InputLatencyTrace.Enabled)_wetBatch=size;}
    public static void SetPath(string path,int hresult=0)
    {if(!InputLatencyTrace.Enabled)return;_path=path;if(hresult!=0)_fallbackHresult=hresult;}
    public static void PointerBatch(long arrival,ulong currentTimestamp,ulong acceptedTimestamp,double endpointGapDips,bool projected)
    {
        if(!InputLatencyTrace.Enabled)return;
        _arrival=arrival;++_sequence;
        if(projected){++_projected;return;}
        ++_compared;
        _maxEndpointGapDips=Math.Max(_maxEndpointGapDips,endpointGapDips);
        // Both values originate from PointerPoint; never subtract this clock
        // from Stopwatch. This is sample agreement, not time spent in OS queues.
        if(currentTimestamp>=acceptedTimestamp)
            _maxTimestampGapMs=Math.Max(_maxTimestampGapMs,(currentTimestamp-acceptedTimestamp)/1000d);
    }
    public static void BeginDraw()
    {
        _drawingArrival=0;
        if(!InputLatencyTrace.Enabled||_drawnSequence==_sequence)return;
        _drawnSequence=_sequence;_drawingArrival=_arrival;
        InputLatencyTrace.Record(InputStage.PointerBatchToDraw,Stopwatch.GetElapsedTime(_arrival).TotalMilliseconds);
    }
    public static void EndPresent()
    {
        if(_drawingArrival!=0)
            InputLatencyTrace.Record(InputStage.PointerBatchToPresent,Stopwatch.GetElapsedTime(_drawingArrival).TotalMilliseconds);
        _drawingArrival=0;
    }
    public static void EndDrawWithoutPresent()=>_drawingArrival=0;
    internal static object Summary()=>new{renderPath=_path,fallbackHresult=_fallbackHresult,solidWetBatchSize=_wetBatch,
        comparedBatches=_compared,projectedBatches=_projected,maxEndpointGapDips=_maxEndpointGapDips,maxTimestampGapMs=_maxTimestampGapMs,
        scope="Main canvas event arrival to drawing/submission only; excludes OS input queue and physical display. Endpoint agreement uses received samples; projected ruler strokes excluded. No coordinates retained."};
}

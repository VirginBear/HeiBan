using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

// Queue/preview/complete run on the owning UI thread. Only the isolated worker
// document enters Task.Run; renderers never observe its mutable collections.
internal sealed class CircularEraserGesture
{
    private readonly BoardEraserWork _worker;
    private readonly List<InkPoint> _pending=[];
    private readonly long _generation,_epoch;
    private Task? _batch;
    private Task<HeiBanDocument?>? _completion;
    private bool _cancelled;
    internal EditorSession Preview {get;}=new();
    internal bool IsFinishing {get;private set;}
    internal event Action? PreviewChanged;
    internal CircularEraserGesture(EditorSession session,double radius,bool whole)
    {
        _generation=session.Generation;_epoch=session.DocumentEpoch;
        // The UI preview only reads this starting document. The worker owns the
        // independent clone below; changed previews cross via EraserPreviewPublisher.
        Preview.Open(session.Document);
        _worker=new(DocumentCodec.Clone(session.Document),radius,whole);
    }
    internal bool Matches(EditorSession session)=>!_cancelled&&session.Generation==_generation&&session.DocumentEpoch==_epoch;
    internal void Queue(InkPoint point){if(!_cancelled&&!IsFinishing)_pending.Add(point);}
    internal Task PumpAsync()
    {
        if(_cancelled||IsFinishing||_pending.Count==0||_batch?.IsCompleted==false)return Task.CompletedTask;
        return _batch=DrainAsync();
    }
    private async Task DrainAsync()
    {
        // Start on input, then drain arrivals after each worker completes. A
        // result no longer waits for the next periodic UI timer to be noticed.
        do{await ApplyAsync();}while(!_cancelled&&!IsFinishing&&_pending.Count>0);
    }
    private async Task ApplyAsync()
    {
        var points=_pending.ToArray();_pending.Clear();
        var snapshot=await Task.Run(()=>_worker.Apply(points));
        if(_cancelled||snapshot is null)return;
        Preview.Open(snapshot);PreviewChanged?.Invoke();
    }
    internal Task<HeiBanDocument?> CompleteAsync()=>_completion??=CompleteCoreAsync();
    private async Task<HeiBanDocument?> CompleteCoreAsync()
    {
        IsFinishing=true;if(_batch is not null)await _batch;
        while(!_cancelled&&_pending.Count>0)await ApplyAsync();
        return !_cancelled&&_worker.Changed?Preview.Document:null;
    }
    internal void Cancel(){_cancelled=true;_pending.Clear();_worker.Cancel();}
}

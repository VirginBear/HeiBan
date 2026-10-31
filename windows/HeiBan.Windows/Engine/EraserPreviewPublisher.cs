using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

// EraseChanged / EraseFootprintChanged remove objects or replace them with new
// fragments; they never mutate surviving objects. Clone each survivor once at
// this worker -> UI boundary. Published objects are read-only until completion,
// so later previews keep stable geometry keys without sharing worker state.
internal sealed class EraserPreviewPublisher
{
    private bool _seeded;
    private Dictionary<BoardObject,BoardObject> _published=new(ReferenceEqualityComparer.Instance);
    internal VectorMath.RectBounds? Damage {get;private set;}
    internal bool FullDamage {get;private set;}
    private void Include(BoardObject item)
    {
        var bounds=RectangularEraser.ConservativeBounds(item);if(bounds is null){FullDamage=true;return;}
        var b=bounds.Value;Damage=Damage is { } a?new(Math.Min(a.MinX,b.MinX),Math.Min(a.MinY,b.MinY),Math.Max(a.MaxX,b.MaxX),Math.Max(a.MaxY,b.MaxY)):b;
    }
    internal void Seed(HeiBanDocument worker,HeiBanDocument preview)
    {
        // Worker and preview originate from the same ordered snapshot. Only immutable UI
        // survivors are reused; replaced fragments are cloned before crossing back to UI.
        if(worker.Objects.Count!=preview.Objects.Count)throw new ArgumentException("Preview snapshot mismatch");
        for(var i=0;i<worker.Objects.Count;i++)_published[worker.Objects[i]]=preview.Objects[i];_seeded=true;
    }
    internal HeiBanDocument Publish(HeiBanDocument source)
    {
        Damage=null;FullDamage=!_seeded;_seeded=true;
        var next=new Dictionary<BoardObject,BoardObject>(source.Objects.Count,ReferenceEqualityComparer.Instance);
        var objects=new List<BoardObject>(source.Objects.Count);
        foreach(var item in source.Objects)
        {
            if(!_published.TryGetValue(item,out var copy)){copy=DocumentCodec.Clone(item);Include(item);}
            next[item]=copy;objects.Add(copy);
        }
        foreach(var removed in _published.Keys)if(!next.ContainsKey(removed))Include(removed);
        _published=next; // Removed fragments must not accumulate during a long drag.
        return new HeiBanDocument{SchemaVersion=source.SchemaVersion,Version=source.Version,
            Board=DocumentCodec.Clone(source.Board),Objects=objects,ExportedAt=source.ExportedAt,
            ExtraFields=source.ExtraFields is null?null:new(source.ExtraFields)};
    }
}

using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

// EraseChanged / EraseFootprintChanged remove objects or replace them with new
// fragments; they never mutate surviving objects. Clone each survivor once at
// this worker -> UI boundary. Published objects are read-only until completion,
// so later previews keep stable geometry keys without sharing worker state.
internal sealed class EraserPreviewPublisher
{
    private Dictionary<BoardObject,BoardObject> _published=new(ReferenceEqualityComparer.Instance);
    internal HeiBanDocument Publish(HeiBanDocument source)
    {
        var next=new Dictionary<BoardObject,BoardObject>(source.Objects.Count,ReferenceEqualityComparer.Instance);
        var objects=new List<BoardObject>(source.Objects.Count);
        foreach(var item in source.Objects)
        {
            if(!_published.TryGetValue(item,out var copy))copy=DocumentCodec.Clone(item);
            next[item]=copy;objects.Add(copy);
        }
        _published=next; // Removed fragments must not accumulate during a long drag.
        return new HeiBanDocument{SchemaVersion=source.SchemaVersion,Version=source.Version,
            Board=DocumentCodec.Clone(source.Board),Objects=objects,ExportedAt=source.ExportedAt,
            ExtraFields=source.ExtraFields is null?null:new(source.ExtraFields)};
    }
}

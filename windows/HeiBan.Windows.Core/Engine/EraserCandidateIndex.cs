using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

// This index belongs exclusively to an erase worker. Objects are replaced, never
// mutated in place; every fragment is registered before the next contact query.
internal sealed class EraserCandidateIndex
{
    private const double CellSize=256;
    private readonly record struct Cells(int Left,int Top,int Right,int Bottom)
    {public long Count=>((long)Right-Left+1)*((long)Bottom-Top+1);}
    private readonly Dictionary<(int,int),HashSet<BoardObject>> _cells=[];
    private readonly Dictionary<BoardObject,(Cells? Cells,VectorMath.RectBounds? Bounds)> _entries=new(ReferenceEqualityComparer.Instance);
    private readonly HashSet<BoardObject> _global=new(ReferenceEqualityComparer.Instance);
    internal EraserCandidateIndex(IEnumerable<BoardObject> objects){foreach(var item in objects)Add(item);}
    internal void Add(BoardObject item)
    {
        var bounds=RectangularEraser.ConservativeBounds(item);
        if(bounds is not { } box||!TryCells(box,out var cells)||cells.Count>64)
        {_entries[item]=(null,bounds);_global.Add(item);return;}
        _entries[item]=(cells,bounds);
        for(var x=cells.Left;x<=cells.Right;x++)for(var y=cells.Top;y<=cells.Bottom;y++)
        {if(!_cells.TryGetValue((x,y),out var bucket))_cells[(x,y)]=bucket=new(ReferenceEqualityComparer.Instance);bucket.Add(item);}
    }
    internal void Remove(BoardObject item)
    {
        if(!_entries.Remove(item,out var entry))return;
        _global.Remove(item);
        if(entry.Cells is not { } cells)return;
        for(var x=cells.Left;x<=cells.Right;x++)for(var y=cells.Top;y<=cells.Bottom;y++)
        {if(!_cells.TryGetValue((x,y),out var bucket))continue;bucket.Remove(item);if(bucket.Count==0)_cells.Remove((x,y));}
    }
    internal IReadOnlyList<BoardObject> Query(VectorMath.RectBounds bounds)
    {
        if(!TryCells(bounds,out var cells)||cells.Count>4096)return _entries.Keys.ToArray();
        var found=new HashSet<BoardObject>(_global,ReferenceEqualityComparer.Instance);
        for(var x=cells.Left;x<=cells.Right;x++)for(var y=cells.Top;y<=cells.Bottom;y++)
            if(_cells.TryGetValue((x,y),out var bucket))found.UnionWith(bucket);
        return found.Where(item=>_entries[item].Bounds is not { } box||box.Intersects(bounds)).ToArray();
    }
    private static bool TryCells(VectorMath.RectBounds bounds,out Cells cells)
    {
        cells=default;
        if(!double.IsFinite(bounds.MinX)||!double.IsFinite(bounds.MinY)||!double.IsFinite(bounds.MaxX)||!double.IsFinite(bounds.MaxY)||bounds.MaxX<bounds.MinX||bounds.MaxY<bounds.MinY)return false;
        var left=Math.Floor(bounds.MinX/CellSize);var top=Math.Floor(bounds.MinY/CellSize);var right=Math.Floor(bounds.MaxX/CellSize);var bottom=Math.Floor(bounds.MaxY/CellSize);
        if(left < -1000000000||top < -1000000000||right>1000000000||bottom>1000000000)return false;
        cells=new((int)left,(int)top,(int)right,(int)bottom);return true;
    }
}

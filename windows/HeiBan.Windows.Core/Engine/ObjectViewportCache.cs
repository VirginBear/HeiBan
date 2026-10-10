using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>
/// UI-thread rendering broad phase, not an exact hit/erase index. Results are immutable ordered views.
/// Mutable model fields are checked before reuse, including edits inside an uncommitted transaction.
/// </summary>
public sealed class ObjectViewportCache
{
    private const int SmallDocument=512, MaxMemberships=16, MaxQueryCells=4096;
    private const double CellSize=256;
    private readonly record struct Key(double X,double Y,double Width,double Height,double Stroke,string Type,string? Extension,double OffsetX,double OffsetY,ulong Version)
    {
        public static Key Read(BoardObject item)=>new(item.X,item.Y,item.Width,item.Height,item.StrokeWidth,item.Type,item.Extension,item.PreviewOffsetX,item.PreviewOffsetY,item.RenderBoundsVersion);
        public bool Matches(BoardObject item)=>Version==item.RenderBoundsVersion;
    }
    private readonly record struct Cells(int Left,int Top,int Right,int Bottom)
    {
        public long Count=>((long)Right-Left+1)*((long)Bottom-Top+1);
    }
    private OrderedBoardObjects? _source;
    private Key[] _keys=[];
    private VectorMath.RectBounds[] _bounds=[];
    private Cells?[] _ranges=[];
    private readonly Dictionary<(int X,int Y),List<int>> _cells=[];
    private readonly HashSet<int> _global=[];
    private int[] _seen=[];
    private int _stamp;
    public long Rebuilds { get; private set; }
    public long Updates { get; private set; }
    public int CellCount=>_cells.Count;
    public int MembershipCount { get; private set; }
    public int GlobalCount=>_global.Count;
    public void Clear()
    {
        _source=null;_keys=[];_bounds=[];_ranges=[];_seen=[];_cells.Clear();_global.Clear();MembershipCount=0;_stamp=0;
    }
    public OrderedBoardObjects Query(OrderedBoardObjects source,VectorMath.RectBounds world)
    {
        if(!source.IsAscending||source.Items.Length<SmallDocument)
        {
            // Switching to a small/new document must release the previous document's strong references.
            if(!ReferenceEquals(source,_source))Clear();
            return source;
        }
        Ensure(source);
        if(!TryCells(world,out var range)||range.Count>MaxQueryCells||range.Count>=_cells.Count*.35)return source;
        if(_stamp==int.MaxValue){Array.Clear(_seen);_stamp=0;}_stamp++;
        var candidates=new List<int>();
        foreach(var index in _global){_seen[index]=_stamp;candidates.Add(index);}
        for(var x=range.Left;x<=range.Right;x++)
        for(var y=range.Top;y<=range.Bottom;y++)
        {
            if(!_cells.TryGetValue((x,y),out var bucket))continue;
            foreach(var index in bucket)
                if(_seen[index]!=_stamp)
                {
                    _seen[index]=_stamp;
                    if(world.Intersects(_bounds[index]))candidates.Add(index);
                }
        }
        // Dense views pay no per-object sorting/output allocation: use the existing ordered scan.
        if(candidates.Count>=source.Items.Length/4)return source;
        candidates.Sort();
        var items=new BoardObject[candidates.Count];
        for(var i=0;i<items.Length;i++)items[i]=source.Items[candidates[i]];
        return new(source.Document,items,true);
    }
    private void Ensure(OrderedBoardObjects source)
    {
        var items=source.Items;
        if(ReferenceEquals(source,_source))
        {
            for(var i=0;i<items.Length;i++)
            {
                if(_keys[i].Matches(items[i]))continue;
                // Moving a few selected objects must not rebuild the whole document's grid each frame.
                Remove(i);Insert(i,Key.Read(items[i]));Updates++;
            }
            return;
        }
        Clear();_source=source;_keys=new Key[items.Length];_bounds=new VectorMath.RectBounds[items.Length];
        _ranges=new Cells?[items.Length];_seen=new int[items.Length];
        for(var i=0;i<items.Length;i++)Insert(i,Key.Read(items[i]));
        Rebuilds++;
    }
    private void Remove(int index)
    {
        if(_ranges[index] is not { } range){_global.Remove(index);return;}
        for(var x=range.Left;x<=range.Right;x++)
        for(var y=range.Top;y<=range.Bottom;y++)
        {
            var bucket=_cells[(x,y)];bucket.Remove(index);MembershipCount--;
            if(bucket.Count==0)_cells.Remove((x,y));
        }
        _ranges[index]=null;
    }
    private void Insert(int index,Key key)
    {
        _keys[index]=key;
        if(!TryBounds(key,out var bounds)||!TryCells(bounds,out var range)||range.Count>MaxMemberships)
        {_global.Add(index);return;}
        _bounds[index]=bounds;_ranges[index]=range;
        for(var x=range.Left;x<=range.Right;x++)
        for(var y=range.Top;y<=range.Bottom;y++)
        {
            if(!_cells.TryGetValue((x,y),out var bucket))_cells[(x,y)]=bucket=[];
            bucket.Add(index);MembershipCount++;
        }
    }
    private static bool TryBounds(Key key,out VectorMath.RectBounds bounds)
    {
        bounds=default;
        // Other types may extend beyond XYWH (curve control hull, line endpoints, text decorations).
        // They stay global and retain the renderer's existing exact culling/drawing behavior.
        if(key.Type is not ("rect" or "circle" or "image" or "tape")||key.Extension is "start" or "end" or "both")return false;
        var radius=Math.Sqrt(key.Width*key.Width+key.Height*key.Height)/2+key.Stroke+32;
        // This encloses the existing rotation-independent renderer bounds AND transient translated bounds.
        radius+=Math.Abs(key.OffsetX)+Math.Abs(key.OffsetY);
        var cx=key.X+key.Width/2;var cy=key.Y+key.Height/2;
        bounds=new(cx-radius,cy-radius,cx+radius,cy+radius);
        return key.Width>=0&&key.Height>=0&&key.Stroke>=0&&radius>=0;
    }
    private static bool TryCells(VectorMath.RectBounds bounds,out Cells cells)
    {
        cells=default;
        if(!double.IsFinite(bounds.MinX)||!double.IsFinite(bounds.MinY)||!double.IsFinite(bounds.MaxX)||!double.IsFinite(bounds.MaxY)
            ||bounds.MaxX<bounds.MinX||bounds.MaxY<bounds.MinY)return false;
        var left=Math.Floor(bounds.MinX/CellSize);var top=Math.Floor(bounds.MinY/CellSize);
        var right=Math.Floor(bounds.MaxX/CellSize);var bottom=Math.Floor(bounds.MaxY/CellSize);
        // Bounded cell coordinates also keep inclusive loops and count arithmetic away from overflow.
        if(left < -1000000000||top < -1000000000||right > 1000000000||bottom > 1000000000)return false;
        cells=new((int)left,(int)top,(int)right,(int)bottom);return true;
    }
}

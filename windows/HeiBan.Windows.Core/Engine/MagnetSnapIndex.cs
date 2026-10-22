using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>A gesture-local spatial index; querying never changes document points or undo history.</summary>
public sealed class MagnetSnapIndex
{
    // Both hosts use the same boundary: construction anchors may snap, but
    // freehand samples must not be pulled toward an existing stroke mid-gesture.
    public static bool SupportsConstructionTool(string tool)=>tool is "curve" or "line" or "arrow" or "rect" or "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star";
    private readonly Dictionary<(long X,long Y),List<InkPoint>> _cells=[];
    private readonly double _radius;
    public MagnetSnapIndex(IEnumerable<BoardObject> objects,double radius)
    {
        _radius=double.IsFinite(radius)&&radius>0?radius:10;
        foreach(var item in objects)Add(item);
    }
    // Only append-only ink may update an existing index. Edits, removals, page
    // changes and Undo must still rebuild it at the host's generation boundary.
    public void Add(BoardObject item)
    {
        if(item.IsVisible==false)return;
        foreach(var p in ReferencePoints(item))
        {
            if(!double.IsFinite(p.X)||!double.IsFinite(p.Y))continue;
            var key=Cell(p);if(!_cells.TryGetValue(key,out var bucket))_cells[key]=bucket=[];
            bucket.Add(new(p.X,p.Y));
        }
    }
    /// <summary>Geometric references are independent of editable handles, including locked shapes.</summary>
    public static IEnumerable<InkPoint> ReferencePoints(BoardObject item)
    {
        static InkPoint Middle(InkPoint a,InkPoint b)=>new((a.X+b.X)/2,(a.Y+b.Y)/2);
        if(item.Type is "line" or "arrow")
        {
            var a=ObjectHandles.Endpoint(item,0);var b=ObjectHandles.Endpoint(item,1);
            yield return a;yield return Middle(a,b);yield return b;yield break;
        }
        if(item.Type is "circle" or "arc")
        {
            var center=ObjectHandles.Center(item);yield return center;
            var rx=item.Type=="arc"?item.ArcRadius??item.Width/2:item.Width/2;
            var ry=item.Type=="arc"?rx:item.Height/2;
            foreach(var (x,y) in new[]{(0d,-1d),(1d,0d),(0d,1d),(-1d,0d)})
                yield return ObjectHandles.ToWorld(item,new(center.X+x*rx,center.Y+y*ry));
            if(item.Type=="arc")foreach(var angle in new[]{item.ArcStartAngle??0,(item.ArcStartAngle??0)+(item.ArcSweepAngle??360)})
                yield return ObjectHandles.ToWorld(item,new(center.X+rx*Math.Cos(angle*Math.PI/180),center.Y+rx*Math.Sin(angle*Math.PI/180)));
            yield break;
        }
        var polygon=item.Type is "rect" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star";
        var points=item.ParsedPoints.Select(p=>ObjectHandles.ToWorld(item,p)).ToArray();
        if(item.Type=="rect")points=ObjectHandles.Outline(item).ToArray();
        else if(polygon&&points.Length==0)
        {
            var count=item.Type=="triangle"?3:item.Type=="pentagon"?5:item.Type=="star"?10:4;
            points=Enumerable.Range(0,count).Select(i=>{var angle=-Math.PI/2+i*2*Math.PI/count;var radius=item.Type=="star"&&i%2==1?.45:1;return ObjectHandles.ToWorld(item,new(item.X+item.Width/2+Math.Cos(angle)*item.Width/2*radius,item.Y+item.Height/2+Math.Sin(angle)*item.Height/2*radius));}).ToArray();
        }
        foreach(var point in points)yield return point;
        if(polygon&&points.Length>1)for(var i=0;i<points.Length;i++)yield return Middle(points[i],points[(i+1)%points.Length]);
        if(item.Type=="rect")yield return ObjectHandles.Center(item);
    }
    private (long X,long Y) Cell(InkPoint p)=>((long)Math.Floor(p.X/_radius),(long)Math.Floor(p.Y/_radius));
    public InkPoint Snap(InkPoint point,out bool snapped)
    {
        var cell=Cell(point);var distance=_radius*_radius;InkPoint? nearest=null;
        for(var x=-1;x<=1;x++)for(var y=-1;y<=1;y++)
            if(_cells.TryGetValue((cell.X+x,cell.Y+y),out var bucket))foreach(var target in bucket)
            {var d=Math.Pow(point.X-target.X,2)+Math.Pow(point.Y-target.Y,2);if(d<=distance){distance=d;nearest=target;}}
        snapped=nearest is not null;
        if(nearest is null)return point;
        var result=new InkPoint(nearest.X,nearest.Y,point.Pressure){TiltX=point.TiltX,TiltY=point.TiltY};return result;
    }
}

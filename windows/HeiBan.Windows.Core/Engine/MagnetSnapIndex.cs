using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>A gesture-local spatial index; querying never changes document points or undo history.</summary>
public sealed class MagnetSnapIndex
{
    private readonly Dictionary<(long X,long Y),List<InkPoint>> _cells=[];
    private readonly double _radius;
    public MagnetSnapIndex(IEnumerable<BoardObject> objects,double radius)
    {
        _radius=double.IsFinite(radius)&&radius>0?radius:10;
        foreach(var item in objects.Where(o=>o.IsVisible!=false))
        {
            IEnumerable<InkPoint> points;
            if(item.Type is "line" or "arrow")points=[ObjectHandles.Endpoint(item,0),ObjectHandles.Endpoint(item,1)];
            else if(item.ParsedPoints.Count>0)points=item.ParsedPoints.Select(p=>ObjectHandles.ToWorld(item,p));
            else if(item.Type=="rect")points=ObjectHandles.Outline(item);
            else if(item.Type is "circle" or "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star")
            {
                var count=item.Type=="triangle"?3:item.Type=="pentagon"?5:item.Type=="star"?10:4;
                points=Enumerable.Range(0,count).Select(i=>{var angle=-Math.PI/2+i*2*Math.PI/count;var radius=item.Type=="star"&&i%2==1?.45:1;return ObjectHandles.ToWorld(item,new(item.X+item.Width/2+Math.Cos(angle)*item.Width/2*radius,item.Y+item.Height/2+Math.Sin(angle)*item.Height/2*radius));});
            }
            else continue;
            foreach(var p in points)
            {
                if(!double.IsFinite(p.X)||!double.IsFinite(p.Y))continue;
                var key=Cell(p);if(!_cells.TryGetValue(key,out var bucket))_cells[key]=bucket=[];
                bucket.Add(new(p.X,p.Y));
            }
        }
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

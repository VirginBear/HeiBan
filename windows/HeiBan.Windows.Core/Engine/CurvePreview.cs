using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public static class CurvePreview
{
    private sealed class Cache
    {public object? Key;public IReadOnlyList<InkPoint> Points=[];public VectorMath.RectBounds Bounds;}
    private static readonly System.Runtime.CompilerServices.ConditionalWeakTable<BoardObject,Cache> Geometry=new();
    public static (IReadOnlyList<InkPoint> Points,VectorMath.RectBounds Bounds) ForObject(BoardObject o)
    {
        var cache=Geometry.GetOrCreateValue(o);
        var points=o.ParsedPoints;var key=o.PointsCacheKey;
        if(!Equals(cache.Key,key)||cache.Points.Count==0)
        {cache.Key=key;cache.Points=Flatten(points);cache.Bounds=VectorMath.ComputeBoundingBox(cache.Points,0);}
        return(cache.Points,cache.Bounds);
    }
    // Identical Catmull-Rom control construction to the Win2D committed curve.
    public static IReadOnlyList<InkPoint> Points(IReadOnlyList<InkPoint> anchors,InkPoint cursor)=>anchors.Concat(new[]{cursor}).ToArray();
    public static IReadOnlyList<InkPoint> Flatten(IReadOnlyList<InkPoint> points)
    {
        if(points.Count<2)return points;
        var result=new List<InkPoint>{points[0]};
        for(var i=1;i<points.Count;i++)
        {
            var a=points[Math.Max(0,i-2)];var b=points[i-1];var c=points[i];var d=points[Math.Min(points.Count-1,i+1)];
            Subdivide(b,new(b.X+(c.X-a.X)/6,b.Y+(c.Y-a.Y)/6),new(c.X-(d.X-b.X)/6,c.Y-(d.Y-b.Y)/6),c,0);
        }
        return result;
        void Subdivide(InkPoint a,InkPoint b,InkPoint c,InkPoint d,int depth)
        {
            var dx=d.X-a.X;var dy=d.Y-a.Y;var len=Math.Sqrt(dx*dx+dy*dy);
            double Offset(InkPoint point){var t=len<1e-10?0:Math.Clamp(((point.X-a.X)*dx+(point.Y-a.Y)*dy)/(len*len),0,1);return Distance(point,new(a.X+dx*t,a.Y+dy*t));}
            var flat=Math.Max(Offset(b),Offset(c));
            if(depth>=14||flat<=.04){result.Add(d);return;}
            var ab=Mid(a,b);var bc=Mid(b,c);var cd=Mid(c,d);var abc=Mid(ab,bc);var bcd=Mid(bc,cd);var middle=Mid(abc,bcd);
            Subdivide(a,ab,abc,middle,depth+1);Subdivide(middle,bcd,cd,d,depth+1);
        }
        static InkPoint Mid(InkPoint a,InkPoint b)=>new((a.X+b.X)/2,(a.Y+b.Y)/2);
        static double Distance(InkPoint a,InkPoint b)=>Math.Sqrt(Math.Pow(b.X-a.X,2)+Math.Pow(b.Y-a.Y,2));
    }
}

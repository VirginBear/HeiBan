using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>A convex contact surface in world coordinates, independent of its on-screen illustration.</summary>
public sealed class EraserFootprint
{
    private readonly InkPoint[] _corners;
    private readonly record struct Edge(double X,double Y,double NormalX,double NormalY);
    private readonly Edge[] _edges;
    public IReadOnlyList<InkPoint> Corners=>_corners;
    public InkPoint Center { get; }
    public EraserFootprint(IEnumerable<InkPoint> corners)
    {
        _corners=corners.Select(p=>new InkPoint(p.X,p.Y)).ToArray();
        if(_corners.Length<3||_corners.Any(p=>!double.IsFinite(p.X)||!double.IsFinite(p.Y)))throw new ArgumentException("A finite convex footprint is required.",nameof(corners));
        double area=0;var origin=_corners[0];
        // Subtract a nearby origin before the cross product: an infinite canvas may
        // be far from world zero while its contact area remains only a few DIP wide.
        for(var i=1;i<_corners.Length-1;i++){var a=_corners[i];var b=_corners[i+1];area+=(a.X-origin.X)*(b.Y-origin.Y)-(b.X-origin.X)*(a.Y-origin.Y);}
        if(Math.Abs(area)<1e-12)throw new ArgumentException("The contact surface must have an area.",nameof(corners));
        var winding=Math.Sign(area);var edges=new List<Edge>();
        for(var i=0;i<_corners.Length;i++)
        {
            var a=_corners[i];var b=_corners[(i+1)%_corners.Length];var dx=b.X-a.X;var dy=b.Y-a.Y;var length=Math.Sqrt(dx*dx+dy*dy);
            if(length>1e-12)edges.Add(new(a.X,a.Y,-winding*dy/length,winding*dx/length));
        }
        _edges=edges.ToArray();
        Center=new(origin.X+_corners.Average(p=>p.X-origin.X),origin.Y+_corners.Average(p=>p.Y-origin.Y));
    }
    private static double Distance(Edge edge,InkPoint p)=>edge.NormalX*(p.X-edge.X)+edge.NormalY*(p.Y-edge.Y);
    public bool Contains(InkPoint point,double padding=0)
    {foreach(var edge in _edges)if(Distance(edge,point)<-padding)return false;return true;}
    public bool Clip(InkPoint a,InkPoint b,double padding,out double enter,out double exit)
    {
        enter=0;exit=1;
        foreach(var edge in _edges)
        {
            var from=Distance(edge,a)+padding;var to=Distance(edge,b)+padding;
            if(from<0&&to<0)return false;
            if(from>=0&&to>=0)continue;
            var at=from/(from-to);
            if(from<0)enter=Math.Max(enter,at);else exit=Math.Min(exit,at);
            if(enter>exit)return false;
        }
        return true;
    }
    private static InkPoint At(InkPoint a,InkPoint b,double t)
    {
        // Boundary samples inherit unknown point fields; interpolation only changes known geometry.
        var result=DocumentCodec.Clone(t<.5?a:b);
        result.X=a.X+(b.X-a.X)*t;result.Y=a.Y+(b.Y-a.Y)*t;result.Pressure=a.Pressure+(b.Pressure-a.Pressure)*t;
        if(a.TiltX is { } ax&&b.TiltX is { } bx)result.TiltX=ax+(bx-ax)*t;
        if(a.TiltY is { } ay&&b.TiltY is { } by)result.TiltY=ay+(by-ay)*t;
        return result;
    }
    public List<List<InkPoint>> Split(IReadOnlyList<InkPoint> points,double padding=0)
    {
        List<List<InkPoint>> result=[];List<InkPoint> current=[];
        void End(){if(current.Count>0)result.Add(current);current=[];}
        if(points.Count==1){if(!Contains(points[0],padding))result.Add([points[0]]);return result;}
        for(var i=1;i<points.Count;i++)
        {
            var a=points[i-1];var b=points[i];
            if(!Clip(a,b,padding,out var enter,out var exit)||exit-enter<1e-10)
            {if(current.Count==0)current.Add(a);current.Add(b);continue;}
            if(enter>1e-10){if(current.Count==0)current.Add(a);current.Add(At(a,b,enter));}
            End();
            if(exit<1-1e-10){current.Add(At(a,b,exit));current.Add(b);}
        }
        End();return result;
    }
    public static EraserFootprint Rectangle(double left,double top,double right,double bottom)=>new(new[]{new InkPoint(left,top),new InkPoint(right,top),new InkPoint(right,bottom),new InkPoint(left,bottom)});
}

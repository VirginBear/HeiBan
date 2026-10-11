using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>CAD window (left to right) and crossing (right to left), in world coordinates.</summary>
public static class WindowSelection
{
    public static bool Matches(BoardObject o, InkPoint start, InkPoint end)
    {
        if (o.IsVisible == false) return false;
        var frame = new VectorMath.RectBounds(Math.Min(start.X,end.X),Math.Min(start.Y,end.Y),Math.Max(start.X,end.X),Math.Max(start.Y,end.Y));
        var crossing = end.X < start.X;
        var radius = o.Type is "image" or "text" or "sticky" or "tape" ? 0 : Math.Max(0,o.StrokeWidth)/2;
        var paths = Outlines(o).Select(path => path.Select(p => ObjectHandles.ToWorld(o,new(p.X+o.PreviewOffsetX,p.Y+o.PreviewOffsetY))).ToArray()).ToArray();
        if (!crossing)
        {
            if (o.Extension is "start" or "end" or "both") return false;
            return paths.Length>0 && paths.SelectMany(p=>p).All(p=>frame.Contains(p.X-radius,p.Y-radius)&&frame.Contains(p.X+radius,p.Y+radius));
        }
        var expanded = new VectorMath.RectBounds(frame.MinX-radius,frame.MinY-radius,frame.MaxX+radius,frame.MaxY+radius);
        foreach (var path in paths)
        {
            if (path.Any(p=>expanded.Contains(p.X,p.Y))) return true;
            for(var i=1;i<path.Length;i++) if (SegmentTouches(path[i-1],path[i],expanded)) return true;
        }
        // Text and images own their whole surface; filled polygons also select when the frame is inside them.
        if (o.Type is "image" or "text" or "sticky" or "tape" || o.FillColor is not (null or "none") && (o.FillOpacity??o.Opacity)>0)
            return paths.Any(path=>LassoSelection.Contains(new(frame.MidX,frame.MidY),path));
        return false;
    }

    private static bool SegmentTouches(InkPoint a,InkPoint b,VectorMath.RectBounds box)
    {
        double low=0,high=1;
        bool Clip(double origin,double delta,double min,double max)
        {
            if(Math.Abs(delta)<1e-12)return origin>=min&&origin<=max;
            var first=(min-origin)/delta;var last=(max-origin)/delta;
            if(first>last)(first,last)=(last,first);
            low=Math.Max(low,first);high=Math.Min(high,last);return low<=high;
        }
        return Clip(a.X,b.X-a.X,box.MinX,box.MaxX)&&Clip(a.Y,b.Y-a.Y,box.MinY,box.MaxY);
    }

    private static IEnumerable<IReadOnlyList<InkPoint>> Outlines(BoardObject o)
    {
        if(o.Type is "line" or "arrow")
        {
            var a=new InkPoint(o.X1??o.X,o.Y1??o.Y);var b=new InkPoint(o.X2??o.X+o.Width,o.Y2??o.Y+o.Height);
            var dx=b.X-a.X;var dy=b.Y-a.Y;var length=Math.Sqrt(dx*dx+dy*dy);
            if(length>1e-12)
            {
                var ux=dx/length;var uy=dy/length;
                yield return new[]{o.Extension is "start" or "both"?new(a.X-ux*1e9,a.Y-uy*1e9):a,o.Extension is "end" or "both"?new(b.X+ux*1e9,b.Y+uy*1e9):b};
                if(o.Type=="arrow")
                {
                    var head=o.ArrowHeadLength??16;var half=(o.ArrowHeadWidth??10)/2;
                    yield return new[]{new InkPoint(b.X-ux*head-uy*half,b.Y-uy*head+ux*half),b,new InkPoint(b.X-ux*head+uy*half,b.Y-uy*head-ux*half)};
                }
            }
            else yield return new[]{a};
            yield break;
        }
        if(o.Type is "stroke" or "pen" or "highlighter" or "paint" or "curve")
        {yield return CurvePreview.ForObject(o).Points;yield break;}
        if(o.Type is "circle" or "arc")
        {
            var rx=o.Type=="arc"?o.ArcRadius??o.Width/2:o.Width/2;var ry=o.Type=="arc"?rx:o.Height/2;
            var sweep=o.Type=="arc"?o.ArcSweepAngle??360:360;var first=o.Type=="arc"?o.ArcStartAngle??0:0;
            var count=Math.Clamp((int)Math.Ceiling(Math.Abs(sweep)*Math.PI/180*Math.Sqrt(Math.Max(rx,ry)/.08)),16,8192);
            yield return Enumerable.Range(0,count+1).Select(i=>{var angle=(first+sweep*i/count)*Math.PI/180;return new InkPoint(o.X+o.Width/2+Math.Cos(angle)*rx,o.Y+o.Height/2+Math.Sin(angle)*ry);}).ToArray();yield break;
        }
        if(o.Type is "triangle" or "quadrilateral" or "diamond" or "pentagon" or "star")
        {
            var n=o.Type=="triangle"?3:o.Type=="pentagon"?5:o.Type=="star"?10:4;
            var points=o.ParsedPoints.Count>0?o.ParsedPoints:Enumerable.Range(0,n).Select(i=>{var a=-Math.PI/2+i*Math.PI*2/n;var r=o.Type=="star"&&i%2==1?.45:1;return new InkPoint(o.X+o.Width/2+Math.Cos(a)*o.Width/2*r,o.Y+o.Height/2+Math.Sin(a)*o.Height/2*r);}).ToArray();
            yield return points.Concat(points.Take(1)).ToArray();yield break;
        }
        yield return new[]{new InkPoint(o.X,o.Y),new InkPoint(o.X+o.Width,o.Y),new InkPoint(o.X+o.Width,o.Y+o.Height),new InkPoint(o.X,o.Y+o.Height),new InkPoint(o.X,o.Y)};
    }
}

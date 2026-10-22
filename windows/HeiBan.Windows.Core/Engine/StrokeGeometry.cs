using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

public static class StrokeGeometry
{
    // Split exact segment/circle intersections, including sparsely sampled long lines.
    public static List<List<InkPoint>> Erase(IReadOnlyList<InkPoint> points, InkPoint center, double radius)
    {
        List<List<InkPoint>> result = []; List<InkPoint> current = [];
        void End() { if (current.Count > 1) result.Add(current); current = []; }
        if (points.Count == 1)
        {
            var p = points[0]; if (Math.Pow(p.X-center.X,2)+Math.Pow(p.Y-center.Y,2)>radius*radius) result.Add([p]);
            return result;
        }
        Span<double> cuts=stackalloc double[4];
        for (var i=1; i<points.Count; i++)
        {
            var a=points[i-1]; var b=points[i]; var dx=b.X-a.X; var dy=b.Y-a.Y;
            var fx=a.X-center.X; var fy=a.Y-center.Y; var aa=dx*dx+dy*dy;
            cuts[0]=0;cuts[1]=1;var count=2;var bb=2*(fx*dx+fy*dy); var cc=fx*fx+fy*fy-radius*radius;
            var discriminant=bb*bb-4*aa*cc;
            if (aa>1e-15 && discriminant>=0)
            {
                var root=Math.Sqrt(discriminant);var t1=(-bb-root)/(2*aa);var t2=(-bb+root)/(2*aa);
                if(t1>0&&t1<1)cuts[count++]=t1;if(t2>0&&t2<1&&t2!=t1)cuts[count++]=t2;
            }
            cuts[..count].Sort();
            InkPoint At(double t)
            {
                // Retain unknown sample metadata and tilt while creating owned
                // fragments. Midpoint membership needs no temporary InkPoint.
                var point=(t<.5?a:b).Snapshot();point.X=a.X+dx*t;point.Y=a.Y+dy*t;point.Pressure=a.Pressure+(b.Pressure-a.Pressure)*t;
                if(a.TiltX is { } ax&&b.TiltX is { } bx)point.TiltX=ax+(bx-ax)*t;
                if(a.TiltY is { } ay&&b.TiltY is { } by)point.TiltY=ay+(by-ay)*t;
                return point;
            }
            for(var j=1;j<count;j++)
            {
                var mid=(cuts[j-1]+cuts[j])/2;var mx=a.X+dx*mid-center.X;var my=a.Y+dy*mid-center.Y;
                if(mx*mx+my*my < radius*radius) {End();continue;}
                if(current.Count==0)current.Add(At(cuts[j-1])); current.Add(At(cuts[j]));
            }
        }
        End();return result;
    }
}

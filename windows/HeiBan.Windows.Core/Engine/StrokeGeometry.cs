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
        for (var i=1; i<points.Count; i++)
        {
            var a=points[i-1]; var b=points[i]; var dx=b.X-a.X; var dy=b.Y-a.Y;
            var fx=a.X-center.X; var fy=a.Y-center.Y; var aa=dx*dx+dy*dy;
            List<double> cuts = [0,1]; var bb=2*(fx*dx+fy*dy); var cc=fx*fx+fy*fy-radius*radius;
            var discriminant=bb*bb-4*aa*cc;
            if (aa>1e-15 && discriminant>=0)
                foreach(var t in new[]{(-bb-Math.Sqrt(discriminant))/(2*aa),(-bb+Math.Sqrt(discriminant))/(2*aa)})
                    if(t>0 && t<1) cuts.Add(t);
            cuts.Sort();
            InkPoint At(double t) => new(a.X+dx*t,a.Y+dy*t,a.Pressure+(b.Pressure-a.Pressure)*t);
            for(var j=1;j<cuts.Count;j++)
            {
                var mid=At((cuts[j-1]+cuts[j])/2);
                if(Math.Pow(mid.X-center.X,2)+Math.Pow(mid.Y-center.Y,2) < radius*radius) {End();continue;}
                if(current.Count==0)current.Add(At(cuts[j-1])); current.Add(At(cuts[j]));
            }
        }
        End();return result;
    }
}

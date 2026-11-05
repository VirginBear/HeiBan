namespace HeiBan.Windows.Engine;

/// <summary>One immutable local crack pattern. Never added to document objects.</summary>
public static class CaneCrackGeometry
{
    public readonly record struct Segment(double X1,double Y1,double X2,double Y2);
    public const double Radius=104;
    public static IReadOnlyList<Segment> Segments {get;}=Build();
    private static IReadOnlyList<Segment> Build()
    {
        var random=new Random(5105);var lines=new List<Segment>();
        var rings=new (double X,double Y)[9,4];
        for(var ray=0;ray<9;ray++)
        {
            double x=0,y=0;var angle=ray*Math.PI*2/9+random.NextDouble()*.2;
            for(var ring=0;ring<4;ring++)
            {
                var radius=(ring+1)*22+random.NextDouble()*7;var a=angle+(random.NextDouble()-.5)*.2;
                var nx=Math.Cos(a)*radius;var ny=Math.Sin(a)*radius;
                lines.Add(new(x,y,nx,ny));rings[ray,ring]=(nx,ny);x=nx;y=ny;
                if(ring>1)lines.Add(new(x,y,x+Math.Cos(a+.7)*10,y+Math.Sin(a+.7)*10));
            }
        }
        for(var ray=0;ray<9;ray++)for(var ring=0;ring<3;ring++)
        {
            if((ray+ring)%3==0)continue;
            var a=rings[ray,ring];var b=rings[(ray+1)%9,ring];
            var mx=(a.X+b.X)/2+3;var my=(a.Y+b.Y)/2-2;
            lines.Add(new(a.X,a.Y,mx,my));lines.Add(new(mx,my,b.X,b.Y));
        }
        return lines.AsReadOnly();
    }
}

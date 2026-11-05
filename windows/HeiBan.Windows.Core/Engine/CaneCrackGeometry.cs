namespace HeiBan.Windows.Engine;

/// <summary>One immutable local crack pattern. Never added to document objects.</summary>
public static class CaneCrackGeometry
{
    public readonly record struct Segment(double X1,double Y1,double X2,double Y2);
    public const double Radius=104;
    public const double DisplayScale=.62;
    public const int ShardCount=18;
    // Includes every shard's velocity/gravity path for the 1.2s lifetime, plus stroke padding.
    public static readonly ToolArtBounds VisualBounds=new(-98,-80,98,196);
    public readonly record struct Shard(double X,double Y,double Size,double Angle,double Opacity);
    public static Shard Particle(int index,double elapsed)
    {
        if(index<0||index>=ShardCount)throw new ArgumentOutOfRangeException(nameof(index));
        var t=elapsed-(index%6)*.018;var life=.72+(index%7)*.055;
        if(t<0||t>=life)return default;
        var angle=index*2.39996323;var radius=(27+index%4*11)*DisplayScale;
        var x=Math.Cos(angle)*radius+(index%7-3)*8*t;
        var y=Math.Sin(angle)*radius-(20+index%5*5)*t+125*t*t;
        return new(x,y,2+index%4*.65,angle+t*(index%2==0?4:-5),Math.Min(1,t/.045)*Math.Min(1,(life-t)/.28));
    }
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

using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>Contact-plane calibration for the original paper-white/sage BoardEraser.png, in screen DIP.</summary>
public static class BoardEraserGeometry
{
    public const double DisplayWidth=160,DisplayHeight=320d/3;
    public const double SweepStep=5;
    private static readonly (double X,double Y)[] Contact=CreateContact();
    // Numeric convex hull of the final asset's alpha >= 128, simplified within four pixels.
    // This rejects transparent padding while allowing the white grip above the felt.
    private static readonly (double X,double Y)[] GrabHull=[(0.07943,0.58594), (0.11589,0.47363), (0.18490,0.39746), (0.32487,0.30664), (0.75195,0.07910), (0.84180,0.11523), (0.91471,0.21973), (0.94010,0.31543), (0.94922,0.40234), (0.94401,0.53418), (0.91667,0.57520), (0.73242,0.68359), (0.24479,0.91992), (0.19661,0.91016), (0.10807,0.80859), (0.07617,0.72266), (0.07552,0.62891)];
    private static readonly EraserFootprint GripSurface=new(GrabHull.Select(p=>new InkPoint(p.X,p.Y)));
    private static (double X,double Y)[] CreateContact()
    {
        // Calibrated in the generated 1536x1024 asset: two rounded felt end caps joined
        // along the visible base edge (about 20 degrees upward to the right). This is
        // an oblique contact plane, not the illustration's upright bounding rectangle.
        var points=new List<(double X,double Y)>();
        for(var end=0;end<2;end++)for(var i=0;i<=8;i++)
        {
            var angle=(-Math.PI/2+end*Math.PI)+i*Math.PI/8;
            var cx=end==0?1300d:300d;var cy=end==0?453d:820d;
            points.Add(((cx+135*Math.Cos(angle)+85*Math.Sin(angle))/1536,(cy-49.545*Math.Cos(angle)+100*Math.Sin(angle))/1024));
        }
        return points.ToArray();
    }
    public static InkPoint[] ContactAt(double imageLeft,double imageTop)=>Contact.Select(p=>new InkPoint(imageLeft+p.X*DisplayWidth,imageTop+p.Y*DisplayHeight)).ToArray();
    public static bool CanGrab(double imageX,double imageY)=>GripSurface.Contains(new(imageX/DisplayWidth,imageY/DisplayHeight));
}

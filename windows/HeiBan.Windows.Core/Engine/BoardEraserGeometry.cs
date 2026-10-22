using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>Flat, board-facing calibration for the original top-down magnetic eraser sprite.</summary>
public static class BoardEraserGeometry
{
    public const double DisplayWidth=160,DisplayHeight=1280d/13;
    public const double SweepStep=5;
    public const double LengthScale=.8;
    public static readonly (double M11,double M12,double M21,double M22) ImageTransform=CreateTransform();
    private static (double,double,double,double) CreateTransform()
    {
        var angle=-20*Math.PI/180;var x=Math.Cos(angle);var y=Math.Sin(angle);var delta=LengthScale-1;
        // Compress along the illustrated long axis, then mirror left/right. The
        // perpendicular axis stays full size, preserving the accepted grip thickness.
        return (-(1+delta*x*x),delta*x*y,-delta*x*y,1+delta*y*y);
    }
    // The generated 1599x984 sprite is already rotated within the board plane.
    // Its alpha silhouette is shared by grabbing, contact rendering and erasing;
    // an overhead view has no perspective-dependent felt offset or hidden rear edge.
    private static readonly (double X,double Y)[] Outline=[(0.12070,0.59146), (0.15322,0.55488), (0.79049,0.17480), (0.83615,0.19411), (0.85679,0.24187), (0.89181,0.40650), (0.87930,0.47764), (0.83615,0.52033), (0.20763,0.88923), (0.17198,0.87907), (0.14196,0.81606), (0.10944,0.65854)];
    // Match the image's centered affine transform while keeping the pointer host untransformed.
    // Mirroring this single hull keeps grab, preview and world-space erasure aligned.
    private static readonly InkPoint[] DisplayOutline=Outline.Select(p=>
    {
        var x=(p.X-.5)*DisplayWidth;var y=(p.Y-.5)*DisplayHeight;var t=ImageTransform;
        return new InkPoint(.5+(t.M11*x+t.M21*y)/DisplayWidth,.5+(t.M12*x+t.M22*y)/DisplayHeight);
    }).ToArray();
    private static readonly EraserFootprint GrabSurface=new(DisplayOutline);
    public static InkPoint[] ContactAt(double imageLeft,double imageTop)=>DisplayOutline.Select(p=>new InkPoint(imageLeft+p.X*DisplayWidth,imageTop+p.Y*DisplayHeight)).ToArray();
    public static bool CanGrab(double imageX,double imageY)=>GrabSurface.Contains(new(imageX/DisplayWidth,imageY/DisplayHeight));
}

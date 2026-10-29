using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>Flat, board-facing calibration for the original top-down magnetic eraser sprite.</summary>
public static class BoardEraserGeometry
{
    public const double DisplayWidth=160,DisplayHeight=1280d/13;
    public const double SweepStep=5;
    public const double LengthScale=.8;
    private static readonly (double X,double Y)[] Outline=[(0.12070,0.59146), (0.15322,0.55488), (0.79049,0.17480), (0.83615,0.19411), (0.85679,0.24187), (0.89181,0.40650), (0.87930,0.47764), (0.83615,0.52033), (0.20763,0.88923), (0.17198,0.87907), (0.14196,0.81606), (0.10944,0.65854)];
    public static readonly (double M11,double M12,double M21,double M22,double M31,double M32) ImageTransform=CreateTransform();
    private static (double,double,double,double,double,double) CreateTransform()
    {
        var angle=-20*Math.PI/180;var x=Math.Cos(angle);var y=Math.Sin(angle);var delta=LengthScale-1;
        // Compress along the illustrated long axis, then mirror left/right. The
        // perpendicular axis retains its ratio before the final uniform host fit.
        var a=-(1+delta*x*x);var b=delta*x*y;var c=-delta*x*y;var d=1+delta*y*y;
        // The mirrored artwork rests at +20°. Rotate its long axis to +45°.
        var r=25*Math.PI/180;var cr=Math.Cos(r);var sr=Math.Sin(r);
        var m11=cr*a-sr*b;var m12=sr*a+cr*b;var m21=cr*c-sr*d;var m22=sr*c+cr*d;
        var bounds=ToolArtBounds.From(Outline.Select(p=>
        {var px=(p.X-.5)*DisplayWidth;var py=(p.Y-.5)*DisplayHeight;return (X:px*m11+py*m21,Y:px*m12+py*m22);}));
        // Keep the whole contact hull inside its pointer host. Rendering, grabbing
        // and erasing consume this exact affine transform, including centering.
        var fit=Math.Min(1,Math.Min(DisplayWidth*.9/bounds.Width,DisplayHeight*.9/bounds.Height));
        return (m11*fit,m12*fit,m21*fit,m22*fit,-(bounds.Left+bounds.Right)*.5*fit,-(bounds.Top+bounds.Bottom)*.5*fit);
    }
    // The generated 1599x984 sprite is already rotated within the board plane.
    // Its alpha silhouette is shared by grabbing, contact rendering and erasing;
    // an overhead view has no perspective-dependent felt offset or hidden rear edge.

    // Match the image's centered affine transform while keeping the pointer host untransformed.
    // Mirroring this single hull keeps grab, preview and world-space erasure aligned.
    private static readonly InkPoint[] DisplayOutline=Outline.Select(p=>
    {
        var x=(p.X-.5)*DisplayWidth;var y=(p.Y-.5)*DisplayHeight;var t=ImageTransform;
        return new InkPoint(.5+(t.M11*x+t.M21*y+t.M31)/DisplayWidth,.5+(t.M12*x+t.M22*y+t.M32)/DisplayHeight);
    }).ToArray();
    private static readonly EraserFootprint GrabSurface=new(DisplayOutline);
    public static readonly ToolArtBounds DisplayBounds=ToolArtBounds.From(DisplayOutline.Select(p=>(p.X*DisplayWidth,p.Y*DisplayHeight)));
    public static InkPoint[] ContactAt(double imageLeft,double imageTop)=>DisplayOutline.Select(p=>new InkPoint(imageLeft+p.X*DisplayWidth,imageTop+p.Y*DisplayHeight)).ToArray();
    public static bool CanGrab(double imageX,double imageY)=>GrabSurface.Contains(new(imageX/DisplayWidth,imageY/DisplayHeight));
}

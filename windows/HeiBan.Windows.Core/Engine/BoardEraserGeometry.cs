using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>Flat, board-facing calibration for the original top-down magnetic eraser sprite.</summary>
public static class BoardEraserGeometry
{
    public const double DisplayWidth=160,DisplayHeight=1280d/13;
    public const double SweepStep=5;
    // The generated 1599x984 sprite is already rotated within the board plane.
    // Its alpha silhouette is shared by grabbing, contact rendering and erasing;
    // an overhead view has no perspective-dependent felt offset or hidden rear edge.
    private static readonly (double X,double Y)[] Outline=[(0.12070,0.59146), (0.15322,0.55488), (0.79049,0.17480), (0.83615,0.19411), (0.85679,0.24187), (0.89181,0.40650), (0.87930,0.47764), (0.83615,0.52033), (0.20763,0.88923), (0.17198,0.87907), (0.14196,0.81606), (0.10944,0.65854)];
    private static readonly EraserFootprint GrabSurface=new(Outline.Select(p=>new InkPoint(p.X,p.Y)));
    public static InkPoint[] ContactAt(double imageLeft,double imageTop)=>Outline.Select(p=>new InkPoint(imageLeft+p.X*DisplayWidth,imageTop+p.Y*DisplayHeight)).ToArray();
    public static bool CanGrab(double imageX,double imageY)=>GrabSurface.Contains(new(imageX/DisplayWidth,imageY/DisplayHeight));
}

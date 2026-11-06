using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public static class RulerGeometry
{
    public const float HeightDip = 64;
    public const float MinimumLengthDip = 200;
    public const float MaximumLengthDip = 6000;
    public const float HandleInsetDip = 28;
    public const float EndGripDip = 16;

    public static float ClampLength(double length) =>
        (float)Math.Clamp(length, MinimumLengthDip, MaximumLengthDip);

    // Compute the new length in DIPs. The host shifts the center by half of
    // the length change along the ruler axis, keeping the opposite end fixed.
    public static float Stretch(float length, float pointerAlong, float grabOffset, int side) =>
        ClampLength(length / 2 + side * (pointerAlong - grabOffset));

    public static InkPoint PivotOffset(double angle,double length,double height,double ratio,string edge)
    {
        var x=(ratio-.5)*length;var y=edge=="top"?-height/2:edge=="bottom"?height/2:0;
        return ObjectHandles.Rotate(new(x,y),new(0,0),angle);
    }
    public static (double Ratio,string Edge) PickPivot(double localX,double localY,double length,double height)
        =>(Math.Clamp(localX/Math.Max(1,length)+.5,0,1),localY<-height*.22?"top":localY>height*.22?"bottom":"center");
}

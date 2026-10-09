using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public static class RulerGeometry
{
    public static InkPoint PivotOffset(double angle,double length,double height,double ratio,string edge)
    {
        var x=(ratio-.5)*length;var y=edge=="top"?-height/2:edge=="bottom"?height/2:0;
        return ObjectHandles.Rotate(new(x,y),new(0,0),angle);
    }
    public static (double Ratio,string Edge) PickPivot(double localX,double localY,double length,double height)
        =>(Math.Clamp(localX/Math.Max(1,length)+.5,0,1),localY<-height*.22?"top":localY>height*.22?"bottom":"center");
}

using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
internal static class ShapeConstraintChecks
{
    internal static void Run(Action<bool,string> check)
    {
        static bool Near(double a,double b)=>Math.Abs(a-b)<1e-8;
        foreach(var scale in new[]{.25,1,2.5})foreach(var angle in Enumerable.Range(0,72).Select(i=>i*5d-180))
        {
            var start=new InkPoint(-52*scale,83*scale);var radians=angle*Math.PI/180;
            var end=new InkPoint(start.X+100*scale*Math.Cos(radians),start.Y+100*scale*Math.Sin(radians),.6){TiltX=12};
            var p=ShapeConstruction.ConstrainLine(start,end);var dx=p.X-start.X;var dy=p.Y-start.Y;
            check(Math.Abs(dx)<1e-8||Math.Abs(dy)<1e-8||Near(Math.Abs(dx),Math.Abs(dy)),"Shift line is on a 45-degree ray");
            check(Near((end.X-p.X)*dx+(end.Y-p.Y)*dy,0),"Shift projection is the nearest point on the chosen ray");
            check(Near(p.Pressure,.6)&&p.TiltX==12&&Near(end.X,start.X+100*scale*Math.Cos(radians)),"Constraint preserves sample metadata and input");
        }
        foreach(var type in new[]{"rect","circle","diamond","pentagon","star","quadrilateral"})
        foreach(var dx in new[]{-80d,0,80})foreach(var dy in new[]{-130d,0,130})
        {
            var a=new InkPoint(-20,40);var b=new InkPoint(a.X+dx,a.Y+dy);var o=new BoardObject{Type=type};
            ShapeConstruction.Drag(o,a,b,true);check(Near(o.Width,o.Height),"Shift makes equal radial axes or square bounds");
            if(type is "circle" or "diamond" or "pentagon" or "star")check(Near(o.X+o.Width/2,a.X)&&Near(o.Y+o.Height/2,a.Y),"Radial first point remains the center");
            else check(Near(o.X,a.X)||Near(o.X+o.Width,a.X),"Corner anchor is retained");
            ShapeConstruction.Drag(o,a,b,false);
            check(type is "circle" or "diamond" or "pentagon" or "star"?Near(o.Width,Math.Max(1,Math.Abs(dx)*2))&&Near(o.Height,Math.Max(1,Math.Abs(dy)*2)):Near(o.Width,Math.Max(1,Math.Abs(dx)))&&Near(o.Height,Math.Max(1,Math.Abs(dy))),"Releasing Shift restores unconstrained aspect");
        }
        foreach(var b in new[]{new InkPoint(150,80),new InkPoint(-90,-70),new InkPoint(20,220)})
        {
            var a=new InkPoint(20,30);var o=new BoardObject{Type="triangle"};ShapeConstruction.Drag(o,a,b,true);
            var p=o.ParsedPoints;double Length(InkPoint x,InkPoint y)=>Math.Sqrt(Math.Pow(x.X-y.X,2)+Math.Pow(x.Y-y.Y,2));
            check(p.Count==3&&Near(p[0].X,a.X)&&Near(p[0].Y,a.Y),"Triangle retains its first vertex");
            check(Near(Length(p[0],p[1]),Length(p[1],p[2]))&&Near(Length(p[1],p[2]),Length(p[2],p[0])),"Shift triangle is equilateral");
            var document=new HeiBanDocument{Objects=[o]};var restored=DocumentCodec.Decode(DocumentCodec.Encode(document));
            check(restored.Objects[0].ParsedPoints.Count==3,"Regular polygon uses the existing document contract");
        }
    }
}

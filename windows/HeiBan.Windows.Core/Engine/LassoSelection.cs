using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;
public static class LassoSelection
{
    public static bool Contains(InkPoint p,IReadOnlyList<InkPoint> polygon)
    {
        if(polygon.Count<3)return false;var inside=false;
        for(int i=0,j=polygon.Count-1;i<polygon.Count;j=i++)
        {var a=polygon[i];var b=polygon[j];if((a.Y>p.Y)!=(b.Y>p.Y)&&p.X<(b.X-a.X)*(p.Y-a.Y)/(b.Y-a.Y)+a.X)inside=!inside;}
        return inside;
    }
    public static bool Intersects(BoardObject o,IReadOnlyList<InkPoint> polygon)
    {
        if(polygon.Count<3||o.IsVisible==false)return false;
        var corners=new[]{new InkPoint(o.X,o.Y),new InkPoint(o.X+o.Width,o.Y),new InkPoint(o.X+o.Width,o.Y+o.Height),new InkPoint(o.X,o.Y+o.Height)}.Select(p=>ObjectHandles.ToWorld(o,p)).ToArray();
        if(corners.Any(p=>Contains(p,polygon))||Contains(ObjectHandles.Center(o),polygon)||polygon.Any(p=>VectorMath.IsPointInObject(p,o,0)))return true;
        for(var i=0;i<polygon.Count;i++)for(var j=0;j<4;j++)if(Crosses(polygon[i],polygon[(i+1)%polygon.Count],corners[j],corners[(j+1)%4]))return true;
        return false;
    }
    private static bool Crosses(InkPoint a,InkPoint b,InkPoint c,InkPoint d)
    {
        static double Cross(InkPoint p,InkPoint q,InkPoint r)=>(q.X-p.X)*(r.Y-p.Y)-(q.Y-p.Y)*(r.X-p.X);
        return Cross(a,b,c)*Cross(a,b,d)<0&&Cross(c,d,a)*Cross(c,d,b)<0;
    }
}

using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>Held pointer position and one replaceable swing, outside document/undo state.</summary>
public sealed class CaneFeedback
{
    public const double Duration=.26;
    public InkPoint? Point {get;private set;}
    public double StartedAt {get;private set;}=double.NegativeInfinity;
    public bool IsActive(double now)=>Point is not null&&now-StartedAt>=0&&now-StartedAt<Duration;
    public bool Move(InkPoint point)
    {if(Point is { } old&&old.X==point.X&&old.Y==point.Y)return false;Point=new(point.X,point.Y);return true;}
    public void Strike(InkPoint point,double now){Move(point);StartedAt=now;}
    public void Clear(){Point=null;StartedAt=double.NegativeInfinity;}
}

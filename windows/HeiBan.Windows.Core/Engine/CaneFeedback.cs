using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>A single replaceable teaching cue, never part of the document or undo history.</summary>
public sealed class CaneFeedback
{
    public const double Duration=.32;
    public InkPoint? Point {get;private set;}
    public double StartedAt {get;private set;}
    public bool IsActive(double now)=>Point is not null&&now-StartedAt>=0&&now-StartedAt<Duration;
    public void Strike(InkPoint point,double now){Point=new(point.X,point.Y);StartedAt=now;}
    public void Clear()=>Point=null;
}

using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>Held pointer position and one replaceable swing, outside document/undo state.</summary>
public sealed class CaneFeedback
{
    public const double Duration=.26;
    public const double ComboSeconds=1.2,ComboRadius=36,CrackDuration=1.2;
    private InkPoint? _firstHit;
    private double _firstAt;
    private int _hits;
    private bool _soundPending;
    public InkPoint? CrackGrip {get;private set;}
    public double CrackStartedAt {get;private set;}=double.NegativeInfinity;
    public bool NeedsAnimation(double now)=>IsActive(now)||CrackGrip is not null&&now<CrackStartedAt+CrackDuration;
    public double CrackOpacity(double now)=>now<CrackStartedAt?0:Math.Clamp(1-(now-CrackStartedAt)/CrackDuration,0,1);
    // Consume even while muted: unmuting later must not replay an old impact.
    public bool TakeCrackSound(double now)
    {if(!_soundPending||now<CrackStartedAt)return false;_soundPending=false;return now<CrackStartedAt+CrackDuration;}
    public InkPoint? Point {get;private set;}
    public double StartedAt {get;private set;}=double.NegativeInfinity;
    public bool IsActive(double now)=>Point is not null&&now-StartedAt>=0&&now-StartedAt<Duration;
    public bool Move(InkPoint point)
    {if(Point is { } old&&old.X==point.X&&old.Y==point.Y)return false;Point=new(point.X,point.Y);return true;}
    public void Strike(InkPoint point,double now,InkPoint? screenDip=null)
    {
        Move(point);StartedAt=now;var hit=screenDip??point;
        // Compare against the first hit, not the last: three wandering hits are not one region.
        if(_firstHit is null||now<_firstAt||now-_firstAt>ComboSeconds||Math.Pow(hit.X-_firstHit.X,2)+Math.Pow(hit.Y-_firstHit.Y,2)>ComboRadius*ComboRadius)
        {_firstHit=new(hit.X,hit.Y);_firstAt=now;_hits=0;}
        if(++_hits<3)return;
        CrackGrip=new(point.X,point.Y);CrackStartedAt=now+CanePose.ImpactSeconds;_soundPending=true;_firstHit=null;_hits=0;
    }
    public void Clear(){Point=CrackGrip=_firstHit=null;StartedAt=CrackStartedAt=double.NegativeInfinity;_hits=0;_soundPending=false;}
}

namespace HeiBan.Windows.Engine;

public enum OperateRightAction { None, ReplayClick, ReplayDown, WheelStarted, WheelMoved, WheelFinished, Cancelled }
public sealed class OperateRightGesture
{
    public enum State { Idle, Pending, Dragging, Wheel, Cancelled }
    public State Phase {get;private set;}
    public double OriginX {get;private set;}
    public double OriginY {get;private set;}
    public double X {get;private set;}
    public double Y {get;private set;}
    private double _started,_slop;
    public bool OwnsRelease=>Phase is State.Pending or State.Wheel or State.Cancelled;
    public void Press(double x,double y,double now,double scale)
    {Phase=State.Pending;OriginX=X=x;OriginY=Y=y;_started=now;_slop=10*Math.Max(1,scale);}
    public OperateRightAction Poll(double now)
    {if(Phase!=State.Pending||now-_started<RadialGesture.HoldSeconds)return OperateRightAction.None;Phase=State.Wheel;return OperateRightAction.WheelStarted;}
    public OperateRightAction Move(double x,double y,double now)
    {
        X=x;Y=y;
        if(Phase==State.Pending)
        {
            if(Poll(now)==OperateRightAction.WheelStarted)return OperateRightAction.WheelStarted;
            if(Math.Abs(X-OriginX)+Math.Abs(Y-OriginY)>_slop){Phase=State.Dragging;return OperateRightAction.ReplayDown;}
        }
        return Phase==State.Wheel?OperateRightAction.WheelMoved:OperateRightAction.None;
    }
    public OperateRightAction Release(double x,double y,double now)
    {
        X=x;Y=y;var action=Phase switch{
            State.Pending=>now-_started>=RadialGesture.HoldSeconds?OperateRightAction.WheelFinished:OperateRightAction.ReplayClick,
            State.Wheel=>OperateRightAction.WheelFinished,
            State.Cancelled=>OperateRightAction.Cancelled,
            _=>OperateRightAction.None};Phase=State.Idle;return action;
    }
    public void Cancel(bool suppressRelease=false){if(OwnsRelease||suppressRelease&&Phase!=State.Idle)Phase=State.Cancelled;}
}

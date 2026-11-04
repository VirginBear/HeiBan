using HeiBan.Windows.Engine;
internal static class OperateRightGestureChecks
{
    internal static void Run(Action<bool,string> check)
    {
        var g=new OperateRightGesture();g.Press(100,200,0,1);
        check(g.OwnsRelease&&g.Phase==OperateRightGesture.State.Pending,"Pending right down is paired with an owned release");
        check(g.Poll(.1)==OperateRightAction.None&&g.Release(100,200,.1)==OperateRightAction.ReplayClick,"Short click replays one pair rather than opening wheel");
        check(!g.OwnsRelease&&g.Phase==OperateRightGesture.State.Idle,"Short click leaves no pending ownership");
        g.Press(100,200,1,1);check(g.Poll(1.25)==OperateRightAction.WheelStarted,"Stationary hold opens wheel");
        check(g.Move(160,240,1.3)==OperateRightAction.WheelMoved&&g.X==160&&g.Y==240,"Wheel movement retains latest screen coordinates");
        check(g.Release(160,240,1.4)==OperateRightAction.WheelFinished&&!g.OwnsRelease,"Wheel consumes the release exactly once");
        check(g.Release(160,240,1.5)==OperateRightAction.None,"Duplicate releases do not replay or select again");
        g.Press(0,0,2,1);check(g.Move(20,0,2.05)==OperateRightAction.ReplayDown&&!g.OwnsRelease,"Early right drag hands down back to external app");
        check(g.Release(30,0,2.3)==OperateRightAction.None,"External drag keeps native release instead of synthesizing another up");
        g.Press(0,0,3,2);check(g.Move(16,0,3.05)==OperateRightAction.None,"Drag slop scales to screen DPI");
        check(g.Move(22,0,3.06)==OperateRightAction.ReplayDown,"Scaled slop eventually hands real drag back");g.Release(22,0,3.1);
        g.Press(0,0,4,1);g.Cancel();check(g.OwnsRelease&&g.Release(0,0,4.3)==OperateRightAction.Cancelled,"Escape drains the swallowed down without leaking a context-menu up");
        g.Press(0,0,5,1);g.Poll(5.3);g.Cancel();check(g.Poll(5.5)==OperateRightAction.None&&g.Release(0,0,5.6)==OperateRightAction.Cancelled,"Cancelled wheel cannot reappear on timer");
        g.Press(0,0,6,1);check(g.Release(0,0,6.4)==OperateRightAction.WheelFinished,"Late release still identifies hold when timer was coalesced");
        g.Press(-300,120,7,1);check(g.Poll(7.3)==OperateRightAction.WheelStarted&&g.OriginX==-300,"Virtual desktop negative coordinates remain intact");g.Release(-300,120,7.4);
        g.Press(0,0,8,1);g.Move(30,0,8.02);g.Cancel(true);check(g.OwnsRelease&&g.Release(30,0,8.1)==OperateRightAction.Cancelled,"Abandoned target does not receive an unmatched up");
        for(var i=0;i<1000;i++){g.Press(i,i,i,1);check(g.Release(i,i,i+.05)==OperateRightAction.ReplayClick,"Repeated short clicks remain individually paired");}
        var prefs=ToolbarPreferences.CreateDefault();prefs.OperateRadialEnabled=false;var copy=DocumentCodec.Clone(prefs);copy.Normalize();check(!copy.OperateRadialEnabled,"Operate wheel opt-out survives preference cloning and normalization");
    }
}

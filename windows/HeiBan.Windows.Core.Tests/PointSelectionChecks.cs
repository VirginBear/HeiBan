using System.Text.Json;
using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
internal static class PointSelectionChecks
{
    internal static void Run(Action<bool,string> check)
    {
        var hollow=new BoardObject{Id="outer",Type="rect",X=100,Y=100,Width=200,Height=120,StrokeWidth=2,FillColor="none",ZIndex=1};
        check(!VectorMath.IsPointInObject(new(170,150),hollow,2),"Precise erasing still ignores hollow rectangle interior");
        check(PointSelection.Contains(hollow,new(170,150),2),"Point selection accepts hollow rectangle interior");
        var stroke=new BoardObject{Id="stroke",Type="stroke",X=10,Y=10,Width=100,Height=100,StrokeWidth=2};stroke.SetCompletedInkPoints([new(10,10),new(110,110)]);
        check(PointSelection.Contains(stroke,new(20,100),0),"Stroke bounding region includes gaps away from painted pixels");
        check(!VectorMath.IsPointInObject(new(20,100),stroke,2),"Precise stroke hit remains unchanged");
        var line=new BoardObject{Type="line"};ObjectHandles.SetEndpoints(line,new(10,10),new(110,110));
        check(PointSelection.Contains(line,new(20,100),0),"Diagonal line accepts its object bounds");
        var thin=new BoardObject{Type="line",StrokeWidth=2};ObjectHandles.SetEndpoints(thin,new(10,10),new(110,10));
        check(PointSelection.Contains(thin,new(50,16),6)&&!PointSelection.Contains(thin,new(50,19),6),"Screen-scaled tolerance makes thin line clickable without unbounded padding");
        foreach(var rotation in new[]{0d,35d,90d,180d})
        {
            var rotated=DocumentCodec.Clone(hollow);rotated.Rotation=rotation;
            check(PointSelection.Contains(rotated,ObjectHandles.ToWorld(rotated,new(110,110)),0),"Rotated local bounding region remains selectable");
            check(!PointSelection.Contains(rotated,ObjectHandles.ToWorld(rotated,new(95,95)),0),"Rotated bounds exclude points outside local box");
        }
        var a=DocumentCodec.Clone(hollow);a.Id="a";a.ZIndex=3;
        var b=DocumentCodec.Clone(hollow);b.Id="b";b.ZIndex=3;
        var hidden=DocumentCodec.Clone(hollow);hidden.Id="hidden";hidden.ZIndex=99;hidden.IsVisible=false;
        var other=DocumentCodec.Clone(hollow);other.Id="other";other.ZIndex=100;other.PageId="other";
        var session=new EditorSession();session.Open(new(){Board=new(){CanvasMode="notebook",ActivePageId="current"},Objects=[a,b,hidden,other]});
        check(session.HitSelection(new(170,150),2)?.Id=="b","Topmost uses the reverse of actual paint order including equal-Z ties");
        a.ZIndex=4;check(session.HitSelection(new(170,150),2)?.Id=="a","Z-order edits update point selection");
        a.IsLocked=true;check(session.HitSelection(new(170,150),2)?.Id=="a","Locked top object does not click through to lower layer");
        a.IsVisible=false;check(session.HitSelection(new(170,150),2)?.Id=="b","Hidden and other-page objects are excluded");
        var generation=session.Generation;session.SelectedId="b";session.ToggleSelection("a");
        check(session.SelectedIds.SetEquals(new[]{"a","b"}),"Additive point toggle accumulates distinct objects");
        session.ToggleSelection("b");check(session.SelectedIds.SetEquals(new[]{"a"}),"Additive point toggle removes selected object only");
        check(session.Generation==generation&&!session.CanUndo,"Selection alone creates no document mutation or undo entry");
        check(session.HitSelection(new(-100,-100),2) is null,"Blank point remains eligible for marquee");
        check(!PointSelection.Contains(hollow,new(double.NaN,0),2),"Invalid coordinates cannot select objects");
        var prefs=ToolbarPreferences.CreateDefault();check(!prefs.CaneMuted,"Existing sound remains enabled by default");prefs.CaneMuted=true;
        prefs.ExtraFields=new(){["futureSetting"]=JsonSerializer.SerializeToElement(42)};
        var roundtrip=DocumentCodec.Clone(prefs);roundtrip.Normalize();
        check(roundtrip.CaneMuted&&roundtrip.ExtraFields!["futureSetting"].GetInt32()==42,"Mute preference and unknown settings survive serialization/normalization");
    }
}

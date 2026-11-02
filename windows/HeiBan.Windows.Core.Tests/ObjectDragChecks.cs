using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;
internal static class ObjectDragChecks
{
    internal static void Run(Action<bool,string> check)
    {
        var stroke=new BoardObject{Id="stroke",Type="stroke",X=10,Y=10,Width=80,Height=50,ZIndex=1};stroke.SetCompletedInkPoints([new(10,10),new(90,60)]);
        var doc=new HeiBanDocument{Objects=[new(){Id="below",Type="rect",ZIndex=0},stroke,new(){Id="between",Type="rect",ZIndex=2},new(){Id="moving",Type="rect",X=120,Y=80,ZIndex=3},new(){Id="locked",Type="rect",IsLocked=true,X=500,ZIndex=4}]};
        var session=new EditorSession();session.Open(doc);session.SetSelection(new[]{"stroke","moving","locked"});
        var before=DocumentCodec.Encode(doc);var drag=new ObjectDragPreview(session,new(10,20));
        for(var i=0;i<1000;i++)drag.Move(new(10+i,20+i*.5));
        check(DocumentCodec.Encode(doc)==before&&session.Generation==0&&!session.HasTransaction,"1000 drag samples do not modify/clone document or open undo transaction");
        check(drag.Runs.Select(r=>r.Moving).SequenceEqual(new[]{false,true,false,true,false}),"Interleaved static/selected runs retain original Z order");
        check(!drag.IsMoving(doc.Objects.Last()),"Selected locked object remains static");
        drag.Move(new(40,60));check(drag.X==30&&drag.Y==40,"Absolute displacement uses original pointer instead of accumulated rounding");
        check(drag.Commit(session)&&session.Generation==1&&session.CanUndo,"Release commits one change");
        check(stroke.X==40&&stroke.Y==50&&stroke.ParsedPoints[0].X==40&&stroke.ParsedPoints[0].Y==50,"Stroke bounds and point JSON translated exactly once at release");
        check(doc.Objects.Last().X==500,"Locked member not moved at release");
        check(!drag.Commit(session),"Same preview cannot commit twice after generation changes");
        session.Undo();check(DocumentCodec.Encode(session.Document)==before&&!session.CanUndo,"One undo restores whole group including original stroke points");
        session.Redo();check(session.Document.Objects.Single(o=>o.Id=="moving").X==150,"Redo restores group move");
        var cancelledBefore=DocumentCodec.Encode(session.Document);var cancelled=new ObjectDragPreview(session,new(0,0));cancelled.Move(new(900,900));
        check(DocumentCodec.Encode(session.Document)==cancelledBefore,"Discarding a preview requires no document restoration");
        var noMove=new ObjectDragPreview(session,new(0,0));check(!noMove.Commit(session),"Zero movement creates no undo entry");
        var stale=new ObjectDragPreview(session,new(0,0));stale.Move(new(5,5));session.Open(new());check(!stale.Commit(session)&&session.Document.Objects.Count==0,"Late drag cannot cross document epoch");
        var pages=new EditorSession();pages.Open(new(){Board=new(){CanvasMode="notebook",ActivePageId="a"},Objects=[new(){Id="a",PageId="a"},new(){Id="b",PageId="b"},new(){Id="hidden",IsVisible=false}]});pages.SelectedId="a";
        var page=new ObjectDragPreview(pages,new(0,0));check(page.Runs.SelectMany(r=>r.Objects).Select(o=>o.Id).SequenceEqual(new[]{"a"}),"Cached paint runs exclude hidden and other-page objects");
        page.Move(new(10,10));pages.Document.Board.ActivePageId="b";check(!page.Commit(pages),"Page change rejects old preview");
    }
}

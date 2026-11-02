using HeiBan.Windows.Models;
namespace HeiBan.Windows.Engine;

/// <summary>A UI-owned translation preview. Original objects and point JSON stay untouched until release.</summary>
public sealed class ObjectDragPreview
{
    public sealed record Run(bool Moving,BoardObject[] Objects);
    private readonly HeiBanDocument _document;
    private readonly long _epoch,_generation;
    private readonly string? _page;
    private readonly InkPoint _origin;
    private readonly HashSet<string> _moving;
    public BoardObject[] Selected {get;}
    public IReadOnlyList<Run> Runs {get;}
    public double X {get;private set;}
    public double Y {get;private set;}
    public bool IsMoving(BoardObject item)=>_moving.Contains(item.Id);
    public bool Current(EditorSession session)=>ReferenceEquals(session.Document,_document)&&session.DocumentEpoch==_epoch&&session.Generation==_generation&&session.Document.Board.ActivePageId==_page;
    public ObjectDragPreview(EditorSession session,InkPoint origin)
    {
        _document=session.Document;_epoch=session.DocumentEpoch;_generation=session.Generation;_page=_document.Board.ActivePageId;_origin=origin.Snapshot();
        Selected=session.SelectedObjects.ToArray();_moving=Selected.Where(o=>o.IsLocked!=true).Select(o=>o.Id).ToHashSet();
        var runs=new List<Run>();var objects=new List<BoardObject>();bool? moving=null;
        foreach(var item in session.DrawingObjects)
        {
            var next=IsMoving(item);
            if(moving is not null&&moving!=next){runs.Add(new(moving.Value,objects.ToArray()));objects.Clear();}
            objects.Add(item);moving=next;
        }
        if(moving is not null)runs.Add(new(moving.Value,objects.ToArray()));Runs=runs;
    }
    public void Move(InkPoint point)
    {if(double.IsFinite(point.X)&&double.IsFinite(point.Y)){X=point.X-_origin.X;Y=point.Y-_origin.Y;}}
    public bool Commit(EditorSession session)
    {
        if(!Current(session)||_moving.Count==0||X==0&&Y==0)return false;
        session.Begin();foreach(var item in Selected.Where(IsMoving))session.Move(item,X,Y);session.Commit();return true;
    }
}

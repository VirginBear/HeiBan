using System.Text.Json;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>UI-thread document transactions; live pointer movement does not serialize the document.</summary>
public sealed class EditorSession
{
    public HeiBanDocument Document { get; private set; } = new();
    private readonly HashSet<string> _selectedIds=[];
    public IReadOnlySet<string> SelectedIds => _selectedIds;
    public string? SelectedId { get => Selected?.Id; set { _selectedIds.Clear();if(value is not null)_selectedIds.Add(value); } }
    public IEnumerable<BoardObject> SelectedObjects => PageObjects.Where(o=>_selectedIds.Contains(o.Id));
    public void SetSelection(IEnumerable<string> ids) { var valid=PageObjects.Select(o=>o.Id).ToHashSet();_selectedIds.Clear();_selectedIds.UnionWith(ids.Where(valid.Contains)); }
    public void ToggleSelection(string id) { if(!_selectedIds.Remove(id)&&PageObjects.Any(o=>o.Id==id))_selectedIds.Add(id); }
    public void MoveSelection(double dx,double dy) { foreach(var o in SelectedObjects.Where(o=>o.IsLocked!=true))Move(o,dx,dy); }
    public BoardObject? Selected => SelectedObjects.OrderBy(o=>o.IsLocked==true).ThenByDescending(o=>o.ZIndex).FirstOrDefault();
    public bool IsDirty => Generation != SavedGeneration;
    public long Generation { get; private set; }
    public long SavedGeneration { get; private set; }
    private sealed record Snapshot(HeiBanDocument Document,long Bytes);
    private readonly List<Snapshot> _undo = [];
    private readonly List<Snapshot> _redo = [];
    private HeiBanDocument? _transaction;
    private readonly HashSet<BoardObject> _previewMoves=[];
    public bool HasTransaction=>_transaction is not null;
    public long DocumentEpoch {get;private set;}
    public bool CanUndo => _undo.Count > 0;
    public bool CanRedo => _redo.Count > 0;
    public IEnumerable<BoardObject> PageObjects => Document.Objects.Where(o => Document.Board.CanvasMode != "notebook" || o.PageId is null || o.PageId == Document.Board.ActivePageId);
    public IEnumerable<BoardObject> VisibleObjects => PageObjects.Where(o=>o.IsVisible!=false);
    public void Open(HeiBanDocument doc)
    {
        ClearPreviewMoves();DocumentEpoch++;Document = doc; SelectedId = null; _undo.Clear(); _redo.Clear(); _transaction = null;
        Generation = SavedGeneration = 0;
    }
    public void Begin() => _transaction ??= DocumentCodec.Clone(Document);
    public void Commit()
    {
        FlushPreviewMoves();
        if (_transaction is null) return;
        var before = _transaction; _transaction = null;
        if (DocumentSnapshot.Same(before,Document)) return;
        _undo.Add(new(before,DocumentSnapshot.EstimatedBytes(before))); _redo.Clear(); Generation++;
        Trim(_undo);
    }
    private static void Trim(List<Snapshot> history)
    {
        var bytes=history.Sum(s=>s.Bytes);
        while(history.Count>64||(history.Count>1&&bytes>32*1024*1024))
        {bytes-=history[0].Bytes;history.RemoveAt(0);}
    }
    public void Cancel() { ClearPreviewMoves();if (_transaction is not null) { var revision=Document.Board.Revision;Document = _transaction;Document.Board.Revision=Math.Max(revision,Document.Board.Revision); } _transaction = null; }
    public void Undo() => Restore(_undo, _redo);
    public void Redo() => Restore(_redo, _undo);
    private void Restore(List<Snapshot> from, List<Snapshot> to)
    {
        if (from.Count == 0) return;
        Cancel();
        var snapshot=DocumentCodec.Clone(Document);to.Add(new(snapshot,DocumentSnapshot.EstimatedBytes(snapshot)));Trim(to);
        var revision = Document.Board.Revision;
        Document = DocumentCodec.Clone(from[^1].Document); from.RemoveAt(from.Count - 1);
        Document.Board.Revision = revision; SelectedId = null; Generation++;
    }
    // During a drag only bounds/endpoints change. Absolute point JSON and its GPU path stay unchanged until commit.
    public void PreviewMoveSelection(double dx,double dy)
    {
        if(!double.IsFinite(dx)||!double.IsFinite(dy)||(dx==0&&dy==0))return;
        Begin();
        foreach(var o in SelectedObjects.Where(o=>o.IsLocked!=true))
        {
            MoveBounds(o,dx,dy);_previewMoves.Add(o);
            if(o.ParsedPoints.Count>0){o.PreviewOffsetX+=dx;o.PreviewOffsetY+=dy;}
        }
    }
    private static void MoveBounds(BoardObject o,double dx,double dy)
    {
        o.X+=dx;o.Y+=dy;
        if(o.X1.HasValue){o.X1+=dx;o.X2+=dx;o.Y1+=dy;o.Y2+=dy;}
    }
    private static void TranslatePoints(BoardObject o,double dx,double dy)
    {
        if(o.ParsedPoints.Count==0||(dx==0&&dy==0))return;
        o.Points=JsonSerializer.Serialize(o.ParsedPoints.Select(p=>{var moved=DocumentCodec.Clone(p);moved.X+=dx;moved.Y+=dy;return moved;}),DocumentCodec.Options);
    }
    private void FlushPreviewMoves()
    {
        foreach(var o in _previewMoves){TranslatePoints(o,o.PreviewOffsetX,o.PreviewOffsetY);o.UpdatedAt=DateTime.UtcNow.ToString("o");}
        ClearPreviewMoves();
    }
    private void ClearPreviewMoves()
    {
        foreach(var o in _previewMoves)o.PreviewOffsetX=o.PreviewOffsetY=0;
        _previewMoves.Clear();
    }
    public void MarkSaved(long generation, int revision)
    {
        SavedGeneration = generation; Document.Board.Revision = revision;
        if(_transaction is not null)_transaction.Board.Revision=revision;
    }
    public BoardObject Add(BoardObject o)
    {
        o.BoardId = Document.Board.Id; o.PageId = Document.Board.ActivePageId;
        o.ZIndex = Document.Objects.Count == 0 ? 0 : Document.Objects.Max(x => x.ZIndex) + 1;
        Document.Objects.Add(o); SelectedId = o.Id; return o;
    }
    public void DeleteSelected()
    {
        var objects=SelectedObjects.Where(o=>o.IsLocked!=true).ToArray();if(objects.Length==0)return;
        Begin();foreach(var o in objects)Document.Objects.Remove(o);SelectedId=null;Commit();
    }
    public void Move(BoardObject o, double dx, double dy)
    {
        if(!double.IsFinite(dx)||!double.IsFinite(dy)||(dx==0&&dy==0))return;
        MoveBounds(o,dx,dy);TranslatePoints(o,dx,dy);o.UpdatedAt=DateTime.UtcNow.ToString("o");
    }
    public BoardObject? Hit(InkPoint p, double tolerance) => VisibleObjects.OrderByDescending(o => o.ZIndex)
        .FirstOrDefault(o => VectorMath.IsPointInObject(p, o, tolerance));
    public void Erase(InkPoint center, double radius, bool wholeObject)
    {
        foreach (var o in VisibleObjects.Where(o => o.IsLocked != true && o.IsErasable).ToList())
        {
            if (!wholeObject && o.Type is not ("stroke" or "pen" or "highlighter" or "paint")) continue;
            if (!VectorMath.IsPointInObject(center, o, radius)) continue;
            if (wholeObject || o.ParsedPoints.Count == 0) { Document.Objects.Remove(o); continue; }
            var fragments = StrokeGeometry.Erase(o.ParsedPoints, center, radius + o.StrokeWidth / 2);
            if (fragments.Count == 1 && fragments[0].Count == o.ParsedPoints.Count &&
                fragments[0].Zip(o.ParsedPoints).All(p => p.First.X == p.Second.X && p.First.Y == p.Second.Y)) continue;
            Document.Objects.Remove(o);
            foreach (var fragment in fragments)
            {
                var copy = DocumentCodec.Clone(o); copy.Id = Guid.NewGuid().ToString();
                copy.Points = JsonSerializer.Serialize(fragment, DocumentCodec.Options);
                var box = VectorMath.ComputeBoundingBox(fragment, o.StrokeWidth);
                copy.X = box.MinX; copy.Y = box.MinY; copy.Width = box.Width; copy.Height = box.Height;
                Document.Objects.Add(copy);
            }
        }
    }
}

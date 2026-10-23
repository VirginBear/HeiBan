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
    public IEnumerable<BoardObject> SelectedObjects => _selectedIds.Count==0?Enumerable.Empty<BoardObject>():PageObjects.Where(o=>_selectedIds.Contains(o.Id));
    public void SetSelection(IEnumerable<string> ids) { var valid=PageObjects.Select(o=>o.Id).ToHashSet();_selectedIds.Clear();_selectedIds.UnionWith(ids.Where(valid.Contains)); }
    public void ToggleSelection(string id) { if(!_selectedIds.Remove(id)&&PageObjects.Any(o=>o.Id==id))_selectedIds.Add(id); }
    public void MoveSelection(double dx,double dy) { foreach(var o in SelectedObjects.Where(o=>o.IsLocked!=true))Move(o,dx,dy); }
    public BoardObject? Selected => SelectedObjects.OrderBy(o=>o.IsLocked==true).ThenByDescending(o=>o.ZIndex).FirstOrDefault();
    public bool IsDirty => Generation != SavedGeneration;
    public long Generation { get; private set; }
    public long SavedGeneration { get; private set; }
    private sealed record Snapshot(HeiBanDocument? Document,long Bytes,BoardObject? Added=null,int Index=-1);
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
    private readonly ObjectOrderCache _order = new();
    public OrderedBoardObjects DrawingObjects => _order.Ascending(Document);
    public void Open(HeiBanDocument doc)
    {
        ClearPreviewMoves();_order.Clear();DocumentEpoch++;Document = doc; SelectedId = null; _undo.Clear(); _redo.Clear(); _transaction = null;
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
    public void Undo() => Restore(_undo, _redo,true);
    public void Redo() => Restore(_redo, _undo,false);
    private void Restore(List<Snapshot> from, List<Snapshot> to,bool undo)
    {
        if (from.Count == 0) return;
        Cancel();
        var entry=from[^1];
        if(entry.Added is { } added)
        {
            // Completed ink only appends a top-level object. Store just that object's
            // isolated snapshot; mixed edits still use full-document transactions.
            var index=Document.Objects.FindIndex(o=>o.Id==added.Id);
            if(undo){if(index<0)return;Document.Objects.RemoveAt(index);}
            else{if(index>=0)return;Document.Objects.Insert(Math.Clamp(entry.Index,0,Document.Objects.Count),DocumentCodec.Clone(added));}
            from.RemoveAt(from.Count-1);to.Add(entry);Trim(to);SelectedId=null;Generation++;return;
        }
        var snapshot=DocumentCodec.Clone(Document);to.Add(new(snapshot,DocumentSnapshot.EstimatedBytes(snapshot)));Trim(to);
        var revision = Document.Board.Revision;
        Document = DocumentCodec.Clone(entry.Document!); from.RemoveAt(from.Count - 1);
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
    public BoardObject AppendInk(BoardObject item)
    {
        if(HasTransaction||_previewMoves.Count!=0)throw new InvalidOperationException("Complete or cancel the current transaction before appending ink.");
        if(item.Type is not("stroke" or "pen" or "highlighter" or "paint" or "line"))throw new ArgumentException("Only completed ink or its held-line result can use this transaction.",nameof(item));
        var added=Add(item);SelectedId=null;
        using var trace=global::HeiBan.Windows.Diagnostics.InputLatencyTrace.Measure(global::HeiBan.Windows.Diagnostics.InputStage.InkSnapshot);
        var snapshot=DocumentCodec.Clone(added);
        _undo.Add(new(null,DocumentSnapshot.EstimatedBytes(snapshot),snapshot,Document.Objects.Count-1));
        _redo.Clear();Trim(_undo);Generation++;return added;
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
    public BoardObject? Hit(InkPoint p, double tolerance)
    {
        foreach (var item in _order.Descending(Document))
            if (VectorMath.IsPointInObject(p, item, tolerance)) return item;
        return null;
    }
    public void Erase(InkPoint center, double radius, bool wholeObject)
        =>EraseChanged(center,radius,wholeObject);
    public bool EraseChanged(InkPoint center,double radius,bool wholeObject)
    {
        var changed=false;
        for(var objectIndex=Document.Objects.Count-1;objectIndex>=0;objectIndex--)
        {
            var o=Document.Objects[objectIndex];
            if(o.IsVisible==false||o.IsLocked==true||!o.IsErasable||Document.Board.CanvasMode=="notebook"&&o.PageId is not null&&o.PageId!=Document.Board.ActivePageId)continue;
            if (!wholeObject && o.Type is not ("stroke" or "pen" or "highlighter" or "paint")) continue;
            if (!VectorMath.IsPointInObject(center, o, radius)) continue;
            if (wholeObject || o.ParsedPoints.Count == 0) { Document.Objects.RemoveAt(objectIndex);changed=true;continue; }
            IReadOnlyList<InkPoint> world=o.Rotation==0?o.ParsedPoints:o.ParsedPoints.Select(p=>{var copy=p.Snapshot();var at=ObjectHandles.ToWorld(o,p);copy.X=at.X;copy.Y=at.Y;return copy;}).ToArray();
            var fragments = StrokeGeometry.Erase(world, center, radius + o.StrokeWidth / 2);
            if (fragments.Count == 1 && fragments[0].Count == world.Count &&
                fragments[0].Zip(world).All(p => p.First.X == p.Second.X && p.First.Y == p.Second.Y)) continue;
            Document.Objects.RemoveAt(objectIndex);changed=true;var index=objectIndex;
            foreach (var fragment in fragments)
            {
                var copy = DocumentCodec.Clone(o); copy.Id = Guid.NewGuid().ToString();copy.Rotation=0;
                copy.SetOwnedInkPoints(fragment);
                var box = VectorMath.ComputeBoundingBox(fragment, o.StrokeWidth);
                copy.X = box.MinX; copy.Y = box.MinY; copy.Width = box.Width; copy.Height = box.Height;
                Document.Objects.Insert(index++,copy);
            }
        }
        return changed;
    }
    public void EraseRectangle(InkPoint center,double width,double height,bool wholeObject)
    {
        EraseFootprint(EraserFootprint.Rectangle(center.X-width/2,center.Y-height/2,center.X+width/2,center.Y+height/2),wholeObject);
    }
    public void EraseFootprint(EraserFootprint footprint,bool wholeObject)
        =>EraseFootprintChanged(footprint,wholeObject);
    public bool EraseFootprintChanged(EraserFootprint footprint,bool wholeObject)
    {
        var changed=false;
        // Walk backward so newly inserted fragments are skipped in this contact.
        // Avoid allocating a full eligible-object array for each swept sample.
        for(var objectIndex=Document.Objects.Count-1;objectIndex>=0;objectIndex--)
        {
            var item=Document.Objects[objectIndex];
            if(item.IsVisible==false||item.IsLocked==true||!item.IsErasable||
                Document.Board.CanvasMode=="notebook"&&item.PageId is not null&&item.PageId!=Document.Board.ActivePageId)continue;
            if(!wholeObject&&item.Type is not("stroke" or "pen" or "highlighter" or "paint"))continue;
            if(!RectangularEraser.Intersects(item,footprint))continue;
            if(wholeObject||item.ParsedPoints.Count==0){Document.Objects.RemoveAt(objectIndex);changed=true;continue;}
            // Bake the old rotation into points before computing fragment bounds. Leaving
            // rotation on each fragment would rotate it around a different center.
            IReadOnlyList<InkPoint> world=item.Rotation==0?item.ParsedPoints:
                item.ParsedPoints.Select(p=>{var copy=DocumentCodec.Clone(p);var at=ObjectHandles.ToWorld(item,p);copy.X=at.X;copy.Y=at.Y;return copy;}).ToArray();
            var pad=item.StrokeWidth/2;
            var fragments=footprint.Split(world,pad);
            if(fragments.Count==1&&fragments[0].Count==world.Count&&fragments[0].Zip(world).All(pair=>pair.First.X==pair.Second.X&&pair.First.Y==pair.Second.Y))continue;
            var index=objectIndex;Document.Objects.RemoveAt(index);changed=true;
            foreach(var fragment in fragments)
            {
                var copy=DocumentCodec.Clone(item);copy.Id=Guid.NewGuid().ToString();copy.Rotation=0;
                copy.SetOwnedInkPoints(fragment);
                var bounds=VectorMath.ComputeBoundingBox(fragment,item.StrokeWidth);copy.X=bounds.MinX;copy.Y=bounds.MinY;copy.Width=bounds.Width;copy.Height=bounds.Height;
                Document.Objects.Insert(index++,copy);
            }
        }
        return changed;
    }
}

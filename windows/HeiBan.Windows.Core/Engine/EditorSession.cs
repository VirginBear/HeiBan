using System.Text.Json;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>UI-thread document transactions; live pointer movement does not serialize the document.</summary>
public sealed class EditorSession
{
    public HeiBanDocument Document { get; private set; } = new();
    public string? SelectedId { get; set; }
    public BoardObject? Selected => Document.Objects.FirstOrDefault(o => o.Id == SelectedId);
    public bool IsDirty => Generation != SavedGeneration;
    public long Generation { get; private set; }
    public long SavedGeneration { get; private set; }
    private readonly List<string> _undo = [];
    private readonly List<string> _redo = [];
    private string? _transaction;
    public bool CanUndo => _undo.Count > 0;
    public bool CanRedo => _redo.Count > 0;
    public IEnumerable<BoardObject> VisibleObjects => Document.Objects.Where(o => o.IsVisible != false &&
        (Document.Board.CanvasMode != "notebook" || o.PageId is null || o.PageId == Document.Board.ActivePageId));
    public void Open(HeiBanDocument doc)
    {
        Document = doc; SelectedId = null; _undo.Clear(); _redo.Clear(); _transaction = null;
        Generation = SavedGeneration = 0;
    }
    public void Begin() => _transaction ??= DocumentCodec.Encode(Document);
    public void Commit()
    {
        if (_transaction is null) return;
        var before = _transaction; _transaction = null;
        if (before == DocumentCodec.Encode(Document)) return;
        _undo.Add(before); _redo.Clear(); Generation++;
        // Cap undo memory, in addition to the number of transactions.
        while (_undo.Count > 64 || (_undo.Count > 1 && _undo.Sum(s => (long)s.Length * 2) > 32 * 1024 * 1024)) _undo.RemoveAt(0);
    }
    public void Cancel() { if (_transaction is not null) Document = DocumentCodec.Decode(_transaction); _transaction = null; }
    public void Undo() => Restore(_undo, _redo);
    public void Redo() => Restore(_redo, _undo);
    private void Restore(List<string> from, List<string> to)
    {
        if (from.Count == 0) return;
        to.Add(DocumentCodec.Encode(Document));
        var revision = Document.Board.Revision;
        Document = DocumentCodec.Decode(from[^1]); from.RemoveAt(from.Count - 1);
        Document.Board.Revision = revision; SelectedId = null; Generation++;
    }
    public void MarkSaved(long generation, int revision)
    {
        SavedGeneration = generation; Document.Board.Revision = revision;
    }
    public BoardObject Add(BoardObject o)
    {
        o.BoardId = Document.Board.Id; o.PageId = Document.Board.ActivePageId;
        o.ZIndex = Document.Objects.Count == 0 ? 0 : Document.Objects.Max(x => x.ZIndex) + 1;
        Document.Objects.Add(o); SelectedId = o.Id; return o;
    }
    public void DeleteSelected()
    {
        if (Selected is not { } o || o.IsLocked == true) return;
        Begin(); Document.Objects.Remove(o); SelectedId = null; Commit();
    }
    public void Move(BoardObject o, double dx, double dy)
    {
        o.X += dx; o.Y += dy;
        if (o.X1.HasValue) { o.X1 += dx; o.X2 += dx; o.Y1 += dy; o.Y2 += dy; }
        if (o.ParsedPoints.Count > 0)
            o.Points = JsonSerializer.Serialize(o.ParsedPoints.Select(p => { var moved = DocumentCodec.Clone(p); moved.X += dx; moved.Y += dy; return moved; }), DocumentCodec.Options);
        o.UpdatedAt = DateTime.UtcNow.ToString("o");
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

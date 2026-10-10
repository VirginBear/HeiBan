using System.Collections;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>UI-thread order cache. The public document list and ZIndex remain mutable during transactions.</summary>
public sealed class ObjectOrderCache
{
    private readonly record struct Entry(BoardObject Object, int ZIndex, int SourceIndex);
    private HeiBanDocument? _document;
    private List<BoardObject>? _list;
    private Entry[] _source = [];
    private OrderedBoardObjects? _ascending, _descending;
    public long Rebuilds { get; private set; }

    public OrderedBoardObjects Ascending(HeiBanDocument document) { Ensure(document); return _ascending!; }
    public OrderedBoardObjects Descending(HeiBanDocument document) { Ensure(document); return _descending!; }
    public void Clear() { _document = null; _list = null; _source = []; _ascending = _descending = null; }

    private void Ensure(HeiBanDocument document)
    {
        var objects = document.Objects;
        // Generation alone misses in-transaction edits and same-size list replacements.
        // An allocation-free scan detects identity, source order and ZIndex changes before reuse.
        var valid = ReferenceEquals(document, _document) && ReferenceEquals(objects, _list) && objects.Count == _source.Length;
        if (valid)
            for (var i = 0; i < objects.Count; i++)
                if (!ReferenceEquals(objects[i], _source[i].Object) || objects[i].ZIndex != _source[i].ZIndex) { valid = false; break; }
        if (valid) return;
        _source = new Entry[objects.Count];
        for (var i = 0; i < objects.Count; i++) _source[i] = new(objects[i], objects[i].ZIndex, i);
        var sorted = (Entry[])_source.Clone();
        Array.Sort(sorted, static (a, b) => { var order = a.ZIndex.CompareTo(b.ZIndex); return order != 0 ? order : a.SourceIndex.CompareTo(b.SourceIndex); });
        var ascending = new BoardObject[sorted.Length]; var descending = new BoardObject[sorted.Length];
        for (var i = 0; i < sorted.Length; i++) ascending[i] = sorted[i].Object;
        var destination = 0;
        for (var end = sorted.Length - 1; end >= 0;)
        {
            var start = end;
            while (start > 0 && sorted[start - 1].ZIndex == sorted[end].ZIndex) start--;
            // Descending LINQ order keeps original tie order; reversing the array would change hits.
            for (var i = start; i <= end; i++) descending[destination++] = sorted[i].Object;
            end = start - 1;
        }
        _document = document; _list = objects;
        _ascending = new(document, ascending, true); _descending = new(document, descending, false); Rebuilds++;
    }
}

/// <summary>Stable Z order with live page/visibility filtering, never serialized into a document.</summary>
public sealed class OrderedBoardObjects : IEnumerable<BoardObject>
{
    private readonly HeiBanDocument _document;
    private readonly BoardObject[] _objects;
    public bool IsAscending { get; }
    internal OrderedBoardObjects(HeiBanDocument document, BoardObject[] objects, bool isAscending) { _document = document; _objects = objects; IsAscending = isAscending; }
    public IEnumerator<BoardObject> GetEnumerator()
    {
        var board = _document.Board;
        foreach (var item in _objects)
            if (item.IsVisible != false && (board.CanvasMode != "notebook" || item.PageId is null || item.PageId == board.ActivePageId)) yield return item;
    }
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
}

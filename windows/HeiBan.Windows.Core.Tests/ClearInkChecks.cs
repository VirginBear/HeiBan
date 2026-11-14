using HeiBan.Windows.Engine;
using HeiBan.Windows.Models;

static class ClearInkChecks
{
    public static void Run(Action<bool, string> check)
    {
        var session = new EditorSession();
        var doc = new HeiBanDocument
        {
            Board = new BoardMetadata { CanvasMode = "notebook", ActivePageId = "current" },
            Objects =
            [
                new() { Id = "stroke", Type = "stroke", PageId = "current" },
                new() { Id = "pen", Type = "pen", PageId = "current" },
                new() { Id = "highlighter", Type = "highlighter", PageId = "current" },
                new() { Id = "paint", Type = "paint", PageId = "current" },
                new() { Id = "image", Type = "image", PageId = "current" },
                new() { Id = "shape", Type = "line", PageId = "current" },
                new() { Id = "text", Type = "text", PageId = "current" },
                new() { Id = "locked", Type = "stroke", PageId = "current", IsLocked = true },
                new() { Id = "other", Type = "stroke", PageId = "other" },
                new() { Id = "shared", Type = "stroke" },
            ]
        };
        session.Open(doc);
        session.AppendInk(new BoardObject { Id = "straightened", Type = "line" });
        session.Open(DocumentCodec.Decode(DocumentCodec.Encode(doc)));
        var before = session.Document.Objects.Select(item => item.Id).ToArray();
        session.SetSelection(["image", "stroke"]);
        check(session.ClearPageInk(), "Clear ink changes the current notebook page");
        string[] remaining = ["image", "shape", "text", "locked", "other", "shared"];
        check(session.Document.Objects.Select(item => item.Id).SequenceEqual(remaining), "Clear ink keeps protected objects and removes straightened pen ink after reload");
        check(session.SelectedIds.SequenceEqual(["image"]), "Clear ink retains the selection of surviving objects");
        check(!session.ClearPageInk() && session.Generation == 1, "A second clear does not add history");
        session.Undo();
        check(session.Document.Objects.Select(item => item.Id).SequenceEqual(before), "Undo restores pen marks together");
        check(!session.CanUndo, "Clear ink records exactly one undo");
        session.Redo();
        check(session.Document.Objects.Select(item => item.Id).SequenceEqual(remaining), "Redo clears the same pen marks");

        session.Open(new HeiBanDocument { Objects = [new() { Type = "pen" }, new() { Type = "arrow" }] });
        check(session.ClearPageInk() && session.Document.Objects.Single().Type == "arrow", "Unpaged canvas clears ink without removing shapes");
    }
}

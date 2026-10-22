namespace HeiBan.Windows.Engine;

/// <summary>Host filtering for the shared toolbar preference. Hosts create their own controls and keep their own command/session handlers.</summary>
public static class ToolbarContentPolicy
{
    private static readonly HashSet<string> ScreenNavigationOnly = ["pins", "viewLock"];
    // This is the screen host's implemented capability set, not a second toolbar definition.
    // New catalog entries stay hidden there until a real command/session adapter exists.
    private static readonly HashSet<string> ScreenCanvasToolSet =
    [
        "select", "pen", "curve", "highlighter", "paint", "eraser", "shapes", "sticky", "text",
        "screenshot", "brush", "dash", "undo", "redo", "laser", "layers", "lasso", "tape", "magnet", "clearAll"
    ];

    public static IReadOnlyList<string> ScreenCanvasTools { get; } =
        ToolbarPreferences.AllDefaultTools.Where(ScreenCanvasToolSet.Contains).ToArray();

    public static bool IsAvailableOnScreen(string key) => ScreenCanvasToolSet.Contains(key);

    /// <summary>Returns the saved order after applying only host capabilities; it never mutates or persists preferences.</summary>
    public static IReadOnlyList<string> VisibleTools(ToolbarPreferences preferences, bool screenCanvas)
    {
        preferences.Normalize();
        return screenCanvas
            ? preferences.VisibleTools.Where(IsAvailableOnScreen).Where(key => !ScreenNavigationOnly.Contains(key)).ToArray()
            : preferences.VisibleTools.ToArray();
    }

    /// <summary>Hidden tools retain the same custom order and cannot expose screen navigation-only commands.</summary>
    public static IReadOnlyList<string> HiddenTools(ToolbarPreferences preferences, bool screenCanvas)
    {
        preferences.Normalize();
        return screenCanvas
            ? preferences.HiddenTools.Where(IsAvailableOnScreen).Where(key => !ScreenNavigationOnly.Contains(key)).ToArray()
            : preferences.HiddenTools.ToArray();
    }
}

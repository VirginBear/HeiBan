using System.Text.Json;

namespace HeiBan.Windows.Engine;

/// <summary>
/// 工具列設定偏好：停靠方向、自訂顯示工具、隱藏工具（收納於「更多」）與排序。
/// </summary>
public sealed class ToolbarPreferences
{
    public string DockSide { get; set; } = "上方";
    public List<string> VisibleTools { get; set; } = [];
    public List<string> HiddenTools { get; set; } = [];
    public string DisplayMode { get; set; } = "labels";
    public bool MagnetEnabled { get; set; }
    public bool BoardEraserVisible { get; set; } = true;
    public bool CaneVisible { get; set; } = true;
    public int DefaultToolsRevision { get; set; }
    public int DefaultPresentationRevision { get; set; }
    public int DefaultCommonRevision { get; set; }
    public static readonly string[] FixedTools = ["select","laser","cane"];
    public static bool IsFixedTool(string key)=>key is "select" or "laser" or "cane";
    public static readonly string[] DefaultCommonTools = ["select","laser","cane","pen","highlighter","eraser","brush","dash","undo","redo","magnet","clearAll"];
    public List<string> CommonTools { get; set; } = [.. DefaultCommonTools];
    [System.Text.Json.Serialization.JsonExtensionData] public Dictionary<string,JsonElement>? ExtraFields { get; set; }

    public static readonly string[] StreamlinedTools =
    [
        "select", "pen", "highlighter", "eraser", "ruler", "shapes", "magnet", "layers", "undo", "redo"
    ];

    public static readonly string[] AllDefaultTools =
    [
        "select", "pen", "curve", "highlighter", "paint", "eraser",
        "ruler", "shapes", "sticky", "text", "screenshot", "image",
        "brush", "dash", "pins", "calculator", "timer", "compass",
        "undo", "redo", "dock", "laser", "cane", "tape", "lasso", "extension", "clearAll", "viewLock", "layers", "magnet"
    ];

    public static readonly Dictionary<string, string> ToolNames = new()
    {
        ["select"] = "選取",
        ["pen"] = "鋼筆",
        ["curve"] = "曲線",
        ["highlighter"] = "螢光筆",
        ["paint"] = "油漆筆刷",
        ["eraser"] = "橡皮擦",
        ["ruler"] = "螢幕尺",
        ["shapes"] = "圖形",
        ["sticky"] = "便條紙",
        ["text"] = "文字",
        ["screenshot"] = "截圖",
        ["image"] = "匯入圖片",
        ["brush"] = "筆刷與物件設定",
        ["dash"] = "線條樣式",
        ["pins"] = "圖釘",
        ["calculator"] = "計算機",
        ["timer"] = "計時器",
        ["compass"] = "圓規",
        ["undo"] = "復原",
        ["redo"] = "重做",
        ["laser"]="雷射", ["cane"]="藤條", ["tape"]="遮題膠帶", ["lasso"]="套索多選", ["extension"]="延伸直線", ["clearAll"]="清除本頁", ["viewLock"]="鎖定視角",
        ["layers"] = "物件圖層",
        ["dock"] = "停靠位置"
        ,["magnet"] = "磁鐵"
    };

    public static ToolbarPreferences CreateDefault() => new()
    {
        DockSide = "上方",
        DefaultToolsRevision = 1,
        DefaultPresentationRevision = 1,
        DefaultCommonRevision = 1,
        VisibleTools = [..FixedTools,..AllDefaultTools.Where(t=>!IsFixedTool(t))],
        HiddenTools = []
    };

    public void Normalize()
    {
        // Upgrade only the exact former preset. An explicit custom ordering or
        // visibility choice remains owned by the user, including deliberately hidden tools.
        if(DefaultToolsRevision<1)
        {
            if(VisibleTools is not null&&HiddenTools is not null&&VisibleTools.SequenceEqual(StreamlinedTools)&&
                (HiddenTools.ToHashSet().SetEquals(AllDefaultTools.Except(StreamlinedTools))||
                 HiddenTools.ToHashSet().SetEquals(AllDefaultTools.Except(StreamlinedTools).Where(key=>key!="cane"))))
            {VisibleTools=[..AllDefaultTools];HiddenTools=[];}
            DefaultToolsRevision=1;
        }
        // Migrate only the former untouched presentation. Custom favorites and
        // intentionally hidden tools remain user choices across an upgrade.
        if(DefaultPresentationRevision<1)
        {
            if(CommonTools is not null&&CommonTools.SequenceEqual(new[]{"pen","highlighter","eraser","undo","redo","magnet"}))
            {
                CommonTools=[..DefaultCommonTools];
                if(DisplayMode=="icons"&&VisibleTools is not null&&HiddenTools is not null&&
                    (VisibleTools.SequenceEqual(AllDefaultTools)||VisibleTools.SequenceEqual(AllDefaultTools.Where(key=>key!="cane")))&&HiddenTools.Count==0)DisplayMode="labels";
            }
            DefaultPresentationRevision=1;
        }
        if(DisplayMode is not("icons" or "labels"))DisplayMode="labels";
        if (DockSide is not ("上方" or "左側" or "下方" or "右側"))
        {
            DockSide = "上方";
        }

        // Introduce clear once, without replacing the user's other favorites.
        // Removing it after this revision remains an explicit saved choice.
        if(DefaultCommonRevision<1)
        {
            CommonTools??=[..DefaultCommonTools];
            if(!CommonTools.Contains("clearAll"))CommonTools.Add("clearAll");
            DefaultCommonRevision=1;
        }
        var allKnown = AllDefaultTools.ToHashSet();
        CommonTools = (CommonTools ?? [..DefaultCommonTools]).Where(t=>allKnown.Contains(t)&&t!="extension").Distinct().ToList();
        VisibleTools ??= [];
        HiddenTools ??= [];

        // One-time discovery: old preferences lack layers in both lists. A later explicit hide remains respected.
        if(!VisibleTools.Contains("layers")&&!HiddenTools.Contains("layers"))VisibleTools.Add("layers");
        if(!VisibleTools.Contains("magnet")&&!HiddenTools.Contains("magnet"))VisibleTools.Add("magnet");
        // These are structural controls, independent from per-page favorites.
        // Restore older hidden preferences without discarding any other user order.
        HiddenTools.RemoveAll(IsFixedTool);
        VisibleTools.RemoveAll(IsFixedTool);VisibleTools.InsertRange(0,FixedTools);
        CommonTools=FixedTools.Concat(CommonTools.Where(t=>!IsFixedTool(t))).ToList();
        var seen = new HashSet<string>();
        VisibleTools = VisibleTools.Where(t => allKnown.Contains(t) && seen.Add(t)).ToList();
        HiddenTools = HiddenTools.Where(t => allKnown.Contains(t) && seen.Add(t)).ToList();

        foreach (var tool in AllDefaultTools)
        {
            if (!seen.Contains(tool))
            {
                // 新工具收折進 HiddenTools (更多)，避免破壞使用者既有配置
                HiddenTools.Add(tool);
                seen.Add(tool);
            }
        }
    }

    public void ResetToDefault()
    {
        DefaultToolsRevision=1;
        DefaultPresentationRevision=1;
        DefaultCommonRevision=1;
        DisplayMode="labels";MagnetEnabled=false;
        CommonTools=[..DefaultCommonTools];
        DockSide = "上方";
        VisibleTools = [..FixedTools,..AllDefaultTools.Where(t=>!IsFixedTool(t))];
        HiddenTools = [];
    }

    public bool MoveToolUp(string toolKey)
    {
        if(IsFixedTool(toolKey))return false;
        int idx = VisibleTools.IndexOf(toolKey);
        if (idx <= FixedTools.Length) return false;
        (VisibleTools[idx - 1], VisibleTools[idx]) = (VisibleTools[idx], VisibleTools[idx - 1]);
        return true;
    }

    public bool MoveToolDown(string toolKey)
    {
        if(IsFixedTool(toolKey))return false;
        int idx = VisibleTools.IndexOf(toolKey);
        if (idx < 0 || idx >= VisibleTools.Count - 1) return false;
        (VisibleTools[idx + 1], VisibleTools[idx]) = (VisibleTools[idx], VisibleTools[idx + 1]);
        return true;
    }

    public void HideTool(string toolKey)
    {
        if(IsFixedTool(toolKey))return;
        if (VisibleTools.Remove(toolKey))
        {
            if (!HiddenTools.Contains(toolKey))
            {
                HiddenTools.Add(toolKey);
            }
        }
    }

    public void ShowTool(string toolKey)
    {
        HiddenTools.Remove(toolKey);
        if (!VisibleTools.Contains(toolKey) && AllDefaultTools.Contains(toolKey))
        {
            VisibleTools.Add(toolKey);
        }
    }
}

/// <summary>
/// 偏好儲存管理器：讀寫至 DocumentSessionManager.DataDirectory/Settings/toolbar.json
/// </summary>
public static class ToolbarPreferencesStore
{
    private static readonly SemaphoreSlim SaveGate=new(1,1);
    public static string GetPreferencesPath(string dataDirectory) =>
        Path.Combine(dataDirectory, "Settings", "toolbar.json");

    public static ToolbarPreferences Load(string dataDirectory)
    {
        var path = GetPreferencesPath(dataDirectory);
        if (!File.Exists(path)) return ToolbarPreferences.CreateDefault();
        try
        {
            var json = File.ReadAllText(path);
            var prefs = JsonSerializer.Deserialize<ToolbarPreferences>(json, DocumentCodec.Options);
            if (prefs is null) return ToolbarPreferences.CreateDefault();
            prefs.Normalize();
            return prefs;
        }
        catch
        {
            return ToolbarPreferences.CreateDefault();
        }
    }

    public static async Task<ToolbarPreferences> LoadAsync(string dataDirectory)
    {
        var path = GetPreferencesPath(dataDirectory);
        if (!File.Exists(path)) return ToolbarPreferences.CreateDefault();
        try
        {
            var json = await File.ReadAllTextAsync(path);
            var prefs = JsonSerializer.Deserialize<ToolbarPreferences>(json, DocumentCodec.Options);
            if (prefs is null) return ToolbarPreferences.CreateDefault();
            prefs.Normalize();
            return prefs;
        }
        catch
        {
            return ToolbarPreferences.CreateDefault();
        }
    }

    public static async Task SaveAsync(string dataDirectory, ToolbarPreferences preferences)
    {
        var path = GetPreferencesPath(dataDirectory);
        preferences.Normalize();
        var json = JsonSerializer.Serialize(preferences, DocumentCodec.Options);
        // Main/screen/dock commands can arrive while a previous atomic replacement is still pending.
        await SaveGate.WaitAsync();
        try{await DocumentSessionManager.WriteAtomicAsync(path,json);}
        finally{SaveGate.Release();}
    }
}

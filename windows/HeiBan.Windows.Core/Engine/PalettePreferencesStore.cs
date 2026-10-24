using System.Text.Json;
using System.Text.Json.Serialization;

namespace HeiBan.Windows.Engine;

public sealed class PalettePreferences
{
    public int SchemaVersion { get; set; } = 1;
    public List<string> Colors { get; set; } = [];
    [JsonExtensionData] public Dictionary<string,JsonElement>? ExtraFields { get; set; }
}

/// <summary>One profile-owned palette. Changes commit to disk before notification; document transactions never enter this store.</summary>
public sealed class PalettePreferencesStore
{
    public static readonly string[] DefaultColors = ["#86EFAC","#FEF08A","#93C5FD","#FFFFFF","#F472B6","#FB923C","#C084FC","#24533D"];
    private readonly string _path;
    private readonly SemaphoreSlim _gate = new(1,1);
    private PalettePreferences _preferences = new() { Colors = [..DefaultColors] };
    public bool LoadFailed { get; private set; }
    public IReadOnlyList<string> Colors => _preferences.Colors.AsReadOnly();
    public event Action? Changed;

    public PalettePreferencesStore(string dataDirectory)
    {
        _path = Path.Combine(dataDirectory,"Settings","palette.json");
        try
        {
            if(!File.Exists(_path))return;
            var json=File.ReadAllText(_path);
            var saved=JsonSerializer.Deserialize<PalettePreferences>(json,DocumentCodec.Options)
                ?? throw new JsonException("Invalid palette");
            // Missing colors and explicit [] are different: never repopulate a deliberately empty palette.
            using var raw=JsonDocument.Parse(json);
            if(saved.SchemaVersion!=1||raw.RootElement.ValueKind!=JsonValueKind.Object||!raw.RootElement.TryGetProperty("colors",out var colors)||colors.ValueKind!=JsonValueKind.Array||saved.Colors is null)
                throw new JsonException("Unsupported palette");
            saved.Colors=saved.Colors.Select(color=>Canonical(color)??throw new JsonException("Invalid palette color")).Distinct().ToList();
            _preferences=saved;
        }
        catch(Exception e) when(e is IOException or UnauthorizedAccessException or JsonException or ArgumentException)
        {LoadFailed=true;} // Keep the original bytes; a damaged/future file is not overwritten by defaults.
    }

    public static string? Canonical(string? color)
    {
        if(color is null||color.Length is not(7 or 9)||color[0]!='#'||color.Skip(1).Any(c=>!Uri.IsHexDigit(c)))return null;
        var value=color.ToUpperInvariant();
        return value.Length==9&&value.EndsWith("FF",StringComparison.Ordinal)?value[..7]:value;
    }
    public Task<bool> AddAsync(string color)=>ChangeAsync(list=>
    {
        var normalized=Canonical(color)??throw new ArgumentException("Invalid color",nameof(color));
        if(list.Contains(normalized))return false;list.Add(normalized);return true;
    });
    public Task<bool> RemoveAsync(string color)=>ChangeAsync(list=>list.Remove(Canonical(color)??color));
    public Task<bool> ResetAsync()=>ChangeAsync(list=>{list.Clear();list.AddRange(DefaultColors);return true;});
    private async Task<bool> ChangeAsync(Func<List<string>,bool> change)
    {
        await _gate.WaitAsync();
        try
        {
            if(LoadFailed)throw new InvalidOperationException("Palette file was not loaded; original retained");
            var next=new PalettePreferences { Colors=[.._preferences.Colors], ExtraFields=_preferences.ExtraFields };
            if(!change(next.Colors))return false;
            var json=JsonSerializer.Serialize(next,DocumentCodec.Options);
            await Task.Run(()=>DocumentSessionManager.WriteAtomicAsync(_path,json));
            _preferences=next;
            Changed?.Invoke();
            return true;
        }
        finally{_gate.Release();}
    }
    // Shutdown disables editing first, then joins all already queued preference writes.
    public async Task FlushAsync(){await _gate.WaitAsync();_gate.Release();}
}

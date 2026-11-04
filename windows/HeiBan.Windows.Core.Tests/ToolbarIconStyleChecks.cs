using System.Text.Json;
using HeiBan.Windows.Engine;
internal static class ToolbarIconStyleChecks
{
    internal static void Run(Action<bool,string> check)
    {
        var old=JsonSerializer.Deserialize<ToolbarPreferences>("{\"futureField\":{\"keep\":true}}",DocumentCodec.Options)!;old.Normalize();
        check(old.IconStyle=="classic","Older toolbar files retain the original artwork");
        old.IconStyle="duotone";var copy=DocumentCodec.Clone(old);copy.ApplyToolSubset(new[]{"pen"},new HashSet<string>{"pen"},new HashSet<string>{"pen"},"icons");
        check(copy.IconStyle=="duotone"&&copy.ExtraFields!["futureField"].GetProperty("keep").GetBoolean(),"Screen subset edits preserve icon choice and unknown fields");
        var restored=JsonSerializer.Deserialize<ToolbarPreferences>(JsonSerializer.Serialize(copy,DocumentCodec.Options),DocumentCodec.Options)!;restored.Normalize();
        check(restored.IconStyle=="duotone","Chosen style survives a saved toolbar round trip");
        restored.IconStyle="future-style";restored.Normalize();check(restored.IconStyle=="classic","Unknown style falls back to available original artwork");
        restored.IconStyle="duotone";restored.ResetToDefault();check(restored.IconStyle=="classic","Explicit toolbar reset restores original style");
    }
}

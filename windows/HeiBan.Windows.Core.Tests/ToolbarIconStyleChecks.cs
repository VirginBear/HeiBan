using System.Text.Json;
using HeiBan.Windows.Engine;
internal static class ToolbarIconStyleChecks
{
    internal static void Run(Action<bool,string> check)
    {
        var old=JsonSerializer.Deserialize<ToolbarPreferences>("{\"futureField\":{\"keep\":true}}",DocumentCodec.Options)!;old.Normalize();
        check(old.IconStyle=="duotone","Missing style uses the new color default");
        var savedClassic = JsonSerializer.Deserialize<ToolbarPreferences>("{\"iconStyle\":\"classic\"}", DocumentCodec.Options)!;
        savedClassic.Normalize();
        check(savedClassic.IconStyle == "classic", "An explicitly saved original style remains selected");
        check(ToolbarPreferences.CreateDefault().IconStyle == "duotone", "New profiles use color icons");
        old.IconStyle="duotone";var copy=DocumentCodec.Clone(old);copy.ApplyToolSubset(new[]{"pen"},new HashSet<string>{"pen"},new HashSet<string>{"pen"},"icons");
        check(copy.IconStyle=="duotone"&&copy.ExtraFields!["futureField"].GetProperty("keep").GetBoolean(),"Screen subset edits preserve icon choice and unknown fields");
        var restored=JsonSerializer.Deserialize<ToolbarPreferences>(JsonSerializer.Serialize(copy,DocumentCodec.Options),DocumentCodec.Options)!;restored.Normalize();
        check(restored.IconStyle=="duotone","Chosen style survives a saved toolbar round trip");
        restored.IconStyle="future-style";restored.Normalize();check(restored.IconStyle=="duotone","Unknown style falls back to the color default");
        restored.IconStyle="duotone";restored.ResetToDefault();check(restored.IconStyle=="duotone","Explicit toolbar reset restores the color default");
    }
}

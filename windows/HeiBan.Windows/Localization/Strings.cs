using System.Globalization;
using System.Text.Json;
using HeiBan.Windows.Engine;

namespace HeiBan.Windows.Localization;

public sealed record AppLanguage(string Code, string NativeName);

/// <summary>Only UI strings enter this catalog. Document text, IDs, geometry and persisted tool keys never do.</summary>
public static class Strings
{
    public static IReadOnlyList<AppLanguage> Languages { get; } = new AppLanguage[]
    {
        new("zh-TW", "正體中文"), new("zh-CN", "简体中文"), new("en", "English"),
        new("ja", "日本語"), new("ko", "한국어"), new("es", "Español"),
        new("fr", "Français"), new("de", "Deutsch"), new("pt-BR", "Português (Brasil)"), new("ar", "العربية")
    };
    private static readonly Dictionary<string, Dictionary<string, string>> Catalogs = new(StringComparer.Ordinal);
    private static Dictionary<string, JsonElement> _preferences = [];
    private static readonly SemaphoreSlim SaveGate = new(1, 1);
    private static string? _settingsPath;
    public static string Language { get; private set; } = "zh-TW";
    public static bool RightToLeft => Language == "ar";
    public static CultureInfo Culture => CultureInfo.GetCultureInfo(Language);
    public static string NativeName => Languages.First(language => language.Code == Language).NativeName;
    public static string? PreferenceReadError { get; private set; }

    public static void Initialize(string dataDirectory)
    {
        _settingsPath = Path.Combine(dataDirectory, "Settings", "language.json");
        try
        {
            _preferences = File.Exists(_settingsPath)
                ? JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(File.ReadAllText(_settingsPath)) ?? [] : [];
            var code = _preferences.TryGetValue("language", out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
            // An unknown preference is retained on disk until an explicit user change.
            Language = Languages.FirstOrDefault(language => language.Code == code)?.Code ?? "zh-TW";
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException)
        { Language = "zh-TW"; PreferenceReadError = error.Message; }
        _ = Catalog(Language);
        ApplyPlatformLanguage();
    }

    private static Dictionary<string, string> Catalog(string language)
    {
        lock (Catalogs)
        {
            if (Catalogs.TryGetValue(language, out var cached)) return cached;
            using var stream = typeof(Strings).Assembly.GetManifestResourceStream($"HeiBan.Localization.{language}.json")
                ?? throw new InvalidOperationException($"Missing bundled language catalog: {language}");
            var entries = JsonSerializer.Deserialize<Dictionary<string, string>>(stream)
                ?? throw new InvalidOperationException($"Invalid bundled language catalog: {language}");
            Catalogs[language] = entries;
            return entries;
        }
    }

    public static string T(string source) => Catalog(Language).GetValueOrDefault(source, source);
    public static string F(FormattableString source) => string.Format(Culture, T(source.Format), source.GetArguments());

    private static void ApplyPlatformLanguage()
    {
        try { Microsoft.Windows.Globalization.ApplicationLanguages.PrimaryLanguageOverride = Language; }
        catch (Exception error) when (error is System.Runtime.InteropServices.COMException or NotSupportedException)
        {
            // Catalog strings still work if the framework override is unavailable on a deployment.
            System.Diagnostics.Debug.WriteLine($"Native language override unavailable: {error.Message}");
        }
    }

    public static async Task SelectAsync(string language)
    {
        if (!Languages.Any(candidate => candidate.Code == language)) throw new ArgumentException("Unsupported UI language.", nameof(language));
        if (_settingsPath is null) throw new InvalidOperationException("Language preferences have not been initialized.");
        await SaveGate.WaitAsync();
        try
        {
            var updated = new Dictionary<string, JsonElement>(_preferences)
            { ["language"] = JsonSerializer.SerializeToElement(language) };
            await DocumentSessionManager.WriteAtomicAsync(_settingsPath, JsonSerializer.Serialize(updated, new JsonSerializerOptions { WriteIndented = true }));
            // Apply only after an atomic save succeeds; a disk error cannot pretend the choice will survive restart.
            _preferences = updated; Language = language; PreferenceReadError = null;
            ApplyPlatformLanguage();
            Ui.Refresh();
        }
        finally { SaveGate.Release(); }
    }
}

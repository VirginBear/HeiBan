using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace HeiBan.Windows.Updating;

public sealed record ReleaseVersion(int Major, int Minor, int Patch, int? Preview) : IComparable<ReleaseVersion>
{
    public static ReleaseVersion? Parse(string value)
    {
        var match = Regex.Match(value, @"\A(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-preview\.(0|[1-9]\d*))?\z", RegexOptions.CultureInvariant);
        if (!match.Success) return null;
        var numbers = new int[4];
        for (var i = 1; i <= 4; i++)
            if (match.Groups[i].Success && !int.TryParse(match.Groups[i].Value, NumberStyles.None, CultureInfo.InvariantCulture, out numbers[i - 1])) return null;
        return new(numbers[0], numbers[1], numbers[2], match.Groups[4].Success ? numbers[3] : null);
    }
    public int CompareTo(ReleaseVersion? other)
    {
        if (other is null) return 1;
        foreach (var comparison in new[] { Major.CompareTo(other.Major), Minor.CompareTo(other.Minor), Patch.CompareTo(other.Patch) })
            if (comparison != 0) return comparison;
        return Preview is null ? (other.Preview is null ? 0 : 1) : other.Preview is null ? -1 : Preview.Value.CompareTo(other.Preview.Value);
    }
    public override string ToString() => $"{Major}.{Minor}.{Patch}" + (Preview is null ? "" : $"-preview.{Preview}");
    public Version FileVersion => new(Major, Minor, Patch, Preview ?? 0);
}

public sealed record UpdatePackage(string Version, string Architecture, bool Portable, string Name, string Url, long Size, string Sha256)
{
    public string Tag => "windows-v" + Version;
    public string InstallerName => $"HeiBan-Setup-{Version}-{Architecture}.exe";
}

public static class UpdatePolicy
{
    public const string Repository = "VirginBear/HeiBan";
    public const long MaxPackageBytes = 512L * 1024 * 1024;
    public static bool ValidHash(string? value) => value is not null && Regex.IsMatch(value, @"\A[a-fA-F0-9]{64}\z", RegexOptions.CultureInvariant);

    public static void Validate(UpdatePackage package)
    {
        if (ReleaseVersion.Parse(package.Version) is null || package.Architecture is not ("x64" or "arm64") ||
            package.Size <= 0 || package.Size > MaxPackageBytes || !ValidHash(package.Sha256))
            throw new InvalidDataException("更新資訊不完整，請改用官方下載。");
        var zip = $"HeiBan-Windows-{(package.Portable ? "Portable" : "Installer")}-{package.Version}-win-{package.Architecture}.zip";
        if (package.Name != zip && (package.Portable || package.Name != package.InstallerName))
            throw new InvalidDataException("更新包與安裝類型不符。");
        if (!Uri.TryCreate(package.Url, UriKind.Absolute, out var uri) || uri.Scheme != "https" || uri.Host != "github.com" ||
            !uri.IsDefaultPort || uri.UserInfo.Length != 0 || uri.Query.Length != 0 || uri.Fragment.Length != 0 ||
            Uri.UnescapeDataString(uri.AbsolutePath) != $"/{Repository}/releases/download/{package.Tag}/{package.Name}")
            throw new InvalidDataException("更新下載位置不是 HeiBan 的 GitHub Release。");
    }

    public static UpdatePackage? Select(JsonElement releases, string currentVersion, string architecture, bool portable, bool includePreview)
    {
        var current = ReleaseVersion.Parse(currentVersion) ?? throw new InvalidDataException("無法判讀目前版本。");
        UpdatePackage? best = null;
        foreach (var release in releases.EnumerateArray())
        {
            if (release.GetProperty("draft").GetBoolean()) continue;
            var tag = release.GetProperty("tag_name").GetString() ?? "";
            if (!tag.StartsWith("windows-v", StringComparison.Ordinal)) continue;
            var versionText = tag[9..];
            var version = ReleaseVersion.Parse(versionText);
            if (version is null || version.CompareTo(current) <= 0 ||
                (!includePreview && (version.Preview is not null || release.GetProperty("prerelease").GetBoolean()))) continue;
            var zipName = $"HeiBan-Windows-{(portable ? "Portable" : "Installer")}-{versionText}-win-{architecture}.zip";
            var exeName = $"HeiBan-Setup-{versionText}-{architecture}.exe";
            // Prefer a directly published installer; the older public ZIP wrapper remains compatible.
            foreach (var asset in release.GetProperty("assets").EnumerateArray().OrderBy(a => a.GetProperty("name").GetString() == exeName ? 0 : 1))
            {
                var name = asset.GetProperty("name").GetString() ?? "";
                if (name != zipName && (portable || name != exeName)) continue;
                var digest = asset.TryGetProperty("digest", out var value) ? value.GetString() : null;
                if (digest is null || !digest.StartsWith("sha256:", StringComparison.Ordinal)) continue;
                var package = new UpdatePackage(versionText, architecture, portable, name,
                    asset.GetProperty("browser_download_url").GetString() ?? "", asset.GetProperty("size").GetInt64(), digest[7..]);
                try { Validate(package); } catch (InvalidDataException) { continue; }
                if (best is null || version.CompareTo(ReleaseVersion.Parse(best.Version)) > 0) best = package;
                break;
            }
        }
        return best;
    }
}

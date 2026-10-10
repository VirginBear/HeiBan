using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;

namespace HeiBan.Windows.Updating;

public sealed record UpdateInventory(string Version, Dictionary<string, string> Files);

public static class UpdateFiles
{
    public const string InventoryName = "update-files.json";
    public static void RequireArchitecture(string executable, string architecture)
    {
        using var reader = new BinaryReader(File.OpenRead(executable));
        if (reader.BaseStream.Length < 64 || reader.ReadUInt16() != 0x5A4D) throw new InvalidDataException("更新程式不是 Windows 執行檔。");
        reader.BaseStream.Position = 0x3C;
        var offset = reader.ReadInt32();
        if (offset < 64 || offset > reader.BaseStream.Length - 6) throw new InvalidDataException("更新程式 PE 標頭無效。");
        reader.BaseStream.Position = offset;
        if (reader.ReadUInt32() != 0x4550 || reader.ReadUInt16() != (architecture == "arm64" ? 0xAA64 : 0x8664))
            throw new InvalidDataException("更新程式處理器架構不符。");
    }
    public static string Relative(string input)
    {
        var path = input.Replace('\\', '/');
        if (path.Length == 0 || path.StartsWith('/') || path.Length > 220) throw new InvalidDataException("更新包路徑不合法。");
        foreach (var part in path.Split('/'))
        {
            var stem = part.Split('.')[0].ToUpperInvariant();
            if (part is "" or "." or ".." || part.EndsWith('.') || part.EndsWith(' ') ||
                part.Any(c => c < 32 || "<>:\"|?*".Contains(c)) || stem is "CON" or "PRN" or "AUX" or "NUL" ||
                (stem.Length == 4 && (stem.StartsWith("COM") || stem.StartsWith("LPT")) && stem[3] is >= '0' and <= '9'))
                throw new InvalidDataException("更新包含不安全的檔案路徑。");
        }
        return path;
    }
    public static string Under(string root, string relative)
    {
        var fullRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        var full = Path.GetFullPath(Path.Combine(fullRoot, Relative(relative)));
        if (!full.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("更新路徑超出目標資料夾。");
        // A junction in an otherwise safe relative path can redirect a write into user data.
        for (var check = Path.GetDirectoryName(full); check is not null; check = Path.GetDirectoryName(check))
        {
            if (Directory.Exists(check) && (File.GetAttributes(check) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("更新路徑不可包含連結或接合點。");
            if (string.Equals(check.TrimEnd(Path.DirectorySeparatorChar), fullRoot.TrimEnd(Path.DirectorySeparatorChar), StringComparison.OrdinalIgnoreCase)) break;
        }
        if (File.Exists(full) && (File.GetAttributes(full) & FileAttributes.ReparsePoint) != 0) throw new IOException("更新檔案不可是連結。");
        return full;
    }
    public static async Task VerifyAsync(string path, long size, string sha256, CancellationToken cancellationToken = default)
    {
        if (!UpdatePolicy.ValidHash(sha256) || new FileInfo(path).Length != size) throw new InvalidDataException("更新包大小不符。");
        await using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        var digest = Convert.ToHexString(await SHA256.HashDataAsync(stream, cancellationToken));
        if (!digest.Equals(sha256, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("更新包 SHA-256 不符。");
    }
    public static void Extract(string zipPath, string destination)
    {
        using var archive = ZipFile.OpenRead(zipPath);
        if (archive.Entries.Count > 10000) throw new InvalidDataException("更新包檔案數過多。");
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        long total = 0;
        foreach (var entry in archive.Entries)
        {
            var path = Relative(entry.FullName.TrimEnd('/', '\\'));
            if (!seen.Add(path) || ((entry.ExternalAttributes >> 16) & 0xF000) == 0xA000 ||
                (entry.ExternalAttributes & (int)FileAttributes.ReparsePoint) != 0)
                throw new InvalidDataException("更新包有重複路徑或連結。");
            total = checked(total + entry.Length);
            if (total > 2L * 1024 * 1024 * 1024) throw new InvalidDataException("更新包解壓後過大。");
            var isDirectory = entry.FullName.EndsWith('/') || entry.FullName.EndsWith('\\');
            if (path.Equals("Data", StringComparison.OrdinalIgnoreCase) || path.StartsWith("Data/", StringComparison.OrdinalIgnoreCase))
            {
                if (!isDirectory) throw new InvalidDataException("更新包不可包含作品資料。");
                continue;
            }
            var target = Under(destination, path);
            if (isDirectory) Directory.CreateDirectory(target);
            else { Directory.CreateDirectory(Path.GetDirectoryName(target)!); entry.ExtractToFile(target, false); }
        }
    }
    public static async Task<UpdateInventory> ReadInventoryAsync(string root, string version)
    {
        var inventory = JsonSerializer.Deserialize<UpdateInventory>(await File.ReadAllTextAsync(Under(root, InventoryName)))
            ?? throw new InvalidDataException("缺少程式檔案清單。");
        if (inventory.Version != version || inventory.Files is null || inventory.Files.Count is 0 or > 10000)
            throw new InvalidDataException("程式清單版本不符。");
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var (path, hash) in inventory.Files)
        {
            var safe = Relative(path);
            if (!seen.Add(safe) || !UpdatePolicy.ValidHash(hash) || safe.Equals("Data", StringComparison.OrdinalIgnoreCase) ||
                safe.StartsWith("Data/", StringComparison.OrdinalIgnoreCase) || safe.Equals("portable.dat", StringComparison.OrdinalIgnoreCase) ||
                safe.Equals(InventoryName, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("程式清單包含禁止更新的資料。");
        }
        foreach (var required in new[] { "HeiBan.exe", "HeiBan.pri", "coreclr.dll", "Updater/HeiBan.Updater.exe" })
            if (!inventory.Files.Keys.Contains(required, StringComparer.OrdinalIgnoreCase)) throw new InvalidDataException("程式清單不完整。");
        return inventory;
    }

    public static async Task ApplyPortableAsync(string targetRoot, string payloadRoot, string backupRoot, string currentVersion, string nextVersion)
    {
        var previous = await ReadInventoryAsync(targetRoot, currentVersion);
        var next = await ReadInventoryAsync(payloadRoot, nextVersion);
        var known = previous.Files.Keys.ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var (path, hash) in previous.Files)
        {
            var existing = Under(targetRoot, path);
            if (Directory.Exists(existing)) throw new IOException("程式檔案位置已成為資料夾，請手動更新。");
            if (File.Exists(existing)) await VerifyAsync(existing, new FileInfo(existing).Length, hash);
        }
        foreach (var (path, hash) in next.Files)
        {
            var source = Under(payloadRoot, path);
            await VerifyAsync(source, new FileInfo(source).Length, hash);
            var target = Under(targetRoot, path);
            if (Directory.Exists(target)) throw new IOException("新版檔案位置已有資料夾，請手動更新。");
            if (File.Exists(target) && !known.Contains(path)) throw new IOException("新版檔案會覆蓋未知檔案，請手動更新。");
        }
        // Preflight every old and new path before moving anything. Data and unknown files are never in this set.
        var paths = previous.Files.Keys.Concat(next.Files.Keys).Append(InventoryName).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        foreach (var path in paths) { Under(targetRoot, path); Under(backupRoot, path); }
        var moved = new List<string>();
        var written = new List<string>();
        try
        {
            foreach (var path in paths)
            {
                var target = Under(targetRoot, path);
                if (!File.Exists(target)) continue;
                var backup = Under(backupRoot, path);
                Directory.CreateDirectory(Path.GetDirectoryName(backup)!); File.Move(target, backup); moved.Add(path);
            }
            foreach (var path in next.Files.Keys.Append(InventoryName))
            {
                var target = Under(targetRoot, path);
                Directory.CreateDirectory(Path.GetDirectoryName(target)!); written.Add(path); File.Copy(Under(payloadRoot, path), target);
            }
        }
        catch
        {
            foreach (var path in written.AsEnumerable().Reverse()) File.Delete(Under(targetRoot, path));
            foreach (var path in moved.AsEnumerable().Reverse()) File.Move(Under(backupRoot, path), Under(targetRoot, path));
            throw;
        }
    }
}

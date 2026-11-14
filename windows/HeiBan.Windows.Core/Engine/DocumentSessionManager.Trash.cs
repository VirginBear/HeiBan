using System.Globalization;
using System.Text.Json;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

public sealed partial class DocumentSessionManager
{
    public const int TrashRetentionDays = 30;
    private const string TrashDateFormat = "yyyyMMdd-HHmmss-ffff";
    private const string CurrentTrashPrefix = "retention-";
    private readonly TimeProvider _timeProvider;
    private string TrashRoot => Path.Combine(DataDirectory, "Trash");

    public async Task TrashAsync(string id)
    {
        using var trashLock = await LockTrashAsync();
        await _gate.WaitAsync();
        try
        {
            var board = BoardPath(id);
            using var boardLock = new FileStream(board + ".lock", FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            if (!File.Exists(board)) return;

            var timestamp = _timeProvider.GetUtcNow().ToString(TrashDateFormat, CultureInfo.InvariantCulture);
            var folder = Path.Combine(TrashRoot, CurrentTrashPrefix + timestamp + "-" + Key(id));
            if (Directory.Exists(folder)) throw new IOException("作品已在垃圾桶，請重新整理。");
            Directory.CreateDirectory(folder);
            foreach (var file in new[] { board, board + ".bak", ThumbnailPath(id), Path.Combine(DataDirectory, "Metadata", Key(id) + ".json") })
                if (File.Exists(file)) File.Move(file, Path.Combine(folder, Path.GetFileName(file)));
        }
        finally { _gate.Release(); }
    }

    public async Task<IReadOnlyList<(string Path, BoardMetadata Board, DateTimeOffset? ExpiresAt)>> RefreshTrashAsync()
    {
        using var trashLock = await LockTrashAsync();
        var now = _timeProvider.GetUtcNow();
        var migrationStart = await ReadTrashMigrationStartAsync(now);
        var entries = new List<(string, BoardMetadata, DateTimeOffset?)>();
        foreach (var folder in new DirectoryInfo(TrashRoot).EnumerateDirectories())
        {
            if (IsLink(folder) || !TryReadTrashFolder(folder.Name, out var key, out var deletedAt, out var legacy)) continue;
            var boardPath = Path.Combine(folder.FullName, key + ".blackboard.json");
            DateTimeOffset? expiresAt = legacy
                ? migrationStart is { } start ? (deletedAt > start ? deletedAt : start).AddDays(TrashRetentionDays) : null
                : deletedAt.AddDays(TrashRetentionDays);
            var boardFile = new FileInfo(boardPath);
            try
            {
                if (IsLink(boardFile)) continue;
                _ = File.GetAttributes(boardPath);
                var document = await ImportAsync(boardPath);
                if (Key(document.Board.Id) != key) continue;
                if (expiresAt <= now && TryPurgeTrashFolder(folder, key)) continue;
                entries.Add((boardPath, document.Board, expiresAt));
            }
            catch (FileNotFoundException)
            {
                // A restored work can leave a backup and thumbnail behind.
                if (expiresAt <= now) TryPurgeTrashFolder(folder, key);
            }
            catch (Exception error) when (error is JsonException or InvalidDataException or NotSupportedException or IOException or UnauthorizedAccessException)
            {
                // An unreadable entry is retained for recovery or a future refresh.
            }
        }
        return entries;
    }

    public async Task RestoreAsync(string trashPath)
    {
        using var trashLock = await LockTrashAsync();
        var (folder, key) = ResolveTrashEntry(trashPath);
        var doc = await ImportAsync(Path.Combine(folder.FullName, key + ".blackboard.json"));
        if (Key(doc.Board.Id) != key) throw new InvalidDataException("無效的垃圾桶檔案。");
        await SaveCoreAsync(doc, false, CancellationToken.None, requireNew: true);
        var oldThumbnail = Path.Combine(folder.FullName, key + ".png");
        if (File.Exists(oldThumbnail) && !IsLink(new FileInfo(oldThumbnail)))
        {
            try { File.Copy(oldThumbnail, ThumbnailPath(doc.Board.Id), true); }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException) { }
        }
        File.Delete(Path.Combine(folder.FullName, key + ".blackboard.json")); // Keep the existing backup behavior after a restore.
    }

    public async Task DeleteTrashEntryAsync(string trashPath)
    {
        using var trashLock = await LockTrashAsync();
        var (folder, key) = ResolveTrashEntry(trashPath);
        PurgeTrashFolder(folder, key);
    }

    private async Task<FileStream> LockTrashAsync()
    {
        if (IsLink(new DirectoryInfo(TrashRoot))) throw new IOException("無效的垃圾桶資料夾。");
        var path = Path.Combine(TrashRoot, ".lock");
        if (IsLink(new FileInfo(path))) throw new IOException("無效的垃圾桶鎖定檔。");
        for (var attempt = 0; ; attempt++)
        {
            try { return new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
            catch (IOException error) when (attempt < 20 && (error.HResult & 0xffff) is 32 or 33)
            {
                await Task.Delay(50);
            }
        }
    }

    private async Task<DateTimeOffset?> ReadTrashMigrationStartAsync(DateTimeOffset now)
    {
        var path = Path.Combine(TrashRoot, ".retention-start");
        if (IsLink(new FileInfo(path))) return null;
        try
        {
            if (!File.Exists(path))
                await WriteAtomicAsync(path, now.ToString("O", CultureInfo.InvariantCulture));
            return DateTimeOffset.TryParseExact(await File.ReadAllTextAsync(path), "O", CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var value) && value <= now && value.Year < 9999 ? value : null;
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            return null; // Without a durable start date, old items stay recoverable.
        }
    }

    private (DirectoryInfo Folder, string Key) ResolveTrashEntry(string trashPath)
    {
        var fullPath = Path.GetFullPath(trashPath);
        var folder = new DirectoryInfo(Path.GetDirectoryName(fullPath)!);
        if (!string.Equals(folder.Parent?.FullName, Path.GetFullPath(TrashRoot), StringComparison.OrdinalIgnoreCase)
            || !TryReadTrashFolder(folder.Name, out var key, out _, out _)
            || Path.GetFileName(fullPath) != key + ".blackboard.json"
            || IsLink(folder) || IsLink(new FileInfo(fullPath)))
            throw new InvalidDataException("無效的垃圾桶檔案。");
        if (!File.Exists(fullPath)) throw new FileNotFoundException("找不到垃圾桶中的作品。", fullPath);
        return (folder, key);
    }

    private static bool TryReadTrashFolder(string name, out string key, out DateTimeOffset deletedAt, out bool legacy)
    {
        legacy = !name.StartsWith(CurrentTrashPrefix, StringComparison.Ordinal);
        var entry = legacy ? name : name[CurrentTrashPrefix.Length..];
        var separator = entry.LastIndexOf('-');
        key = separator < 0 ? "" : entry[(separator + 1)..];
        deletedAt = default;
        if (key.Length != 64 || !key.All(c => c is >= '0' and <= '9' or >= 'a' and <= 'f')) return false;
        var timestamp = entry.AsSpan(0, separator);
        // Older builds used the Windows culture for the folder date. Only new dates drive expiration directly.
        var parsed = DateTimeOffset.TryParseExact(timestamp, TrashDateFormat, CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal, out deletedAt) && deletedAt.Year < 9999;
        if (!parsed) deletedAt = default;
        return legacy ? timestamp.Length == 20 && timestamp[8] == '-' && timestamp[15] == '-' : parsed;
    }

    private static bool IsLink(FileSystemInfo item) => item.LinkTarget is not null
        || (item.Exists && (item.Attributes & FileAttributes.ReparsePoint) != 0);

    private static bool TryPurgeTrashFolder(DirectoryInfo folder, string key)
    {
        try { PurgeTrashFolder(folder, key); return true; }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException) { return false; }
    }

    private static void PurgeTrashFolder(DirectoryInfo folder, string key)
    {
        var boardName = key + ".blackboard.json";
        // Validate all known files before deleting any. Keep the editable board until last so a failed cleanup can retry.
        var files = new[] { boardName + ".bak", key + ".png", key + ".json", boardName }
            .Select(name => new FileInfo(Path.Combine(folder.FullName, name))).ToArray();
        if (IsLink(folder) || files.Any(IsLink)) throw new IOException("垃圾桶項目包含連結。");
        foreach (var file in files) file.Delete();
        if (!folder.EnumerateFileSystemInfos().Any()) folder.Delete();
    }
}

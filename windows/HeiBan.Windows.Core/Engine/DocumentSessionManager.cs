using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>All application-owned data uses one explicit root; portable mode never falls back to AppData.</summary>
public sealed class DocumentSessionManager
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    public string DataDirectory { get; }
    public bool IsPortableMode { get; }
    public DocumentSessionManager(string? executableDirectory = null)
    {
        var exe = executableDirectory ?? AppContext.BaseDirectory;
        IsPortableMode = File.Exists(Path.Combine(exe, "portable.dat"));
        var isolated = Environment.GetEnvironmentVariable("HEIBAN_WINDOWS_DATA_DIRECTORY");
        DataDirectory = !string.IsNullOrWhiteSpace(isolated) ? Path.GetFullPath(isolated) : IsPortableMode
            ? Path.Combine(exe, "Data")
            : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "HeiBan", "Windows");
        foreach (var name in new[] { "Boards", "Metadata", "Thumbnails", "Trash", "Settings" })
            Directory.CreateDirectory(Path.Combine(DataDirectory, name));
    }
    public string BoardPath(string id) => Path.Combine(DataDirectory, "Boards", Key(id) + ".blackboard.json");
    public string ThumbnailPath(string id) => Path.Combine(DataDirectory, "Thumbnails", Key(id) + ".png");
    private static string Key(string id) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(id))).ToLowerInvariant();
    public Task SaveAsync(HeiBanDocument document,CancellationToken cancellationToken=default)
        =>SaveCoreAsync(document,false,cancellationToken);
    /// <summary>The caller must not read or mutate this isolated snapshot until the task finishes.</summary>
    public Task SaveOwnedSnapshotAsync(HeiBanDocument snapshot,CancellationToken cancellationToken=default)
        =>SaveCoreAsync(snapshot,true,cancellationToken);
    private async Task SaveCoreAsync(HeiBanDocument snapshot,bool owned,CancellationToken cancellationToken)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            var path = BoardPath(snapshot.Board.Id);
            // A lock shared across processes also prevents concurrent saves by two app instances.
            using var fileLock = new FileStream(path + ".lock", FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            if (File.Exists(path))
            {
                var disk = DocumentCodec.Decode(await File.ReadAllTextAsync(path, cancellationToken));
                if (disk.Board.Revision > snapshot.Board.Revision)
                    throw new IOException("磁碟上的黑板較新；請重新開啟，或匯出副本以保留目前內容。");
            }
            var next = owned ? snapshot : DocumentCodec.Clone(snapshot);
            var previousBoard=next.Board;var previousExported=next.ExportedAt;
            next.Board=DocumentCodec.Clone(previousBoard);next.Board.Revision++;
            next.Board.UpdatedAt=next.ExportedAt=DateTime.UtcNow.ToString("o");next.Board.ItemCount=next.Objects.Count;
            try{await WriteAtomicAsync(path,DocumentCodec.Encode(next),cancellationToken);}
            catch{next.Board=previousBoard;next.ExportedAt=previousExported;throw;}
            snapshot.Board.Revision = next.Board.Revision;
            snapshot.Board.UpdatedAt = next.Board.UpdatedAt;
            // Metadata is recoverable derived data. The board remains the source of truth.
            await WriteAtomicAsync(Path.Combine(DataDirectory, "Metadata", Key(next.Board.Id) + ".json"),
                JsonSerializer.Serialize(next.Board, DocumentCodec.Options), cancellationToken);
        }
        finally { _gate.Release(); }
    }
    public Task<HeiBanDocument> LoadAsync(string id) => ImportAsync(BoardPath(id));
    public async Task<HeiBanDocument> ImportAsync(string path) { var json=await File.ReadAllTextAsync(path);return await Task.Run(()=>DocumentCodec.Decode(json)); }
    public async Task<IReadOnlyList<BoardMetadata>> ListAsync()
    {
        // Only read small metadata files on the normal home screen path.
        var result = new List<BoardMetadata>();
        foreach (var file in Directory.EnumerateFiles(Path.Combine(DataDirectory, "Metadata"), "*.json"))
        {
            var board = JsonSerializer.Deserialize<BoardMetadata>(await File.ReadAllTextAsync(file), DocumentCodec.Options);
            if (board is not null && File.Exists(BoardPath(board.Id))) result.Add(board);
        }
        // Recover missing index entries after an interrupted save, without overwriting any board.
        var known = result.Select(b => BoardPath(b.Id)).ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var file in Directory.EnumerateFiles(Path.Combine(DataDirectory, "Boards"), "*.blackboard.json"))
        {
            if (known.Contains(file)) continue;
            var board = (await ImportAsync(file)).Board;
            await WriteAtomicAsync(Path.Combine(DataDirectory, "Metadata", Key(board.Id) + ".json"),
                JsonSerializer.Serialize(board, DocumentCodec.Options));
            result.Add(board);
        }
        return result.OrderByDescending(b => b.UpdatedAt).ToList();
    }
    public async Task TrashAsync(string id)
    {
        await _gate.WaitAsync();
        try
        {
            var folder = Path.Combine(DataDirectory, "Trash", DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-ffff") + "-" + Key(id));
            Directory.CreateDirectory(folder);
            foreach (var file in new[] { BoardPath(id), BoardPath(id) + ".bak", ThumbnailPath(id),
                Path.Combine(DataDirectory, "Metadata", Key(id) + ".json") })
                if (File.Exists(file)) File.Move(file, Path.Combine(folder, Path.GetFileName(file)));
        }
        finally { _gate.Release(); }
    }
    public IEnumerable<(string Path, string Title)> TrashedBoards()
        =>TrashedBoardEntries().Select(entry=>(entry.Path,entry.Board.Title));
    public IEnumerable<(string Path, BoardMetadata Board)> TrashedBoardEntries()
    {
        foreach (var file in Directory.EnumerateFiles(Path.Combine(DataDirectory,"Trash"),"*.blackboard.json",SearchOption.AllDirectories))
        {
            HeiBanDocument doc;
            try { doc=DocumentCodec.Decode(File.ReadAllText(file)); }
            catch (Exception e) when (e is JsonException or InvalidDataException or NotSupportedException) { continue; }
            yield return (file,doc.Board);
        }
    }
    public async Task RestoreAsync(string trashPath)
    {
        var root=Path.GetFullPath(Path.Combine(DataDirectory,"Trash"))+Path.DirectorySeparatorChar;
        if(!Path.GetFullPath(trashPath).StartsWith(root,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("無效的垃圾桶檔案。");
        var doc=await ImportAsync(trashPath);
        if(File.Exists(BoardPath(doc.Board.Id)))throw new IOException("作品庫已有同名識別碼；先另存副本再還原。");
        await SaveAsync(doc);
        var folder=Path.GetDirectoryName(trashPath)!;
        var oldThumbnail=Path.Combine(folder,Path.GetFileName(ThumbnailPath(doc.Board.Id)));
        if(File.Exists(oldThumbnail))File.Copy(oldThumbnail,ThumbnailPath(doc.Board.Id),true);
        File.Delete(trashPath); // A restored copy now lives in Boards; retained backups remain in Trash.
    }
    public static async Task WriteAtomicAsync(string path, string content, CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            await using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 65536, true))
            {
                var bytes = Encoding.UTF8.GetBytes(content);
                await stream.WriteAsync(bytes, cancellationToken);
                await stream.FlushAsync(cancellationToken);
                stream.Flush(flushToDisk: true);
            }
            if (File.Exists(path)) File.Replace(temporary, path, path + ".bak");
            else File.Move(temporary, path);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}

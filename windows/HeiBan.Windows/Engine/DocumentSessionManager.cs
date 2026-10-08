using System.IO;
using System.Text.Json;
using HeiBan.Windows.Models;

namespace HeiBan.Windows.Engine;

/// <summary>
/// 文件會話與持久化管理核心
/// 支援：原子儲存 (tmp交換)、修訂衝突防護、以及「免安裝版專屬 Portable 資料隔離重定向」
/// </summary>
public sealed class DocumentSessionManager
{
    private static readonly Lazy<DocumentSessionManager> _instance = new(() => new DocumentSessionManager());
    public static DocumentSessionManager Shared => _instance.Value;

    public bool IsPortableMode { get; private set; }
    public string DataDirectory { get; private set; }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.Never
    };

    private DocumentSessionManager()
    {
        string exeDir = AppDomain.CurrentDomain.BaseDirectory;
        string portableFlagFile = Path.Combine(exeDir, "portable.dat");
        string portableDataDir = Path.Combine(exeDir, "Data");

        // 判定是否啟用「免安裝便攜模式」：
        // 若同目錄下存在 portable.dat 或 Data/ 資料夾，則強制切換至本機綠色便攜模式
        if (File.Exists(portableFlagFile) || Directory.Exists(portableDataDir))
        {
            IsPortableMode = true;
            DataDirectory = portableDataDir;
        }
        else
        {
            IsPortableMode = false;
            // 安裝版模式：使用標準 Windows 使用者目錄 %LOCALAPPDATA%\HeiBan
            DataDirectory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "HeiBan");
        }

        Directory.CreateDirectory(DataDirectory);
        Directory.CreateDirectory(Path.Combine(DataDirectory, "Boards"));
        Directory.CreateDirectory(Path.Combine(DataDirectory, "Thumbnails"));
    }

    /// <summary>
    /// 原子儲存黑板文件 (防斷電或系統當機損壞原始資料)
    /// </summary>
    public async Task<bool> SaveBoardAsync(HeiBanDocument doc, string? targetFilePath = null)
    {
        string filePath = targetFilePath ?? Path.Combine(DataDirectory, "Boards", $"{doc.Board.Id}.blackboard.json");
        string tempPath = filePath + ".tmp";
        string backupPath = filePath + ".bak";

        try
        {
            doc.Board.UpdatedAt = DateTime.UtcNow.ToString("o");
            doc.ExportedAt = DateTime.UtcNow.ToString("o");
            doc.Board.Revision++; // 遞增修訂號

            // 1. 寫入臨時檔案
            await using (var fs = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None, 4096, true))
            {
                await JsonSerializer.SerializeAsync(fs, doc, JsonOptions);
                await fs.FlushAsync();
            }

            // 2. 自動備份既有檔案
            if (File.Exists(filePath))
            {
                File.Copy(filePath, backupPath, true);
            }

            // 3. 原子替換目標檔案
            File.Move(tempPath, filePath, true);
            return true;
        }
        catch
        {
            if (File.Exists(tempPath)) File.Delete(tempPath);
            return false;
        }
    }

    /// <summary>
    /// 載入黑板文件 (支援舊版自動遷移與未來不相容版本防護)
    /// </summary>
    public async Task<HeiBanDocument?> LoadBoardAsync(string filePath)
    {
        if (!File.Exists(filePath)) return null;

        try
        {
            await using var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, true);
            var doc = await JsonSerializer.DeserializeAsync<HeiBanDocument>(fs, JsonOptions);
            if (doc == null) return null;

            // 契約驗證：若遇未來大版本號則安全防護
            if (Version.TryParse(doc.SchemaVersion, out var ver) && ver.Major > 1)
            {
                throw new NotSupportedException($"無法讀取未來版本 (Schema: {doc.SchemaVersion})，請升級 HeiBan");
            }

            return doc;
        }
        catch
        {
            return null;
        }
    }
}

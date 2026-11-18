# Windows 1.1.6 長圖與解析度適應

開工核對平台文件並保留既有三份修改及三份未追蹤文件。使用者暫定 1.1.6，要求修正圖片拖放與貼上，以及新增右鍵解析度適應。附件只用於本機驗證。

程式追蹤確認原本檔案與剪貼簿均先呼叫 CanvasBitmap.LoadAsync 才計算畫布擺放，頁面渲染也直接建立原尺寸點陣圖。附件 PNG 高 18,382 像素，原始尺寸可能超過 GPU 裝置的單邊限制。改為讀取編碼資料及像素尺寸，再依裝置上限及 1,600 萬像素預算解碼預覽。顯式縮減以單次復原交易處理，原圖像素座標中的裁切範圍同步等比轉換，文件 schema 無變更。

## 實作與檢查

- `MainWindow.Input.cs` 與 `MainWindow.ImageResolution.cs` 共用檔案、拖放與剪貼簿點陣圖的匯入路徑。採用編碼內容判斷 PNG、JPEG、GIF、TIFF 和 BMP，保留其資料。DPI／Zoom 不再影響能否匯入，初始擺放仍沿用 `ImagePlacementMath`。切換頁面、預備關閉或進入唯讀時放棄尚未完成的置入。
- `Engine/CanvasImageDecoding.cs` 在需要時先縮減預覽像素。`Direct2DCanvasRenderer.cs` 將原始裁切範圍映射至預覽像素。右鍵「解析度適應」依固定頁面尺寸或無邊界視窗大小等比縮減像素，保留外框、角度、翻轉與圖層。以 PNG 保留透明度，JPEG 續用 JPEG。這項指令會更新作品內的圖檔，可復原。未改動使用者磁碟上的來源檔。
- 更新 Windows 開發 metadata 至 1.1.6／1.1.6.0，以及十種語言的介面與圖片使用說明。介面與指南分別執行 `python windows/scripts/Build-LocalizationCatalogs.py`、`python windows/scripts/Build-UserGuides.py`，十語系共 738 個介面鍵、無缺漏，每語系指南 26 章。
- `dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release --artifacts-path …/core` 通過 6,903 項。`dotnet build windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 --artifacts-path …/app -p:Platform=x64 -p:WindowsPackageType=None -p:HeiBanValidationBuild=true` 成功，0 警告、0 錯誤。
- 用 `--release-validation-output`、`--release-validation-exit` 及隔離資料路徑啟動 WinUI 驗證。原始 PNG 是 3840 × 18382，Win2D 裝置上限 16384，舊載入方法實測被拒。檔案及點陣圖兩種資料格式均可貼進 400 × 300 畫布且渲染出可見像素；適應後是 62 × 300，裁切、幾何與翻轉通過檢查，Undo 回復來源、Redo 後序列化重開仍可渲染。測試直接使用 DataPackageView，未操作 Explorer 拖曳手勢、系統剪貼簿或右鍵選單。原圖只供本機驗證。

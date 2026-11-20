# Windows 開發與驗證入口

每批先從 CURRENT_STATUS 與當批日誌找版本、目前試用、使用者回報及未驗收項目。修改涉及哪個使用者入口，就沿下表找到宿主及共用核心。

| 使用者操作 | 宿主與共用實作 | 必須確認的結果 |
| --- | --- | --- |
| 畫筆連續繪製 | MainWindow.Input、WindowsInkCoordinator、Direct2DCanvasRenderer.WetInk | 保留全部採樣、轉角跟隨，放開只提交一筆復原 |
| 螢幕畫布繪製 | ScreenAnnotationWindow.OnPointerCore、共用 renderer | 實體像素與 DIP 正確換算，切模式及取消不留下預覽 |
| 選取、拖動與框選 | MainWindow.ObjectDrag、共用 ObjectHandles／PointSelection／WindowSelection／EditorSession | 預覽不逐步改寫永久點資料，重疊次序與 Ctrl 多選保留 |
| 擦除與板擦 | CircularEraserGesture、BoardEraserWork、EraserPreviewPublisher | worker 持有隔離資料，取消不提交，放開一筆復原 |
| 圖片拖放、貼上及載入 | MainWindow.ImageResolution、ScreenAnnotationWindow.Chrome、CanvasImageDecoding | 方向、比例、透明度與裁切正確，長圖可顯示 |
| 文字及便條紙 | MainWindow.Text、ScreenAnnotationWindow.Text、TextDraftEditor | 局部格式與 IME 可用，重開編輯不還原預設樣式 |
| 保存、垃圾桶及恢復 | DocumentSessionManager、DocumentSessionManager.Trash、MainWindow.Saving | 保存失敗可重試，舊資料及未知欄位保留 |
| 工具列與輪盤 | ToolbarPreferences、ToolbarContentPolicy、ToolbarUi、兩宿主 | 共用顯示政策，控制項由各視窗持有，固定工具與偏好遷移正確 |

## 可重跑的驗證

在 repository 根目錄以 PowerShell 7 執行。需要 .NET 10 SDK 與 Python 3。原生測試需要可用的 Windows 桌面。

```powershell
./windows/scripts/Verify-Development.ps1
./windows/scripts/Verify-Development.ps1 -IncludeNative
```

可用 -OutputDirectory 指定新的證據目錄。預設在 windows/.build 以唯一目錄保存每輪結果。入口依序檢查 C# 架構政策、介面目錄、操作指南、核心行為及最佳化對照。IncludeNative 另編譯 x64 驗證版本，在兩份隔離資料中執行文字／工具／螢幕及合成長圖／方向檢查。

verification.json 記錄本次命令結果、執行環境、來源 commit、來源清單與未驗證範圍。sources.json 是實際工作樹的程式與資源雜湊，包含未提交來源。驗證期間來源有變動會失敗，須以新目錄重跑。程序正常結束後仍須有成功結果檔，不能沿用前輪證據。

介面或手冊改動時，先修改對應 authoring 檔，再執行 Build-LocalizationCatalogs.py 或 Build-UserGuides.py 產生資源。兩工具的 --check 只核對輸出是否最新，CI 使用此模式。

## 架構政策的邊界

HeiBan.Windows.ArchitectureChecks 使用 SDK 內 Roslyn 解析語法。HB001 保持 Core 與 UI 的依賴方向，HB002 攔截指定的同步等待及強制 GC，HB003 禁止產品新增直接把使用者影像載入 GPU 的路徑，HB004 保護已指定的高頻採樣函式，HB005 核對版本與商店身分。程式內有違規、合法及字串／註解案例，用來檢查政策本身。

這些規則涵蓋指定語法及入口。間接呼叫、別名等價寫法、完整事件轉移與真實硬體延遲仍須透過程式審查、原生測試與實機採樣核對。新增入口時，優先重用共用 API，再根據實際回歸補規則或測試。

## 交付與實機驗收

GitHub 的 Windows workflow 在 push main、Windows PR 或手動啟動時跑共用檢查，成功後才製作兩架構產物。雲端 GUI 測試不包含在此流程，CI 完成狀態應從該次 run 核對。

封裝試用時附上來源、ZIP 及產物雜湊。使用者作品接續需在正常保存並關閉後進行。Store 版號及提交沿用使用者當次指示。

繪圖流暢度使用 Collect-InputLatency.ps1 的採樣，並記錄顯示器刷新率、DPI、畫布物件量、工具與冷／熱啟動。需要對照輸入到呈現的延遲和轉角偏差。候選查詢次數、核心斷言數或編譯成功都不足以代表使用者感受到的延遲。

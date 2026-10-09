# Windows 截圖自動置入畫布調整計劃

**最新接手入口**：[Windows 開發計劃 W-N00b/c](WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md)。後續已有狀態機、解碼後情境檢查與單一等比排版；本頁保留原計劃紀錄。結果來源、Processing逾時與成功提示仍需補缺，不能用舊項目或舊測試數字當作目前 Windows 驗收。

日期：2026-10-09（Asia/Taipei）。狀態：**程式已接入；先前交付記錄回報核心測試通過。2026-10-09 原始碼審查仍有待修正項目，Windows 截圖實機驗收與新版封裝未確認完成。**

## 目標與現況

點程式工具列的截圖按鈕，完成 Windows 框選後，截圖直接成為目前畫布的一個圖片物件，自動選取，可移動、縮放、旋轉、復原及保存；不用找截圖檔案，也不用再按 Ctrl+V。

本輪已完成以下四項架構重構與實作：
1. **抽離統一圖片置入入口 (`ApplyImageInsertionAsync`)**：
   - 截圖串流、剪貼簿 Ctrl+V（Bitmap 與 StorageItems）、選檔 (`Image_Click`) 及拖入 (`DrawingArea_Drop`) 全部收斂至同一置入管線。
   - 自動依當前視角與頁面邊界進行等比縮放（保持原圖長寬比，原始解析度寫入 `OriginalWidth`/`OriginalHeight`）。
   - 一次置入嚴格保證僅產生一筆 Undo 交易。
   - 置入後自動切換至選取工具 (`select`)，選取框與 8 個縮放把手 + 1 個旋轉把手立即可用。
2. **獨立一次性截圖工作階段協調器 (`ScreenshotCaptureCoordinator`)**：
   - 負責管理截圖請求生命週期 (`BeginCapture` -> `CanAcceptResult` -> `Complete` / `Cancel`)。
   - 嚴格綁定請求 ID、作品 ID、頁面 ID、啟動當下畫布視野中心座標 (`TargetCenter`) 與啟動前系統剪貼簿版號 (`BaselineClipboardSequence`)。
   - 支援 60 秒逾時保護與情境變更主動撤銷 (`InvalidateIfContextChanged`)。
3. **P/Invoke `GetClipboardSequenceNumber` 與防誤判機制**：
   - 透過 Win32 `user32.dll!GetClipboardSequenceNumber` 進行零成本版號比對。
   - 若剪貼簿版號未變更（如使用者按 Esc 取消剪取），系統不讀取舊剪貼簿圖片，排除版號未變更的舊圖；尚不能證明新圖片來自本次截圖。
   - 核心的明確取消會撤銷請求；外部剪取工具取消辨識及取消後複製圖片仍須修正與實機驗證。
4. **生命週期與多重清理**：
   - 視窗啟動 (`Activated`) 即時檢查結果，搭配短週期的 `_screenshotWatchTimer` (250ms) 監聽。
   - 在作品切換 (`OpenAsync` / `Home_Click` / `New_Click` / `Import_Click`)、頁面切換 (`AddPage_Click` / `SwitchPage`)、視窗關閉 (`Closing` / `Closed`) 及按下 Esc 鍵時，一律立即停止監聽並撤銷請求，防跨板/跨頁污染。

## 主要修改位置

- `windows/HeiBan.Windows.Core/Engine/ScreenshotCaptureCoordinator.cs`：一次性請求、結果接收、取消、情境驗證與去重。
- `windows/HeiBan.Windows/MainWindow.Input.cs`：
  - P/Invoke `GetClipboardSequenceNumber`。
  - `Screenshot_Click` 啟動截圖工作階段。
  - `MainWindow_Activated` 與 `OnScreenshotWatchTickAsync` 驅動結果檢驗。
  - `TryConsumeScreenshotResultAsync` 安全消費結果。
  - `InsertImageStreamAsync`、`InsertImageFileAsync`、`ApplyImageInsertionAsync` 統一圖片置入入口。
- `windows/HeiBan.Windows/MainWindow.xaml.cs`：
  - 視窗啟用、關閉、計時器初始化。
  - 作品切換與分頁切換時清理工作階段。
- `windows/HeiBan.Windows.Core.Tests/Program.cs`：
  - 涵蓋請求建立、重複啟動阻擋、舊版號防誤判、情境不符阻擋、單次去重消費、手動取消、情境切換撤銷與逾時失效等完整單元驗收斷言。

## 驗收斷言與回歸狀態

1. **Windows 核心互動幾何與截圖協調器** (`windows/HeiBan.Windows.Core.Tests/Program.cs`)：
   - 全部通過，驗證截圖協調器在各種邊界狀態下的確定性行為。
2. **Web 既有功能契約檢驗** (`pnpm run check`)：
   - 355 項標準化斷言全部通過，零回歸。
3. **macOS 既有功能契約檢驗** (`swift run HeiBanTestRunner`)：
   - 1,224 項標準化斷言全部通過，零回歸。
4. **架構獨立性**：
   - `windows/` 完全獨立於 `macos/` 與 `src/`，無任何跨架構耦合。

## 2026-10-09 審查補充

最新 Windows 執行計劃與封裝前必修項見 [Antigravity 工作計劃](ANTIGRAVITY_UI_PLAN_2026-10-09.zh-TW.md)。目前約 2.5 秒可見性取消判定、非同步解碼後切作品、逾時分支與細長圖片比例需修正；剪貼簿版號不能單獨證明截圖來源。上面的測試結果為先前文件回報，本次沒有重跑，不代表這些 WinUI 邊界已通過。

## 本輪封裝清理

保留最新 preview.4 的 x64／ARM64 安裝版、免安裝 ZIP 與 SHA-256。清除專案及 Windows 建置副本中 preview.1–preview.3 的舊安裝檔、ZIP 與 SHA-256；保留歷史建置紀錄。已解壓的程式資料夾與其中的 `Data`／作品不在清除範圍。
清理結果：專案移除 24 個舊包／雜湊檔，Windows 建置副本移除 32 個，合計釋放約 2.06 GiB。最新四個 preview.4 發行檔及其雜湊已核對保留。

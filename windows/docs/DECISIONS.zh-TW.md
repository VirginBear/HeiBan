# Windows 開發決策

## 2026-10-09 — 螢幕畫布入口

依使用者追加要求，W-S01採右上導覽列獨立螢幕圖示，位於閱讀／編輯與圖釘之間；首頁提供完整名稱按鈕，工具列更多提供同一命令。入口隨既有導覽收合，不擴大常駐工具列；共用一個螢幕註記session。首頁無作品啟動與作品綁定截圖回貼分別定義目標流程。此輪只補實作規格，透明視窗／功能／入口尚未接程式；preview.5狀態不變。


## 2026-10-09 — preview.5 自有截圖與試用封裝

- 使用者授權直接交付可在模擬機試用的版本；更版為0.1.0-preview.5。保留舊作品與既有封裝，不執行第2～5批。
- 截圖採獨立Win32區域框選與GDI桌面快照，回傳記憶體BMP給既有圖片解碼／Undo流程；不寫截圖資料夾、不用全域剪貼簿版號推斷來源。框選UI不進入裁切結果。
- 請求綁定文件、頁面與視野中心；切文件、翻頁、首頁、Esc、關閉及逾時取消原生框選。舊請求只清除自己的watcher與取消源。
- 圓規調半徑把手改為半徑65%處，鎖定後停用，讓筆尖可被命中；arc端點先於resize命中，角度以先前端點展開並保持掃弧方向。
- PowerShell封裝腳本保存UTF-8 BOM，兼容Windows PowerShell5.1與pwsh7的中文解析。


## 2026-10-09 — 以最新來源分批開發

- 最新主計劃為 [WINDOWS_DEVELOPMENT_PLAN](WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md)。舊W-V計劃／交付報告保留歷史，不再限制新正式工具的範圍。
- 延用 [現行原生架構](ARCHITECTURE.zh-TW.md)，Windows／Mac／Web 程式、資源、產物分開。Mac1.0.8提供操作及文件語意參考，無共享Swift實作。
- 第0批先修目前來源及原需求；每批可交付本機版本，不等待雲端完成。Antigravity做程式，Codex在使用者交回後審查／Windows驗收／封裝。
- 永久內容、暫態預覽、工作區狀態分離；新增模組與schema先定邊界，工具有UI／建置／互動證據才算交付。計算機／計時tick不修改作品，雷射／HUD不持久化。
- 截圖目標為直接插入可編輯圖片；剪貼簿版號僅證明有變動，結果來源需要可辨識的請求。App自有擷取可作必要替代，具體Windows API選擇待實作時驗證。
- 透明螢幕畫布是獨立session與恢復資料，共用工具／renderer，保留真實底層操作；不能用靜止截圖代替。
- 資產引用與差異歷史為後續規劃，尚未遷移現有嵌入格式；任何實作先保全原圖、未知欄位與可攜性。
- 本輪不更版、不更改依賴、不封裝、不清理產物。計劃決定不表示相應程式已落地。

## 2026-10-09 — 第 0 批修復與第 1 批實作決策

- **WinUI 型別契約解耦**：C# 語法規定 `??` 兩側必須有一方可隱式轉換至另一方。為徹底防止 WinUI 3 中 `Button` 與 `StackPanel` 混用引發 CS0019 編譯錯誤，全域以 `GetToolAnchor(key) => _toolButtons.TryGetValue(key, out var btn) ? btn : (FrameworkElement)Tools` 統一收斂；`MenuFlyoutItem.Icon` 統一使用 `ToolIcons.CreateIcon(name)` 返回合法 `PathIcon`（`IconElement`）。
- **選取快速列渲染解耦**：繪製與 UI 控制項完全分離，嚴禁在 `CanvasSurface_Draw` 中重新排隊清空重建按鈕；分立 `RebuildSelectionBar`（僅選取對象改變時觸發）與 `UpdateSelectionBarPosition`（移動/旋轉/縮放時僅平移 Transform），徹底解決拉動 Slider / 開啟 Flyout 時被 60fps 繪圖回調強制關閉的問題。
- **截圖非同步安全狀態機**：`ScreenshotCaptureCoordinator.State` 改為純讀取屬性，逾時由 watch tick 推進，消除狀態突變副作用；以 `BeginProcessing` 守護多階段解碼；`CancelIfMatching` 防止舊請求例外誤殺新請求；置入方法回傳 `bool`，真正寫入文件才發布成功狀態。
- **圓規與 arc 資料模型相容**：Mac 與 Windows 統一採 `type: "arc"`，並將 `ArcRadius`、`ArcStartAngle`、`ArcSweepAngle` 作為第一公民具名欄位，支持 Direct2D 開口圓弧路徑與整圓退回繪製，並全面納入橡皮擦與包圍盒計算。
- **工具偏好與自訂排序**：工具偏好儲存使用使用者自訂順序；`ShowCustomizeToolbarDialog` 具備 ↑/↓ 排序與 CheckBox 顯示切換，精簡工具列預設 8 項，新工具預設收納至「更多」，保全使用者排版習慣。


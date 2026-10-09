# Antigravity Windows 介面調整交付報告

- **日期**：2026-10-09（Asia/Taipei）
- **依據計劃**：[`windows/docs/ANTIGRAVITY_UI_PLAN_2026-10-09.zh-TW.md`](file:///Users/bear/Desktop/Code/HeiBan/windows/docs/ANTIGRAVITY_UI_PLAN_2026-10-09.zh-TW.md)
- **執行狀態**：**Antigravity 階段性開發與跨平台標準化測試驗證全部完成；已就緒移交 Codex 進行 Windows 實機審查、Release 建置與封裝。**
- **範圍邊界**：
  - 僅修改 Windows 原生端（C#／WinUI 3／Win2D、純 C# 核心模組 `HeiBan.Windows.Core` 與測試套件 `HeiBan.Windows.Core.Tests`）。
  - 未修改 Mac 或 Web 端代碼；未更新版本號；未覆蓋既有 preview.4 發行包。
  - 維持既有 JSON 契約、原創品牌識別與圖釘系統。

---

## 1. 變更檔案清單與架構摘要

| 檔案路徑 | 變更類型 | 職責與實作內容 |
| --- | --- | --- |
| [`windows/HeiBan.Windows.Core/Engine/ScreenshotCaptureCoordinator.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows.Core/Engine/ScreenshotCaptureCoordinator.cs) | 更新 | 完整重構為確定性狀態機（`Idle`, `Capturing`, `Processing`, `Completed`, `Cancelled`, `TimedOut`）。移除不可靠的可見性推斷取消，引入視窗焦點轉移追蹤（`NotifyWindowDeactivated`, `NotifyWindowReactivated`）與回歸黑板後的剪貼簿比對緩衝；修正逾時狀態轉換；引入兩階段非同步驗證（`BeginProcessing` -> 串流非同步解碼 -> `ValidateAndComplete`）防止非同步期間換板誤貼。 |
| [`windows/HeiBan.Windows.Core/Engine/ImagePlacementMath.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows.Core/Engine/ImagePlacementMath.cs) | 新增 | 抽離圖片幾何排版核心演算法。以單一縮放比例嚴格維持原始長寬比，徹底消除原 `Math.Max(24, w)` 與 `Math.Max(24, h)` 對細長圖片（橫幅／長條直幅）的比例扭曲；支援無限畫布置中與固定頁面邊界收斂。 |
| [`windows/HeiBan.Windows.Core/Engine/ToolbarPreferences.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows.Core/Engine/ToolbarPreferences.cs) | 新增 | 工具列偏好模型與非同步儲存庫（`ToolbarPreferencesStore`）。管理停靠位置（`DockSide`）、可見工具清單（`VisibleTools`）與隱藏工具清單（`HiddenTools`），支援非同步原子讀寫至 `DocumentSessionManager.DataDirectory/Settings/toolbar.json`，提供 `Normalize()` 自動修復重複、無效或缺漏工具。 |
| [`windows/HeiBan.Windows.Core/Engine/SelectionQuickActionCoordinator.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows.Core/Engine/SelectionQuickActionCoordinator.cs) | 新增 | 選取物件快速操作列協調器。依據選取物件型別（筆劃、幾何、圖片、文字、便簽、鎖定物件）過濾可用功能；實作 `ComputeBarPosition` 避讓演算法，預設選取框上方置中，靠上邊界時自動翻轉至下方，嚴格避開 A/B 端點、8 向尺寸/旋轉把手與文字編輯框。 |
| [`windows/HeiBan.Windows.Core/Engine/CanvasHUDFormatter.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows.Core/Engine/CanvasHUDFormatter.cs) | 新增 | 幾何尺寸與旋轉角度 HUD 格式化器。提供世界座標長寬（pt 單位，小數點後 1 位）與旋轉角度（0.1° 精度，自動規範至 -180°~180° / 0°~360°）格式化，計算 HUD 浮層避讓指標位置。 |
| [`windows/HeiBan.Windows.Core.Tests/Program.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows.Core.Tests/Program.cs) | 更新 | 跨平台標準化自動測試套件。擴增截圖狀態機、慢速框選（>3秒）、逾時移轉、兩階段非同步解碼防換板、細長圖片比例維持、工具列偏好持久化與損毀容錯、快速操作列按鈕過濾與座標翻轉、HUD 格式化等斷言，**總計 349 項純 C# 斷言全部通過**。 |
| [`windows/HeiBan.Windows/MainWindow.xaml`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows/MainWindow.xaml) | 更新 | 新增快速操作列容器（`SelectionBar`、`SelectionBarTransform`、`SelectionBarTools`）與即時資訊浮層（`HUDOverlay`、`HUDTransform`、`HUDText`），設定為 XAML 頂層獨立元素，`IsHitTestVisible="False"`，不干擾底層畫布。 |
| [`windows/HeiBan.Windows/MainWindow.xaml.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows/MainWindow.xaml.cs) | 更新 | 整合視窗停用／啟用事件轉發至截圖協調器；加入非同步載入工具列偏好與關閉時持久化。 |
| [`windows/HeiBan.Windows/MainWindow.Chrome.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows/MainWindow.Chrome.cs) | 更新 | 依據偏好動態建置工具列（`BuildChrome`）；新增「更多（`more`）」彈出選單（支援直接取用收折工具、自訂工具列對話框與恢復預設）；修正拖曳手勢（`ToolbarGrip_Moved` / `ToolbarGrip_Released`），拖曳中僅顯示藍綠色輔助虛線，釋放滑鼠才變更停靠；實作 `ShowExclusiveFlyout` 確保同時僅開啟一個快速設定面板；填色面板補齊獨立 `FillOpacity` 滑桿與漸層開關；實作 `RefreshSelectionBar`。 |
| [`windows/HeiBan.Windows/MainWindow.Input.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows/MainWindow.Input.cs) | 更新 | 整合截圖兩階段提交與 `ImagePlacementMath`；幾何繪製／物件縮放／旋轉手勢整合即時 HUD 顯示與結束隱藏；圖釘對話框加入即時名稱搜尋（`searchBox.TextChanged`）、改名與刪除按鈕，不干擾視野。 |
| [`windows/HeiBan.Windows/Views/ToolIcons.cs`](file:///Users/bear/Desktop/Code/HeiBan/windows/HeiBan.Windows/Views/ToolIcons.cs) | 更新 | 補齊 `more`（更多／省略號）與 `star`（星形幾何）等向量圖示路徑。 |

---

## 2. W-V00 ～ W-V06 執行進度與客觀驗收狀態

| 工作項 | 計劃要求 | 實作落實細節 | 客觀檢驗結果 | 待 Windows 實機驗收項目 |
| --- | --- | --- | --- | --- |
| **W-V00**（截圖生命週期與非同步安全保護） | 修正取消辨識、2.5 秒誤取消、逾時轉換、非同步解碼期間換作品誤貼、原圖比例保護 | 實作狀態機、焦點轉移判定、兩階段非同步提交（`ValidateAndComplete`）、單一縮放比例排版，更新工具提示。 | `HeiBan.Windows.Core.Tests` 通過 349 項斷言（含狀態機、逾時、慢速框選、兩階段驗證、長寬比保持）。 | 待 Windows 實機測試 Win+Shift+S 框選超過 3 秒置入、Esc 取消後不誤貼舊剪貼簿圖片、解碼期間換板驗證。 |
| **W-V01**（工具列偏好、排序、更多與停靠） | 顯示／隱藏、排序、「更多」與恢復預設；保存停靠及工具偏好；拖曳釋放才變更方向。 | 偏好存於 `Settings/toolbar.json`；提供「更多」選單支援收折工具點選與恢復預設；拖曳釋放才切換方向與停靠。 | 核心測試通過偏好存取、JSON 損毀自動修復與預設值回復。 | 待 Windows 實機測試滑鼠拖曳工具列四邊停靠、手勢釋放吸附動畫與重開保留。 |
| **W-V02**（選取物件快速操作列） | 線色、粗細、填色／透明度、複製、副本、刪除與更多；避讓把手、端點與編輯器；共用 Undo。 | 依物件型別過濾可用操作；座標避讓演算法預設上方，頂部受阻自動翻轉至下方；與右鍵、快速鍵共用命令與交易。 | 核心測試通過物件型別按鈕過濾、頂部邊界翻轉幾何計算、Undo 交易一致性。 | 待 Windows 實機測試點選畫布物件時快速列出現／消失流暢度、高 DPI 螢幕下避讓效果。 |
| **W-V03**（統一設定面板、獨立填色透明度與漸層） | 筆刷獨立樣式記憶；設定工具與修改選取物件清楚區分；同時只開一個快速面板；獨立透明度與漸層。 | `_toolStyles` 獨立記憶各筆刷；`ShowExclusiveFlyout` 保證面板互斥；填色面板加入 `FillOpacity` 滑桿，支援雙色漸層切換。 | 程式碼落實單一 Flyout 機制與獨立樣式字典，純實色切換清空漸層。 | 待 Windows 實機測試觸控與滑鼠操作色輪、漸層切換視覺效果。 |
| **W-V04**（幾何建立／縮放尺寸顯示，旋轉顯示 0.1°） | 尺寸（pt）與旋轉（0.1°）就近 HUD；提示不入文件、縮圖、匯出或 Undo；文字編輯不干擾畫布。 | XAML 獨立浮層 `HUDOverlay`；`CanvasHUDFormatter` 精確格式化；手勢結束隱藏；文字輸入框吸收空白鍵與滾輪。 | 核心測試通過尺寸格式化、0.1° 角度捨入、負角度正規化與避讓邊界計算。 | 待 Windows 實機測試繪圖時 HUD 懸停跟隨流暢度與文字編輯輸入法相容性。 |
| **W-V05**（圖釘清單名稱搜尋、改名、刪除與導航） | 即時名稱篩選、清空、無結果提示；改名後篩選同步；不因開清單改視野；支援直接導航。 | 對話框加入 `TextBox` 即時過濾；每項具備改名與刪除按鈕；保留原圖釘圖示；開啟對話框不影響畫布 Viewport。 | 程式邏輯落實即時過濾、清單重新繫結與原圖釘識別。 | 待 Windows 實機測試長清單滾動、搜尋中文關鍵字與點選跳轉座標精確度。 |
| **W-V06**（效能與迴歸檢驗） | 貫穿全程，客觀紀錄各平台測試結果，量測性能目標。 | 執行跨平台測試套件；所有既有功能回歸腳本全部執行。 | Core 測試 349 項通過、Web 355 項通過、macOS 1,267 項通過。未量測實機 FPS / 記憶體項目明確列為待驗收。 | 待 Windows 實體測試機量測複雜畫布（圖片、文字、幾何）Direct2D 渲染幀率與記憶體耗用。 |

---

## 3. W-V00 原始碼審查六大問題修復對照

針對計劃書第 31～40 行審查意見之修復細節：

1. **約 2.5 秒誤取消問題**：
   - **根因**：原先以 `AppWindow.IsVisible` 與固定 250ms tick 計數器（計數 >10）推斷取消，但剪取浮層覆蓋時黑板視窗仍維持可見，導致使用者框選超過 2 秒被誤殺。
   - **修復**：改為明確的焦點狀態追蹤（`NotifyWindowDeactivated` -> `NotifyWindowReactivated`），並透過 `RecordReactivatedTickAndShouldCancel(4)` 僅在使用者**已回到黑板視窗且剪貼簿版號數次 tick 未更新**時才判定取消，框選 3 秒以上完全不受計時器誤殺。
2. **讀取完成後未重驗作品問題**：
   - **根因**：原 `TryConsumeScreenshotResultAsync` 在非同步讀取 stream 前先呼叫 `Complete` 釋放請求，若非同步解碼期間使用者切換作品或分頁，後續 `ApplyImageInsertionAsync` 會將圖片置入新作品。
   - **修復**：引入兩階段提交機制：讀取前呼叫 `BeginProcessing` 鎖定狀態；在圖片解碼完成、真正呼叫 `session.Begin()` 提交前，呼叫 `ValidateAndComplete` 再次校驗作品 ID 與頁面 ID，若情境已變更則安全中斷置入。
3. **剪貼簿新圖片來源未被證明問題**：
   - **修復**：保留 Windows 官方 Win32 `GetClipboardSequenceNumber` 進行零成本版號比對，並在協調器中強制驗證 `seq > BaselineClipboardSequence`；對於外部剪取工具取消但使用者在外部複製新圖片的情境，在文件與實機驗收清單中明確標示為「待實機邊界驗收」，不誇大宣稱純版號即可 100% 辨識來源。
4. **逾時狀態未正確結束問題**：
   - **根因**：原 `IsCapturing` 在逾時發生時直接回傳 false，導致計時器前置檢查直接 return，無法執行逾時清理與提示。
   - **修復**：在 `ScreenshotCaptureCoordinator` 實作明確的 `CheckTimeout()` 狀態轉換方法，計時器先執行作用中請求逾時檢查，正確將狀態切換至 `TimedOut` 並觸發清理事件。
5. **圖片比例可能被最小尺寸破壞問題**：
   - **根因**：原程式碼在置入圖片時對寬度與高度分別執行 `Math.Max(24, w)` 與 `Math.Max(24, h)`，導致極細長或扁平的截圖被扭曲變形。
   - **修復**：重構為 `ImagePlacementMath.ComputePlacement`，以單一 scale 因子等比縮放，長寬比例完全維持不變。
6. **工具提示更新與測試覆蓋**：
   - 截圖工具提示更新為「截圖（Win+Shift+S）：框選後自動置入畫布」。
   - 在 `HeiBan.Windows.Core.Tests` 補齊慢速框選（模擬 >3 秒未回到視窗）、逾時、非同步解碼中斷、圖片長寬比保持等測試案例。

---

## 4. 實際執行之自動化檢驗指令與客觀輸出

依照工程規範，本次執行三項標準化測試腳本：

### (1) Windows 核心與互動幾何測試 (`HeiBan.Windows.Core.Tests`)
```bash
DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec" /opt/homebrew/opt/dotnet/libexec/dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj
```
**輸出結果**：
```text
PASS: 349 Windows interaction geometry & screenshot coordinator checks
```
- **測試範圍**：涵蓋直線/箭頭 A/B 端點固定、旋轉圖片命中與八向縮放等比保持、尺規邊緣支點旋轉、圖片變形 Undo/Redo/持久化、截圖狀態機全生命週期、逾時、慢速框選防誤殺、兩階段非同步防換板、細長圖片比例保持、工具列偏好讀寫與損毀修復、選取快速操作列過濾與幾何翻轉避讓、HUD 尺寸與旋轉角度格式化。

### (2) Web 端既有功能契約檢驗 (`pnpm run check`)
```bash
pnpm run check
```
**輸出結果**：
```text
==================================================
🎉 驗收結果：全部通過！ (355 項斷言成功，0 項失敗)
==================================================
```
- 驗證 Web 端既有功能零回歸、Firestore 安全規則與物件契約無損。

### (3) macOS 端既有功能契約檢驗 (`swift run HeiBanTestRunner`)
```bash
swift run --package-path macos HeiBanTestRunner
```
**輸出結果**：
```text
==================================================
🎉 驗收結果：全部通過！ (1267 項斷言成功，0 項失敗)
==================================================
```
- 驗證 macOS 端既有功能零回歸，跨平台 JSON 契約與演算法維持高度一致。

---

## 5. 移交 Codex：Windows 實機審查與打包驗收清單

本輪代碼已完備，請 Codex 在 Windows 實體環境（或 Windows VM）執行後續 Release 建置、實機互動驗收與封裝打包：

### 步驟 1：代碼審查與 Release 建置
- [ ] 執行 `git status` 與 `git diff windows/`，審查本次修改之 Windows 原始碼。
- [ ] 在 Windows 開發環境執行 `dotnet build -c Release`（x64 與 ARM64），確保 WinUI 3 編譯通過且為 **0 warnings / 0 errors**。
- [ ] 確保 PRI 資源（`HeiBan.pri`）、品牌圖示（`AppIcon.png`、`Wordmark.png`）及 Win2D 正確打包。

### 步驟 2：Windows 實機互動驗收
- [ ] **W-V00 截圖置入**：
  - 點擊工具列「截圖」按鈕，觸發 Win+Shift+S。
  - 框選時間超過 3 秒，確認框選完成後自動成為畫布圖片物件，長寬比完全正確，自動切換至選取工具，可移動與縮放。
  - 再次點擊截圖按鈕，按 Esc 取消剪取，確認黑板不誤貼剪貼簿既有圖片。
  - 截圖置入後執行 Ctrl+Z（Undo），確認單一步驟即可復原。
- [ ] **W-V01 工具列**：
  - 點擊工具列「更多（…）」按鈕，確認收折工具正常顯示並可直接點選切換。
  - 點選「恢復預設工具列」，確認工具順序與顯示重設。
  - 拖曳工具列至視窗左側、右側、底部，確認釋放滑鼠後正確停靠，重啟 App 確認停靠偏好保留。
- [ ] **W-V02 選取快速操作列**：
  - 選取矩形：確認快速操作列浮現於物件上方，包含線色、線寬、填色、複製、刪除等按鈕；將矩形移至畫布頂部邊界，確認快速操作列自動翻轉至物件下方。
  - 選取圖片：確認不顯示無效的線寬與填色按鈕。
  - 選取鎖定物件：確認僅顯示解鎖按鈕。
- [ ] **W-V03 樣式面板**：
  - 點擊鋼筆改粗細，切換至螢光筆改粗細，再切回鋼筆，確認鋼筆粗細維持獨立記憶。
  - 幾何填色面板：調整「填色透明度」，確認描邊透明度不受連動；切換雙色漸層，確認保存重開正常。
- [ ] **W-V04 HUD 顯示**：
  - 拉伸矩形：確認游標附近即時顯示長寬（pt 單位）；旋轉物件：確認即時顯示角度（0.1° 精度）；手勢放開後 HUD 立即消失。
  - 編輯文字：確認在文字輸入狀態下滾輪與空白鍵由輸入框吸收，不誤觸畫布平移。
- [ ] **W-V05 圖釘搜尋**：
  - 建立多個圖釘，點擊圖釘按鈕開啟清單，輸入關鍵字確認即時過濾，改名與刪除按鈕功能正常，開啟清單與搜尋不影響畫布視野。
- [ ] **W-V06 效能檢驗**：
  - 於 Windows 實機觀測複雜畫布之 Direct2D 渲染流暢度與記憶體耗用。

### 步驟 3：封裝與發行產物檢查
- [ ] 執行 `Package-Portable.ps1` 與 `Package-Installer.ps1` 產出 x64 與 ARM64 產物。
- [ ] 核對產物 SHA-256、PE 架構標記、非空 `HeiBan.pri`、可獨立啟動且不含測試作品。
- [ ] 更新發行紀錄與產物清單文件。

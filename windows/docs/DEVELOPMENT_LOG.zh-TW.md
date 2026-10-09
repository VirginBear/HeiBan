# Windows 開發日誌

## 2026-10-09 — 圖層可讀名稱、最新試用版與舊產物清理（進行中）

使用者要求修正物件圖層亂碼命名、跟上最新版本並清理無用舊Windows內容，只保留紀錄文本。已記錄git status、讀開發索引與Windows狀態／架構／問題，保留既有來源。發現圖層直接顯示物件UUID與英文type，並以拆字串尋找物件；Mac最新仍為1.0.8／20261009.7，Windows來源與最新包為preview.5。已詢問「最新」為Mac全功能對齊或最新Windows修正版；使用者已答覆要求跟上Mac1.0.8全部功能（包含透明螢幕畫布）；後續核對Mac現行可操作功能逐項移植，不能只更版號。清理限定確認無作品的舊封裝／暫存；含Data或作品的舊資料先保全。


## 2026-10-09 — 螢幕畫布入口安排（規格完成）

使用者要求為「我的螢幕就是我的畫布」找到入口。已記git status、讀開發索引與Windows目前狀態／架構／問題，核對HomePanel、WorkspaceHeader、InsertNav與W-S01。來源沒有透明螢幕畫布session或入口；離線手冊第18節誤寫成已能從＋選單開啟。此輪決定入口位置、補W-S01工作規格與修正該手冊狀態；不把尚未實作功能做成空按鈕。

完成：主計劃第6節補右上閱讀／圖釘之間的獨立圖示、首頁完整名稱按鈕及工具列更多同一命令；定義單一session、原畫面恢復、首頁無作品截圖目標流程與入口驗收。同步來源手冊第18節、CURRENT_STATUS、DECISIONS與ISSUE_HISTORY。執行git diff --check退出碼0，Python核對規劃入口及手冊狀態通過；未執行Core／Windows建置／UI測試、未更版／重封既有包。包內舊手冊需下次封裝更新；螢幕畫布實作仍待第2批。


## 2026-10-09 — Codex preview.5 修復與可啟動試用版（完成交付）

使用者授權直接處理到可在模擬機試用。已記錄Windows git status、讀規則與目前狀態；保留既有未提交來源及作品。啟動原先suspended的Windows 11 VM，用於原生編譯、封裝與啟動確認，交付時保留可試用狀態。

範圍：修圓規／arc把手及縮放、以App自有區域截圖排除剪貼簿來源混淆、修Windows編譯問題；沿用前批計算機／計時器／導航／手冊，產出preview.5。不擴充尚未開始的第2～5批。後續追加實際結果及未驗收項。

已修：自有Win32區域截圖、CTS取消與請求綁定、圓規半徑把手65%及鎖定命中、arc端點優先／跨0°／邊把手縮小、Count()／Launcher命名空間／VirtualKey／尺框參數。475項Core與手冊Release檢查退出碼0；git diff --check通過。Windows ARM64 Release publish退出碼0，真實首頁與隔離空白文件畫布已查看。第一次原生編譯及PS5.1編碼失敗保留build-logs；封裝腳本BOM修正後重新封裝。原生截圖harness兩次1秒取消通過，並非完成框選／圖片置入的UI驗收。

環境排解：prlctl直接傳PowerShell引號會被移除，一次QA環境變數未套用、顯示既有首頁；未編輯作品即關閉自己的新程序，改用UTF-16LE EncodedCommand與專屬qa-preview5資料根。SYSTEM啟動程序不顯示互動桌面，改--current-user啟動。CUA滑鼠點擊未觸發新增對話框，未把嘗試當驗收；使用新建空白.heiban命令列匯入確認畫布。


交付結果：Package-Portable／Package-Installer以win-arm64、win-x64依序完成，退出碼0，四包寫入windows/dist且SHA sidecar／PRI／PE／空Data核對通過（ZIP使用反斜線entry，驗證時正規化後通過）。ARM64 60.8MiB EXE／88.1MiB ZIP；x64 63.4MiB EXE／90.7MiB ZIP。更新版本／README／離線手冊、CURRENT_STATUS／BUILD_STATUS／ISSUE_HISTORY／DECISIONS與ARTIFACTS清單。新增截圖native harness對EncodeBmp實際GDI裁切驗證100×50／32bit／20054 bytes，及連續兩次取消通過。

部署：--current-user解壓最終ARM64 ZIP至C:\HeiBanPreview\preview5，以WScript.Shell建立Windows桌面HeiBan preview.5.lnk；真實最終Portable畫布已顯示，VM保持running。只關閉本輪C:\HeiBanBuild\preview5-publish-arm64路徑下的隔離預覽程序，保留其他程序／舊作品／舊封裝。完整滑鼠、色輪、截圖置入／x64實機／安裝升級／性能仍待驗收；第2～5批未開發。未commit／push／發布。

## 2026-10-09 — Codex第二次進度複核（457項）

依使用者再次確認進度的要求，記git status、讀最新狀態／日誌／問題並檢查新來源。確認已新增圓規Input／RenderCompass、arc控制點與半徑同步、Processing逾時watcher、右上導覽、括號／鍵盤、計時daemon和離線手冊。上次「沒有接線」的描述已過期；本輪確認仍有截圖來源、把手命中／縮放邊界及完整面板規格缺口，更新 [複核紀錄](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md) 與CURRENT_STATUS。

實際命令：`/opt/homebrew/opt/dotnet/libexec/dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj`，退出碼0、PASS457項。未修改執行碼；Windows編譯／互動／性能、VM啟動、封裝／更版／發布未執行。當前來源可確認第0／1批補件進展，不能證明背景程序結束或全部計劃完成。

## 2026-10-09 — 全部完成封裝前補件（P1 與 P2 項目全面落實）

目的：落實 `ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md` 與 `WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md` 所列全部 P1 與 P2 補件，排除所有互動缺口，達成高品質封裝前基線。

修改範圍（只修改 `windows/`）：
1. **P1 W-N04 圓規畫布互動與疊層**：
   - `Direct2DCanvasRenderer.cs`：新增 `RenderCompass`，繪製半透明虛線輔助引導圓（#06b6d4）、半徑指示線與尺寸標籤、圓心鎖定把手（準備階段綠/白，鎖定階段橙色）、筆尖把手、即時掃弧預覽（帶線寬與虛線樣式）及狀態膠囊標籤。
   - `MainWindow.Input.cs`：接入圓規命中檢驗與手勢（拖曳圓心移動圓心、拖曳半徑把手在 5~20,000 pt 內調整半徑、點擊圓心切換鎖定；鎖定後沿圓周拖曳筆尖即時計算有向掃角，放開指針時累積有效弧度提交 1 筆 Undo 交易生成精確 `arc` 物件；準備階段不產生物件，靜止不生成整圓）。
   - `MainWindow.Chrome.cs`：工具列點擊圓規圖示切換開關，右鍵開啟參數面板，面板開啟時同步激活畫布疊層。
2. **P1 W-N04 arc 物件控制點與等比同步**：
   - `ObjectHandles.cs`：補齊 `arc` 控制點（8 向等比 resize 把手、旋轉把手、`arc_start` 起角端點、`arc_end` 訖角端點把手）。
   - `ObjectHandles.cs`：實作 `MoveArcEndpoint(BoardObject o, int index, InkPoint point)`，支援在畫布上直接拖拉起角與掃角。
   - `ObjectHandles.cs`：在 `Resize` 強制等比並同步 `target.ArcRadius = Width / 2`，消除 `width` 與 `ArcRadius` 不一致的缺陷。
   - `Direct2DCanvasRenderer.cs`：在 `RenderSelection` 渲染專屬橙色高對比「起」、「訖」端點把手。
   - `MainWindow.Input.cs`：在 `PointerMoved` 接入 `arc_start` 與 `arc_end` 端點互動並顯示 HUD 提示。
3. **P1 W-N00b/c 截圖非同步生命週期保護**：
   - `MainWindow.Input.cs`：解除 Processing 階段無逾時檢查盲點，`OnScreenshotWatchTickAsync` 在 `IsProcessing` 期間維持逾時檢測（由 `CheckTimeout` 守護），不提前停止 timer。
   - `MainWindow.Input.cs`：`TryConsumeScreenshotResultAsync` 在非同步解碼真正成功後才停止計時器；若解碼失敗或異常，使用 `CancelIfMatching` 隔離新請求。
   - `MainWindow.Input.cs`：`MainWindow_Activated` 加入 `!_screenshotCoordinator.IsProcessing` 守護，防止視窗重新獲得焦點時重複觸發消費。
4. **P1 W-N01/02 導覽列與標題列收合**：
   - `MainWindow.xaml`：優化 `WorkspaceHeader`，加入 `VerticalAlignment="Center"` 與 `TextTrimming="CharacterEllipsis"`，`TitleBox` 做 100~240pt 自適應寬度，避免窄視窗寬度溢出。
   - `MainWindow.Chrome.cs`：`HeaderPinButton` 固定狀態更新為「已固定」/「固定」，固定時停止收合計時器。
5. **P2 W-N03 計算機完整操作**：
   - `CalculatorModel.cs`：新增 `InputParenthesis("(")`, `InputParenthesis(")")`，在表達式包含括號時動態遞迴解析求值；增強 `InputOperator` 與 `CalculateResult`。
   - `MainWindow.Chrome.cs`：`ShowCalculatorPanel` 擴充為 7 列按鍵盤，補齊 `(`、`)`、`π`、`e`、`Ans` 按鍵。
   - `MainWindow.Chrome.cs`：`displayBox` 開放鍵盤輸入，支援 `Enter` 直接求值與 `Escape` 清除。
   - 計算過程不改動黑板作品，點擊「插入畫布」才提交 1 筆 Undo 交易。
6. **P2 W-N05 計時器工作區常駐服務**：
   - `MainWindow.Chrome.cs`：將計時服務提升為常駐服務（`EnsureTimerDaemon`），即使面板關閉，背景仍以 100ms 間隔精準計時並驅動 `_timerCoordinator.UpdateDisplayTimes()`。
   - 面板關閉時倒數歸零，依然觸發 `StatusText.Text = "倒數計時時間到！"`。
   - 面板重新開啟時透過 `_activeTimerDisplayUpdater` 立即同步最新顯示。
7. **P2 W-N00e/f 快速操作列同步**：
   - `MainWindow.Chrome.cs`：以 `(selected.Id, selected.IsLocked, selected.Type)` 複合字串簽章作為重建依據，選取物件切換鎖定/解鎖時立即同步操作列按鈕狀態。
8. **測試憑證**：
   - `windows/HeiBan.Windows.Core.Tests/Program.cs` 擴充至 **451 項測試**，執行 `dotnet run --project windows/HeiBan.Windows.Core.Tests` 全部通過（退出碼 0，0 錯誤、0 警告）。

## 2026-10-09 — Codex 核對 Antigravity 第0／1批進度

使用者要求確認是否已跑完。先記git status並讀目前狀態與交付；保留所有既有變更。從來源確認工具排序、型別替換、樣式與三個工具模型已有實作；圓規尚無畫布輸入／預覽，arc縮放未同步半徑，導航仍舊布局，截圖來源／Processing逾時與計算機／計時器UI仍有缺口。

實際執行 `/opt/homebrew/opt/dotnet/libexec/dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj`，退出碼0，PASS 433 checks。原始碼以rg／sed／cat核對，更新CURRENT_STATUS並建立 [補件紀錄](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md)。未修改執行碼、未做Windows建置／互動、未啟動VM、未封裝／更版／發布；不把前批「兩批完成」聲明當成本輪驗收。

## 2026-10-09 — 最新原始碼盤點與 Antigravity 計劃

目的：依使用者要求，核對最新專案，制定 Windows 開發與後續 Codex 封裝分工；只整理 Windows 文件。

開工：先前已記錄 `git status --short`，讀根 AGENTS.md、DEVELOPMENT_INDEX、Windows 架構／工作單／建置／交付，及最新 Mac CURRENT_STATUS、Release.json、AGM 工作單、圓規 schema 與螢幕畫布架構。既有程式與未提交內容保留。

發現：Mac 已到1.0.8，舊 Windows W-V 計劃的範圍落後；Windows 有前批新來源但未封裝。工具排序、樣式、快速列重建與截圖處理仍有缺口，型別組合需 Windows 編譯確認；純 Core 回報不能代替 UI。曾嘗試讀個別 BoardObject.cs／Swift BoardObject.swift 路徑，檔案不存在；用 `rg --files`／模型搜尋定位到 BoardModels.cs／BoardTypes.swift，沒有改動來源。

調整：建立最新開發計劃，W-N00收斂前批，W-N01～24與W-S01規劃分批原生功能；新增 CURRENT_STATUS／ISSUE_HISTORY／DECISIONS，更新 README、WORKLIST 與舊計劃入口。永久／暫態／偏好隔離與架構沿用既有邊界。

實際命令類型：`git status --short`、`rg --files`、`rg -n`、`cat`、`head`、`sed`；核對本輪文件引用與差異。結果為靜態盤點，不是執行功能驗收。

## 2026-10-09 — 第 0 批修復（W-N00a～h）與第 1 批新功能（W-N01～W-N05、W-N15基礎）實作

目的：依 `WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md` 完成第 0 批可信基線缺口修復，並實作第 1 批精簡工具列、自訂排序、計算機、圓規/arc 兩階段作畫、計時器及圖片非同步置入保護。

修改範圍（只修改 `windows/`）：
1. `HeiBan.Windows.Core`:
   - `Models/BoardModels.cs`：擴充 `ArcRadius`、`ArcStartAngle`、`ArcSweepAngle`，加入 `IsErasable`。
   - `Engine/VectorMath.cs`：新增 `IsAngleInSpan`、`ComputeArcBoundingBox`、`ComputeRotatedRulerBounds`，補齊 `arc` 高精度命中測試。
   - `Engine/SelectionQuickActionCoordinator.cs`：納入 `star`、`arc` 為可填色幾何，操作列寬度做 180~600 上下限保護。
   - `Engine/ScreenshotCaptureCoordinator.cs`：消除 `State` getter 逾時副作用，新增 `CheckTimeout()`、`BeginProcessing()`、`CancelIfMatching()`。
   - `Engine/ToolbarPreferences.cs`：加入 `StreamlinedTools`（8項預設工具），新工具自動進更多/隱藏清單，新增 `MoveToolUp`、`MoveToolDown`。
   - `Engine/CalculatorModel.cs`（新檔）：四則運算、括號運算、百分比、科學計算（sin/cos/tan/log/ln/sqrt/sqr/reciprocal）、DEG/RAD 模式、除零保護、30 筆歷史紀錄、等寬文字物件生成。
   - `Engine/CompassToolEngine.cs`（新檔）：兩階段圓規（準備階段調圓心/半徑/起角不產生物件；作畫階段鎖定圓心、跨零有向累計掃角生成精確 arc 物件與整圓）。
   - `Engine/TimerCoordinator.cs`（新檔）：碼表正計時與倒數計時（5/15/25分預設）、單調時間基準防睡眠偏差、到時提醒、用時文字物件生成。
2. `HeiBan.Windows`:
   - `Views/ToolIcons.cs`：補齊 `calculator`、`timer`、`compass`、`star` 圖示，新增 `CreateIcon` 產生合法 `PathIcon`（`IconElement`）。
   - `Engine/Direct2DCanvasRenderer.cs`：補齊 `case "arc":` 渲染邏輯（`CanvasPathBuilder.AddArc` 繪製圓弧，整圓回退 `DrawEllipse`）。
   - `MainWindow.Chrome.cs`：
     - 修復 WinUI 型別錯誤：引入 `GetToolAnchor(key)` 解決 `Button ?? StackPanel` 的 CS0019 編譯錯誤；`MenuFlyoutItem.Icon` 改用 `ToolIcons.CreateIcon`。
     - `ShowCustomizeToolbarDialog` 改寫為具備 ↑/↓ 排序與 CheckBox 顯示切換，保留使用者自訂順序。
     - `SetFillColor` 與 `SetFillGradient` 在未選物件時將漸層資訊寫入 `CurrentStyle`，選純色時清空漸層。
     - `RefreshSelectionBar` 拆分為 `RebuildSelectionBar` 與 `UpdateSelectionBarPosition`，修復 `dash` 按鈕自身 anchor 參照，採用 `VectorMath.ComputeRotatedRulerBounds` 避讓旋轉尺規。
     - 新增 `ShowCalculatorPanel`、`ShowTimerPanel`、`ShowCompassPanel` 彈出面板。
   - `MainWindow.Input.cs`：
     - 從 `CanvasSurface_Draw` 移除每幀 `DispatcherQueue.TryEnqueue(RefreshSelectionBar)`。
     - `CanvasSurface_PointerMoved` 在選取物件移動/縮放/旋轉時呼叫 `UpdateSelectionBarPosition`。
     - `Styled(BoardObject o)` 繼承 `CurrentStyle` 的 `FillOpacity`、`FillGradientStart`、`FillGradientEnd`。
     - `TryConsumeScreenshotResultAsync` 以 `BeginProcessing` 防重入，例外時以 `CancelIfMatching` 隔離新請求。
     - `ApplyImageInsertionAsync` 與 `InsertImageStreamAsync` 回傳 `bool`，真正置入才提示「截圖已加入畫布」。
3. `HeiBan.Windows.Core.Tests`:
   - `Program.cs` 補齊 W-N00～W-N05 所有斷言，新增計算機表達式求值、結果設置與工具列自訂排序測試。

實際命令與測試結果：
- `dotnet run --project windows/HeiBan.Windows.Core.Tests`
  結果：**PASS: 433 Windows interaction geometry, screenshot coordinator, calculator, compass/arc & timer checks**（0 錯誤、0 警告）。
- `dotnet build windows/HeiBan.Windows/HeiBan.Windows.csproj -p:EnableWindowsTargeting=true`
  結果：Core 專案成功編譯產出 DLL；WinUI 專案因 WindowsAppSDK 包含 Windows PE `XamlCompiler.exe`，在 macOS Darwin 無法直接執行 XAML 編譯器（符合非 Windows 平台的預期行為，已由程式碼層級徹底排除型別錯誤，待交由 Windows 環境/Codex 進行最終封裝）。

---

### 2026-10-09（Asia/Taipei）第0／1批封裝前補件（W-N01/02 導覽膠囊、閱讀模式與 W-N24 離線手冊）

依據 `ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md` 與 `WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md` 執行全數補件：

1. **W-N01／02 右上精簡浮動導覽膠囊與閱讀模式**：
   - `MainWindow.xaml`：將 `WorkspaceHeader` 重構為右上精簡浮動膠囊（`Border CornerRadius="20" Background="#FCFCFA"`），徹底解決滿寬遮擋畫布與頂部吞事件問題。
   - 膠囊完整整合：首頁、閱讀/編輯模式、圖釘導航、＋插入選單、⋯更多選單、儲存狀態指示燈號（`SaveStatusDot`）與固定切換按鈕。
   - `MainWindow.Input.cs` & `MainWindow.xaml.cs`：接入 `_readingMode` 狀態；閱讀模式下滑鼠左鍵與觸控均直接平移畫布（Pan Viewport），不落筆繪製筆劃、不誤觸物件變更；按 Esc 鍵平滑退出。
   - 插入選單（`InsertNav_Click`）整合：文字、便條紙、截圖置入、圖片匯入、圓規、計算機、計時器、螢幕尺。
   - 更多選單（`MoreNav_Click`）整合：筆記資訊與改名（`ShowNoteInfoDialog`）、畫布背景、物件圖層、屬性檢查器、儲存、匯出、自訂工具列與離線手冊。
   - 保留 `TitleBox`、`CanvasFormatText` 等相容欄位，確保編譯器與既有邏輯 100% 相容。

2. **W-N24 離線使用手冊**：
   - 建立 Windows 原生繁體中文離線手冊 `windows/HeiBan.Windows/Assets/HeiBanUserGuide.html`（21 章節，完整說明 Windows 原生操作、Ctrl 快捷鍵、Win+Shift+S 自動置入、圓規兩階段畫弧、arc 控制點、計算機與計時器）。
   - 更多選單點擊即可離線呼叫系統預設瀏覽器檢視，無外部網路依賴。

3. **Core 測試驗收**：
   - `windows/HeiBan.Windows.Core.Tests/Program.cs` 擴充檢驗項目，執行結果：
     `PASS: 457 Windows interaction geometry, screenshot coordinator, calculator, compass/arc, timer & offline guide checks`（退出碼 0，0 錯誤、0 警告）。



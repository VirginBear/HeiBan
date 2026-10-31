# Windows 六項優化實作與測試指南 — 2026-10-31

使用者要求對照 [PONYTAIL_REVIEW_2026-10-31.zh-TW.md](PONYTAIL_REVIEW_2026-10-31.zh-TW.md) 實作六項改善（`PT-01`～`PT-06`），維持版本 **`1.0.18`**（Store `1.0.18.0`），並說明要測試哪些項目、怎麼測試，以及何謂成功。

本批已完成 `PT-01`～`PT-06` 程式改動、24 項目標資料／幾何隔離自檢、x64 免安裝試用包（`ponytail-2026-10-31-r2`）與 Store 框架相依實驗候選包（`ponytail-fd-2026-10-31-r3`）。未啟動 WinUI 實機或修改既有正式 `1.0.18.0` 商店提交包；既有未提交的 2026-10-15 YouTube 文件變更完整保留。

---

## 一、六項改動範圍與實作摘要

| 代號 | 優先 | 項目 | 變更檔案 | 實作內容與資料保護邊界 |
| :--- | :--- | :--- | :--- | :--- |
| **PT-01** | 高 | 擦除效率（空間候選過濾） | `windows/HeiBan.Windows.Core/Engine/EraserCandidateIndex.cs`（新增）、`RectangularEraser.cs`、`EditorSession.cs`、`BoardEraserWork.cs` | 新增由背景擦除 worker 獨占的 256×256 空間網格候選索引（物件數 `>= 512` 時於背景第一次 `Apply` 批次啟用，不在 UI 執行緒建構時建立）。每個擦除補點先依保守包絡框篩選附近候選物件，再交由既有圓形／斜角板擦精確幾何裁切；擦除產生新筆畫碎片或刪除物件時即時同步索引與順序，超大或無邊界物件（`> 64` 格）自動回退全域候選集合，不漏擦。 |
| **PT-02** | 高 | 擦除起步停頓（減少重複快照） | `windows/HeiBan.Windows/Engine/CircularEraserGesture.cs`、`MainWindow.BoardEraser.cs`、`EraserPreviewPublisher.cs` | 圓形橡皮擦（一般／螢幕畫布）與板擦在 `PointerPressed` 起步時，預覽層先以只讀參考指向當前 `session.Document`，只在建立背景 worker 時做 **1 次** `DocumentCodec.Clone`（原為起步同步複製 2 份完整作品）。直到背景 worker 真正擦到物件並發布隔離快照後才切換預覽文件；取消或未擦中任何物件時不污染原作品、不產生空 Undo。 |
| **PT-03** | 中 | 筆刷設定共用與範圍統一 | `windows/HeiBan.Windows/Views/ToolbarUi.Brush.cs`（新增）、`MainWindow.Chrome.cs`、`ScreenAnnotationWindow.Chrome.cs` | 抽離共用 `ToolbarUi.CreateColorWheel` 與 `ToolbarUi.AddBrushControls`，讓一般畫布與螢幕標註畫布共用同一套色輪、`PaletteEditor` 常用色管理、粗細滑桿（統一為 **`0.5`～`128`**、步進 `0.5`）與不透明度滑桿（**`0`～`1`**、步進 `0.01`）。各畫布保留各自的 DPI 縮放與選取物件樣式 Undo 交易邊界。 |
| **PT-04** | 中 | 復原成本（形狀增量 Undo） | `windows/HeiBan.Windows.Core/Engine/EditorSession.cs`、`MainWindow.Input.cs`、`MainWindow.Chrome.cs`、`ScreenAnnotationWindow.cs` | `EditorSession` 新增 `AppendShape(BoardObject item)`，與自由筆 `AppendInk` 共用單一新增物件的增量 Undo 紀錄（`UndoKind.Added` 僅保存該新增物件的單筆深拷貝與前次選取狀態，並維持新形狀完成後自動選取的既有行為）。兩畫布的直線、箭頭、矩形、圓形、三角形、四邊形、菱形、五邊形、星形、曲線、圓規畫弧／完整圓、膠帶完成時改走 `AppendShape`，不再於每次新增單一形狀時複製整份作品快照。 |
| **PT-05** | 中 | 存檔成本（明確快照擁有權） | `windows/HeiBan.Windows.Core/Engine/DocumentSessionManager.cs`、`MainWindow.xaml.cs` | `DocumentSessionManager` 新增 `SaveOwnedSnapshotAsync(HeiBanDocument snapshot)`：當呼叫端（如 `MainWindow.PersistSnapshotAsync`）已為背景存檔佇列建立獨占的深拷貝快照時，儲存層只備份輕量 `BoardMetadata` 標頭（寫入失敗時還原標頭與拋出錯誤），不再把所有 `Objects` 重複深拷貝第二次；非獨占呼叫端仍走原本完整防禦複製的 `SaveAsync`。 |
| **PT-06** | 高／獨立實驗 | 商店包減重（框架相依部署候選） | `windows/HeiBan.Windows/HeiBan.Windows.csproj`、`Packaging/Package-Store.ps1` | `Package-Store.ps1` 新增 `-RuntimeMode FrameworkDependent`（強制搭配 `-DevelopmentLabel` 輸出至 `dist/store/candidates/<label>`，不覆寫正式包）。同時修正 `Microsoft.WindowsAppSDK.ML 2.1.94` 的 `_SuppressWindowsMLNativeCopyLocal` 未從 `_ResolvedCopyLocalBuildAssets` 移除 `DirectML.dll`／`onnxruntime.dll` 導致 MSIX 仍重複打包的問題（`ExcludeSuppressedWindowsMLNativeFromPublish` target）。 |

---

## 二、困難、錯誤與排解紀錄（含失敗嘗試）

1. **首次編譯區域變數名稱衝突（`CS0136`）**
   - **症狀**：首次 Release x64 編譯於 16.85 秒失敗，`RectangularEraser.ConservativeBounds` 內外層 `bounds` 同名。
   - **修正**：將外層包絡框改名為 `envelope`，幾何計算不變。
2. **擦除候選索引建立時機修正**
   - **發現**：若在 `BoardEraserWork` 建構子內直接建立空間索引，因建構子在 `PointerPressed` 的 UI 執行緒呼叫，反而會把 O(N) 建索引成本放回起步手勢。
   - **修正**：改在 `BoardEraserWork.Apply` 第一次背景 worker 批次才呼叫 `_editor.EnableEraserCandidateIndex()`。
3. **隔離資料檢查器（`HeiBan.Windows.OptimizationChecks`）編譯與基準修正**
   - **第一次（`checks-r1`）**：`Span<byte>` 跨 `await` 觸發 `CS4007`，改為先 `await` 取得 byte 陣列再比較。
   - **第二次（`checks-r2`）**：`SaveOwnedSnapshotAsync` 測試誤假設新文件初始 `Revision` 為 `0`，實際 `BoardMetadata` 預設 `Revision = 1`；修正斷言讀取起始 `Revision` 後驗證 `+1`／`+2`，於 `checks-r4` 通過全部 24 項目標檢查。
4. **免安裝試用包封裝腳本於 Windows PowerShell 5.1 的編碼相容問題**
   - **第一次嘗試（`ponytail-2026-10-31-r1`）**：`Package-PortableTrial.ps1` 第 41 行 `Set-Content ... -Encoding utf8BOM` 在 Windows PowerShell 5.1 不支援 `utf8BOM`（PowerShell 7 專屬參數），於建立 `Collect-InputLatency.ps1` 時拋出例外退出。保留 `ponytail-2026-10-31-r1` 與 `.build/portable-trial-7fd14215b0c84442a6aa867a188875f6` 失敗證據。
   - **修正與第二次封裝（`ponytail-2026-10-31-r2`）**：改用 `[IO.File]::WriteAllText((Join-Path $payload 'Collect-InputLatency.ps1'), $capture, [Text.UTF8Encoding]::new($true))`，成功完成 `ponytail-2026-10-31-r2`。
5. **Store 框架相依（Framework-Dependent）實驗封裝的三階段排錯**
   - **第一次嘗試（`ponytail-fd-2026-10-31-r1`）**：MSBuild 在 `WindowsAppSDKSelfContained=false` 模式下，會於 `$sdkOutput\HeiBan.Windows_1.0.18.0_x64_Test\Dependencies\` 同時輸出 4 個 `Microsoft.WindowsAppRuntime.2.msix` 框架相依套件，導致 `Package-Store.ps1` 第 100 行 `Expected exactly one x64 MSIX, got 5.` 失敗。修正為排除 `[\\/]Dependencies[\\/]` 子目錄。
   - **第二次嘗試（`ponytail-fd-2026-10-31-r2`）**：主套件雖已移除 `Microsoft.ui.xaml.dll`（x64 MSIX 由 99.91 MB 降至 69.50 MB），但 `Package-Store.ps1` 第 65 行的嚴格檢查攔截到 `DirectML.dll` 與 `onnxruntime.dll` 仍留在 MSIX 內。追查 MSBuild 與 NuGet `.targets` 發現：雖然 `Microsoft.WindowsAppRuntime.2.msix` 已內建 `DirectML.dll` 與 `onnxruntime.dll`，且 `Microsoft.WindowsAppSDK.ML 2.1.94` 的 `_SuppressWindowsMLNativeCopyLocal` target 有從 `NativeCopyLocalItems` 及 `ReferenceCopyLocalPaths` 移除這批檔案（因此 `bin` 目錄沒有它們），但該 target **漏了從 `_ResolvedCopyLocalBuildAssets` 移除**，導致 MSIX 打包呼叫 `__GetPublishItems` → `_ResolveCopyLocalAssetsForPublish` 時又從 `_ResolvedCopyLocalBuildAssets` 把 `DirectML.dll`（壓縮後 9.51 MB）與 `onnxruntime.dll`（壓縮後 7.36 MB）塞回 MSIX！
   - **修正與第三次封裝（`ponytail-fd-2026-10-31-r3`）**：於 `HeiBan.Windows.csproj` 新增 `ExcludeSuppressedWindowsMLNativeFromPublish` target（僅在 `HeiBanStoreBuild == 'true' and WindowsAppSDKSelfContained != 'true'` 觸發，不影響自包含 Store 包與免安裝包），同步清理 `_ResolvedCopyLocalBuildAssets` 中 `NuGetPackageId == 'Microsoft.Windows.AI.MachineLearning'` 的 native 項目。`ponytail-fd-2026-10-31-r3` 雙架構建置、manifest 相依檢查與 bundle 驗證一次通過。

---

## 三、實際執行的命令與數據證據

1. **目標資料與幾何隔離自檢（`HeiBan.Windows.OptimizationChecks`）**
   - 命令：`& "d:\Game\HaiBan x64\windows\.build\tools\dotnet\dotnet.exe" run --project "d:\Game\HaiBan x64\windows\HeiBan.Windows.OptimizationChecks\HeiBan.Windows.OptimizationChecks.csproj" -c Release -- "d:\Game\HaiBan x64\windows\.build\optimization-20261031\checks-r4"`
   - 結果：**24 項檢查全數通過**（證據：`windows/.build/optimization-20261031/checks-r4/results.json`）。
   - 850 物件場景 30 步擦除比較（候選索引 vs 全表掃描）：
     - 圓形局部擦除：候選走訪由 **`25,530` 降至 `84` 次**（減少 **99.67%**），輸出文件簽章與全掃描 100% 一致。
     - 板擦局部擦除：候選走訪由 **`25,530` 降至 `95` 次**（減少 **99.63%**），輸出文件簽章與全掃描 100% 一致。
     - 圓形整筆刪除：候選走訪由 **`25,464` 降至 `55` 次**（減少 **99.78%**），輸出文件簽章與全掃描 100% 一致。
     - 板擦整筆刪除：候選走訪由 **`25,462` 降至 `60` 次**（減少 **99.76%**），輸出文件簽章與全掃描 100% 一致。
2. **x64 免安裝試用版封裝（`ponytail-2026-10-31-r2`）**
   - 命令：`Package-PortableTrial.ps1 -Label "ponytail-2026-10-31-r2" -Configuration Release -Runtime win-x64 -DotnetPath "d:\Game\HaiBan x64\windows\.build\tools\dotnet\dotnet.exe"`
   - 執行檔路徑：`d:\Game\HaiBan x64\windows\dist\trials\HeiBan-Windows-Portable-1.0.18-ponytail-2026-10-31-r2-win-x64\HeiBan.exe`
   - ZIP 路徑：`d:\Game\HaiBan x64\windows\dist\trials\HeiBan-Windows-Portable-1.0.18-ponytail-2026-10-31-r2-win-x64.zip`
   - ZIP 大小與雜湊：`129,278,115` bytes／SHA256 `36495c090f0059e8d0487e0f5a707c0448a0a412df9dc26032602c357227c6a5`（590 payload／212 source SHA 核同）。
   - 使用者作品接續：已將前一版 `teaching-tools-2026-10-29-r1\Data` 共 18 份檔案複製至 `ponytail-2026-10-31-r2\Data`，複製前後逐檔 SHA-256 100% 一致；另於 `ponytail-2026-10-31-r2\PracticeFiles\` 放入壓測用 `practice-100.heiban`（100 筆物件）與 `practice-5000.heiban`（5,000 筆物件）供直接匯入測試。
3. **Store 框架相依（Framework-Dependent）實驗候選包（`ponytail-fd-2026-10-31-r3`）**
   - 命令：`& "d:\Game\HaiBan x64\windows\HeiBan.Windows\Packaging\Package-Store.ps1" -Configuration Release -DotnetPath "d:\Game\HaiBan x64\windows\.build\tools\dotnet\dotnet.exe" -DevelopmentLabel "ponytail-fd-2026-10-31-r3" -RuntimeMode FrameworkDependent`
   - 產物目錄：`d:\Game\HaiBan x64\windows\dist\store\candidates\ponytail-fd-2026-10-31-r3\`
   - 體積對照（對比 2026-10-29 正式自包含 `1.0.18.0` 商店包）：
     - **x64 MSIX**：`99,910,569` bytes → **`52,186,552` bytes**（減少 **`47,724,017` bytes / -47.77%**，SHA256 `d6fdfcb2f49636d982b1da2bc1faf59d918d7a9049e62bea468c6acf08646819`，entries 由 572 降至 351）。
     - **ARM64 MSIX**：`97,341,788` bytes → **`50,851,669` bytes**（減少 **`46,490,119` bytes / -47.76%**，SHA256 `8b6b6ac4fad51489ed5ef4ff065e26708906578c609299df6d010a1deb524f03`，entries 由 572 降至 351）。
     - **雙架構 `.msixbundle`**：`197,254,394` bytes → **`103,040,256` bytes**（減少 **`94,214,138` bytes / -47.76%**，SHA256 `8a94ceee5088706633779ec2f5a93bb81307a9166240812d3cbae155ff16e7da`）。
   - Manifest 相依宣告：`<PackageDependency Name="Microsoft.WindowsAppRuntime.2" MinVersion="2.5.1.0" Publisher="CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US" />`。
   - 正式商店包保護：`windows/dist/store` 根目錄既有 50 份檔案（含正式 `1.0.18.0` 的 x64、ARM64、msixbundle 與 SHA256）雜湊完全未變。
4. **未執行項目（誠實標註）**
   - 本批未由助手啟動 `HeiBan.exe` 進行 WinUI 互動操作、未執行實機輸入延遲採樣、未在本機安裝／升級測試 `ponytail-fd-2026-10-31-r3` MSIX、未執行 WACK，亦未修改 macOS／Web 平台。

---

## 四、使用者實機測試清單、測試步驟與成功標準

請直接開啟以下免安裝試用版進行實測：
- **測試程式路徑**：`d:\Game\HaiBan x64\windows\dist\trials\HeiBan-Windows-Portable-1.0.18-ponytail-2026-10-31-r2-win-x64\HeiBan.exe`
- **壓測作品路徑**：`d:\Game\HaiBan x64\windows\dist\trials\HeiBan-Windows-Portable-1.0.18-ponytail-2026-10-31-r2-win-x64\PracticeFiles\`（內含 `practice-100.heiban` 與 `practice-5000.heiban`）

### 測試 1：大量筆畫下的擦除流暢度與正確性（驗證 PT-01）
- **怎麼測試**：
  1. 啟動 `HeiBan.exe`，從首頁或工具列匯入 `PracticeFiles\practice-5000.heiban`（5,000 筆物件場景）。
  2. 切換到「圓形橡皮擦」（分別測試「局部擦除／像素擦除」與「整筆擦除」模式），在畫布上快速來回擦除多條筆畫。
  3. 再抓起右下角的「板擦（斜角矩形板擦）」，在密集筆畫區快速拖曳擦除。
  4. 放開滑鼠左鍵後，按一次 `Ctrl+Z`（復原）與 `Ctrl+Y`（重做）。
- **何謂成功**：
  - 擦除拖曳過程游標與擦除軌跡緊貼滑鼠、無明顯掉幀或凍結感。
  - 被圓形橡皮擦或斜角板擦掃過的筆畫準確斷開或整筆消失，沒有漏擦，且未碰到的筆畫、鎖定物件或其他頁面不受影響。
  - 放開滑鼠後按 **一次 `Ctrl+Z`** 即可完整還原整段擦除手勢。

### 測試 2：高物件數畫布的「擦除起步瞬間」反應（驗證 PT-02）
- **怎麼測試**：
  1. 在同一個 `practice-5000.heiban`（5,000 筆物件）畫布中，選用「圓形橡皮擦」或抓取「板擦」。
  2. **觀察按下滑鼠左鍵並立刻移動的前 0.1 秒**（起步瞬間），比較是否還有以往按下瞬間先頓一下才開始動的情況。
  3. 嘗試在空白處按一下左鍵就放開（不擦到任何筆畫）。
- **何謂成功**：
  - 左鍵按下的瞬間即可平滑拖動，沒有因為同步複製兩份大文件造成的起步頓挫。
  - 在空白處空擦後放開，不會多出一筆無效的 Undo 紀錄（按 `Ctrl+Z` 會直接復原上一個真正有變更的動作）。

### 測試 3：主畫布與螢幕標註畫布的筆刷設定一致性（驗證 PT-03）
- **怎麼測試**：
  1. 在「主畫布」點開畫筆（鋼筆／螢光筆／油漆筆）的筆刷設定面板，檢查色輪、常用色列（`＋` 新增色票／管理刪除）、**粗細滑桿**與**不透明度滑桿**。
  2. 將粗細滑桿拉到最左與最右，確認範圍並畫一筆最細（`0.5`）與最粗（`128`）的線條。
  3. 切換到「螢幕標註模式（Screen Annotation）」，同樣點開畫筆設定面板，檢查色輪、常用色列、粗細滑桿與不透明度滑桿。
- **何謂成功**：
  - 兩個畫布的筆刷面板外觀、常用色同步、不透明度滑桿（`0`～`1`）完全一致。
  - **螢幕標註畫布的粗細滑桿範圍已與主畫布統一為 `0.5`～`128`**（不再被限制在舊版的 `1`～`32`）。

### 測試 4：大量物件畫布中新增幾何形狀與 `Ctrl+Z` 復原速度（驗證 PT-04）
- **怎麼測試**：
  1. 在 `practice-5000.heiban` 畫布中，依序使用「直線、箭頭、矩形、圓形、三角形、星形、曲線、圓規畫弧、膠帶」各畫一個物件。
  2. 每畫完一個形狀，觀察放開滑鼠瞬間是否順暢，並確認新畫好的形狀呈現選取狀態。
  3. 連續按多次 `Ctrl+Z` 逐一復原剛剛畫的形狀，再按 `Ctrl+Y` 逐一重做；接著也可穿插畫一筆自由筆、移動一個形狀，再按 `Ctrl+Z` 測試混合順序。
- **何謂成功**：
  - 在 5,000 筆物件的畫布上，放開滑鼠完成一個形狀的瞬間沒有停頓（不再整份作品深拷貝）。
  - 每次 `Ctrl+Z`／`Ctrl+Y` 都精準復原／重做單一形狀，且與自由筆、移動、改色、擦除的復原順序完全正確。

### 測試 5：自動存檔、手動切換首頁與重開作品完整性（驗證 PT-05）
- **怎麼測試**：
  1. 在作品中新增幾筆畫線、形狀與文字，觀察狀態列自動存檔，或點選左上角返回「首頁」讓系統完成保存與縮圖更新。
  2. 從首頁重新點開該作品，以及關閉 `HeiBan.exe` 後重新啟動再打開該作品。
- **何謂成功**：
  - 存檔與返回首頁過程流暢無卡頓，首頁縮圖正常更新。
  - 重新打開作品後，所有筆畫、形狀、圖層順序與頁面內容 100% 完整保留，無遺失或損毀。

### 測試 6：Store 框架相依減重候選包安裝與啟動驗證（驗證 PT-06，獨立可選）
- **候選包位置**：
  - 雙架構 Bundle（約 **98.27 MiB**，較原版 188.12 MiB 減少 **47.76%**）：`d:\Game\HaiBan x64\windows\dist\store\candidates\ponytail-fd-2026-10-31-r3\HeiBan-Store-1.0.18.0-x64-arm64.msixbundle`
  - x64 MSIX（約 **49.77 MiB**，較原版 95.28 MiB 減少 **47.77%**）：`d:\Game\HaiBan x64\windows\dist\store\candidates\ponytail-fd-2026-10-31-r3\HeiBan-Store-1.0.18.0-x64.msix`
  - 隨附 Windows App Runtime 2.5.1 框架套件（供未安裝 Runtime 2.5 的機器側載測試）：`d:\Game\HaiBan x64\windows\dist\store\candidates\ponytail-fd-2026-10-31-r3\Dependencies\x64\Microsoft.WindowsAppRuntime.2.msix`
- **怎麼測試**：
  - **注意**：`candidates\ponytail-fd-2026-10-31-r3` 為未簽章的 Store 上傳結構驗證包；若要在上傳 Partner Center 前於本機直接側載測試，需先對候選 MSIX 進行本機測試簽章，或於 Partner Center 沙盒／測試通道驗證 Windows Store 自動配發 `Microsoft.WindowsAppRuntime.2`（`>= 2.5.1.0`）後的啟動、繪圖與舊版升級作品保留。
- **何謂成功**：
  - 確認 `STORE_ARTIFACTS_1.0.18.0.json` 中 `runtimeMode` 為 `FrameworkDependent`、`entries` 為 `351`（不含 `Microsoft.ui.xaml.dll`、`DirectML.dll`、`onnxruntime.dll`），且正式 `windows/dist/store/HeiBan-Store-1.0.18.0-*` 自包含套件維持原狀不變，可由您決定下一版是否改用框架相依模式送審。

## 最終來源凍結與補充（以此節及最終驗收指南為準）

較早的ponytail-r2／FD-r3保留為歷史候選；查來源發現EditorSession、OptimizationChecks、csproj及Store script在其封裝後有追加修改，因此不把舊包作最後交付。最後加入密集擦除回退（直接倒序槽位，避免大量刪除逐件IndexOf）與延伸線全域候選驗證；`checks-final-r1`實際26項通過（前24項與新增2項），實際走訪次數不是端到端性能數字。checks-r4因資料夾已存在被保護入口拒絕，未覆寫；改用新final-r1。

十語指南同步兩畫布0.5～128pt／0～100%。新增[最終實機測試指南](OPTIMIZATION_TEST_GUIDE_2026-10-31.zh-TW.md)含一般／螢幕、物件／像素、Undo／取消／存檔與Capture步驟及成功標準。最終來源先commit，再用新的optimization-final標籤封裝，避免內嵌來源commit混用。新包使用獨立作品庫與生成測試文件，不把已存在的使用者Data打入ZIP。未啟動GUI；FD仍待乾淨機安裝／升級驗收，不替代正式10/29商店包。

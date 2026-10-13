# Windows操作與精簡優化批次（2026-10-13）

狀態：實作進行中；尚未驗收。

## 開始基線

- 日期：2026-10-13（Asia/Taipei）。公開來源起點 `c04cd797654a563e7b3a9bb6b85c02a9bdb52853`，與 `origin/main` 一致。
- 工作區既有未追蹤 `.vscode/`，保留不修改；本批只改 Windows 原始碼與 Windows 開發／操作文件。
- 主要範圍：延續 WT-01–04，把一般／螢幕畫布的工具列、面板與可用操作對齊；整理可證明重複／閒置的實作，降低不必要維護面積；針對包體依賴只做有靜態證據且不破壞執行契約的調整。
- 未授權／本輪不執行：build、測試、啟動 App、硬體效能量測、MSIX／Portable封裝、版本號變更、Store提交、刪除舊成品或其他平台變更。這些留到使用者實機階段。

## 實作中記錄

- 工作區乾淨度基線僅有既存 `.vscode/`；遠端 main 與本機 HEAD 相同。
- Graphify CLI 可用但 `graphify-out/graph.json` 不存在；本環境明確禁止子代理，先以精確 Windows 源碼／呼叫關係盤點完成分析，避免掃描產生大量與本批無關的索引產物。

## 實作進度

- 一般工具catalog是`ToolbarPreferences.AllDefaultTools`；screen原另存`ToolbarUi.ScreenTools`及`ScreenToolbarSupported`。將screen實作能力移至Core policy，工具名／順序從共用catalog投影；自訂清單與畫面建立使用同一能力範圍，尚未實作的命令不會出現空按鈕。
- 主／screen九形狀按鍵／名稱有兩份，screen手勢還有一份集合。新增單一`ToolbarUi.ShapeTools`供兩個形狀選單與screen預覽能力使用，減少多處改漏。
- screen工具列原有獨立填色按鈕，佔用一般畫布沒有的格子。現併入「圖形」選單，右鍵物件面板仍可由更多按鈕開啟，避免形狀按鈕隱藏時失去填色入口；十語手冊說明已改由圖形選單設定。
- `ScreenAnnotationWindow`每16ms渲染tick曾呼叫`GetForegroundWindow`。焦點記錄現在獨立250ms timer，切到操作穿透與結束保存時同步取樣；該timer在session啟停、停止失敗時恢復。沒有更動渲染tick或輸入預覽。
- screen套索沿用Core `LassoSelection.Intersects`，獨立保存暫態桌面座標點，拖曳時只畫預覽，放開才更新選取；Shift可將圈選加入目前選取，不建立文件物件或Undo交易。入口接入一般toolbar偏好，screen能力已新增`lasso`。
- screen可從共用工具目錄建立便條紙與遮題膠帶：便條紙沿現有文字編輯器建立並使用淡黃底色；膠帶沿既有形狀預覽建立，雙擊切換揭示狀態並記錄一筆session交易。兩項只完成screen來源接線，尚未人工驗收。
- screen圖形選單包含填色入口與共用九形狀項目，兩畫布的形狀選單及screen形狀預覽能力共用`ToolbarUi.ShapeTools`。
- screen直線停筆吸附沿用一般畫布的同一Core幾何判斷`StraightStrokeRecognizer`；screen以DPI感知的一秒timer判斷，合格時只更新筆跡預覽端點，放開才建立line物件。timer在取消／完成／Dispose時停止。普通畫布原有hold處理仍由`WindowsInkCoordinator`負責。
- Store原生ML/AI依賴約42MB，source只有meta package引用，尚無DLL級安全排除證據；Updater helper尚未AOT候選，也未動csproj／manifest，以免無測試包改動SDK部署契約。

## 範圍與驗收狀態

- 追加來源實作：新增共用Core直線幾何辨識，screen持筆時以100ms timer檢查；最後一次超過12 DIP移動後靜止滿一秒、且筆跡長度／彎曲符合門檻才吸附。screen預覽即時改為端點，指標放開後建立線段，取消／完成／Dispose都停止timer。
- 修正 Windows 主畫布與螢幕畫布按 `Delete`／`Backspace`（相容 Mac 鍵盤 `Delete` 傳送之 `VirtualKey.Back`）刪除選取物件：
  - **原因 1（WinUI 3 焦點遺失與輸入框殘留焦點）**：`MainWindow.xaml` 的 `CanvasSurface`（`CanvasControl`）原為 `IsTabStop="False"`，且 `CanvasSurface_PointerPressed` 設 `e.Handled = true`。開啟作品隱藏 `HomePanel` 或重繪 `SelectionBarTools.Children.Clear()` 後，WinUI 3 會把焦點退回 `Root` 外層的內部 `RootScrollViewer`，導致 `KeyDown` 氣泡事件未經過 `<Grid x:Name="Root" KeyDown="Root_KeyDown">`；或者使用者先點擊過屬性面板 `NumberBox`／`TextBox` 後再點畫布選取物件時，焦點仍留在輸入框而被 `e.OriginalSource is TextBox or NumberBox` 攔截。
  - **原因 2（Mac／筆電鍵盤習慣差異）**：Mac 鍵盤上的 `Delete` 鍵在 Windows 對應 `VirtualKey.Back`（`Backspace`），原本 `Root_KeyDown` 只處理 `VirtualKey.Delete`。
  - **原因 3（螢幕畫布缺鍵盤刪除）**：`ScreenAnnotationWindow` 僅右鍵選單呼叫 `DeleteScreenSelection()`，未綁定 `Delete`／`Back` 鍵盤事件。
  - **修復方案**：
    1. `CanvasSurface` 設 `IsTabStop="True" UseSystemFocusVisuals="False"`，並在 `OpenAsync`、`CanvasSurface_PointerPressed`、`FinishText`、`FinishPinRename`、`ActivateTool`、`Delete_Click`、`Undo_Click`、`Redo_Click`、`Lock_Click` 呼叫 `FocusCanvasSurface()`，確保點擊畫布或完成文字輸入後焦點回到畫布並離開 `TextBox`／`NumberBox`。
    2. `Root.Loaded` 將 `Root_KeyDown` 同時掛載於 `VisualTreeHelper.GetParent(Root)`（`RootScrollViewer`），並在 `Root_KeyDown` 加入 `if (e.Handled) return;`，支援 `VirtualKey.Delete` 與 `VirtualKey.Back`（排除 `TextBox`、`NumberBox`、`RichEditBox`、`_pinNameEditor` 編輯狀態）。
    3. `ScreenAnnotationWindow` 在 `Content` 與外層 `rootHost` 綁定 `Screen_KeyDown`，支援 `VirtualKey.Delete` 與 `VirtualKey.Back` 呼叫 `DeleteScreenSelection()`（排除 `_screenTextOverlay` 文字編輯狀態），並在選取完成時呼叫 `FocusScreenChrome()` 取得鍵盤焦點。

- 本批是WT-01／WT-03／WT-04的一部分，不是完整優化方案結案。screen仍未接入尺規、圖片檔匯入、圓規、計算機／計時器等功能；WT-02共用設定面板、WT-04全面停靠／窄視窗校正仍待續作。
- 程式簡化目前限於共用工具能力表與形狀清單，未刪除不確定的程式或資產，也沒有實際C#行數／安裝包體積改善數據。包體減重要以同來源建置並驗證必要執行元件後才能判定；42MB ML載荷仍保留。
- `python windows/scripts/Build-UserGuides.py`執行成功，產生十語手冊；`HeiBan.Windows.Core.Tests`（Release）執行通過：`PASS: 2325 Windows interaction geometry, screenshot coordinator, calculator, compass/arc, timer & offline guide checks`。
- `dotnet publish windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 --self-contained true` 執行成功（0 warning／0 error），已同步更新本機測試目錄 `windows/dist/trials/HeiBan-Windows-Portable-1.0.14-guides-2026-10-12-win-x64`（29 個 Data 檔案／922,975 bytes 完整保留）與 `dist/HeiBan-Windows-Portable-x64`（21 個 Data 檔案／788,855 bytes 完整保留），`HeiBan.dll` SHA256 `34FCC94AEF5F8BDFB2AA3AB89B00CAEEBBC95C87B86E1A02235CD1314B30C65D`，版本維持 `1.0.14.0`。待使用者實機驗收鍵盤刪除與各項交互。

## 本機實測包交付補記（2026-10-13）

- Core Release 檢查 2325 項通過；x64 Release self-contained 發佈成功；另以 PowerShell 7 執行 `Package-PortableTrial.ps1 -Runtime win-x64 -Label optimization-2026-10-13-r1`，App／Updater發佈、清單、空白Data及ZIP完成。
- 免安裝試用包：`windows/dist/trials/HeiBan-Windows-Portable-1.0.14-optimization-2026-10-13-r1-win-x64.zip`，131,764,163 bytes，SHA256 `e9f1ab87616a84f7ea1c30ddd469b86c2d14e56c6ee6e5000ce7ff334460c580`。來源以包內`TRIAL-SOURCE.json`記錄基底commit與封裝當下Windows工作樹檔案雜湊；版本仍1.0.14.0。
- 封裝時Store bundle前後SHA一致；沒有覆寫舊試用包，沒有發布Store／GitHub Release。Windows PowerShell 5.1的Git pathspec引號語法曾造成ParserError，未寫入包；改用PowerShell 7完成。未啟動此包或執行UI／WACK驗收，待使用者實機測試。

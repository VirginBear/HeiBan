# Windows 操作回饋第二階段（2026-10-11）

## 開工紀錄
- 目的：螢幕畫布工具列取消捲軸並自動換行／換列；圖層拖曳預覽；縮放與旋轉游標；箭頭頭部線寬同步；主工具列圖層入口。
- 起點：605eed4a1bec78ebd0a077d649795af5b045319b；git status 僅未追蹤 .vscode/，保留。
- 範圍：Windows 程式、文件與本機免安裝試用；私人專案記錄需求摘要和 Mac 比對依據。
- 限制：不修改 Mac、不發布商店／Release；未執行測試與桌面操作驗收。
- 本次使用者覆寫上一階段決策：箭頭頭部輪廓線寬改跟隨線條粗細，頭部長寬仍獨立設定。

## 階段 1：調查
- 現有工具列中段使用 ScrollViewer，超過工作區即產生捲軸。
- 圖層拖曳已有放開時一筆 undo，但移動中只有文字提示，缺乏跟隨圖示／插入線。
- 實際讀取命令：git status、Get-Content 開發索引／平台狀態／架構／問題、rg 搜尋工具列與拖曳引用。
- 初次 ToolbarPreferences 路徑誤寫 HeiBan.Core，讀取失敗；以 rg --files 找到 HeiBan.Windows.Core，未修改資料。

## 階段 2：實作（進行中）
- 新增 ToolbarFlowPanel 以工具所需 DIP 量測，工作區不足時換行／換列；移除工具列 ScrollViewer（圖層清單仍可捲動）。
- 新增共用 LayerDragPreview：原列淡化、同圖示／標題卡片跟隨、目標上下邊界插入線；放開或取消後清理，原一筆 undo 交易保留。
- 新增 ShapeCursor：八方向依物件旋轉角度映射 Windows 系統縮放游標；旋轉點使用自行產生的透明 AND/XOR 圓弧箭頭游標，依 DPI 尺寸建立並釋放。
- 主工具列 layers 偏好首次缺項時顯示；已存在 hiddenTools 者尊重隱藏。主畫布與螢幕畫布均接上游標回饋。
- 箭頭原生繪圖／SVG 同步 StrokeWidth；保留頭部長寬與連續線（不受虛線影響）。
- 調查時有一次私人資料讀取工作目錄混用造成找不到 Windows 路徑；後續改回公開工作目錄。未修改私人產品 JSON。

## 階段 3：建置與靜態檢視（進行中）
- 第一次 x64 Release build 成功：0 warning／0 error，40.91 秒；log `windows/.build/ux-feedback-build-2026-10-11.log`。沒有跑測試或啟動 App。
- 靜態追查 WinUI 內容橋可能重設游標，補 WM_SETCURSOR 子類化（僅畫布控制點生效），視窗關閉時移除 hook 並釋放自製游標。hover 與按下命中半徑對齊主畫布 10 DIP、螢幕畫布 14 physical px。
- 清單更新／關閉會清掉拖曳浮層，避免取消或換文件後殘留；虛擬化列仍按實際座標定位。

## 階段 4：清理
- rg 掃描正式程式／平台文件／索引無八個暫存腳本引用（exit 1 = 無命中）。逐檔核 resolved path 在 windows/.build、非 reparse point，計算 SHA／bytes 後只用 Remove-Item -LiteralPath 刪除八檔。
- 刪除清單與原因見 UX_FEEDBACK_CLEANUP_2026-10-11.json；保留失敗原因日誌、建置 log、封裝 manifest、所有已交付免安裝 ZIP/MSIX、SDK、作品／Data、歷史文件與 .vscode/。
- 固定工具列尺寸常數已無程式引用，接續移除；其他平台未動。

## 階段 5：交付來源與對照

| 需求 | 實作檔案（windows/ 下） | 理由／實際結果 |
|---|---|---|
| 無捲軸工具列 | HeiBan.Windows/Views/ToolbarFlowPanel.cs、ScreenAnnotation/ScreenAnnotationWindow.Chrome.cs／Docking.cs、ScreenAnnotationWindow.cs | 中段用工作區剩餘 DIP 自動換行／列；整段量測大小再乘 DPI；螢幕範圍改變重新量測。移除未引用固定尺寸常數。 |
| 拖曳回饋 | Views/LayerDragPreview.cs、MainWindow.Properties.cs／Rendering.cs／xaml／xaml.cs、ScreenAnnotationWindow.Panels.cs | 原列 opacity 暫時 .3，同圖示／標題浮層跟隨垂直拖曳，真實列邊界畫插入線。取消／清單重建／關閉清掉，釋放捕捉前先保存 source／target／after，避免 captureLost 清 state 影響提交。 |
| 控制點游標 | Views/ShapeCursor.cs、MainWindow.Input.cs／xaml.cs、ScreenAnnotation/NativeOverlayWindow.cs／ScreenAnnotationWindow.cs | resize index 八方向加旋轉角度；旋轉用圓弧箭頭。WinUI 內容橋 WM_SETCURSOR 僅畫布控制點覆寫；其他工具保持原游標。原生 overlay 別個控制視窗不套此 hook。 |
| 箭頭輪廓線寬 | HeiBan.Windows/Engine/Direct2DCanvasRenderer.cs、HeiBan.Windows.Core/Engine/BoardExporter.cs | native／SVG 用 o.StrokeWidth；頭長16／寬10 fallback 与獨立設定仍保留，不改 JSON；覆寫舊固定2政策。 |
| 主工具列圖層 | MainWindow.Chrome.cs、HeiBan.Windows.Core/Engine/ToolbarPreferences.cs | 可見工具增加 layers，圖示隨面板開關反白；更多／自訂也能调用。同時缺 visible／hidden 時才補可見，尊重日後隐藏。 |
| 舊診斷引用整理 | ScreenAnnotationWindow.Interaction.Validation.cs | 原 scroll host 改為 Border／wrap panel，變數与輸出欄名更新；未執行診斷，這不是本批測試結果。 |
| 說明／紀錄 | HeiBan.Windows/Assets/HeiBanUserGuide.html、README.md、docs/CURRENT_STATUS／ARCHITECTURE／DECISIONS／ISSUE_HISTORY／DEVELOPMENT_LOG、此日誌／清理 JSON | 使用入口、相容策略、症狀與原因、實際建置及未驗收同步記錄。聊天內容只放私人庫。 |

### Mac 後續比對要點

本批 Mac 未改。比對 HomeView 的一般／批次選取；Inspector 型別矩陣；LayerPanel 的跟隨預覽、插入線、取消、一筆 undo；CursorHelper 的 resize 方向需包含 rotation；螢幕列工作區／DPI 換行；箭頭 head geometry 與輪廓線寬分開。Windows 新圖釘 color/textColor 已知 Mac 旧 BoardPin 不保留，重存前需處理文件契約。私人摘要完整保留 20 項與最新5項，避免後續誤用已覆寫箭頭／捲動決策。

### 實際命令／結果

- `git fetch origin`、`git rev-list --left-right --count HEAD...origin/main`：公開／私人均 0／0，私人 PRIVATE 核對成功。
- `dotnet build windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 --artifacts-path windows/.build/ux-feedback-build-final-2026-10-11`：0 warning／0 error，25.80 秒；log 同名 `.log`。
- `git diff --check`：退出 0。JSON 清理清單 parse，八原路徑不存在、totalBytes 38,193；只作靜態資料核對。
- 包裝將用 `Packaging/Package-PortableTrial.ps1 -Runtime win-x64 -Label ux-feedback-2026-10-11`；實際結果完成後追加。
- 未執行：Core／native／UI 診斷或測試、App 啟動、實機滑鼠／4K／混合 DPI／多螢幕／觸控筆、ARM64 包、商店後台／WACK／Release 發佈。拖曳浮層與子類化游標仍需使用者實機試用。

### 清理結果

UX_FEEDBACK_CLEANUP_2026-10-11.json 已確認八檔不存在，原檔合計 38,193 bytes；無用五個尺寸常數同時移除。PowerShell 初次用 Select-Object 顯示 ordered dictionary 為空欄，並非刪除失敗；改讀 JSON 與逐檔 Path.exists 核對、重新算總量，沒有刪除其他檔案。失敗方案／建置 log 与旧交付產物保留。

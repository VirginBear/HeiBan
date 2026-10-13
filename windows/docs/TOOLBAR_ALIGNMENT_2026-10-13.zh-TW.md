# Windows 工具列一致性實作日誌（2026-10-13）

## 開工記錄

- 依使用者對 `TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md` 的「GO」，開始執行 Windows 工具列／面板對齊；不修改 macOS、Web、版本號、Store 套件或原有試用／發布產物。
- 開工 HEAD：`d3935ef6790046bf8e8d9150735580e315b22130`；`git status --short` 僅有既存未追蹤 `.vscode/`，保留。
- 已讀開發索引、Windows AGENTS、CURRENT_STATUS、ARCHITECTURE、ISSUE_HISTORY、DECISIONS 與工具列分析規格。
- 本批不執行測試、建置、啟動 App、封裝或 Store 操作；只記錄本批實際執行命令及靜態檢視。不可將來源編輯稱為已驗收。

## 開工時確認

- 一般工具偏好由 Core `ToolbarPreferences`／`toolbar.json` 提供；螢幕畫布自行建立固定 `ScreenTools`、動作列與樣式列，停靠方式另存 `screen-ui.json`。
- WinUI 控制項不能共用同一個 instance；可以共用工具描述／篩選／順序／偏好，screen 需自行建立按鈕並保留桌面穿透、螢幕座標及獨立文件 session。
- 工作內容、實際差異、未解問題、指令與 GitHub 同步結果將於進度中追加。

## 本批已寫入來源

- 新增`HeiBan.Windows.Core/Engine/ToolbarContentPolicy.cs`：一般／螢幕依同一已正規化偏好取得visible／hidden順序，screen只排除`pins`／`viewLock`。偏好schema與存檔內容不變。
- ScreenAnnotation從相同Data目錄讀`toolbar.json`；更多→自訂僅允許目前有實際screen handler的共用工具。保存透過主視窗owner更新其記憶體偏好並重建主toolbar，避免隱藏owner之後用舊記憶體覆寫剛保存的值。手動改screen-ui停靠仍使用自己的`screen-ui.json`。
- Screen toolbar中支援的catalog項目現在依一般工具順序顯隱；screen原先獨立的line／arrow／rect／circle四格收成一個Shapes入口，九種形狀使用相同選擇菜單，Core renderer已支援的四種多邊形新增screen預覽及填色。screen的clear／close與fill、palette是其桌面工作階段外殼／局部功能，保留各自入口。
- 將十個語言的`Documentation/Guides/*.txt`及`Assets/Guides`派生頁／manifest同步；簡中沿現有Windows NLS生成路徑。

## 已知未完成／未驗收

- 目前篩選故意不把缺handler項目呈現成假工具。尺規、貼紙／匯圖、圓規、計算機、計時器、套索、膠帶及完整筆跡停筆規則等WT工作未接齊；主與screen的多數panel／圖層UI也尚未抽共用(session-aware)。故仍不符合「僅圖釘與視角導航不同」的最終要求。
- 第一版程式層級共用不會直接產生可量化MSIX減重或FPS收益；WR減重方案仍只分析，沒有改依賴。
- 命令：`python windows/scripts/Build-UserGuides.py`退出0，報告十語25章55段；`git diff --check`沒有空白錯誤，Git輸出僅有換行正規化提示。這不代表C# build或App／互動驗證。
- 未執行build、tests、App、封裝、Store／Release、效能量測、版本遞增或刪除產物。故編譯與操作狀態未知，WT-01／03為局部source work，WT-02／04待完成。
- GitHub：Windows來源實作commit `0b6b79a6f8417345f97e7dfce3fbcd72a9d66b6b`已push至公開`main`；`git ls-remote origin refs/heads/main`相同；工作樹僅留下預先存在的未追蹤`.vscode/`。私人交接已另外記錄並同步；私人repo持續保持PRIVATE。

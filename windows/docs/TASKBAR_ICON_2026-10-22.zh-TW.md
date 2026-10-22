# Windows工作列圖示粉色框 — 2026-10-22

## 開工
- 基準f69419dd0e9e3f274a7a664b8b5344094123661e；保留CURRENT_STATUS／DEVELOPMENT_LOG／ISSUE_HISTORY既有YouTube未提交內容與三份YouTube新文件。只改Windows，來源版本維持1.0.15。
- 使用者截圖顯示圓角圖示外有不透明粉色方框。先讀開發入口與Windows狀態、架構、問題、決策；追AppIcon.png → AppIcon.ico → EXE ApplicationIcon／AppWindow.SetIcon與Store PNG的資源鏈。
- 不新增或執行測試；本批以資源格式檢視、編譯封裝及檔案完整性紀錄處理，工作列實際外觀待使用者確認。

## 已確認與推論
- AppIcon.png RGBA角落(0,0,0,0)、alpha範圍0–255、可見粉紫像素0；原ICO僅256px PNG一個frame。解析前批portable EXE的RT_GROUP_ICON（32512）也是同張256px透明圖、可見粉紫像素0。沒有證據是原Logo去背殘留，使用者截圖所屬Store／portable通道尚未核對。
- Store原僅9個scale PNG，沒有targetsize或unplated。Microsoft官方指出若缺少對應深／淺色unplated，Shell會補背景色板，與截圖相符。此為已確認的資源缺漏與有依據的症狀推論，Shell現場仍待確認。
- 官方來源：[Construct your Windows app's icon](https://learn.microsoft.com/en-us/windows/apps/design/iconography/app-icon-construction)，App icon／Dark theme／Light theme與backplate注意事項；[AppWindow.SetIcon](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.windowing.appwindow.seticon)。

## 實作與實際命令
- 新增Packaging/Generate-DesktopIcon.ps1：從不變AppIcon.png格式／尺寸轉換，ICO含16、20、24、30、32、36、40、48、60、64、72、80、96、256共14尺寸。小圖32bit BGRA alpha加1bit AND mask，透明像素RGB歸零；256px用PNG，無粉色key／matte。沿用既有ApplicationIcon與AppWindow.SetIcon入口。
- Store/Generate-StoreAssets.ps1新增14尺寸×default／unplated／lightunplated共42個PNG。三變體同byte、透明alpha，保留原9個scale資源；不改標誌設計、manifest、功能或文件schema。既有MSIX條件Content glob收錄，portable只使用ICO。
- 實際執行兩個PowerShell生成腳本與taskbar-icon-record.py，紀錄14 ICO frame／42 PNG尺寸、角落alpha=0、alpha範圍0–255、無可見粉紫。原PNG byte與HEAD符合。這是資源格式完整性檢查，未執行App／實作測試。
- pefile模組本機不存在，未安裝依賴；改以小型唯讀PE資源目錄解析。Pillow舊inspect腳本getdata出deprecation warning，不影響讀取，正式數值紀錄用get_flattened_data。
- 正在製作同系列x64候選；尚未建立Store新套件，既有已送審／發布包保留不變。商店通道需後續使用者核准提交更新才帶入。

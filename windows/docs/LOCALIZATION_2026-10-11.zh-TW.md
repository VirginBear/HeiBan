# Windows 十語介面開發 — 2026-10-11

## 階段 1：開工與範圍

- 使用者要求首頁可設定語言、常見十種語言，預設正體中文。只修改 Windows；保留既有 Store 送審及發行包。
- 起點公開 main 8c5fcc3；git status 僅既有未追蹤 .vscode/，保留不提交。已讀開發入口及 Windows CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY。
- 先採 zh-TW／zh-CN／en／ja／ko／es／fr／de／pt-BR／ar，已提出可選語言組合確認；沒有指定市場排名的保證。
- 調查：目前 XAML、MainWindow／ScreenAnnotation 與 Core 提供的標籤多為硬編碼正體中文；需要集中字串資源及使用者偏好，不能翻譯作品內容、文件代碼、快捷鍵、路徑或工程診斷。
- 本批不新增／執行測試，不啟動 App 或自行發布 Store／Release。實作、建置、封裝、翻譯與尚未驗收的邊界在進行中追加。

## 階段 2：入口與資源邊界

- 使用者已回覆「採用這10種」。首頁側欄新增語言選單，原生語言名永遠可辨認；預設zh-TW，不跟隨OS擅自改語言。Settings/language.json 原子保存、保留未知欄位；保存失敗不套用新語言。
- 靜態XAML採附加資源鍵＋弱引用更新；動態標籤與插值採T／F。資料名稱、作品Text、ID、JSON欄位、色碼、快捷鍵、中文停靠值保持原契約；圖層只翻譯自動產生的類型／狀態標籤。
- 阿拉伯語翻轉首頁導覽與對話文字；一般／螢幕畫布的幾何與輸入保持LTR，不鏡像使用者物件。手冊及法律文件保留原文，使用說明入口明示正體中文。
- 建置輸入採UTF-8翻譯表、固定UI來源清單、10份嵌入JSON；不需要線上翻譯服務。簡體中文以Windows NLS字形转换及區域術語表編製，其他語言人工編寫，仍需母語使用者校閱。
- 實際遇到：PowerShell字面萬用字元路徑的rg讀取失敗，改查目錄與-g；最初搜尋錯寫HeiBan.Core，改HeiBan.Windows.Core。資源編製工具stdout預設cp950無法輸出⋯，明確設UTF-8後成功列出缺項。這些是來源調查／字串編製，不是App或測試執行。


## 階段 3：介面交叉比對與建置排解

- 首次 x64 Release build（localization-build-2026-10-11）：退出0、0警告／0錯誤、53.04秒。其時570個字串；追加Core工具列11個展示名後最終581個。資源編製工具逐項檢查非空及插值索引／格式，十語皆581，missing=0；這是資源輸入檢查，未執行App或測試。
- 中文停靠／文字粗斜底線仍作内部值，只在展示處T；补屬性／螢幕停靠選單、圖層拖曳方向、共用文字色票。移除只有BOM的無意變更，現有來源沿用原BOM政策。更新服務以延遲字串保留目前狀態並於語言變更時重新求值，未更動下載安全／更新時機。
- 螢幕已存在的工具列重標tooltips及可及性名；模式字寬量測、切換作畫／操作重算尺寸，繼續換行／換列而無scrollbar。保留快捷鍵註冊失敗提示。截圖GDI提示改DrawText量測換行＋DT_RTLREADING，框選座標不變。
- 查官方ApplicationLanguages.PrimaryLanguageOverride，設定前優先本機偏好；自製字串即時刷新，WinUI內建資源可能需重啟，Portable／Store的原生控制項語言仍待實機；不假設Root.Language等於完整系統資源切換。Store來源manifest宣告十語，但本輪沒有產出新版MSIX；原送審1.0.12.0不變，下次Store更新須另增版本並提交。
- 第二次隔離build（localization-build-final-2026-10-11）失敗：1警告／89錯誤、17.61秒。根因2個CS1061：MenuFlyout不是FrameworkElement，沒有FlowDirection；其後XAML pass2缺LocalAssembly造成其餘類型／內部錯誤為連鎖症狀。修成MenuFlyoutPresenterStyle的FlowDirection Setter，普通Flyout內容仍直接設方向。失敗log保留，不把它當成功建置。
- 後續調查重複遇到PowerShell字面萬用字元rg失敗，改目錄-g；讀取Common.ps1不存在，rg找到實際Publish-Common.ps1。Python終端cp950顯示手冊亂碼是stdout編碼，UTF-8檔案本體未轉碼；後續stdout統一UTF-8。
- 官方API說明：https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.windows.globalization.applicationlanguages.primarylanguageoverride 。設定影響resource qualifier，已載入的原生資源可能不立即重載；自製JSON資源繞開此快取，框架不支援時fallback記Debug診斷。

## Mac 比對與文件契約

| Windows位置 | 目的／理由 | Mac後續比對 |
|---|---|---|
| MainWindow.Localization／XAML／Home | 首頁原生語言名、切換／即時刷新、長側欄省略 | HomeView語言偏好與入口，作品文字不重譯 |
| Localization/Strings／Ui | 原子偏好、未知欄位、弱引用固定資源鍵 | 平台自己的localization／偏好系統，不能共用Windows設定路由 |
| MainWindow各UI partial／TextStyleMenu | 純展示T/F，不改工具enum與data | Inspector／Toolbar／新建等資源覆蓋，替代中文內部值前須遷移 |
| Core LayerPresentation callback | 自動類型／狀態名稱，保持ID及Name／Text | LayerPanel展示翻譯與用戶命名界線 |
| ScreenAnnotation Chrome／Panels／Text | 既存工具列刷新、模式寬度、停靠與RTL彈出 | ScreenCanvas自適應／文字方向，native座標不翻轉 |
| GitHubUpdateService延遲Status | 背景狀態切語言不凍結 | 更新通知語言刷新與下載策略分離 |

文件schema不變，偏好檔獨立Windows Settings。未知作品欄位、用戶Text／Name和圖層undo原樣；新預設名稱依選擇語言只在建立時產生。Mac／Web未修改。手冊新增語言章節且入口明示正體中文；legal與原始OS／Core診斷保留來源語言。

### 實際命令與證據

- `git status --short`：起點僅.vscode/，後續只Windows實作／文件；保留未提交用戶內容。
- `python windows/scripts/Build-LocalizationCatalogs.py`：十語581個來源、authoringRows584、missing0；比對非空／索引／格式，非App測試。
- `windows/.build/tools/dotnet/dotnet.exe build windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 --artifacts-path windows/.build/localization-build-2026-10-11`：0警告／0錯誤，53.04秒。
- 同命令改artifacts-path為localization-build-final-2026-10-11：失敗17.61秒1警告／89錯誤；log同名.log保留。
- 同命令改為localization-build-final-r2-2026-10-11：退出0、0警告／0錯誤、28.23秒。
- 私人庫git status乾淨；讀README／AGENTS／產品JSON／狀態／日誌／摘要，fetch退出0，`gh repo view VirginBear/HeiBan-private --json visibility` = PRIVATE；未改產品JSON／示範截圖。

### 未驗收

本批未執行App、Core/native/UI tests、ARM64編譯／封裝、4K／DPI／多螢幕、十語逐頁長度、RTL可及性、母語校閱與語言偏好重啟／寫入失敗實測。未發佈Release／MSIX／Store，未啟用排程。UI／翻譯仍需試用；不能以資源581×10或build通過代替這些驗收。

## 階段 4：最終來源與封裝前

- PresenterStyle修正後r2 x64 Release建置28.23秒、0警告／0錯誤。靜態讀HeiBan.dll bytes確認十份Catalog JSON完整內嵌；literal T來源與Sources清單0缺項。未載入或執行App。
- 最後交叉比對補文字物件的粗體／斜體／底線展示T（反射IsBold等欄位不變）；隨後Portable publish將編譯此最新來源。這個晚補不冒用r2成品，其實際結果接續記。
- 檔案分類：Strings／Ui／MainWindow.Localization／581來源及10資源／翻譯表／生成器為新增；MainWindow各UI partial、ScreenAnnotation各UI partial、TextStyleMenu／TextDraftEditor／RegionScreenshotService、Core LayerPresentation、GitHubUpdateService是展示邊界變更；csproj／Store manifest／Package-PortableTrial是資源及來源SHA；WindowsREADME／手冊／平台五份紀錄與本日誌同步。具體每檔可查本批git commit diff，Mac／Web不修改。
- 封裝沿用preview.6，另Label multilingual-2026-10-11避免覆寫。Git只同步來源／文件／來源清單，不上傳二進位或Data。新包完成後才清理先前未發布canvas-setup trial，沿用保護Data／未知修改檔／publishedassets／Store的脚本；若舊程式仍開著將停止清理。

- 封裝前git diff --cached --check指出翻譯表的刻意尾端空白；改以\s顯式編碼、生成器decode，產出JSON內容不變，再核diff。沒有為消除警告移除UI連接詞所需空白。

# Windows 開發決策

## 2026-10-10 — 私人產品管理另用獨立 repo

公開 HeiBan 的技術來源／必要套件 manifest 继续維護。產品管理與跨電腦交接使用獨立 PRIVATE HeiBan-private，不把公開庫分支或子目錄視作私人區域，也不把私人 repo 放成公開 submodule。公開平台入口只連到私人庫；有權限的開發者先取回／讀取紀錄，再核最新平台來源。身份／價格／進度變動兩庫依職責分别提交，不保存密碼／權杖／私鑰。前述公開產品身分屬安裝必要中繼資料，未改寫既有公開歷史。

## 2026-10-10 — 已取得正式 Store 身分，選 SDK single-project MSIX

使用者提供 DD7EC7CF.HeiBan／正式 Publisher／純潔的熊／HeiBan 黑板及產品 9NV8T7RKV4MZ。保存必要公開套件身分，不保存其他帳戶 ID。使用原生 SDK MSIX 管道，不直接壓縮 Unpackaged ZIP；Store 與 EXE／Portable bin／obj 隔離。首份 package version 1.0.12.0，產品 preview.6 保留；後續重送更高版本須提高套件版本。MSIX／bundle 未購買 CA／未自行公開側載，交 Store 重新簽章。只使用 runFullTrust，不先增加 unvirtualizedResources 或承諾資料庫共用；首次移轉／解除安裝保留須驗收。

## 2026-10-10 — 商店身分與第一版移轉前置

正式 MSIX 必須使用 Partner Center 指派的 Identity Name／Publisher／PublisherDisplayName 及使用者保留名稱，不猜測。商店對 MSIX 重新簽章，因此不購買 CA 憑證作為商店前置。EXE FileVersion 與 Store 套件版本分開；取得身分後建立遞增的四段套件版本。首次從 Inno／Portable 遷移、資料重新導向及商店解除安裝生命週期需實際驗收，不能套用獨立版的作品保留結論。GitHub 來源同步不等於 Release 或 Store 更新。

## 2026-10-10 — GitHub 與 MSIX 更新責任

- 現有每使用者 Inno 安裝版及 Portable 使用 GitHub Releases（清單，不能用排除預覽版的 latest）；固定 VirginBear/HeiBan、windows-v 語意版本及程序架構／包類型。preview.6 預設接收預覽，可在更新設定停用背景更新或預覽。只在 App 開啟期間檢查，沒有系統排程／常駐服務。
- 不另外購買 CA 憑證作為 GitHub 更新前置；驗證 GitHub HTTPS／asset SHA 與大小，只描述平台來源與完整性，不當作獨立簽章。Microsoft Store 的 EXE／MSI 路線仍需可信任簽章；MSIX 路線由商店免費簽章／託管／更新，後續需真實 Store Identity／Publisher。
- 主視窗保存作品／教學設定／螢幕註記成功後才交接，helper 等父程序退出再套用；租約與短期互斥鎖阻止新舊同一安裝重疊替換，舊版沒有租約時補查程序。交接 work lock 重試，不強制終止使用者程序。別的視窗未關閉時保留 pending。
- Portable `update-files.json` schema：`Version` 是產品語意版本、`Files` 是相對路徑 → SHA-256 映射；排除 Data／portable.dat／清單本身。封裝時記錄全部程式檔。更新前核對舊／新清單與來源 hash，遇到修改過的已知檔、未知檔名衝突、junction 或壞路徑時改手動處理。普通失敗還原已移動程式檔；停電／強殺不宣稱完成 crash recovery，備份保留供修復。
- Installer 交原 Inno 靜默升級，不跳過其註冊／解除安裝資訊，不變作品根。helper 從安裝目錄外的個別安裝 cache 執行，pending／偏好／結果不放在作品 JSON。保留未知更新偏好欄位。更新不自動重啟，不阻止離線使用。
- `major.minor.patch-preview.N` 以語意排序，stable 高於同版 preview；Windows FileVersion stable 的第四碼為 0，不能用純數字判斷是否已轉正式。待更新架構及 installed／payload 的 PE Machine 均核對。
- 有 MSIX package identity 時不使用 GitHub 檔案替換；本批未製作商店包，不把 identity 偵測分支當作商店驗收。正常關閉／隔離 smoke 及 synthetic 更新檢查不等於實際發布後的網路／硬體驗收。

## 2026-10-10 — GitHub Windows下載只保留最新二進位

使用者明確要求更新及清理GitHub舊版本。先推相應Windows來源，draft上傳並核SHA／size後公開，確認未登入下載可用再刪已替代的Windows二進位及舊HTML。保留歷史Release／tag與SHA／manifest文本，不改寫Git歷史。原本機包與公開授權ZIP分開，公開manifest指向精確source commit，source tag不移動；Mac由其平台另行更新。


## 2026-10-10 — preview.5：右鍵用於物件操作

使用者最新要求取消右鍵切「操作」，取代preview.4的舊偏好。決定右鍵命中物件開編輯／複製／刪除，已選命中保留多選；空白取消手勢但維持作畫。穿透只由模式控制／Ctrl+Alt+D明確切換。移除物件選單的穿透項目，避免物件操作時意外把滑鼠交給下方App。保留歷史preview.4紀錄，最新行為由本條與手冊定義。


## 2026-10-10 — 螢幕物件編輯與右鍵

按使用者最新試用要求，螢幕右鍵任何位置直接切穿透；複製／刪除／文字與層級選單保留在更多 → 選取物件。色圓／線條／填滿在select時修改所選未鎖定物件，其他繪圖工具只改新物件預設；滑桿300ms合併一筆交易、換工具／穿透／保存前提交。填滿只套用有填色語意的圖形。

RegionScreenshotService保留原byte[] API供普通畫布，用CapturedRegion回傳實體桌面選區；螢幕截圖直接加入screen session，座標減去overlay原點，不寫主作品或另存截圖資料夾。Undo／Redo補載內嵌圖片，防止scene Prune後重做缺圖。Shift按主位移軸限制水平／垂直，預覽與提交及A/B端點一致。

首頁單擊選取、Ctrl／Shift多選、雙擊開啟，明確多選按鈕仍支援逐一勾選；批次移到垃圾桶保留原稿與還原。矩形／圈／直線／框選暫態只傳輸舊新bounds合併區域，無手勢換工具不重刷整屏；保留模式alpha全幅刷新與實際內容變更的scene重建。

## 2026-10-10 — 使用者指定CAD框選與預選樣式

方向只依X差，不受往上／往下拖曳影響；包含框藍色實線，碰觸框綠色虛線。框選不使用物件空白AABB誤命中，曲線依同一平滑渲染細分。顏色／線條控制是明確使用者意圖，換工具不得以舊配色蓋回；既有工具特有粗細／透明度不因此被抹平。

圖釘稱「圖釘」，畫布直接編輯，不另開改名對話框。樣式選單不能只檢查Icon非null：PathIcon填滿閉合區域，open path沒有可見筆畫；按鈕／選項要顯示當前值。快捷列原地更新樣式並依model引用重綁，避免同步顯示與操作目標分離。

## 2026-10-10 — 已量測熱點先修正，保留文件契約

以真實原生同機基準和像素等價驗證支撐性能修正。快取永久scene／排版，pointer preview避免逐點JSON；保留文件格式、未知欄位、單筆Undo與資料保存保護。snapshot共享immutable payload、隔離mutable model，hist64／32MB仍保留。新增mutable model欄位時需同步Snapshot與隔離檢查。

保存／縮圖只操作自己的snapshot；DocumentEpoch防切文件回寫。autosave與偏好移到背景／空檔，並不以省略保存提高速度。最終中位與P95只列同VM管線時間，第一輪仍有尖峰；不宣稱端到端延遲、固定fps或所有硬體已驗收。螢幕工具列配置繼續Mac1.0.12基準。


## 2026-10-10 — 基準1.0.12、緊湊列與文字交易

使用Mac Release1.0.12／20261010.4實際來源對齊橫直圖示配置、色圓面板與文字操作。Windows保留Ctrl鍵慣例（Ctrl+Enter完成）及使用者指定的截圖直接回貼／Ctrl+Alt+K清空，未改Mac來源。原生WinUI控制項樣式、材質與平台字型會有細節差異，不宣稱逐像素相同。

新增文字用草稿避免空物件或取消也留下Undo；右鍵面板焦點轉移不自動提交，點畫布／換工具／截圖／保存／結束才提交。多選文字只套用明確指定欄位，保留未改混合值、RichTextSpans與未知欄位；對文字／便簽、當頁、未鎖定範圍一筆Undo。螢幕使用實體像素儲存，8～144pt字級限制及批次設定先乘DPI，編輯器反向換算。

2026-10-10追加：發現共享Mac來源已更新1.0.9／20261010.1（其他工作變更），本輪以此快照跟進UI，不改Mac。Windows升1.0.9-preview.1；作品庫按Mac重排並補上收藏／多選，視角與頁面收左下膠囊。螢幕四邊停靠與直排重排既有控件，避免重建丟值／handlers；右鍵物件編輯優先於穿透，空白才切操作；一鍵清除不確認但一筆Undo，Ctrl+Alt+K避開Windows保留的Ctrl+Alt+Delete。


2026-10-10：依使用者作畫不順回報，先量測渲染管線。保留真實桌面與獨立session，改committed快取及dirty-region更新，不用降低螢幕解析度掩蓋瓶頸；曲線範圍含控制點overshoot、收筆含整段、雷射含前後範圍，確保刪除／消退不殘留。原生像素比對優先於純耗時；時間僅列同VM測量，不承諾fps／端到端筆延遲。


## 2026-10-10 — Mac 1.0.8 功能、緊湊螢幕工具列與清理

- 依使用者截圖對照，把螢幕工具列改為720×80 DIP兩排／720×48 DIP單排，頻繁工具圖示化，六色票與滑桿常駐；低頻命令移更多。使用原生DesktopAcrylicBackdrop，支援不足由Windows回退材質。模式切換保留z-order，不能讓疊層遮住控制列。
- 基準取 Mac 現行可操作功能；Mac 本身未交付的 Google／結構化／PDF 匯入等原型不冒充完成。Windows版本獨立編號1.0.8-preview.2，不共用Swift或改Mac來源。
- 圖層以中文類型序號、文字摘要或Name展示；所有命令仍用物件ID。Name／brushKind／tape狀態與既有Mac契約相容，未知欄位保留。
- 批次編輯提交一筆交易且保護鎖定物件；暫態雷射以有界樣本與計時器渲染，不保存筆跡。
- 螢幕畫布採原生透明Win32疊層＋獨立WinUI控制列，不用桌面截圖充作靜態背景。獨立session／lease／恢復檔，來源board/page只作截圖置入目標。
- 富文字使用 Win2D CanvasTextLayout 的 range 格式與 character regions，SVG用foreignObject保存換行／格式；其閱讀器相容性明列。PDF利用WebView2，圖片仍內嵌，不引入額外PDF字型套件。
- 直接把JSON附在PDF %%EOF之後會破壞strict parser；改合法incremental stream/xref，同Macmarker與base64不變。
- 使用者明確授權清理無用舊Windows包。先完整備份作品／垃圾桶／設定並驗證SHA，才刪舊程式、暫存、重複鏡像；只保留最新四包、當前部署及文字紀錄。保留SDK／Inno工具、所有AppData／Documents與獨立作品備份。

## 先前紀錄（歷史）


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


## 2026-10-09 — 公開 GPL 來源與限定 Windows SDK 例外

使用者明確選 GPL-3.0，並同意限定平台元件的 GPL 第 7 節連結／散布例外。HeiBan 與衍生仍須提供相應原始碼；Microsoft SDK／runtime 保持原始條款。精確 nupkg license／notice 及第三方版本清單收入公開文件與 ZIP，安裝／使用前要求閱讀並同意該元件條款。

原 preview.5 二進位 payload 不改動；Installer ZIP／Portable 另放 dist/public，重新計算公開包SHA而原 dist保留。最新來源手冊另供下載，未聲稱替換原 App 內手冊。公開 UI 功能／性能未重驗，保持 prerelease與已知限制。

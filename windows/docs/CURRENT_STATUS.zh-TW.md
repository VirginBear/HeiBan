# Windows 目前開發狀態

## 2026-10-11 — 操作回饋追加五項

螢幕工具列移除 ScrollViewer，工作區不足改換行／換列；主／螢幕圖層拖曳加入原列淡化、圖示名稱預覽與插入線；形狀八方向縮放及圓弧旋轉游標；箭頭頭部輪廓跟隨 StrokeWidth（覆寫上一階段固定 2 的策略，幾何長寬仍独立）；主工具列 layers 入口及保留隱藏偏好的遷移。

[階段紀錄／Mac 比對](UX_FEEDBACK_2026-10-11.zh-TW.md)保存原因、修改檔案、命令、清理與驗收界線。對話的精簡交接摘要保存私人庫。本批 x64 build 初次 0 warning／0 error；整合補強後最終 x64 build 0 warning／0 error、25.80 秒，封裝結果接續記錄。測試、App、4K／DPI／滑鼠實機均未執行。已交付 ZIP、Store bundle、SDK、Data、歷史保留；僅清理八個一次性腳本，見[清單](UX_FEEDBACK_CLEANUP_2026-10-11.json)。


本輪新 x64 免安裝包 `dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-ux-feedback-2026-10-11-win-x64.zip`，131,541,143 bytes，SHA256 `e77d2dd28526fc70b0f9049cf96d68d22c1156373bf6044c5e79d6ac719c1aa7`；來源 77a563d，App/helper publish 退出0／無warning/error。557 inventory／106 source SHA／空 Data／PE／guide／README／sidecar 靜態一致，Store原SHA相同。[artifact](UX_FEEDBACK_PORTABLE_ARTIFACT_2026-10-11.json)／[靜態檢視](UX_FEEDBACK_PORTABLE_INSPECTION_2026-10-11.json)。未執行測試／App／實機操作，未發布 Release／Store。


## 2026-10-11 — Windows 20 項操作調整

已接上首頁開啟／一般選取／圓形多選、停筆一秒直線預覽、百分比尺長、依物件分類屬性、箭頭頭部獨立尺寸、個別圖釘配色、延伸入口移入屬性、紙張便條視覺、上下視角鎖定同步、独立圖層與拖曳排序、雷射再次點擊設定、存檔勾號／虛線圓、屬性四邊停靠；螢幕畫布增加橡皮擦預覽、內容量測工具列、圖層與調色盤。

最終本機 x64 試用：`dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-ux20-2026-10-11-r2-win-x64.zip`，131,531,917 bytes，SHA `c7c9cd4d23e300f8c3e68b5ecbac763432e4fbcde782aba8ded075cce0f252e3`；同名資料夾直接啟動 HeiBan.exe。[產物](UX20_PORTABLE_ARTIFACT_2026-10-11.json)／[靜態檢視](UX20_PORTABLE_INSPECTION_2026-10-11.json)。來源 e60728d，App／helper publish 退出 0、log 無 warning／error，557 inventory／103 source SHA／空 Data／PE／手冊／sidecar 核對完成。補強四邊面板留白以避免蓋工具列；第一份候選與舊包均保留。

第一輪／第二輪 x64 build 已退出 0，第二輪 0 warning／0 error。本批未執行 Core／native／實際 UI 操作測試；20 項實體滑鼠、4K DPI、多螢幕驗收仍待使用者試用。完整入口、類型矩陣、原因、命令與限制見[本批紀錄](UX_ALIGNMENT_2026-10-11.zh-TW.md)。本機免安裝另以 ux20 標籤製作，來源版號維持 preview.6；沒有發 Release 或改 Store 送審版。

## 2026-10-11 — 第二批本機x64免安裝試用包可用

使用者要求未發布版本仍可試用，已另製作`dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-perf2-2026-10-11-r2-win-x64.zip`與同名直接啟動資料夾。完整解壓、雙擊HeiBan.exe，作品存自己Data。Label区分同version歷史包，沒有覆寫原dist或Store1.0.12.0；ZIP只在本機，未發GitHub Release／Store。初包保留，最終r2補強封裝guard後重出。

App／helper self-contained x64 publish与封裝退出0、無warning/error，557 payload逐SHA／空Data／PE／版本／sidecar／93來源SHA核對完成；本批未執行新App／Core／native／smoke測試，前批2324／127是歷史來源驗收。原bundle SHA相同，ARM64本批未封裝。來源／檔案／命令／限制见[本批紀錄](PORTABLE_TRIAL_2026-10-11.zh-TW.md)、[產物清單](PORTABLE_TRIAL_ARTIFACT_2026-10-11.json)。Git同步封裝入口與紀錄，不包含本機ZIP／作品。

## 2026-10-11 — 第二批渲染候選索引

完成PERF04渲染分支：大而稀疏視野採網格，保留stable Z與live頁面／visibility，小／密集／超界回原scan、複雜型別保守global。非序列化bounds counter、交易內geometry增量更新、Z/list／Cancel／Undo替換重建。Hit／擦除／框選沒有接index，PERF04整項仍待辦；PERF05 GPU分區未實作。

本批2324 Core、127幅零容差pixels、x64／ARM64 Release publish通過、無warning/error訊息（ARM64未實跑）。Sparse10000 CPU p95 scan0.36124→grid0.07980ms、單物件更新0.08176ms，cold／配置成本另記。完整scene pan兩組6.3884→4.2346、4.8220→5.4971ms，不一致，不能宣稱整體FPS／端到端延遲达標；dense pan仍約196ms。下一批PERF05優先但需新基準／GPU預算設計。

[日誌](PERFORMANCE_BATCH2_2026-10-11.zh-TW.md)、[raw資料／限制](performance/2026-10-11-batch2/README.zh-TW.md)。版本／送審bundle SHA／私人三圖保留；無新Installer／MSIX／Release／Store操作／硬體矩陣驗收。既有.vscode/保留不讀／提交，其他平台未改。

## 2026-10-10 — 流暢度第一批實作與同機證據

使用者對九項清單指示 GO，完成首批的軟體基準、熱路徑配置改善及穩定 Z 順序快取。命中保留 locked／同 Z 次序，交易內直接 Z／list 修改、切頁、Cancel／Undo／Redo 均涵蓋；單物件 preview 不排序，筆跡 damage 索引掃描尾端四點不丟輸入。另修現有 overlay bitmap copy 色階差異，所有像素規則維持零容差。

本次754 Core checks、70個嚴格像素比較及其他曲線／雷射／idle契約通過；x64與ARM64 Release publish退出0，ARM64僅編譯未實跑。10000物件CPU順序p95 2.11462→0.15780ms、命中3.35256→0.33602ms；配置量明顯下降。原生大量場景重建／平移／縮放p95未一致改善，不能宣稱整體FPS提升。PERF-01／02仍缺busy timer、保存期间操作與實體輸入／DPI驗收；04／05是下一批優先候選，06只做現有copy相容修復，07／08與09硬體矩陣仍待執行。

[實作日誌](PERFORMANCE_BATCH1_2026-10-10.zh-TW.md)、[原始樣本／重現命令／限制](performance/2026-10-10-batch1/README.zh-TW.md)、[更新工作清單](ANTIGRAVITY_PERFORMANCE_WORKLIST_2026-10-10.zh-TW.md)。建置與資料全部在新隔離.build目錄；Store 1.0.12.0原bundle SHA前後一致，未更版／重封Store包／發GitHub Release／操作Partner Center。現有.vscode/保留且不提交；Mac／Web與私人產品素材未修改。

## 2026-10-10 — Antigravity 流暢度工作清單已編製

使用者要求列出可交接的修改工作。已依當前來源整理 [九項工作清單](ANTIGRAVITY_PERFORMANCE_WORKLIST_2026-10-10.zh-TW.md)，含現況、優先順序、依賴、定位、修改策略及驗收條件；第一批為 PERF-01 基準、02 熱路徑與排程、03 排序快取。空間索引／分區快取／GPU 合成／獨立輸入／保存記憶體皆依量測與相容驗收展開，不預先承諾收益。尚未執行本輪實作／效能測試／建置／封裝或 Store 操作；送審 1.0.12.0 保留。[編製紀錄](PERFORMANCE_WORKLIST_LOG_2026-10-10.zh-TW.md)。

## 2026-10-10 — 可接續下一版 Windows 開發

目前 Store 1.0.12.0 仍以使用者提供的「認證中」為最新已知狀態；可以開發下一版，GitHub source 更新不會修改已上傳的套件。保留送審 build source aa71e35／原始套件／產物 SHA／私人三張截圖作該版本證據。下一版功能與版本號尚未指定，本批只更新交接紀錄，沒有改程式／提高版本／重封包／測試或 Store 操作。後續正式更新需遞增套件版並另行提交認證。[交接紀錄](NEXT_VERSION_HANDOFF_2026-10-10.zh-TW.md)。

## 2026-10-10 — Store Submission 1 已送審，認證中（使用者提供）

使用者貼出 Partner Center「產品提交：認證中」及「通過認證後立即開始發佈」，已自行完成首次提交；尚未確認通過或已上架，助手未登入後台查證。前次套件 Validated／提交按鈕問題與此次進度見 [本批紀錄](STORE_SUBMISSION_2026-10-10.zh-TW.md)。三張經使用者授權的 Store 示範截圖原 byte 保存於 PRIVATE HeiBan-private，不放入公開程式庫；可跨電腦 clone／pull 取回。當前等待認證結果，未啟用查詢排程。未重封包、執行 App／WACK 測試或修改其他平台；下方「尚未送審」為前批歷史狀態。

## 2026-10-10 — 跨電腦私人產品紀錄已建立

使用者要求私人保存產品資訊，已建立 [HeiBan-private](https://github.com/VirginBear/HeiBan-private)，GitHub visibility 核對 PRIVATE。包含完整產品紀錄、Store 策略／待辦與多電腦交接；開發者需有權限，先讀私人庫 README／AGENTS／PRODUCT_INFORMATION／CURRENT_STATUS，再讀本平台文件。公開庫只保存技術必需識別與讀取入口，不複製私人管理欄位；沒有改程式／重封包／執行測試或 Store 操作。[本批紀錄](PRIVATE_RECORDS_2026-10-10.zh-TW.md)。

## 2026-10-10 — 正式 MSIX／bundle 封裝完成，尚未送審

使用者提供 HeiBan 黑板正式 Product identity，並確認第一版免費。Windows Store SDK single-project MSIX 明確 build 模式，原 EXE／Portable 路線分開。首份套件版 1.0.12.0／產品 preview.6；最後 x64／ARM64 建置各 0 warnings／0 errors，兩份 MSIX 及一份雙架構 bundle 產出。實際包身分、最低 OS 19041、PE Machine、25 份授權與手冊原 byte、不帶作品／helper／symbols、bundle 內 MSIX SHA 通過，135 個來源／3 產物 SHA 相符。[產物清單](STORE_ARTIFACTS_1.0.12.0_2026-10-10.json)。

來源 `aa71e3584ff91b9f5832f9abec66980049d34aa4` 已 push，ls-remote HEAD／main 相同。見 [本批紀錄](MSIX_PACKAGING_2026-10-10.zh-TW.md)、[商店草稿](STORE_LISTING_DRAFT.zh-TW.md) 與 [隱私草稿](PRIVACY_POLICY_DRAFT.zh-TW.md)。未簽章包供 Store 送審，未購買 CA。商店安裝／資料遷移／更新／解除安裝／WACK、ARM64 執行、送審／上架未執行；本批未執行 App 測試。下方「身分待提供」與「尚未產生 MSIX」均為前批歷史，不是目前狀態。

## 2026-10-10 — Partner Center 已申辦，商店準備與來源同步

使用者告知已申辦帳戶，要求紀錄並更新 GitHub。已建立 [商店準備清單與當批日誌](STORE_PREPARATION_2026-10-10.zh-TW.md)，整理正式 MSIX 所需三項產品身分與保留名稱、免費商店簽章、送審素材及資料遷移驗收。尚未檢視私人後台或取得身分，MSIX／Store 送審未完成。本批同步上一批 Windows preview.6 來源；下方「未 commit／push」為上批結束時狀態，實際同步結果以本批日誌為準。GitHub 公開下載仍為 preview.5，未新增 Release。

Windows preview.6 自動更新來源與紀錄已 commit／push：`27c968dc80766d78eb1dac3d2305d32ee2f5c63e`。本機 HEAD 與遠端 main／HEAD 核對一致，push 後工作樹乾淨；本段結果另以文件提交保存。只同步來源不會讓既有安裝版收到新版本。

## 2026-10-10 — 1.0.12-preview.6 GitHub 自動更新（完成本機交付，未發布）

Windows 來源升至 1.0.12-preview.6／FileVersion 1.0.12.6。首頁關於 → 更新設定、畫布更多 → 檢查更新與更新設定；GitHub 版啟動約十秒後及開啟期間每六小時背景檢查／下載，支援停用與預覽管道。按 Windows tag、語意版本、程序架構及 Installer／Portable 篩選，HTTPS 固定 repo／轉址白名單、size／GitHub SHA-256 驗證。

保存成功後交給自包含 helper，等待父程序退出及同一安裝所有視窗關閉。Installer Inno 靜默升級；Portable 宣告檔案清單及 hash 預檢、備份／普通失敗 rollback，保留 Data／portable.dat／未知檔。新增關閉重入防護、交接鎖重試、待更新與已安裝 PE 架構核對、preview → stable 語意比較。Package identity 下不執行 GitHub 更新，由 Store 管理。

本批最後來源 73 更新檢查及 700 Core／手冊檢查實際通過，隔離 x64 真 helper／真 Inno 流程（含鎖重試、preview→stable、其他視窗延後）通過；最終 x64 真 HeiBan 隔離啟動／正常關閉退出 0。兩架構 EXE／Portable 四包封裝退出 0、compiler warning／error 0，Portable x64 555／ARM64 551 個 inventory 檔逐 SHA、架構／手冊／README／空 Data／sidecar 通過。見 [最終產物與來源 SHA](ARTIFACTS_2026-10-10_1.0.12-preview.6.json)。ARM64 本機執行、真正 GitHub 新 Release 發布後更新、完整硬體操作／Store 封裝及送審未執行。MSI／MSIX 未產生，未 commit／push／發布，公開版本仍 preview.5；舊版需先手動裝含更新功能版本。SHA 驗證不是 Authenticode，未購買簽章憑證。見 [本批紀錄](AUTO_UPDATE_2026-10-10.zh-TW.md)。

## 2026-10-10 — GitHub Windows 1.0.12-preview.5（已公開）

x64／ARM64各提供Installer ZIP及Portable ZIP，[新版下載](https://github.com/VirginBear/HeiBan/releases/tag/windows-v1.0.12-preview.5)。相應source fddf85e已推main且tag一致，77build-source blob保持相等；公開Portable原entry／Installer原EXE逐byte相同，7assets遠端size／digest與本機相符，7個未登入下載HEAD均200。

GitHub舊Windows四ZIP及舊HTML已清除，保留歷史Release／tag、原說明及2個manifest文本；本機只留p5原4包及公開4ZIP。Mac來源／公開Release與所有作品／備份保留。沒有為本次上傳重跑程式測試，沿用已核SHA不變的700Core／ARM64原生／PDF成果，x64實機及完整Installer升級仍未驗收。下方「本機交付，未發布」為之前工作的歷史邊界。[公開紀錄](PUBLIC_RELEASE_2026-10-10.zh-TW.md)、[遠端雜湊](GITHUB_ASSETS_1.0.12-preview.5_2026-10-10.json)、[遠端清理](GITHUB_CLEANUP_2026-10-10.json)。


## 2026-10-10 — 1.0.12-preview.5 右鍵物件操作（完成本機交付）

最新Windows為1.0.12-preview.5／FileVersion1.0.12.5。依最新指示取消螢幕右鍵自動穿透：右鍵物件開調整／複製／個別刪除選單，命中已多選物件保留整組；空白右鍵取消暫態但維持作畫，選取不新增Undo。穿透由模式按鈕或Ctrl+Alt+D切換。下方preview.4及更早條目保留歷史偏好，不代表最新操作。

700Core Release及本輪ARM64原生result／screen-result同輪success，實際右鍵選單／空白不切模式／文字多選、副本刪除Undo通過；樣式、截圖、36preview幀byte等價回歸及PDF strict通過。77來源雙鏡像SHA一致，兩架構四包退出0／兩次Successful compile，包內版本／當前手冊／README／授權／空Data與SHA核對通過。

模擬機Current唯一程序11412、捷徑及549payload逐SHA通過；56Data檔SHA保全vm/c7、2目前作品＋9垃圾桶共11份，歷史c12至c6作品全部涵蓋。已清p4舊包／payload與建置鏡像1,965,162,051bytes，QA備份r5a；SDK／Inno／所有作品與歷史備份保留。未改Mac，未commit／push／發布。CUA右鍵／工具列點擊未產生可靠回應，未算硬體驗收；完整硬體／IME／多螢幕／混合DPI／手寫／x64實機與Installer升級未執行。

[右鍵修正紀錄](WINDOWS_RIGHT_CLICK_REVIEW_2026-10-10.zh-TW.md)、[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.5.json)、[清理紀錄](CLEANUP_1.0.12-preview.5_2026-10-10.json)。

## 2026-10-10 — 1.0.12-preview.4 螢幕物件與多選（完成本機交付）

本輪只改Windows。色圓／線條／填滿在選取工具下直接改已完成物件，支援未鎖定多選及滑桿合併Undo；截圖成為螢幕session原位置圖片，尺寸／旋轉／Undo／Redo，沒有寫主作品。Shift限直線／箭頭水平或垂直，包含A/B端點；首頁單擊選取／雙擊開啟、Ctrl／Shift或明確多選，批次垃圾桶／還原。右鍵直接穿透，物件命令在更多 → 選取物件。

Core Release700項通過，最終原生r3 result／screen-result皆success及PDF strict成功；77來源與native／package鏡像SHA一致。新36預覽／收筆幀逐byte一致，傳輸705245184→6114048bytes，中位24.7323→1.824ms（同步render，非硬體輸入延遲）；idle換工具不render。兩架構四包封裝退出0，兩次Successful compile、無compiler warning／error；SHA、架構、PRI／runtime／品牌／當前手冊／README及25份授權逐byte通過，ZIP空Data／無QA作品。

CUA可讀模擬機，但切換隔離QA click回noWindowsAvailable -10005；未算硬體點擊驗收。完整中文IME、手寫、混合DPI、多螢幕、x64實機及Installer升級未執行。前期r1／r2失敗與修正保留，見[本輪稽核](WINDOWS_SCREEN_OBJECTS_REVIEW_2026-10-10.zh-TW.md)。Mac未改，未commit／push／發布。


最終Current為1.0.12.4，唯一程序7720／捷徑及549payload逐SHA通過。正常關閉前後SHA備份vm/c6，56Data檔完整保留、2目前作品／9垃圾桶共11份，歷史c12／c2／c3／c4／c5作品全部仍在。舊Current全部bytes可由舊封裝與保全Data解釋，未知bytes0；更新前亦檢查未知payload檔案。只留最新四包／Current，已清舊p3包／payload及建置鏡像共1,967,680,113bytes；QA先SHA備份e4a～c，SDK／Inno／所有作品保留。見[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.4.json)及[清理紀錄](CLEANUP_1.0.12-preview.4_2026-10-10.json)。

## 2026-10-10 — 1.0.12-preview.3 操作修正（完成本機交付）

最新 Windows 為1.0.12-preview.3／FileVersion1.0.12.3，Mac基準1.0.12／20261010.4。圖釘圖示／原位改名、游標位置滾輪縮放、CAD雙向框選、第一／第二點曲線預覽、顏色／線條跨工具保留、目前線條樣本、直列不擠壓、截圖灰霧已修；切工具關浮窗、暫態預覽不重建永久scene、模式切換正確重建輸入alpha。詳見[本輪稽核](WINDOWS_INTERACTION_REVIEW_2026-10-10.zh-TW.md)。

Core680項通過，最終ARM64原生r7 result／screen-result皆success，包含Win2D四線像素、兩階段曲線、GDI遮罩、圖釘Undo、20按鈕尺寸、暫態快取及模式alpha0／1；PDF strict通過。76個native／封裝來源SHA一致，兩架構四包SHA、架構、PRI／runtime、當前手冊／README及25授權逐byte通過，ZIP空Data／無QA作品。

模擬機Current已更新、唯一新版程序與桌面「黑板 Windows 最新版」，549payload檔逐SHA通過。正常關閉前後備份vm/c5，51Data檔保留、2目前作品／8垃圾桶，歷史c12／c2／c3／c4作品全部仍在；移除舊Current前其全部bytes可由舊payload與保全Data解釋，未刪未知資料。最新四包見[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.3.json)。

Mac鎖定使最後實體點擊未驗收；完整手寫、中文IME、混合DPI、多螢幕、x64實機與Installer升級未執行。Mac來源未改，未commit／push／發布。舊包／鏡像清理及所有資料保全見[清理紀錄](CLEANUP_1.0.12-preview.3_2026-10-10.json)。

本輪舊包／payload／鏡像合計移除3,612,977,725bytes（檔案大小總和），只留最新四包；QA資料先逐SHA備份i3a～g，SDK／Inno及使用者資料保留。

## 2026-10-10 — 1.0.12-preview.2 流暢度修正

此輪只改Windows，Mac基準仍1.0.12／20261010.4。修普通畫布scene／文字排版快取、Selected O(N²)掃描、長筆跡JSON快照／移動、隱藏圖層重建與保存交錯；縮圖／偏好／搜尋改空檔或合併背景工作。螢幕選取拖動局部讀回、手勢中延後保存；維持單排／四邊配置、右鍵物件選單、Ctrl+Alt+K清空／復原與截圖回貼。

Core Release568項通過；原生ARM64 result／screen-result皆success，9普通畫面＋22螢幕幀逐byte等價。最終300物件重繪中位31.3325→1.5991ms，螢幕30.331→4.4957ms，非硬體延遲。第一輪仍有快取P95尖峰；完整硬體／IME／混合DPI／x64實機與Installer升級未完成。[稽核報告](WINDOWS_PERFORMANCE_REVIEW_2026-10-10.zh-TW.md)與[量測數據](PERFORMANCE_1.0.12-preview.2_2026-10-10.json)。

交付完成：兩架構四包SHA／架構／PRI／runtime／品牌／當前手冊／README及25份授權逐byte核對通過、ZIP空Data／無QA作品。ARM64 Portable88.44MiB／Installer61.00MiB；x64 Portable91.02MiB／Installer63.50MiB，精確大小與SHA見本版manifest。

模擬機Current更新至FileVersion1.0.12.2，唯一程序與桌面「黑板 Windows 最新版」，549檔與ZIP逐SHA一致；CUA已查看最終新單排工具列及雷射顯示。正常關閉舊程式前後備份vm/c3、37個Data檔完整保留，現行1份作品／6份垃圾桶；先前c12的6個作品ID均仍存在於此次Data，c12亦保留。資料位置不因封裝改動。

舊p1四包／sidecar、舊Current payload及建置／QA鏡像移除，本批初次交付與曲線補正重封合計3,606,237,162 bytes（約3.61GB），QA資料先逐SHA備份；SDK／Inno／原AppData／Documents及所有作品備份不刪。歷史SHA與文字日誌保留。[封裝清單](ARTIFACTS_2026-10-10_1.0.12-preview.2.json)／[清理紀錄](CLEANUP_1.0.12-preview.2_2026-10-10.json)。


## 2026-10-10 — 最新本機版本 1.0.12-preview.1

Windows **1.0.12-preview.1**（FileVersion1.0.12.1）以Mac **1.0.12／20261010.4**為基準。螢幕工具列改單排820×60 DIP、直式64×688 DIP純圖示，色圓開獨立280 DIP色彩／粗細／透明度面板（3×2色票、垂直滑桿）；短畫面只捲中段，模式及清空／結束可達，去掉固定文字／狀態列與多餘空白。作品庫側欄／卡片及左下視角膠囊延用Mac配置。

補T螢幕文字、Enter換行／Ctrl+Enter完成／Esc取消、雙擊重編輯；普通畫布／螢幕／草稿共用文字右鍵設定，字級8～144、顏色、字型、對齊、透明度及粗斜底線。Shift／框選可多選，批次只改指定欄位、保留混合值與未知富文字欄位、限當頁未鎖定文字／便簽、一筆Undo。僅選取不增加Undo。保留右鍵物件操作／空白穿透、一鍵全清除與Ctrl+Alt+K，以及截圖直接回貼。

本輪Core／手冊**543項**通過；ARM64原生中文草稿、取消／雙擊／換工具、多選右鍵及樣式復原、四邊尺寸、透明層與控制列次序、原作品未污染、Win2D／向量PDF通過。200%DPI實測橫列1640×120px、直列128×1376px，66個來源逐SHA一致。完整對照及限制見[功能表](MAC_1_0_12_PARITY_2026-10-10.zh-TW.md)。

四包已封裝，見[產物與SHA](ARTIFACTS_2026-10-10_1.0.12-preview.1.json)。模擬機已更新C:\HeiBanPreview\Current，桌面「黑板 Windows 最新版」，唯一新版本程序及549個payload逐SHA一致。現有34個Data檔案（含4目前作品）先備份再遷移核對，其他作品／AppData／Documents保留。Mac來源未改；未commit／push／發布。

Mac鎖定使本輪CUA畫面確認未執行；原生合成驗證不等於真實指標／中文IME／多螢幕／混合DPI／觸控筆驗收，x64實機與Installer安裝升級未執行。

本批清理合計1,964,671,701 bytes（約1.96GB），只留最新四包／Current，作品及文字歷史均保留。見[清理摘要](CLEANUP_1.0.12_2026-10-10.json)。

## 1.0.9 交付紀錄（歷史）

## 2026-10-10 — 最新本機版本 1.0.9-preview.1

最新來源及試用封裝改為 Windows **1.0.9-preview.1**（FileVersion 1.0.9.1），對齊 Mac 1.0.9／20261010.1 可操作功能。新增Mac配置作品庫側欄／收藏／篩選／排序／卡片／多選、左下視角膠囊，及四邊停靠／左右直排／可收合的透明螢幕畫布、中文／可改名圖層、多選／套索、膠帶／雷射、富文字與便簽風格、裁切／射線、浮動工具與自訂倒數、頁面／視角管理、多格式匯出。螢幕物件右鍵可複製／副本／刪除／鎖定／層級；主列垃圾桶及Ctrl+Alt+K一鍵全清除，可復原。完整對照見 [功能表](MAC_1_0_9_PARITY_2026-10-10.zh-TW.md)。

螢幕繪圖已改已完成筆跡快取、局部像素讀回／上傳及16ms排程，未落筆懸停不重繪。同一VM原生80樣本舊策略中位66.38ms→5.15ms，18組畫筆／螢光筆／收筆像素比對與雷射清除無殘影通過；這不是實體輸入延遲測量，見 [效能紀錄](SCREEN_CANVAS_PERFORMANCE_2026-10-10.json)。

本輪實際 Core／手冊527項通過，ARM64原生建置與真實 Win2D／PDF／screen API 管線通過；中文 PDF 能以 strict parser 開啟並保留向量及可編輯原稿。透明控制列已查看，未宣稱完整指標／多螢幕／觸控筆／x64 實機或安裝升級通過。

最新四包位於 windows/dist；模擬機部署固定 C:\HeiBanPreview\Current，桌面「黑板 Windows 最新版」。Portable Data 由舊試用版保全後遷移；其他舊作品保存在 windows/recovered-user-data/2026-10-10，AppData／Documents 原作品不刪除。本機舊 preview 包／建置暫存清理約7.83GB，文字紀錄保留；GitHub舊公開版不變，未commit／push／發布。本輪建置／產物／清理的實際結果見 [BUILD_STATUS](BUILD_STATUS.zh-TW.md)及產物清單。

## 先前紀錄（歷史）


更新：2026-10-09。

## GitHub 公開預覽整理

原始碼已公開；本次只整理文件與下載包，不修改 Windows 功能、不重建／不執行測試套件。原創採 GPL-3.0-only 加 [限定 Windows SDK 例外](../LICENSE-WINDOWS-EXCEPTION.txt)，使用者已同意。公開 Installer ZIP 包裝原 EXE，Portable 保持 payload 並加入原始授權；ARM64／x64 各兩包，另附最新版來源 HTML。新公開雜湊見 [下載清單](../../docs/releases/windows-0.1.0-preview.5.assets.json)，原 dist manifest 保留。7個 assets已公開為prerelease，遠端digest／大小及4個主要下載HEAD已核對；來源tag指向991835a。發佈期間後續程式變更未收入該tag，保留本機供後續開發。實際發佈證據見 [公開稽核](../../docs/PUBLIC_RELEASE_2026-10-09.zh-TW.md)。

## 原 preview.5 開發批次與驗收（歷史）

**最新可試用封裝：0.1.0-preview.5**。Codex已整合Antigravity第0／1批來源、修復Windows原生編譯、截圖與圓規／arc邊界，完成ARM64／x64自包含Portable ZIP與安裝檔；不是第2～5批全部功能完成。見 [建置與驗收範圍](BUILD_STATUS.zh-TW.md)、[產物清單](ARTIFACTS_2026-10-09_preview5.json)。

- Windows 11 ARM64模擬機內已查看首頁、隔離空白文件畫布與最終Portable畫布。新版在 `C:\HeiBanPreview\preview5`，Windows桌面捷徑「HeiBan preview.5」，模擬機保留running供使用者試用。Portable作品保存在該資料夾的Data，不覆蓋舊作品。
- Core／手冊 **475項檢查通過**；原生截圖harness確認100×50 BMP裁切與兩次框選取消／清理。四包SHA-256、ZIP必要PRI／執行庫／品牌／手冊、PE架構與空Data檢查通過。
- 第0批：截圖採App自有區域框選，完成直接置入圖片物件，不另存截圖資料夾。請求綁定文件／頁面／視野，取消與逾時處理保留；快速操作列、樣式、工具排序沿用前批修正。
- 第1批：右上浮動導覽／收合、計算機括號與鍵盤／插入、圓規畫布預覽與掃弧、arc起訖控制點與等比縮放、背景計時器、圖片基礎與離線繁體中文手冊已有來源並收入本版。
- 本輪追加：半徑把手改65%位置，鎖定後不攔截筆尖；arc端點優先命中、跨0°連續、邊把手可縮小。修正Count()、命名空間、VirtualKey、尺框呼叫及PS5.1中文腳本編碼。
- **仍待驗收／開發**：完整滑鼠拖曳／色輪／A-B端點／圖片旋轉／尺支點／截圖置入操作、完整浮窗及自訂計時設定、x64實機、安裝升級／解除安裝、手寫硬體與性能。CUA在Parallels內的點擊未觸發新增視窗，不能據此宣稱UI回歸全部通過。
- W-S01入口位置已定：右上導覽列閱讀模式旁的螢幕圖示、首頁完整名稱按鈕，工具列更多備援；功能本體與可操作入口尚未實作，詳見主計劃第6節。來源手冊第18節已更正為規劃狀態；既有preview.5包內舊手冊文字待下次封裝更新。
- 第2～5批仍未完成：雷射／遮題／透明螢幕畫布、結構化筆記、媒體與管理、隱私與線上。下一輪按 [開發計劃](WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md) 推進。

本版沿用preview.4的直線／箭頭A-B、圖片把手、選取顏色、作品列收合與尺邊支點來源。歷史複核見 [Antigravity進度紀錄](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md)，歷史完成聲明不等於全部互動已驗收。

維護：[開發日誌](DEVELOPMENT_LOG.zh-TW.md)、[問題紀錄](ISSUE_HISTORY.zh-TW.md)、[決策](DECISIONS.zh-TW.md)、[架構](ARCHITECTURE.zh-TW.md)。

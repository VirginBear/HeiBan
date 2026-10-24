# 黑板 · Windows 原生版

## 2026-10-22 Microsoft Store 1.0.16.0更新

使用者已確認本次1.0.16／1.0.16.0進版，包含10/22系列工具列、操作指南、筆跡／擦除、磁鐵與工作列圖示改善。雙架構提交包的實際完成狀態、SHA與未驗收事項見[本批紀錄](docs/STORE_RELEASE_1.0.16_2026-10-22.zh-TW.md)；版本說明見[十語文案](docs/STORE_WHATS_NEW_1.0.16_2026-10-22.md)。Microsoft認證／發布依實際後台結果，不由本機包推定。

## 2026-10-22 新系列開發

工具預設全開、首次建立可編輯操作範例、畫筆完成不自動框選、逐筆交易／畫面與切筆刷新整理、板擦縮短20%。沿用1.0.15 metadata作開發候選，不自動送審或正式進版；實際成品與未驗收項見[本批紀錄](docs/DRAWING_FLOW_2026-10-22.zh-TW.md)。

## 2026-10-15 商店更新

使用者已同意本次系列更新，正式套件版本採1.0.15.0。套件、來源、提交及認證狀態以[本批日誌](docs/STORE_RELEASE_2026-10-15.zh-TW.md)為準，歷史候選／試用清單不代表最新上架版本。商店包包含x64與ARM64，採Store更新通道；本機試用作品不隨套件上傳。

## 2026-10-15 畫布操作與一致外觀修整

新增一般畫布生成木質板擦、單排圖文工具組／可自訂常用、完整幾何磁鐵與中心式圖形起點、匯入圖片化說明、圖釘新增優先與固定品牌淺色。維持1.0.14開發候選；新版試用交付與未驗收項見[階段紀錄](docs/CANVAS_UI_REFINEMENT_2026-10-15.zh-TW.md)，不代表正式商店更新。

2026-10-15：[繪圖與文件交換開發批次](docs/DRAWING_WORKFLOW_2026-10-15.zh-TW.md)。新增PDF頁面匯入、依本機桌面PowerPoint轉換PPT/PPTX、多頁PDF匯出、磁鐵、連續繪圖、雙擊詳細屬性、圖示／圖文分頁工具列及四張實機圖的十語手冊。PDF／簡報頁面匯入為可註記圖片；動畫、原元素編輯與缺字型相容性有明確限制，詳[交換契約](docs/DOCUMENT_EXCHANGE_2026-10-15.zh-TW.md)。版號沿用1.0.14開發候選，試用產物及實際驗證見目前狀態。

最新本機免安裝：`dist/trials/HeiBan-Windows-Portable-1.0.14-drawing-2026-10-15-r1-win-x64.zip`（131955475bytes）。解壓至新資料夾啟動HeiBan.exe；原機同名解壓版接續最近試用Data，ZIP本身無作品。舊未發布trials已清理並保留資料備份；以[最新狀態與SHA](docs/CURRENT_STATUS.zh-TW.md)為準，以下舊路徑／數字是歷史。

2026-10-13：[一般／螢幕工具列統一與Windows瘦身本機分析](docs/TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)。WT-01／WT-03第一批已改偏好過濾、形狀入口與十語手冊；程式／App未驗收，其餘WT工作與WR減重待續。未改版本／套件。

## 2026-10-13 Windows版本減重分析計劃

Windows端接手先讀[減重分析計劃報告書](docs/WINDOWS_SIZE_REDUCTION_PLAN_2026-10-13.zh-TW.md)與[基準數據](docs/PACKAGE_SIZE_BASELINE_2026-10-13.json)。Store包已排除獨立Updater；優先比較必要SDK元件與共享SDK框架。方案尚未實作／測試／提交，不提高正式版號；同版候選使用獨立DevelopmentLabel。Windows原機作品／安裝包／工具不會隨Git同步。

## 2026-10-12 十語離線使用說明

首頁／作品內使用說明跟隨目前介面語言，十語均有完整25章55段，手冊本頁亦可切語，離線搜尋／導覽可用、阿拉伯文RTL。新來源與生成器在Documentation/Guides及scripts/Build-UserGuides.py；版本仍1.0.14，用guides-2026-10-12標記開發候選。[階段日誌](docs/MULTILINGUAL_GUIDE_2026-10-12.zh-TW.md)。新試用包已完成：`dist/trials/HeiBan-Windows-Portable-1.0.14-guides-2026-10-12-win-x64.zip`；新同版Store候選在`dist/store/candidates/guides-2026-10-12/`，原包保留。x64／ARM64編譯0warning/error且手冊包體靜態核同，母語及App實機待確認；正式進版規則沿用下段。

## 2026-10-12 — 進版節奏更正（最高優先）

使用者要求整系列開發、測試與驗證完成後才決定進版。停止因單批修改／編譯／封裝自動提高正式版號；後續以日期、commit與試用標籤累積開發，提供整批驗證結果後由使用者明確決定版本。現有1.0.13／1.0.14包是未核准正式進版的開發候選，1.0.14未完整驗收，撤回「可立即上傳最新版」建議。來源metadata暫沿用1.0.14，不再自動提高；原已發布／送審產物、歷史與作品保留。下方交付／上傳紀錄是當時結果，正式進版政策以本段為準。[規則與原因](docs/RELEASE_POLICY_2026-10-12.zh-TW.md)。本次僅更正紀錄，未執行tests／App／編譯／封裝／Store操作。

## 2026-10-12 自動存檔模式（1.0.14）

首頁側欄齒輪「設定」、作品更多「設定」可選自動存檔，新的偏好預設關閉；on沿用原定期保存，off只在手動、離開作品或正常退出保存。螢幕更多亦有開關與「儲存註記」。正常退出顯示儲存動畫，完成後關閉；失败保留作品，當機／斷電／強制終了仍可能丢未保存變更。

產品1.0.14／Store候選1.0.14.0已打包；最新上傳包`dist/store/HeiBan-Store-1.0.14.0-x64-arm64.msixbundle`，免安裝試用`dist/trials/HeiBan-Windows-Portable-1.0.14-save-mode-2026-10-12-win-x64.zip`。x64／ARM64編譯0warning／0error，靜態檢視通過，尚未實機驗收／提交新版商店。前一1.0.13.0包保留。新功能需使用最新版package，舊包不會因原始碼push而改變。[本批日誌／性能待辦](docs/SAVE_MODE_2026-10-12.zh-TW.md)。

## 2026-10-12 商店更新候選1.0.13.0

新來源產品版本1.0.13，包含十語及前批首頁／畫布操作改善，共用兩畫布工具列建立政策並減少儲存圖示重建。本批新版MSIX已封裝，路徑`dist/store/HeiBan-Store-1.0.13.0-x64-arm64.msixbundle`，193,452,627bytes，來源9b6c4e4；僅為更新候選，未提交／發布。x64與ARM64編譯0warning／0error，靜態檢視通过，沒有App／tests驗收。原上架1.0.12.0及已發行版本保留。[上傳素材](docs/STORE_RELEASE_NOTES_1.0.13.zh-TW.md)／[本批紀錄與性能待辦](docs/STORE_UPDATE_TOOLBAR_2026-10-12.zh-TW.md)。下方試用與發布狀態均為有日期的歷史，不表示1.0.13已安裝驗收。

## 2026-10-12 Microsoft Store已上架

依使用者提供的Partner Center後台截圖，首次審核／上架已完成，按Availability設定提供：[HeiBan商店頁面](https://apps.microsoft.com/detail/9NV8T7RKV4MZ)。[來源與查證限制](docs/STORE_AVAILABLE_2026-10-12.zh-TW.md)。下方舊「尚未上架」是當時紀錄；後續十語／操作改善仍需另外提高MSIX版號提交更新。

## 2026-10-11 十種介面語言

首頁左下「語言」可選正體中文（預設）、簡體中文、英文、日文、韓文、西班牙文、法文、德文、葡萄牙文（巴西）、阿拉伯文；側欄收起時點文/A圖示。選擇成功立即套用，存於本機Data/Settings/language.json（安裝版採自己的資料根）；下次開啟沿用。回首頁再改語言，作品內容保持原文。

本機新免安裝試用使用 `dist/trials/*multilingual-2026-10-11*-win-x64.zip`，完整解壓後執行HeiBan.exe。介面字串翻譯完成但尚未母語／實機校閱；手冊保留正體中文，系統選檔／原始錯誤依來源語言。阿拉伯語閱讀UI採RTL，畫布座標保持LTR。未啟動App／執行tests／發布Release或Store；新包、舊未發布trial清理與未驗收項見[日誌](docs/LOCALIZATION_2026-10-11.zh-TW.md)。

## 2026-10-11 一般畫布／作品設定修正

一般畫布改用WinUI ProtectedCursor接管形狀方向／旋轉游標。首頁新增無邊界筆記收起尺寸；有邊界黑板首次預設16:9簡報，仍可自訂。新增作品與畫布背景設定加入空白／橫線／點狀／方格／五線譜；套用可復原，取消不修改。

[階段日誌](docs/CANVAS_SETUP_FIX_2026-10-11.zh-TW.md)。本輪新本機試用使用 `dist/trials/*canvas-setup-2026-10-11*-win-x64.zip`。舊未發布trials將依本次明確授權清理，Data等作品先保存在dist/trial-data-backups；已發布及Store產物保留。新包仍需完整解壓執行HeiBan.exe，未執行App／實機測試。


## 2026-10-11 操作回饋追加

螢幕工具列取消捲軸，依工作區換行／換列；圖層拖曳有跟隨圖示及插入線；形狀控制點有方向／旋轉游標。箭頭頭部輪廓線寬同步線條粗細，頭部長寬可獨立設定。主工具列直接提供「物件圖層」，也可在自訂工具列隱藏。

[階段日誌與 Mac 對照](docs/UX_FEEDBACK_2026-10-11.zh-TW.md) · [暫存清理清單](docs/UX_FEEDBACK_CLEANUP_2026-10-11.json)。新試用包使用 `dist/trials/*ux-feedback-2026-10-11*-win-x64.zip`，完整解壓後開 HeiBan.exe；本批未執行 App／實機操作測試。

## 2026-10-11 操作調整試用

20 項首頁／屬性／螢幕畫布調整見[本批紀錄](docs/UX_ALIGNMENT_2026-10-11.zh-TW.md)。一般單擊只反白，雙擊或右鍵「開啟作品」進入；虛線圓按鈕開啟批次多選。物件屬性按類型顯示、可四邊停靠，圖層為另一個面板。筆近直線停一秒吸附，尺長可按畫布百分比設定；螢幕畫布加入圖層／調色盤與橡皮擦範圍。

本批會另製作 `dist/trials/*ux20-2026-10-11*-win-x64.zip`，完整解壓後執行 HeiBan.exe，保存在自身 Data。是未發布的本機試用，沒有改動 Store 送審套件；本批僅編譯與封裝檢視，實際滑鼠、4K／DPI 操作待試用。

**以下為2026-10-10的本機試用歷史：1.0.12-preview.6**。本批加入 GitHub 背景更新；公開 GitHub 下載仍為 1.0.12-preview.5。以 Mac 1.0.12／20261010.4 的現行可操作功能為基準，Windows 使用 C#／.NET 10、WinUI 3 與 Win2D。主畫布為原生 Direct2D；PDF 匯出單獨使用 WebView2 列印。

[目前狀態](docs/CURRENT_STATUS.zh-TW.md) · [功能對照與驗證](docs/MAC_1_0_12_PARITY_2026-10-10.zh-TW.md) · [建置紀錄](docs/BUILD_STATUS.zh-TW.md) · [離線手冊](HeiBan.Windows/Assets/HeiBanUserGuide.html) · [開發日誌](docs/DEVELOPMENT_LOG.zh-TW.md)

2026-10-11 原始碼接續 Windows 效能第二批：渲染視野候選網格與穩定順序相容退路。[本批紀錄](docs/PERFORMANCE_BATCH2_2026-10-11.zh-TW.md)保存量測、失敗与未驗收項；目前 dist／Store送審套件仍是原版，source更新不代表已發布新安装包。

## 多電腦開發的私人產品紀錄

產品管理與發行交接保存在獨立 PRIVATE 庫 [VirginBear/HeiBan-private](https://github.com/VirginBear/HeiBan-private)。有權限的開發者開工先讀該庫 README／AGENTS／PRODUCT_INFORMATION.json／CURRENT_STATUS，再讀本平台文件。另一台電腦將其 clone 到公開 HeiBan 旁的獨立目錄，兩個 repo 分別核狀態與 pull／push。這個公開入口不包含私人管理欄位；本機二進位／工具／作品沒有隨紀錄庫複製。[建立紀錄](docs/PRIVATE_RECORDS_2026-10-10.zh-TW.md)。

## 開啟與更新

| 類型 | 最新檔案 | 資料位置 |
| --- | --- | --- |
| ARM64 免安裝版 | `dist/HeiBan-Windows-Portable-1.0.12-preview.6-win-arm64.zip` | 解壓後程式旁的 `Data/` |
| x64 免安裝版 | `dist/HeiBan-Windows-Portable-1.0.12-preview.6-win-x64.zip` | 解壓後程式旁的 `Data/` |
| ARM64／x64 安裝版 | `dist/HeiBan-Setup-1.0.12-preview.6-arm64.exe`／`...-x64.exe` | `%LOCALAPPDATA%\HeiBan\Windows\` |

Parallels 的 Windows 11 ARM64 使用 ARM64 包。Portable 必須完整解壓到可寫入的位置，雙擊 HeiBan.exe，不要只複製 EXE。退出程式後才拔除隨身碟。升級前關閉舊程式，備份整個 Data，再複製到新版資料夾；作品、垃圾桶、縮圖與設定一起保留。

.NET 與 Windows App SDK 自包含，普通畫布無需另裝 SDK。PDF 匯出需要 Edge WebView2 runtime；未安裝時會顯示錯誤，不影響其他匯出。安裝版每使用者安裝，不需管理員；可選桌面捷徑及 .heiban 開啟方式，解除安裝保留作品。

本版僅在本機封裝，尚未發布至 GitHub。現行 [1.0.12-preview.5 公開下載](https://github.com/VirginBear/HeiBan/releases/tag/windows-v1.0.12-preview.5) 保持原發行狀態。

## 自動更新（preview.6 起）

首頁「關於黑板 → 更新設定」或畫布「更多 → 檢查更新與更新設定」。GitHub 版預設在啟動約十秒後背景檢查，使用期間每六小時再檢查；可關閉背景更新／預覽版本，手動檢查。依 Windows tag、版本、x64／ARM64、Installer／Portable 篩選，下載後核對 GitHub asset digest 的 SHA-256 與大小。舊版需先手動安裝一次 preview.6 或更新的帶更新功能版本。

正常關閉時先保存作品與螢幕註記，獨立 helper 等待程序退出；同一安裝尚有視窗時延後，不強制關閉、不自動重開。安裝版使用 Inno 靜默升級，Portable 只更新 `update-files.json` 宣告的程式檔，保留 Data／portable.dat／未知檔，普通失敗會還原已移動程式檔。關閉自動更新後不自動套用暫存包。下載中断／離線不阻止使用；更新結果與暫存在 `%LOCALAPPDATA%\HeiBan\Updates\` 的個別安裝目錄。更新期間請勿拔除儲存裝置；中斷電源或安裝失敗需使用官方包修復，備份暫存不自行刪除。

MSIX 有 package identity 時交由 Microsoft Store 更新，不執行 GitHub 替換。商店 MSIX 免費簽章／託管；GitHub SHA 驗證不是 Authenticode，獨立 EXE 首次執行仍可能有系統提示。自動更新批次未產生 MSI／MSIX；後續正式商店身分已取得，MSIX 由下方獨立管道產生。[自動更新紀錄](docs/AUTO_UPDATE_2026-10-10.zh-TW.md)。

## Microsoft Store 封裝

正式套件身分 `DD7EC7CF.HeiBan`，商店產品 `9NV8T7RKV4MZ`。`HeiBanStoreBuild=true` 啟用 SDK 的 MSIX 編譯／PRI／manifest 管道；預設 EXE／Portable 仍使用 None。Store package version 為 `1.0.12.0`，產品版仍是 `1.0.12-preview.6`；這兩個版本分開管理。

在 Windows 使用 .NET 10 SDK：`powershell -File HeiBan.Windows/Packaging/Package-Store.ps1`。腳本依序產出 x64／ARM64 `.msix`，合成 `dist/store/HeiBan-Store-1.0.12.0-x64-arm64.msixbundle`，附 SHA 與 STORE_ARTIFACTS.json。使用獨立 `.build/store-*` 中間產物，保留原授權及手冊，不包含 GitHub helper／Portable marker／作品。未簽章包供商店送審，不能當一般用戶可直接側載的公開包。

商店最低 OS 宣告為 Windows 10 19041；程式與 Windows App SDK 自包含，PDF 仍需 WebView2。首次由 EXE／Portable 改用 Store，先匯出／備份作品，不假設自動共用資料庫；移除／重設 App 前先備份。商店安裝／更新／資料遷移、ARM64 執行與 WACK 未驗收，尚未送審／上架。[商店手冊](HeiBan.Windows/Packaging/Store/README-Store.zh-TW.md)、[本批紀錄](docs/MSIX_PACKAGING_2026-10-10.zh-TW.md)、[刊登草稿](docs/STORE_LISTING_DRAFT.zh-TW.md)。

## 更新發行契約

發布 tag `windows-v<版本>`，版本為 `major.minor.patch` 或 `major.minor.patch-preview.N`；Release 附正確架構的 `HeiBan-Setup-<版本>-<arch>.exe`（建議直接上傳）及／或原 Installer ZIP、Portable ZIP。GitHub 必須提供有效 `sha256:` asset digest；只 push 原始碼不會發送更新。Portable 保留完整 `update-files.json`，不要手動改動程式包內容後沿用舊清單。未經發布的 preview.6 不會讓既有用戶自動更新。

## 本次操作修正

- 滾輪以鼠標位置縮放；中鍵／空白鍵拖曳平移。
- 選取工具由空白處拖框：左往右只選完整包含的物件，右往左選碰到的物件；Ctrl／Shift 可追加。
- 圖釘使用圖釘圖示；雙擊圖釘或名稱，在畫布直接改名，Enter 保存、Esc 取消，可復原。
- 曲線第一點後隨滑鼠預覽，第二點後預覽完整彎曲；第三點提交一次復原。
- 顏色與線條可先選再切畫筆／圖形；線條按鈕與各選項顯示實際樣式。
- 螢幕直列圖示固定尺寸，中段只捲動；色圓、線條、清空與結束固定可用。浮窗允許直接點擊工具列切換。
- 截圖框外灰霧、框內原始清晰，完成直接成為圖片物件。

[本次修正與驗證](docs/WINDOWS_INTERACTION_REVIEW_2026-10-10.zh-TW.md)

## 本次流暢度改善

2026-10-10下一版第一批已加入穩定物件順序快取、命中／preview／筆跡damage配置改善與overlay bitmap區域複製相容修正。當批結果与限制見[第一批開發日誌](docs/PERFORMANCE_BATCH1_2026-10-10.zh-TW.md)及[原始樣本／重現入口](docs/performance/2026-10-10-batch1/README.zh-TW.md)。這些是新source與隔離建置，尚未發新的安裝包；下方為較早批次的功能說明，不能把歷史數字當本輪結果。

減少普通畫布重複重繪與中文字排版、修正選取物件的重複掃描；長筆跡拖動先預覽，收筆才寫回。保存／匯入移到背景，縮圖延後到操作空檔；偏好滑桿合併寫入。原生隔離300物件量測已減少重繪耗時；詳見性能稽核，這是同VM渲染量測，並非硬體輸入延遲。

[性能稽核與驗證](docs/WINDOWS_PERFORMANCE_REVIEW_2026-10-10.zh-TW.md)

## 本次功能

- Mac配置的作品庫側欄、收藏、格式／排序、三種卡片尺寸、單擊選取／雙擊開啟、Ctrl／Shift多選及批次垃圾桶／還原；左下浮動視角／頁面控制。
- 圖層顯示中文類型、文字摘要或自訂名稱；支援改名、排序、鎖定、隱藏與多選，物件 UUID 只作內部身份。
- 畫筆／螢光筆／油漆筆、八種筆刷選擇、色輪與填色；幾何、曲線、A/B 端點、射線；圖片縮放、旋轉與非破壞裁切。
- 框選／Ctrl 或 Shift 多選／套索，批次移動、複製、貼上、樣式及刪除；遮題膠帶與揭示；雷射三模式及暫態消退。
- T 螢幕文字、Enter 換行、Ctrl+Enter 完成、Esc 取消、雙擊編輯；畫布／螢幕共用文字右鍵設定，字級8～144、顏色、字型、對齊、透明度及粗斜體／底線，只修改有調整的欄位，支援多選一筆復原。繁體中文文字、局部富文字、標記色、六種便條紙；浮動計算機、碼表、自訂倒數。
- 尺規支點可到劃線兩端、圓規及圓弧端點、圖釘；工具列自訂與停靠、頂部自動隱藏、視角鎖定及多頁管理。
- 截圖由 App 自有區域框選，直接置入畫布成為可編輯圖片，不另存截圖資料夾。Win+Shift+S 的外部截圖仍需 Ctrl+V。
- 「我的螢幕就是我的畫布」由首頁、右上螢幕圖示、更多工具或 Ctrl+Alt+A 啟動；820×60 DIP 單排半透明工具列、64×688 DIP 直式圖示列、四邊停靠與中段捲動、獨立280 DIP色彩／粗細／透明度面板、透明作畫／穿透操作、獨立保存恢復、透明 PNG／原稿及截圖圖片直接留在螢幕畫布。右鍵物件開啟調整／複製／個別刪除選單，空白右鍵不切換操作；穿透由模式按鈕或 Ctrl+Alt+D 切換；選取後色圓／線條／填滿直接修改已完成物件；工具列垃圾桶或 Ctrl+Alt+K 一鍵清空，可復原。Ctrl+Alt+D 切模式，Ctrl+Alt+S 截圖，Ctrl+Alt+Q 結束。
- 三種畫布、作品庫、副本／垃圾桶、原子保存、JSON／.heiban；PNG／SVG／PDF／HTML 匯出，提供頁面全部、選取與視野範圍。

Mac 基準尚未交付的雲端／Google、協作、心智圖／表格／公式／畫框、外部 PDF／SVG 原稿編輯及文件多視窗仍未提供。八種筆刷使用與該 Mac 基準相同的平滑向量渲染，未提供材質物理模擬。Surface 壓力／傾角可保存，尚未接可變粗細輪廓。

## 驗證範圍

本輪核心與手冊 **700 項**檢查通過；原生 ARM64 Win2D／PDF／透明螢幕層與註記保存檢查通過。兩架構建置及包內檔案／版本／SHA-256 檢查見建置紀錄。這些不是完整滑鼠／觸控筆／混合 DPI／多螢幕操作驗收；x64 實機及安裝升級仍待試用。

Windows 11 為主要平台，Windows 10 1809 為 API 最低基線，尚需驗收。沒有正式簽章、自動更新或 Store 發行。

## 建置

在 Windows 使用 .NET 10 SDK；安裝包需 Inno Setup 6.7+／7。平台來源及產物在 windows/，不編譯 Mac。

```powershell
cd windows
dotnet run --project HeiBan.Windows.Core.Tests -c Release
powershell -ExecutionPolicy Bypass -File HeiBan.Windows/Packaging/Package-Portable.ps1 -Runtime win-arm64
powershell -ExecutionPolicy Bypass -File HeiBan.Windows/Packaging/Package-Installer.ps1 -Runtime win-arm64 -IsccPath 'C:\Tools\InnoSetup\ISCC.exe'
# x64 使用 -Runtime win-x64
```

發行輸出 dist/，封裝暫存 .staging/，每包附 SHA-256。腳本檢查 HeiBan.pri、runtime、品牌資源與授權；不包含使用者作品。開發可設定 HEIBAN_WINDOWS_DATA_DIRECTORY 隔離資料。

## 授權與歷史

HeiBan 為 GPL-3.0-only，附 [限定 Windows SDK 例外](LICENSE-WINDOWS-EXCEPTION.txt)；衍生程式仍需提供對應原始碼。包內 Licenses/ 含完整 GPL、例外與第三方原始條款。

[preview.5 README 封存](docs/README_preview5_ARCHIVE.zh-TW.md) · [原開發工作單](docs/WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md) · [架構](docs/ARCHITECTURE.zh-TW.md) · [問題紀錄](docs/ISSUE_HISTORY.zh-TW.md)

本輪追加：螢幕物件樣式、原位置截圖物件、Shift水平／垂直直線、首頁多選刪除；本版依最新要求恢復右鍵物件選單，取消右鍵自動穿透；圖形／框選局部讀回與無手勢工具切換避免整屏傳輸。實際原生驗證與封裝以本輪BUILD_STATUS為準。

## 畫布顯示異常（2026-10-24修正）

若畫布暫時無法顯示，先等待初始化；畫面失敗提示提供「重新載入畫布」。首幀前不接受繪畫，避免不見的筆跡。不要刪作品來排除顯示問題。修正版免安裝使用獨立標籤canvas-recovery-2026-10-24-r1；舊eraser-laser包有已重現的空白退化。測試範圍／交付來源見[修復紀錄](docs/CANVAS_RECOVERY_2026-10-24.zh-TW.md)。

## 筆刷常用色與雷射（2026-10-24開發試用）

「筆刷」內先調色，再按常用色的＋保存；點色票套用，「管理」或色票右鍵可移除，「還原預設色」重新建立預設列表。允許清空色票，重開保存；兩種畫布共用此profile的Settings/palette.json，搬移作品設定時保留整個Data。工具圖示下方線條表示下筆描邊色，保留工具原本的共用色規則。選取與雷射跨頁常駐，雷射再次點擊開設定。舊作品的BrushKind資料保留，無材質效果的類型選單移除。新指南說明不覆寫已編輯的作品；實際試用來源／驗證見[本批日誌](docs/BRUSH_PALETTE_IMPLEMENTATION_2026-10-24.zh-TW.md)。

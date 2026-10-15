# Microsoft Store 更新批次 — 2026-10-15

## 開工與授權
- 使用者在試用後表示「這一版本可以再次更新到微軟商城了 GO」，授權製作本次正式商店更新並推進提交；不把前批未執行的測試當作通過。
- 公開基準47028f2；既有三份共享紀錄未提交內容與三份YouTube新文件完整保留，排除本批提交。
- 先核對本地來源、目前商店套件版本及身分、Store封裝流程；套件與本機試用／作品分離。版本依實際已提交套件判斷，避免覆寫舊產物。
- 本批開始時尚未編譯／封裝／提交／發布，實作測試未執行。後續命令及結果接續紀錄。

## 版本／提交進度
- 私人資料最後確認的上架包為1.0.12.0，但來源及歷史候選已到1.0.14.0；本次選下一未使用版號1.0.15.0。未將本地歷史候選當成已上架版本；後台即時版本待登入確認。使用者已明確允許本次更新，更新App／manifest／StoreIdentity三處版本，封裝增加FormalVersionApproved旗標以如實記錄，不影響預設候選。
- Partner Center直達產品頁只載入外殼，從可見應用程式與遊戲入口轉到Microsoft登入；瀏覽器連線曾更換識別及逾時，未複製登入資訊。使用者回覆已登入HeiBan後台，待接續。
- 十語手冊狀態說明改為本次Store更新，保留功能限制；作品schema不改。

## 實際交付與操作分工
商店包`dist/store/HeiBan-Store-1.0.15.0-x64-arm64.msixbundle`已完成，195664137bytes／SHA256 `a889482ff3aa171569ce415fc285340b26742528af4306a3e0a0e3d6fa07eb96`；來源`ceed5f96a7241a9561380b4f3cfb596718fba317`。x64／ARM64分別61.69／51.11秒，均0warning／0error。218來源SHA、ZIP CRC、身分／架構、十語手冊與板擦資源核同；原12份Store套件SHA不變。使用者接手Partner Center，助手未上傳／送審／發布。本批App／實作測試／WACK未執行。
實際命令：git status／fetch兩庫0/0、Build-UserGuides.py（十語25章62段）、git commit ceed5f9、Package-Store.ps1 -DotnetPath本機dotnet -FormalVersionApproved、只讀ZIP與來源及舊套件SHA檢視，均完成。MakeAppx bundle身分與兩內含包SHA核同，證據見同版ARTIFACTS／INSPECTION JSON。
後台當時可見提交3定價／可用性：全球市場、公用可搜尋、TWD基本價格0、盡快發行。未修改或保存；套件頁操作逾時未確認成功，使用者要求自己操作、助手改記錄關鍵結果。未將登入或本地封裝視為已上傳／送審。收到結果截圖再補確認。
使用者詢問隱私文字：檢視DocumentImportService、ExportPdfAsync、PdfDocumentAttachment、BoardExporter與GitHubUpdateService，新增Windows專用隱私原則，包含PDF／HTML完整原稿分享風險，沒有改文件契約。Microsoft範例短網址讀取失敗，改讀官方MSIX support-info隱私章；可直接提供文字，沒有保證認證。
障礙：第一次讀取新JSON未指定UTF-8，Windows cp950解碼失敗，發生在任何文件修改之前；補encoding=utf-8重跑。本機source commit先push成功，後補交付文件。查找曾誤用不存在的DocumentExchange／Exporting路徑，改rg定位DocumentImport及Engine後取得實際證據。
未執行App、實作測試、WACK、Store安裝／升級／卸載及完整網路量測；歷史數字不套用。本機作品／trial及Store歷史保留，既有YouTube內容未納本批提交。

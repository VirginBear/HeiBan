# 隱私與資料保存

更新：2026-10-09。適用於此儲存庫的原生公開預覽下載；Web 原型另見下方。

## Windows 目前商店更新

Windows 1.0.15提交使用的隱私文字見[2026-10-15版](windows/docs/PRIVACY_POLICY_2026-10-15.zh-TW.md)，包含本機PDF／PowerPoint轉換、匯出內嵌完整原稿、更新與診斷說明。本次不改Mac或Web行為。

## Mac 1.0.15 文件交換補充

2026-10-16本機開發版新增PDF頁面與簡報匯入。PDF以PDFKit在本機轉成圖片頁；簡報由使用者安裝的Keynote及系統自動化授權轉唯一暫存副本，不修改原始或既有開啟的簡報，也不由黑板上傳到轉換服務。Keynote自己的連線、字型及隱私行為依Apple／使用者設定處理。

Mac PDF匯出會附上**完整可編輯原稿**，可能包含其他頁面、隱藏物件與內嵌圖片，不能因PDF畫面只看見一頁就當作已移除其餘資料。匯出前有提示；若只分享可見內容，請使用PNG並檢查輸出。HTML及.heiban也可包含完整原稿。這些是來源行為說明，不代表本批已完成全部實際往返驗收。

## Mac 與 Windows 原生版

作品主要保存在本機。Mac 位於 `~/Library/Application Support/HeiBan/`；Windows 安裝版位於 `%LOCALAPPDATA%\HeiBan\Windows\`，免安裝版位於程式資料夾 `Data/`。開發隔離環境變數可改變位置，因此它們不是每台電腦的絕對路徑保證。

Mac 螢幕註記另存 `ScreenAnnotations/`；可編輯註記檔只保留註記。截圖 PNG 或插入的截圖／圖片會包含當下畫面，可能有私人內容，分享前請自行檢查。

一般繪圖不需讀取背後 App 畫面。截圖功能需要系統授權，Mac 可能使用 ScreenCaptureKit 或一次性系統選取器。透明畫布不會停止背後影片。

目前原生 Google 登入／雲端同步未正式開放；不要把準備中的設定當成已連線同步。App 可能依使用者動作啟動外部連結；作業系統的安全檢查、崩潰紀錄與執行歷史不由黑板控制，免安裝版不承諾「零痕跡」。

Windows 自包含包附帶 Microsoft runtime／SDK；其原始條款說明可能有診斷、更新等資料與連線行為，依元件政策處理。本輪未量測全部網路行為；詳見 [第三方條款與版本](THIRD_PARTY_NOTICES.md)。

## Web 原型

`src/` 中的早期原型含 Firebase 登入、Firestore 與本機 localStorage 管線；如自行執行或部署，可能聯絡 Google/Firebase。這次沒有部署正式 Web 站台，也沒有確認雲端服務的正式隱私、授權或安全規則配置。

Firebase 用戶端設定是專案識別資訊，與管理員私鑰不同；依 [Firebase 官方說明](https://firebase.google.com/docs/projects/api-keys)，資料存取由 Security Rules／IAM／App Check 控制。自行部署必須使用自己的專案與適當限制，不應把「設定公開」理解成「資料公開」。

## 公開回報與移除

GitHub Issue 是公開的。避免上傳私人筆記、帳號、token、截圖或完整系統日誌。備份後再移除作品，升級一般不需要清空資料。漏洞按 [SECURITY.md](SECURITY.md) 私下回報。第三方服務政策由其提供者訂定。

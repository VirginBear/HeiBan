# 隱私與資料保存

更新：2026-10-09。適用於此儲存庫的原生公開預覽下載；Web 原型另見下方。

## Mac 與 Windows 原生版

作品主要保存在本機。Mac 位於 `~/Library/Application Support/HeiBan/`；Windows 安裝版位於 `%LOCALAPPDATA%\HeiBan\Windows\`，免安裝版位於程式資料夾 `Data/`。開發隔離環境變數可改變位置，因此它們不是每台電腦的絕對路徑保證。

Mac 螢幕註記另存 `ScreenAnnotations/`；可編輯註記檔只保留註記。截圖 PNG 或插入的截圖／圖片會包含當下畫面，可能有私人內容，分享前請自行檢查。

一般繪圖不需讀取背後 App 畫面。截圖功能需要系統授權，Mac 可能使用 ScreenCaptureKit 或一次性系統選取器。透明畫布不會停止背後影片。

目前原生 Google 登入／雲端同步未正式開放；不要把準備中的設定當成已連線同步。App 可能依使用者動作啟動外部連結；作業系統的安全檢查、崩潰紀錄與執行歷史不由黑板控制，免安裝版不承諾「零痕跡」。

## Web 原型

`src/` 中的早期原型含 Firebase 登入、Firestore 與本機 localStorage 管線；如自行執行或部署，可能聯絡 Google/Firebase。這次沒有部署正式 Web 站台，也沒有確認雲端服務的正式隱私、授權或安全規則配置。

Firebase 用戶端設定是專案識別資訊，與管理員私鑰不同；依 [Firebase 官方說明](https://firebase.google.com/docs/projects/api-keys)，資料存取由 Security Rules／IAM／App Check 控制。自行部署必須使用自己的專案與適當限制，不應把「設定公開」理解成「資料公開」。

## 公開回報與移除

GitHub Issue 是公開的。避免上傳私人筆記、帳號、token、截圖或完整系統日誌。備份後再移除作品，升級一般不需要清空資料。漏洞按 [SECURITY.md](SECURITY.md) 私下回報。第三方服務政策由其提供者訂定。

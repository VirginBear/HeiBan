# Microsoft Store 準備與 GitHub 來源同步

## 開工紀錄

2026-10-10，使用者告知已申辦 Partner Center，要求說明下一步、注意事項、保留紀錄並更新 GitHub。本批只處理 Windows 與其文件。已讀開發索引、Windows CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY；開工 `git status --short --branch` 顯示上一批 preview.6 的 Windows 未提交實作，沒有其他平台變更。保留這些內容，準備一起提交。

`git log -1 --format=%H` 與 `git ls-remote origin HEAD refs/heads/main` 都是 `3dca2efc29013ba737e5ced81c26861e0ddf7061`。GitHub CLI 可用且已登入；不把登入帳號設定、權杖或帳戶驗證資料記入文件。Partner Center 的網址本身不能證明帳戶已通過驗證，本批未登入／檢視私人後台。

本批範圍是同步已完成的自動更新來源與開發文件、建立可追蹤的商店準備清單；沒有新增 MSIX 成品、提交商店審核或發布 GitHub Release。上一批的四個本機產物與 SHA snapshot 保持原樣。GitHub source push 與可下載 Release 是兩個獨立結果。

## 使用者現在需要提供的資料

1. 在 Partner Center 確認開發者帳戶驗證完成、可建立 Windows 應用程式。若仍顯示待驗證，依後台要求完成；不需提供登入密碼、驗證碼或證件给開發者。
2. 建立新應用程式、保留商店名稱，例如「HeiBan 黑板」（實際名稱依可用性及使用者選擇）。
3. 打開該產品的「產品管理 → 產品身分識別（Product identity）」，提供以下原文，大小寫、標點及空格都要一致：

| 欄位 | 用途 |
| --- | --- |
| Package/Identity/Name | MSIX 套件身分，不能自行用顯示名稱代替 |
| Package/Identity/Publisher | 完整 `CN=…` 發行者字串 |
| Package/Properties/PublisherDisplayName | 發行者顯示名稱 |
| 已保留的應用程式名稱 | 商店顯示名稱及語系對應 |

這些是公開套件身分中繼資料，後續以此製作正式 manifest。不得猜測或把示範身分當作可送審成品。[Microsoft 身分欄位說明](https://learn.microsoft.com/en-us/windows/apps/publish/view-app-identity-details)。

4. 上架前決定免費／收費、發布市場與語言，提供公開支援聯絡方式。商店文案、截圖與審核說明可以由本專案準備；使用者須確認對外內容及營運選項。

## 已確認的路線與注意事項

- 選 MSIX／MSIX bundle 商店發行。Microsoft Store 對通過審核的 MSIX 重新簽章，無需購買 CA 程式碼簽章憑證或提供 CA `.pfx`。自行在商店外散布 MSIX 的簽章要求不同；不能把未簽的送審包當作所有人可直接安裝的公開包。[官方套件要求](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements)。
- 商店版更新由 Store 管理；既有程式的 package identity 分支會停用 GitHub 自動下載／替換。推 GitHub 原始碼不會更新 Store，Store 必須提交新版本。既有 EXE／Portable 用戶也不會因建立商店產品就自動轉成 MSIX；第一次遷移要安裝商店版並驗證作品移轉。
- 目前為 .NET 10／WinUI 3／Win2D 原生桌面程式，含螢幕註記、全域快捷鍵與使用者主動區域截圖；商店封裝預期需要桌面 `runFullTrust` 宣告。最終能力依實際 manifest 判定，送審要解釋用途。不是申請管理員權限，也不能預先保證審核通過。[能力與審核要求](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/app-capability-declarations)。
- 現有安裝版資料根為 `%LOCALAPPDATA%\HeiBan\Windows`，Portable 為程式旁 `Data`。MSIX 的套件身分、檔案系統重新導向與解除安裝生命週期尚未驗收；必须先驗證舊資料讀取／遷移、商店版更新保存、兩版並存與解除安裝的備份行為。不得先宣稱商店解除安裝必然保留全部作品。
- 目前預覽產品版 `1.0.12-preview.6`／EXE FileVersion `1.0.12.6` 不直接等於 Store Package/Identity/Version。MSIX 用四段整數、保持可升級順序，依 Store 規則保留末段為 0，後續在取得身分後建立獨立版本映射。
- 商店至少需一張截圖、描述、分類與年齡分級等必填項。截圖使用專用示範作品；不使用私人作品或後台證件。隱私說明須與作品保存、使用者主動截圖及網路行為一致，現有 GitHub 發行管道有更新請求，商店管道停用這條請求。不要未經完整確認就寫「完全不連網」。[送審清單](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/create-app-submission)。
- 專案為 GPL-3.0-only 加限定 Windows SDK 例外；MSIX 必須保留 GPL／例外／第三方授權，以及對應原始碼入口。免費或收費都不會免除既有授權義務。

## 接下來的開發工作

取得真實產品身分後建立 x64／ARM64 的 MSIX manifest／封裝，再處理啟動、WinUI PRI、檔案關聯、桌面權限、資料移轉與商店更新測試。隔離的自簽測試只用於本機驗收，不要求使用者購買公開憑證。完成後執行 Windows App Certification Kit 並準備送審包、商店文案／示範截圖／隱私與支援入口；最後才在 Partner Center 提交。

## 實際命令與結果

- 已執行：`git status --short --branch`、`git log -1 --format=%H`、`git ls-remote origin HEAD refs/heads/main`；本地與遠端基準相同，變更只在 Windows。
- 已執行：閱讀開發索引／平台文件，搜尋現有資料根、package identity、HTTP 更新與螢幕快捷鍵，查 Microsoft Learn 官方身分／MSIX 簽章／送審與能力文件；確認 Microsoft 免費商店 MSIX 簽章規則。
- 搜尋曾指定不存在的 `windows/HeiBan.Windows/Services`，rg 提示路徑不存在；有效目錄的結果仍可讀，沒有據此聲稱該目錄存在或修改程式。
- 本批未重跑程式測試或建置。上一批 73 更新／700 Core 檢查與真 x64 helper／Inno／啟動結果只作歷史證據，詳見 [自動更新日誌](AUTO_UPDATE_2026-10-10.zh-TW.md)。
- 未執行：Partner Center 私人帳戶驗證、名稱預留、正式身分取得、MSIX 封裝／安裝／移轉／WACK、Store 送審／發布、GitHub 新 Release 與實際線上版本更新。
- Git 提交／push 的實際結果在完成後追加；不能以「準備同步」代替已完成。
- `git add -- windows` 暫存 32 個 Windows 檔案，没有 bin／obj／dist／工具／作品；Git 提示部分 LF 將依設定轉 CRLF。`git diff --cached --check` 找到 vendored Inno 語言檔第 12／253 行註解原有尾端空白；保留與已封裝 SHA 一致的語言來源，不把這次檢查宣稱全無提示。上一批未暫存時的 diff check 沒包含當時 untracked 語言檔。

## GitHub 同步完成

- `git diff --cached --check -- . ':!windows/HeiBan.Windows/Packaging/Languages/ChineseTraditional.isl'` 退出 0；非 vendored 翻譯檔沒有空白錯誤。
- `git commit -m "Implement Windows background updates and record Store preparation"` 成功，來源 commit `27c968dc80766d78eb1dac3d2305d32ee2f5c63e`，32 個 Windows 檔案，新增 1893／移除 34 行。
- `git push origin main` 退出 0，遠端從 `3dca2ef` 前進到 `27c968d`。隨後 `git ls-remote origin HEAD refs/heads/main` 兩個結果都與本機完整 commit 一致，`git status --short --branch` 乾淨。
- [GitHub 已同步來源](https://github.com/VirginBear/HeiBan/commit/27c968dc80766d78eb1dac3d2305d32ee2f5c63e)。本段同步證據再以文件提交保存；不改寫前述來源 commit 或已封存 artifact manifest。manifest 的 source_status／published 是封裝當時狀態，現在的來源同步由本紀錄補充。
- 公開 Windows Release 仍 preview.5，本批只推來源／紀錄，没有上傳 preview.6 包；Store 身分待提供，MSIX 尚未產生。沒有改 Mac／Web、重跑測試、建立排程或刪除歷史資產。

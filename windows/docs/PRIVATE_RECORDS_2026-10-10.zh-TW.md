# 私人產品紀錄與跨電腦交接

## 開工

2026-10-10，使用者要求把產品資訊存放 GitHub 私人區域，方便不同電腦開發時讀取。開工 `git status --short --branch` 乾淨，讀開發索引／Windows CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY。本批只處理 Windows 發行管理文件與獨立私人紀錄庫，不改程式／產物／Mac／Web。

`gh repo view VirginBear/HeiBan --json nameWithOwner,visibility,url` 確認現有程式庫 PUBLIC；`gh repo list ... --visibility private` 未見 HeiBan 對應私人庫。不使用與產品無關的既有私人庫；準備 `VirginBear/HeiBan-private` 作為獨立產品紀錄庫。本文件在外部建立與上傳前先記錄，完成後追加結果。

## 分工

- 公開 HeiBan：必要程式碼、套件 manifest 中的產品識別、授權與技術開發證據。
- 私人 HeiBan-private：完整產品身分、管理用識別、價格／市場／送審進度、待辦與跨電腦交接，內容由本人與受邀協作者讀取。
- 密碼、存取權杖、驗證碼、簽章私鑰不存於這兩個 Git repo。
- 先前已公開的套件身分仍是安裝必要中繼資料；建立私人庫不代表撤回公開歷史或讓已發布 manifest 變成私人。

## 跨電腦入口

在另一台電腦登入有權限的 GitHub 帳號後，將 `VirginBear/HeiBan-private` clone 為公開 HeiBan 旁的獨立目錄。開工先讀該庫 README、PRODUCT_INFORMATION.json、CURRENT_STATUS.zh-TW.md 與 AGENTS.md；再讀公開平台開發索引及 CURRENT_STATUS。先核 git status／遠端同步，工作後提交／推送各自的變更。

本地 MSIX／EXE／Portable 不屬這次產品資訊備份，不上傳二進位到 Git 歷史。重新封裝依公開 SDK 腳本，使用私人庫的產品身分紀錄作核對來源；不能誤認別台電腦也已存在本機 dist／工具／驗收結果。

## 實際建立結果

本地相鄰目錄初次 Test-Path=false，沒有覆寫既有內容。先準備六份文件並 `git init -b main`／add／diff --cached --check／commit，初始 commit `df6cb37ab9c1353af2cb9210c4c988d8353fd535`。`gh repo create VirginBear/HeiBan-private --private` 成功，`gh repo view ... --json visibility` 確認 PRIVATE 後才加 remote／push。遠端 HEAD／main 與本機初始 commit 相同，私人工作樹乾淨。

公開文件增加授權開發者的讀取入口；完整私人欄位留在私人庫，技術來源不變。沒有使用 submodule、發行二進位、改 Store 後台、刪公開歷史、跑程式測試或排程。本次來源僅文件變更，舊 Store artifact manifest 是 aa71e35 編譯批次快照，不因新增交接入口假稱已重封包。

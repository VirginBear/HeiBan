# Store 首次送審與截圖歸檔（2026-10-10）

## 開工與範圍

- 使用者貼出 Partner Center「產品提交：認證中」及「通過認證後立即開始發佈」文字，並授權保存三張已提交的示範截圖。
- 開工公開／私人工作樹均乾淨。已讀開發索引、Windows 狀態／架構／問題／日誌，以及私人库規則和产品紀錄。
- 只更新 Windows 發行文件及私人管理紀錄；原始 PNG 將存入 PRIVATE HeiBan-private，保留 Downloads 原檔。
- 使用者提供的後台狀態與助手實際登入查證分開；本次沒有登入後台，不以認證中宣稱已通過或已上架。

## 進行中發現

- 前次概觀截圖的套件顯示 Validated，當時價格／年齡分級沒有完成標記；此次使用者已回報進入認證，該提交阻礙已解除。
- 三張圖是使用者提供的商店示範素材；不能用來證明 MSIX 安裝、Store 更新、ARM64 或 WACK 驗收已完成。
- 官方流程包含安全／技術／內容合規檢查，並非只等待人工；認證可能需要最多三個工作天。依使用者貼出的設定，通過後將立即開始發佈。
- 官方來源：https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-certification-process

## 命令與結果

已執行 git status --short（兩庫乾淨）、Get-Content 平台／私人文件、gh repo view VirginBear/HeiBan-private --json visibility,url（PRIVATE）；官方認證文件查閱成功。截圖複製、雜湊及 Git 同步結果於完成後追加。

## 未執行

App 測試、MSIX 安裝／WACK／資料生命週期驗收、重新封裝、Store 後台操作或取消認證、GitHub Release、排程、macOS／Web 修改均未執行。截圖內容不放入公開庫日誌。

## 歸檔結果與交付檔案

PRIVATE repo 內三張 PNG 已原 byte 複製並各核對來源／目的 SHA-256 相同；MANIFEST.json 保存大小、像素尺寸與雜湊。圖像素材不修改、不公開，原檔保留。更新公開 CURRENT_STATUS、DEVELOPMENT_LOG、ISSUE_HISTORY、STORE_LISTING_DRAFT 與本日誌；私人更新 PRODUCT_INFORMATION、CURRENT_STATUS、DEVELOPMENT_LOG、README、素材 README／MANIFEST 及三 PNG。沒有新架構／功能入口／文件格式決策，故無需修改程式架構／手冊；舊產物清單保留原封裝快照。

實際命令：Copy-Item、Get-FileHash（3 組一致）、System.Drawing.Image.FromFile（僅讀尺寸並 Dispose）、ConvertFrom-Json／ConvertTo-Json（更新管理紀錄）。無複製／工具錯誤；本批沒有 App 測試結果。

## 私人同步證據

私人庫提交 `195c36a7436cfbbf376061f41febbe48fe7fb997`（九檔含三 PNG）已 push，git ls-remote HEAD／main 與本地一致、git status 乾淨；提交前確認 origin 為 HeiBan-private、visibility PRIVATE，staged diff --check 退出 0。Git 顯示文字 LF 之後轉 CRLF 的提示，不是素材 bytes 修改或檢查失敗。

## 公開同步證據

公開 Windows 五份文件提交 `1ccacd321bd4501f0290e6a9753c097801a5dac9` 已 push；git ls-remote origin HEAD／main 與本機一致，status 乾淨，staged diff --check 退出 0。圖片僅存在私人庫，公開提交不含 PNG／私人產品管理 JSON。以上結果追加後保存為文件稽核提交。

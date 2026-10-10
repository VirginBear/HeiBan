# HeiBan 黑板商店資料草稿

狀態：2026-10-10，供使用者審閱／填入 Partner Center；原封裝批次的草稿；使用者後續已回報 Submission 1 認證中，尚未確認上架。下列文案／待辦保留當時快照，不代表實際提交內容已逐欄核對。最新進度見 STORE_SUBMISSION_2026-10-10.zh-TW.md。Product ID：`9NV8T7RKV4MZ`。

## 繁體中文商店描述

HeiBan 黑板是 Windows 原生手寫黑板與多頁筆記工具。使用滑鼠或手寫筆記錄想法、畫線與圖形、加入文字及圖片，並整理多頁作品。

螢幕註記模式可在桌面上方書寫、使用雷射指示與局部截圖，適合教學示範或簡報說明。作品以本機檔案保存，也能匯出為圖片；PDF 匯出需要 Microsoft Edge WebView2 Runtime。

此版本仍屬開發預覽。完整手寫硬體、多螢幕與混合 DPI 的驗收狀態請見 GitHub 開發紀錄；商店套件首次安裝、更新及資料遷移仍待驗收，正式刊登前須更新此說明。

## 功能列

- 向量筆跡、線條、圖形、文字與圖片。
- 多頁作品、縮放、平移、選取與復原。
- 螢幕註記、穿透模式、全域快捷鍵與雷射指示。
- 本機作品保存與匯出；Microsoft Store 管理商店版更新。

## 審核備註草稿

This is a native WinUI 3/.NET desktop drawing and note-taking application. The runFullTrust capability is needed for its desktop window, Direct2D/Win2D canvas, user-initiated screen annotation overlay, global keyboard shortcuts, and region screenshots. It runs as the current user and does not require elevation. Screen capture is initiated by the user; the overlay can be closed normally. No user account is needed to use the app. The Store build disables the GitHub application updater and relies on Microsoft Store updates. PDF export requires Microsoft Edge WebView2 Runtime.

上述功能須完成商店安裝環境驗收後再提交，不把本草稿當作已通过认证的證明。

## 待完成欄位與素材

| 項目 | 目前狀態 |
| --- | --- |
| 顯示名稱／發行者 | HeiBan 黑板／純潔的熊，已提供正式身分 |
| 分類 | 建議 Productivity；由使用者確認 |
| 價格／市場 | 使用者已確認第一版免費提供；市場尚未選擇，後台價格尚未操作 |
| 支援入口 | 可用 https://github.com/VirginBear/HeiBan/issues ；是否採用由使用者確認 |
| 年齡分級 | 使用者在 Partner Center 完成問卷；不自行虛填分級 |
| 隱私說明 | 已備 [草稿](PRIVACY_POLICY_DRAFT.zh-TW.md)，需發行者確認內容與正式公開 URL；本批未發布網站 |
| 截圖 | 至少一張；建議主畫布、多頁管理、螢幕註記三張專用示範截圖，未拍攝 |
| 套件驗收 | 本機安裝、首次資料移轉、更新／解除安裝備份、x64／ARM64、WACK 未執行 |

## 提交方式

Partner Center → HeiBan 黑板 → 新提交 → Packages，上傳產生的 `.msixbundle`（含 x64／ARM64）。依後台實際檢查完成 Properties、Age ratings、Pricing and availability、Store listings、Submission options。未簽章包由 Store 在認證發布後重新簽章，不需要另購 CA 憑證。

送審與發布是兩個階段。若不希望通過認證即公開，提交時選擇手動發布／暫停發布選項；本批沒有替使用者選擇或按下送審。

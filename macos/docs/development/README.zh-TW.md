# Mac 開發與維護文件

先讀目前狀態，再看架構與未結問題。歷史日誌追加保存，不以新版本覆蓋舊事件。

| 文件 | 用途 | 何時更新 |
|---|---|---|
| [CURRENT_STATUS](CURRENT_STATUS.zh-TW.md) | 目前成品、可用功能、未驗收、下一步 | 每批交付前 |
| [ARCHITECTURE](ARCHITECTURE.zh-TW.md) | 模組、資料流、狀態與執行緒界線 | 職責／資料流變更時 |
| [DEVELOPMENT_LOG](DEVELOPMENT_LOG.zh-TW.md) | 每日工作、結果、命令與交接 | 開始與進行中追加 |
| [ISSUE_HISTORY](ISSUE_HISTORY.zh-TW.md) | 症狀、原因、失敗方案、解法、防止再犯 | 發現／處理問題時 |
| [DECISIONS](DECISIONS.zh-TW.md) | 架構選擇、替代方案與代價 | 做出重要決定時 |
| [CODE_REVIEW](CODE_REVIEW_2026-10-09.zh-TW.md) | 本次稽核與整理結果 | 本批完成時 |

最新Windows清晨來源核對見[10/12同步與下一步](WINDOWS_SYNC_REVIEW_2026-10-12.zh-TW.md)：两庫已取回、Mac未提交成果保留；本批没有重建App。

最新本機交付為1.0.13／20261011.1，見 [日誌10](logs/2026-10-11/10.zh-TW.md)：右上懸停導覽、普通圖層原生拖曳回饋及首頁螢幕畫布入口已實作封裝，實際操作待驗收。

工具列整體進度依 [Antigravity Mac 工具列追齊清單](../ANTIGRAVITY_MAC_TOOLBAR_WORKLIST_2026-10-11.zh-TW.md)。TB01–03已實作，M23–25有前批回歸確認；TB04–10尚未整體完成。本批普通圖層改進不表示螢幕畫布已有圖層入口。

历史相容性複核見 [Antigravity 第一批獨立複核](ANTIGRAVITY_REVIEW_2026-10-11.zh-TW.md)；其中M21其後已修復。歷史工具列缺口見 [工具列複核](MAC_TOOLBAR_REVIEW_2026-10-11.zh-TW.md)，目前狀態以CURRENT_STATUS的新紀錄為準。

## 工作順序

1. 檢查目前 Git 變更與平台範圍。
2. 執行 `python3 macos/scripts/new_dev_entry.py --title "工作名稱"`，填入目的與起始狀態。
3. 修改時記下重要決定與遇到的錯誤；加入對應 ISSUE／ADR 編號。
4. 按當次授權編譯／驗收；原樣記錄命令和結果，不執行未獲要求的測試套件。
5. 更新 CURRENT_STATUS、日誌實際結果、相關說明與使用手冊，才交付。

## 手冊維護

唯一可編輯內容來源是 `macos/scripts/generate_user_guide.py` 的章節、圖解與樣式。執行該腳本生成 App 資源 HTML、`macos/docs/USER_GUIDE.zh-TW.html`、Markdown。三份輸出用途不同，不要分別修改；App 打包複製資源，不在打包時靜默重寫手冊。

版本修改 `macos/Release.json` 後，先生成手冊，再執行 `bash macos/scripts/build_app.sh`。本輪沒有執行測試套件；未來驗收依當次需求進行並記錄結果。

## 程式與產物

Swift 原始碼在 `macos/Sources/`；目前建置腳本在 `macos/scripts/`；舊圖示探索腳本在 `macos/design/archive/icon-scripts/`。`.build/` 與 `dist/` 是建置產物。使用者資料在 Application Support，不能用原始碼清理流程刪除。

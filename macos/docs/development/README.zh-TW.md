# Mac 開發與維護文件

最新工作：[2026-10-23 工具列／雷射／板擦修整](logs/2026-10-23/03.zh-TW.md)（1.0.16 / 20261023.2）與[目前狀態](CURRENT_STATUS.zh-TW.md)。前批操作修整見[日誌02](logs/2026-10-23/02.zh-TW.md)，Windows雷射另有[原機交接](WINDOWS_LASER_HANDOFF_2026-10-23.zh-TW.md)。下方1.0.13為歷史快照；來源、封裝與實際操作驗收分開。

先讀目前狀態，再看架構與未結問題。歷史日誌追加保存，不以新版本覆蓋舊事件。

| 文件 | 用途 | 何時更新 |
|---|---|---|
| [CURRENT_STATUS](CURRENT_STATUS.zh-TW.md) | 目前成品、可用功能、未驗收、下一步 | 每批交付前 |
| [ARCHITECTURE](ARCHITECTURE.zh-TW.md) | 模組、資料流、狀態與執行緒界線 | 職責／資料流變更時 |
| [DEVELOPMENT_LOG](DEVELOPMENT_LOG.zh-TW.md) | 每日工作、結果、命令與交接 | 開始與進行中追加 |
| [ISSUE_HISTORY](ISSUE_HISTORY.zh-TW.md) | 症狀、原因、失敗方案、解法、防止再犯 | 發現／處理問題時 |
| [DECISIONS](DECISIONS.zh-TW.md) | 架構選擇、替代方案與代價 | 做出重要決定時 |
| [CODE_REVIEW](CODE_REVIEW_2026-10-09.zh-TW.md) | 本次稽核與整理結果 | 本批完成時 |

## 目前交付與接手入口（2026-10-13）

- [Mac開發進度、排錯與交接總表](MAC_DEVELOPMENT_HANDOFF_2026-10-13.zh-TW.md)：功能／操作、近期排解、證據界線及MAC-H01–08下一步。
- 最新App為1.0.13 / 20261011.1，主執行檔SHA94b441f4…；最終功能封裝依[10/12日誌09](logs/2026-10-12/09.zh-TW.md)，一般／螢幕共用工具及指標／輔助疊層已接入，完整回歸待驗收。
- [10/13公開預覽與快取清理](RELEASE_2026-10-13.zh-TW.md)：macos-v1.0.13來源tag固定，5檔assets公開；已清理1.597GB再生快取，保留唯一最新App及開發文件。
- [體積分析](PACKAGE_SIZE_ANALYSIS_2026-10-13.zh-TW.md)與[Windows減重計劃](../../../windows/docs/WINDOWS_SIZE_REDUCTION_PLAN_2026-10-13.zh-TW.md)：WindowsStore尚未實作減重，不與Mac成品混合。

[Antigravity工具列清單](../ANTIGRAVITY_MAC_TOOLBAR_WORKLIST_2026-10-11.zh-TW.md)保留歷史／核心檢查與後續驗收目標；TB04–10已有實作但尚未全面操作確認。M37取代舊獨立螢幕catalog／樣式方案，螢幕已有共用圖層入口；不能沿用10/11「螢幕缺圖層」摘要。Windows同步歷史仍見[10/12核對](WINDOWS_SYNC_REVIEW_2026-10-12.zh-TW.md)。

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

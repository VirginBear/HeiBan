## 2026-10-23 · Mac 1.0.16 開發來源同步

產品 **1.0.16**、本機 build **20261023.2**。本次同步原始碼、可重建的十語指南供應資產、使用手冊及開發／排錯紀錄。

- 工具列依「繪圖」頁寬度偏左置中，換頁保留左錨點；一般與螢幕畫布共用外觀、分頁、設定與尺寸規則。
- 雷射改連續平滑輪廓與柔光；保留光點大小、寬度、淡出及手勢邊界設定。
- 「繪圖 → 板擦」可切換實體板擦，兩種畫布共用拖曳擦除；橡皮擦預覽／放開提交一筆復原、取消保護與指南練習防覆寫一併補齊。
- 十語 Mac QuickStart 有獨立JSON來源、生成器與SHA manifest；不依賴 Windows 資料夾，也不覆寫使用者既有練習。

詳見[目前狀態](docs/development/CURRENT_STATUS.zh-TW.md)、[開發紀錄](docs/development/logs/2026-10-23/03.zh-TW.md)、[使用手冊](docs/USER_GUIDE.zh-TW.md)與[建置說明](../docs/BUILDING.zh-TW.md)。本機Release封裝與簽章檢查已通過，完整互動／性能仍待實機驗收。這批更新GitHub來源，沒有新增DMG／ZIP發行；下方1.0.15／1.0.13內容為歷史記錄。

## 2026-10-16 · Mac 1.0.15 同步開發（歷史）

本機目標1.0.15／20261016.1，與Windows1.0.15同產品版號。同步磁鐵參考點、中心式與連續繪圖、雙擊詳細屬性、圖文分頁與常用工具、原創板擦、PDF多頁交換、Keynote轉簡報、自動保存新設定預設off與退出提示。原生SwiftUI／AppKit／PDFKit，沒有Windows執行時依賴。

詳[功能對照與待試用清單](docs/development/WINDOWS_SYNC_REVIEW_2026-10-16.zh-TW.md)／[開發日誌](docs/development/logs/2026-10-16/01.zh-TW.md)。本機App與最後編譯證據依日誌；未自動發布新GitHub Release，下面1.0.13是既有公開下載歷史。簡報需Keynote及Automation許可；外部PDF／簡報為圖片註記頁。十語手冊為正體中文21章圖解、其他語言13主題總覽，母語與互動仍待驗收。

# 黑板 · macOS 原生版

開發接手：先讀[10/13進度、排錯與待驗收總表](docs/development/MAC_DEVELOPMENT_HANDOFF_2026-10-13.zh-TW.md)與[維護入口](docs/development/README.zh-TW.md)。Mac1.0.13最終共用工具批次已封裝公開預覽，完整功能回歸待驗收；本次文檔同步沒有進版或重建。

Swift／SwiftUI／AppKit；macOS 14+，目前預編譯版支援 Apple Silicon（ARM64）。

- [下載 1.0.13 公開預覽](https://github.com/VirginBear/HeiBan/releases/tag/macos-v1.0.13)
- [安裝、更新與移除](../docs/INSTALL.zh-TW.md)
- [快速開始](../docs/QUICK_START.zh-TW.md)／[完整使用手冊](docs/USER_GUIDE.zh-TW.md)
- [建置原始碼](../docs/BUILDING.zh-TW.md)
- [目前開發狀態](docs/development/CURRENT_STATUS.zh-TW.md)／[架構與維護](docs/development/ARCHITECTURE.zh-TW.md)

此版本未完成 Developer ID 簽章／Apple 公證。Google 登入與同步、完整 PDF／SVG 編輯尚未交付；透明螢幕畫布的跨程式實機操作仍待完整驗收。

原稿與作品庫在本機保存；請先備份重要作品。程式、資源、文件與產物都在 macos/，不引用 Windows 專案。授權為 [GPL-3.0-only](../LICENSE)，第三方依各自條款。

## 1.0.13 公開預覽

2026-10-13 提供與目前本機相同的 1.0.13 / 20261011.1 成品；Apple Silicon ARM64，macOS 14+。新增一般／螢幕畫布共用工具列、四邊排版與樣式面板，原生圖片貼上、AB端點、標題列雙擊放大還原、Mac發行檢查與十語介面入口，並沿用右上導覽自動隱藏、圖層拖曳預覽及螢幕文字右鍵格式。

詳見 [1.0.13變更與操作](docs/CHANGES_1.0.13.zh-TW.md)／[發行紀錄](docs/development/RELEASE_2026-10-13.zh-TW.md)。公開包提供 DMG／ZIP、離線 HTML 手冊與 SHA-256；最新共用工具列的全功能、四邊與多螢幕互動仍待操作驗收，不能以編譯封裝成功當成全部通過。

本機只保留最新 App；build_app.sh 成功封裝／簽章後自動清理可辨識的舊 Mac App／ZIP／DMG。歷史開發文件、來源與公開成品版本／雜湊紀錄保留，舊公開包仍可從 GitHub 取得。

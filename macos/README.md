# 黑板 · macOS 原生版

Swift／SwiftUI／AppKit；macOS 14+，目前預編譯版支援 Apple Silicon（ARM64）。

- [下載 1.0.8 公開預覽](https://github.com/VirginBear/HeiBan/releases/tag/macos-v1.0.8)
- [安裝、更新與移除](../docs/INSTALL.zh-TW.md)
- [快速開始](../docs/QUICK_START.zh-TW.md)／[完整使用手冊](docs/USER_GUIDE.zh-TW.md)
- [建置原始碼](../docs/BUILDING.zh-TW.md)
- [目前開發狀態](docs/development/CURRENT_STATUS.zh-TW.md)／[架構與維護](docs/development/ARCHITECTURE.zh-TW.md)

此版本未完成 Developer ID 簽章／Apple 公證。Google 登入與同步、完整 PDF／SVG 編輯尚未交付；透明螢幕畫布的跨程式實機操作仍待完整驗收。

原稿與作品庫在本機保存；請先備份重要作品。程式、資源、文件與產物都在 macos/，不引用 Windows 專案。授權為 [GPL-3.0-only](../LICENSE)，第三方依各自條款。

## 本機開發版 1.0.13

2026-10-11補齊右上導覽自動隱藏／固定顯示、普通圖層面板原生拖曳預覽與插入位置提示，並在首頁「帳號與設定」上方新增螢幕畫布入口。螢幕畫布 T 與文字右鍵批次格式沿用1.0.12。

本機App位於 macos/dist/HeiBan.app；先正常退出舊行程再開新版。詳見 [1.0.13變更與操作](docs/CHANGES_1.0.13.zh-TW.md)／[本批開發紀錄](docs/development/logs/2026-10-11/10.zh-TW.md)。這批尚未更新上方GitHub下載；編譯封裝與實際操作驗收分開，長列表拖曳、取消／復原與懸停面板仍待試用。

本機只保留最新 App；build_app.sh 成功封裝／簽章後自動清理可辨識的舊 Mac App／ZIP／DMG。歷史開發文件、來源與公開成品版本／雜湊紀錄保留，舊公開包仍可從 GitHub 取得。

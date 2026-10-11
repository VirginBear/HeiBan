# 黑板 · macOS 原生版

Swift／SwiftUI／AppKit；macOS 14+，目前預編譯版支援 Apple Silicon（ARM64）。

- [下載 1.0.8 公開預覽](https://github.com/VirginBear/HeiBan/releases/tag/macos-v1.0.8)
- [安裝、更新與移除](../docs/INSTALL.zh-TW.md)
- [快速開始](../docs/QUICK_START.zh-TW.md)／[完整使用手冊](docs/USER_GUIDE.zh-TW.md)
- [建置原始碼](../docs/BUILDING.zh-TW.md)
- [目前開發狀態](docs/development/CURRENT_STATUS.zh-TW.md)／[架構與維護](docs/development/ARCHITECTURE.zh-TW.md)

此版本未完成 Developer ID 簽章／Apple 公證。Google 登入與同步、完整 PDF／SVG 編輯尚未交付；透明螢幕畫布的跨程式實機操作仍待完整驗收。

原稿與作品庫在本機保存；請先備份重要作品。程式、資源、文件與產物都在 macos/，不引用 Windows 專案。授權為 [GPL-3.0-only](../LICENSE)，第三方依各自條款。

## 本機開發版 1.0.12

2026-10-10螢幕畫布加入 T 文字／原生輸入；普通與螢幕畫布均可對文字框按右鍵調整大小、顏色與其他文字屬性，多選可一起套用。文字輸入區收起常駐格式列，詳見 [變更與操作](docs/CHANGES_1.0.12.zh-TW.md)。本機App在 macos/dist/HeiBan.app；先正常退出舊行程再開新版。此批尚未更新上方GitHub 1.0.8下載，實機拖曳／多螢幕仍待驗收。

本機只保留最新 App；build_app.sh 成功封裝／簽章後自動清理可辨識的舊 Mac App／ZIP／DMG。歷史開發文件、來源與公開成品版本／雜湊紀錄保留，舊公開包仍可從 GitHub 取得。

<p align="center"><img src="public/wordmark.png" alt="黑板 HeiBan" width="260"></p>

# 黑板 HeiBan

在電腦上寫、畫、整理想法。黑板提供筆記本、無邊界筆記和有邊界黑板；macOS 與 Windows 各自使用原生介面與繪圖技術。

**目前是公開預覽版。** 各平台的功能與驗收進度不同，請先備份重要作品。[安裝與更新](docs/INSTALL.zh-TW.md) · [快速開始](docs/QUICK_START.zh-TW.md) · [下載最新版](https://github.com/VirginBear/HeiBan/releases)

## Mac 開發來源更新

GitHub `main` 的 Mac 開發來源已更新至 **1.0.16 / 20261023.2**：工具列左錨點、一般／螢幕畫布共用介面、連續雷射尾跡、實體板擦、指南練習保護及擦除交易修正。[Mac 目前狀態](macos/docs/development/CURRENT_STATUS.zh-TW.md) · [完整手冊](macos/docs/USER_GUIDE.zh-TW.md) · [從來源建置](docs/BUILDING.zh-TW.md)。

這次更新原始碼、資源及文件；下方下載連結仍對應各自已發行的成品，沒有將開發來源版號直接套用到舊下載包。

## 下載

| 電腦 | 版本 | 下載 |
| --- | --- | --- |
| Apple Silicon Mac（M 系列），macOS 14+ | 1.0.13 | [DMG 安裝映像](https://github.com/VirginBear/HeiBan/releases/download/macos-v1.0.13/HeiBan-macOS-1.0.13-arm64.dmg) · [ZIP](https://github.com/VirginBear/HeiBan/releases/download/macos-v1.0.13/HeiBan-macOS-1.0.13-arm64.zip) |
| Windows 11，Intel／AMD 64 位元 | 1.0.12-preview.5 | [安裝版](https://github.com/VirginBear/HeiBan/releases/download/windows-v1.0.12-preview.5/HeiBan-Windows-Installer-1.0.12-preview.5-win-x64.zip) · [免安裝版](https://github.com/VirginBear/HeiBan/releases/download/windows-v1.0.12-preview.5/HeiBan-Windows-Portable-1.0.12-preview.5-win-x64.zip) |
| Windows 11，ARM／Apple Silicon 上的 ARM Windows | 1.0.12-preview.5 | [安裝版](https://github.com/VirginBear/HeiBan/releases/download/windows-v1.0.12-preview.5/HeiBan-Windows-Installer-1.0.12-preview.5-win-arm64.zip) · [免安裝版](https://github.com/VirginBear/HeiBan/releases/download/windows-v1.0.12-preview.5/HeiBan-Windows-Portable-1.0.12-preview.5-win-arm64.zip) |

Windows 安裝版下載檔為 ZIP，內含 `HeiBan-Setup-….exe`、說明與授權；解壓後執行安裝檔。免安裝版必須完整解壓，不能只取出 EXE。每個 Release 都附 `SHA256SUMS.txt`。

Mac 目前只提供 ARM64 下載包；尚無 Intel／Universal 包。Mac 未完成 Developer ID 簽章與 Apple 公證，Windows 未完成 Authenticode 簽章；第一次開啟可能有系統安全提示，詳見安裝指南。沒有宣稱通過所有裝置的操作或性能驗收。

## 可以做什麼

- 建立三種畫布，調整背景，管理作品縮圖、名稱與垃圾桶。
- 手寫、螢光筆、幾何圖形、文字與便簽，置入圖片。
- 修改顏色、粗細、填色、透明度、線型及物件順序，使用選取與復原／重做。
- 使用可移動／旋轉的尺規、圓規、圖釘、計算機與計時器。
- 本機保存與可編輯作品；Mac 提供 `.heiban` 原稿與 PNG／PDF／SVG／HTML 匯出，Windows 提供 JSON／`.heiban` 及 PNG／PDF／SVG／HTML 匯出。
- Mac 與 Windows 提供透明螢幕畫布與雷射工具，用於講解；Windows 右鍵物件可調整／複製／刪除，以模式按鈕或 Ctrl+Alt+D 切換穿透。跨 App／全螢幕的完整硬體操作仍待驗收。

**尚未完成：** 原生 Google 登入／雲端同步、完整 PDF／SVG 編輯、跨平台全功能一致性。Windows 最新版的操作以內建手冊及平台文件為準，x64 實機與安裝升級仍待驗收。沒有正式公開的 Web 服務網址。

## 操作說明

- [快速開始](docs/QUICK_START.zh-TW.md)
- [Mac 完整手冊](macos/docs/USER_GUIDE.zh-TW.md)／[下載 HTML 手冊](https://github.com/VirginBear/HeiBan/releases/download/macos-v1.0.13/HeiBan-User-Guide-macOS-1.0.13.html)
- [Windows 操作與開發說明](windows/README.md)
- [已知限制](docs/KNOWN_ISSUES.zh-TW.md)
- [隱私與資料保存](PRIVACY.md)
- [更新紀錄](CHANGELOG.md)

## 給開發者

| 目錄 | 技術／責任 |
| --- | --- |
| `macos/` | Swift／SwiftUI／AppKit，Mac 原生 App、文件與打包腳本 |
| `windows/` | C#／.NET 10／WinUI 3／Win2D，Windows 原生 App、文件與打包腳本 |
| `src/` | React／TypeScript／Vite，早期 Web 原型；Firebase 設定與服務須自行管理 |
| `docs/` | 文件契約、平台設計、安裝、公開發行及歷史紀錄 |

[從原始碼建置](docs/BUILDING.zh-TW.md) · [貢獻指南](CONTRIBUTING.md) · [開發紀錄入口](docs/DEVELOPMENT_INDEX.zh-TW.md)

各平台程式、快取與發行產物分開；共同遵循 JSON 文件語意，不能假設所有平台已支援全部物件。120 FPS 等為開發目標，尚未量測證實。

## 回報問題

請在 [GitHub Issues](https://github.com/VirginBear/HeiBan/issues) 附上版本、作業系統、CPU 架構與重現步驟。避免上傳含私人內容的作品或截圖；安全漏洞請依 [SECURITY.md](SECURITY.md) 私下回報。

## 授權與第三方

Copyright © 2026 VirginBear and HeiBan contributors.

HeiBan 原創原始碼以 **GPL-3.0-only** 發佈；完整條款見 [LICENSE](LICENSE)。散布修改版本時須依 GPL 提供相應原始碼與授權聲明。Windows 另含僅限平台 SDK 的 [連結／散布例外](windows/LICENSE-WINDOWS-EXCEPTION.txt)，HeiBan 與衍生程式仍須 GPL 開源。第三方套件與系統元件仍依各自條款，見 [第三方聲明](THIRD_PARTY_NOTICES.md)。參考軟體的完整副本不隨本專案發佈。

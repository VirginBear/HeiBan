# 更新紀錄

平台各自版本化。下列為公開發行摘要；完整實作／排錯史仍保留在平台開發文件。

## macOS 1.0.8 — 2026-10-09

首批 GitHub 公開預覽：ARM64 DMG／ZIP，GPL-3.0-only、安裝指南與離線手冊。

- 修正透明螢幕畫布恢復／切換作畫時遺失工具。
- 全螢幕輸入改由 AppKit 視圖擁有，SwiftUI 只渲染；補首點與空白區域命中。
- 調整跨程式疊層、Space 行為與原生對話框處理。
- 沿用前批的原生筆画、物件、作品庫、尺規、圓規、雷射與本機文件；開發架構／排錯日誌已整理。
- 跨 App 完整落筆與特殊全螢幕仍待實機確認。

## Windows 0.1.0-preview.5 — 2026-10-09

首批 GitHub 公開預覽：ARM64／x64，安裝版 ZIP（內含 Setup.exe）、免安裝 ZIP。公開包保留已建置的 preview.5 程式，額外附 GPL／第三方授權與公開安裝說明，不更改 Windows 功能來源。

- 自有區域截圖，完成後作為圖片置入畫布。
- 圓規／圓弧起訖、跨 0° 與把手修正。
- 計算機、計時器、浮動導覽與繁體中文手冊。
- 沿用 preview.4 的 A/B 端點、圖片變形、色彩屬性與尺支點。
- 尚無透明螢幕畫布／雷射、完整 PDF／SVG 或原生 Google 登入；完整互動與 x64／安裝升級待驗收。

## 早期歷史

[Mac 開發日誌](macos/docs/development/DEVELOPMENT_LOG.zh-TW.md)、[Windows 開發日誌](windows/docs/DEVELOPMENT_LOG.zh-TW.md)、[Windows 建置紀錄](windows/docs/BUILD_STATUS.zh-TW.md)。

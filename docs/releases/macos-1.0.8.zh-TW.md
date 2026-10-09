# 黑板 macOS 1.0.8 · 公開預覽

Apple Silicon（ARM64）／macOS 14+。提供 DMG、ZIP、離線使用手冊與 SHA256SUMS.txt。GPL-3.0-only；相應原始碼在本 Release tag。

## 安裝

下載 DMG，打開後把 HeiBan.app 拖到 Applications，再從應用程式啟動。ZIP 亦可完整解壓後移動 App。首次開啟可能顯示系統提示：此包未完成 Developer ID／Apple 公證。

[完整安裝與更新](https://github.com/VirginBear/HeiBan/blob/main/docs/INSTALL.zh-TW.md) · [快速開始](https://github.com/VirginBear/HeiBan/blob/main/docs/QUICK_START.zh-TW.md)

## 本版

修正透明螢幕畫布切換模式／恢復時工具被重設，改用全螢幕原生輸入，補首點與空白區域命中，調整跨程式層級與 Space／對話框處理。包含原生作品庫、畫筆、幾何、文字／便簽、圖片、尺規、圓規、圖層、雷射、計算機／計時器與離線手冊。

## 驗收範圍

本機 ARM64 Release 編譯、簽章檢查與啟動版本確認；工具切換有控制列觀察。跨 App 實際落筆、合成 PNG、多螢幕與特殊全螢幕仍未完整驗收。這次公開整理沒有執行測試套件；沒有 Intel 下載包。原生 Google／同步與完整 PDF／SVG 編輯尚未交付。

作品在本機 Application Support，升級不應清除。請先備份重要 `.heiban` 文件。下載包不包含使用者作品。完整限制與隱私見儲存庫文件。

# 黑板 Windows 0.1.0-preview.5 · 公開預覽

Windows 11，ARM64／x64；安裝版與免安裝版皆為自包含下載。GPL-3.0-only；相應來源在本 Release tag，第三方相依仍使用原授權。

## 選擇與安裝

Intel／AMD 選 win-x64；ARM 處理器（包含 Apple Silicon 的 ARM Windows）選 win-arm64。

- **Installer ZIP**：完整解壓，執行內含 `HeiBan-Setup-….exe`。
- **Portable ZIP**：完整解壓至可寫入資料夾，執行 `HeiBan.exe`；所有 DLL／PRI／資源與 portable.dat 必須保留，作品存在 Data。

[安裝與更新指南](https://github.com/VirginBear/HeiBan/blob/main/docs/INSTALL.zh-TW.md) · [Windows 操作說明](https://github.com/VirginBear/HeiBan/blob/main/windows/README.md)

## 公開包的內容

保留本機已建置的 preview.5 程式，不改動 Windows 功能來源；安裝 EXE 以 ZIP 包裝，Portable 追加 GPL、第三方授權與公開說明。公開 ZIP 的雜湊與先前內部原包不同，以本頁 SHA256SUMS.txt 為準；原始 EXE／程式 payload 沒有改寫。附最新來源 HTML 手冊，替代對包內舊功能規劃的理解。

## 功能與限制

包含原生作品庫、筆畫／幾何、便簽、圖層、圖片變形、尺規、圖釘、圓規／圓弧、區域截圖置入、計算機與計時器。Google／同步、PDF／SVG、透明螢幕畫布、雷射等未完整提供。

前批已完成兩架構封裝與 ARM64 畫面觀察；本次公開整理沒有重跑 Windows 功能／安裝流程。完整互動、x64 實機、安裝升級、手寫硬體與性能仍待驗收。包未 Authenticode 簽章，第一次執行可能有 SmartScreen 提示；來源／雜湊有疑問時先停止。

Windows 10 1809 為 API 基線，未實機驗收；Windows 11 是主要平台。不要混合不同版本的 PRI／DLL。先備份作品再更新，免安裝版更新時保留／複製 Data。

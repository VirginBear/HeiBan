# Windows 1.1.4 — OBS 螢幕畫布擷取

使用者在 OBS 的視窗擷取只看到 HeiBan 首頁。一般畫布能擷取，兩種螢幕畫布皆失敗。已讀開發索引及 Windows 現況、架構、問題、決策，保留開工 Git 狀態。

一般畫布與首頁共用 WinUI 主 HWND。螢幕畫布由獨立透明 Win32 分層 HWND 繪製，工具列另有 WinUI HWND。OBS 視窗擷取綁單一 HWND，原來源因此無法看到註記。新增明確的擷取入口，將同一張 GPU 註記影格呈現在有標題的獨立 WinUI 視窗。首版採白底註記，無桌面像素。若直播須同時出現底下程式，需在 OBS 另外設定來源。

## 實作與建置

- 工具列「更多 → 開啟 OBS 擷取視窗」建立標題固定為 HeiBan · OBS 的標準 WinUI 視窗。視窗共用最終註記 GPU 影格，尺寸依全螢幕或選定區域比例等比呈現。直播視窗只使用註記影格，背景為白色，桌面或底層程式畫面沒有傳入此視窗。未啟用時不建立額外呈現資源。
- 舊目標重建前先解除引用；關閉螢幕畫布或失去繪製裝置時關閉輸出視窗。原透明層繪製與區域輸入維持既有路徑。
- 查 OBS 官方 Window Capture 指南，視窗擷取依單一視窗及標題匹配。手冊加入標題必須相符、白底輸出與桌面合成擷取方式。十語 UI 726 鍵、0 缺漏；十語指南各 26 節／85 段。
- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:Platform=x64 --artifacts-path <scratch>/build` 成功，0 警告／0 錯誤。

## 交付與試用

執行 Package-PortableTrial.ps1 -Runtime win-x64 -Label screen-obs-2026-11-13-r1，使用來源 767eb07743e579e1bafec72a318f36513c0d1b0b。ZIP 100,527,134 bytes，SHA256 e3b1015892997527704ac017e030fbc73d868820e26e207478b9f69d258fa67d。同一版號 1.1.4。本機 verify.py 核對 422 份來源、724 份內容、CRC、PE、十語指南及獨立空白 Data。上一區域試用包與三件 1.1.3.0 Store 成品雜湊一致。

試用全螢幕及區域各一次。更多選「開啟 OBS 擷取視窗」，在 OBS 視窗擷取選 HeiBan · OBS，設定視窗標題必須相符，保持擷取視窗未最小化。在透明畫布畫線、使用雷射、復原，OBS 預覽應同步呈現於白底上。欲串流疊在別的軟體上的畫面，使用 OBS 顯示器擷取加裁切。未執行 OBS、App 操作測試、ARM64 或 Store 提交。

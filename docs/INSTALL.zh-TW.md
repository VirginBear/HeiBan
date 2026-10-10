# 安裝、更新與移除

更新：2026-10-10。下載來源：[VirginBear/HeiBan Releases](https://github.com/VirginBear/HeiBan/releases)。目前為公開預覽，請保留重要作品的 `.heiban` 原稿與備份。

## 選對版本

| 系統 | 選擇 |
| --- | --- |
| Mac「關於這台 Mac」顯示 Apple M 系列晶片 | macOS ARM64，macOS 14 或更新 |
| Mac 顯示 Intel 處理器 | 本次沒有預編譯包；原始碼建置亦未做 Intel 驗收 |
| Windows「設定 → 系統 → 系統資訊」顯示 x64 | Windows win-x64 |
| Windows 顯示 ARM 型處理器 | Windows win-arm64；Apple Silicon 的 Parallels Windows 通常屬於此類 |

Windows 11 為主要支援目標；Windows 10 1809 只是程式 API 最低基線，尚未完成實機驗收。Mac 與 Windows 版本號各自獨立。

## macOS：DMG

1. 下載 `HeiBan-macOS-1.0.8-arm64.dmg`。
2. 打開映像，把 `HeiBan.app` 拖到同一視窗的 **Applications／應用程式**。
3. 退出磁碟映像，再從「應用程式」啟動黑板。
4. 首頁點「＋」選擇筆記本、無邊界筆記或有邊界黑板。

ZIP 也能使用：完整解壓，把 `HeiBan.app` 移到「應用程式」。隨包附授權與安裝說明；正常情況只要啟動 App，不需安裝 Swift 或 Xcode。

### 第一次開啟與系統提示

這個預覽包使用 ad-hoc 簽章，**不是 Developer ID 簽署或 Apple 公證版本**。先確認來自本儲存庫、檔名與 SHA-256 相符。如系統因未識別開發者阻擋，是否允許此 App 由使用者自行決定；Apple 的 [官方開啟說明](https://support.apple.com/en-us/102445) 描述「系統設定 → 隱私權與安全性 → 仍要打開」的單一 App 處理方式。

如果提示損毀、偵測惡意軟體，或檔案雜湊不符，停止使用並重新下載／回報；不要停用 Gatekeeper、SIP、整體防毒，也不要執行移除安全屬性的網路指令。管理中的電腦請由管理員處理。

### 權限

一般繪圖不需要螢幕錄製授權。「截圖」才可能要求螢幕與系統音訊錄製權限或一次性系統選取。到「系統設定 → 隱私權與安全性」查看黑板的授權；設定變更後可能需要退出並重開。更新了未正式簽署的 App 後，系統可能重新要求授權。

### 更新與移除

- 先正常結束舊版，再以新版 `HeiBan.app` 替換「應用程式」中的舊版。
- 作品通常在 `~/Library/Application Support/HeiBan/`，與 App 分開；替換 App 不會由安裝流程刪除作品。
- 移除時把 App 移到垃圾桶；作品保留。需要清除作品前，先匯出原稿並確認備份，勿把清除資料當成一般升級步驟。

## Windows 公開包狀態

Windows ARM64／x64 的安裝版與免安裝版由獨立 Release 提供；HeiBan 使用 GPL-3.0-only 加限定 Windows SDK 例外。安裝／使用附帶的 Microsoft 元件前，必須閱讀並同意 ZIP 內 WINDOWS-RUNTIME-TERMS.txt 與 third-party/ 的原始條款。

## Windows：安裝版

1. 下載符合架構的 `HeiBan-Windows-Installer-1.0.12-preview.5-win-….zip`。
2. 使用檔案總管「全部解壓縮」。
3. 在解壓資料夾執行 `HeiBan-Setup-1.0.12-preview.5-….exe`。
4. 依畫面完成安裝，從開始功能表或捷徑開啟黑板。

目前為每位使用者安裝；桌面捷徑與 `.heiban` 關聯可選。包內已包含所需 .NET／Windows App SDK，不需另外安裝 .NET SDK。預覽安裝程式未做 Authenticode 簽章，SmartScreen 或防毒可能提示未知發行者；先核對來源與 checksum，電腦政策限制時洽管理員，勿關閉系統保護。

安裝版資料通常在 `%LOCALAPPDATA%\HeiBan\Windows\`。升級先關閉舊版再執行新安裝檔；解除安裝會保留作品。安裝／升級／解除安裝的完整實機流程仍待驗收。

## Windows：免安裝版

1. 下載 `HeiBan-Windows-Portable-1.0.12-preview.5-win-….zip`。
2. **全部解壓縮** 到自己可寫入的資料夾，例如使用者文件或隨身碟。
3. 開啟資料夾中的 `HeiBan.exe`，不要在 ZIP 內執行。

不要只複製 `HeiBan.exe`；`HeiBan.pri`、DLL、資源與 `portable.dat` 都要保留。`portable.dat` 啟用免安裝模式，作品放在同一資料夾的 `Data/`。不要直接放在唯讀磁碟或需要管理員權限的系統資料夾。

更新：退出黑板，完整解壓新版到另一資料夾，把舊版 **Data** 複製到新版資料夾，保留舊副本後再啟動。拔除隨身碟前先正常退出。移除程式資料夾也會移除其中 Data，因此先另存／備份作品。

## 校驗下載

Release 附 `SHA256SUMS.txt`，只記錄該平台公開包。

Mac 終端機：

```bash
shasum -a 256 HeiBan-macOS-1.0.8-arm64.dmg
```

Windows PowerShell：

```powershell
Get-FileHash .\HeiBan-Windows-Portable-1.0.12-preview.5-win-arm64.zip -Algorithm SHA256
```

結果應與清單相同。Checksum 用於發現下載損壞，不能代替開發者簽章或病毒檢查。

## 常見問題

- **Windows XAML parsing failed**：舊 preview.1 漏了 `HeiBan.pri`。請下載目前版本並完整解壓；不要拿不同版本的 DLL／PRI 混合替換。
- **無法建立作品資料夾**：免安裝版移到可寫入位置，保留完整資料夾。
- **文字輸入時滾輪混亂**：先完成文字輸入；回報版本與操作步驟，勿直接刪除作品排錯。
- **螢幕畫布不顯示／畫不上去**：Mac 按 `⌘⌥⇧D` 切作畫；回報是哪個 App、是否全螢幕。Windows 使用 Ctrl+Alt+A 啟動、Ctrl+Alt+D 切作畫／穿透，右鍵物件開操作選單。
- **找不到 Google 登入／PDF 編輯**：原生版尚未完整提供，見 [已知限制](KNOWN_ISSUES.zh-TW.md)。

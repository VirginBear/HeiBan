# Windows 建置與發行記錄

## 目前版本：0.1.0-preview.5

2026-10-09：完成Windows 11 ARM64原生Release publish及ARM64／x64的Portable ZIP、Inno Setup安裝檔；整輪封裝退出碼0。四包SHA-256與sidecar一致，ZIP必要PRI／執行庫／圖示／品牌／離線手冊非空，主程式PE為ARM64 `0xAA64`／x64 `0x8664`，ZIP沒有預載作品。大小與雜湊見 [preview.5產物清單](ARTIFACTS_2026-10-09_preview5.json)。

修復：自有區域截圖直接置入、請求取消隔離、圓規筆尖／半徑把手重疊、arc邊縮小與跨0°端點、前批UI編譯錯誤及PowerShell中文腳本編碼。計算機／計時器／導航／手冊已收入封裝。475項Core／手冊檢查退出碼0；原生截圖harness的100×50頂向32bit BMP裁切（20054 bytes）及兩次取消／清理通過。

實際查看ARM64首頁、隔離空白文件畫布及最終免安裝版畫布。最終ARM64 ZIP已解壓至VM `C:\HeiBanPreview\preview5`，桌面建立「HeiBan preview.5」捷徑，VM保留running供試用。沒有匯入舊作品到新Data、未強制結束其他舊版程序。

驗收界線：完整滑鼠／色輪／截圖成功置入、計算機／計時器所有互動、x64實機、安裝／升級及性能尚未驗收。CUA點擊新增沒有開啟對話框，改用命令列開啟新建空白文件確認畫布顯示；不能把核心檢查／BMP裁切當作完整UI驗收。第2～5批功能仍未完成。首次編譯與封裝編碼失敗記錄保存在 `build-logs/preview5-arm64-attempt1.log`、`preview5-packaging-attempt1.log`；成功ARM64編譯／封裝主流程見 `preview5-arm64.log`、`preview5-packaging.log`。PowerShell5.1 Transcript只保存主流程訊息，未完整保存原生compiler stdout。

## preview.4 歷史建置紀錄

2026-10-08 修正 A／B 端點、圖片變形、選取形狀色彩、作品列自動收合與尺邊支點；Windows ARM64 Release 編譯及 216 項純 C# 幾何檢查通過。完整滑鼠／色輪互動仍待驗收，詳見 [本輪紀錄](INTERACTION_FIXES_preview4.zh-TW.md)。

ARM64／x64 自包含 Portable ZIP 與 Inno Setup 安裝檔已全部完成，最終封裝退出碼 0；四個檔案 SHA-256 與 sidecar 一致，ZIP 必要 PRI／執行庫及 PE 架構檢查通過。最終建置紀錄未出現 CS／MSB／NU／WMC warning 或 error。詳見 [preview.4 產物清單](ARTIFACTS_2026-10-08_preview4.json)。

## preview.3 歷史建置紀錄

2026-10-08 對照目前 Mac 介面重整 Windows 工具列、原生圓形色輪、即時屬性及尺規；ARM64 Release 編譯成功，新版工作區已在 Windows 11 ARM64 顯示。兩端旋轉／色輪／停靠等完整互動與效能仍待驗收。詳細變更見 [介面修正](UI_PARITY_preview3.zh-TW.md)。

ARM64／x64 各完成 self-contained publish、Portable ZIP 與 Inno Setup 安裝檔，整輪退出碼 0。四個產物的 SHA-256 與 sidecar 相符；Portable 的主程式 PE machine 為 ARM64 `0xAA64`／x64 `0x8664`，均包含非空 `HeiBan.pri`、執行庫、品牌資源與 preview.3 README。詳見 [產物清單](ARTIFACTS_2026-10-08_preview3.json)。preview.2 的 EXE／ZIP／hash 封存在 `windows/dist/archive/0.1.0-preview.2/`，不移動使用者已解壓的作品目錄。

隔離預覽在 `C:\HeiBanBuild\ui-preview3`，採用原作品副本；預覽期間出現已儲存作品，已另存可開啟的 `.heiban` 到 Windows 使用者 `Documents\HeiBan\Preview-2026-10-08`。沒有強制結束仍在使用的程序。這次查看了真實工作區；完整互動、x64 實機、安裝升級與效能仍待驗收，未執行自動測試。

## preview.2 啟動修復

2026-10-08 修復發行包漏掉應用程式 `HeiBan.pri` 的啟動失敗，重新產出 ARM64／x64 安裝版與免安裝版。Windows 11 ARM64 的兩種新版均已實際查看首頁。詳見 [啟動修復紀錄](STARTUP_FIX_preview2.zh-TW.md) 與 [新版雜湊清單](ARTIFACTS_2026-10-08_preview2.json)。舊包已移至 `windows/dist/archive/0.1.0-preview.1/`，不可再用作可啟動的發行版。

## preview.1 歷史建置紀錄

以下保留原始建置與當時的驗收界線；本次使用者回報證實舊包的主視窗啟動失敗。

日期：2026-10-08（Asia/Taipei）。版本 **0.1.0-preview.1**。

## 完成的工程步驟

- 閱讀原 Windows 骨架／架構／路線與共用 JSON 契約；發現空按鈕、未使用 InkPresenter 與未量測的性能承諾，已修正實作及文件狀態。
- 在本機 Parallels Windows 11 ARM64 VM 安裝獨立開發工具 `.NET SDK 10.0.401` 與官方簽署的 Inno Setup 6.7.3。SDK ZIP 依官方 release metadata 的 SHA-512 驗證；未改系統 PowerShell execution policy、未信任開發憑證。
- 原生 ARM64 Release `dotnet build` 成功，最後明確建置報告為 **0 warnings / 0 errors**。
- x64、ARM64 各完成 self-contained publish、Portable ZIP 及 Inno Setup 安裝檔；最後整輪退出碼 0，compiler log 未出現 CS／NU／WMC／MSB warning 或 error。
- Portable ZIP 含 `.NET coreclr.dll`、`Microsoft.ui.xaml.dll`、Win2D、品牌資源、`portable.dat` 與 Data 目錄。PE machine 分別為 ARM64 `0xAA64`、x64 `0x8664`；ICO PNG 為 256×256。這些是產物結構檢查，不能代替啟動／功能驗收。
- 四個包的 SHA-256 與同名 sidecar 一致，精確大小／hash／架構清單保存於 [ARTIFACTS_2026-10-08.json](ARTIFACTS_2026-10-08.json)。
- ARM64 ZIP 解壓到 Windows 使用者暫存目錄、指定獨立資料目錄後啟動自己的 HeiBan 預覽程序；後續程序仍存在，最近 Application error log 無該 HeiBan 錯誤。這只確認程序啟動，沒有證明首頁或繪圖互動正常。
- 已結束自己的隔離預覽程序，確認預覽 Boards 為空後清除暫存 App／資料；保留編譯工具與建置快取供後續開發。
- 原始碼 `git diff --check` 通過。未修改本輪 Mac 程式或作品、沒有 Windows 預載示範作品。

## 產物

位於 `windows/dist/`，不放到 `macos/dist/` 或 Web `dist/`。

| 檔案 | 大小 |
| --- | --- |
| `HeiBan-Setup-0.1.0-preview.1-arm64.exe` | 60.5 MiB |
| `HeiBan-Setup-0.1.0-preview.1-x64.exe` | 63.0 MiB |
| `HeiBan-Windows-Portable-0.1.0-preview.1-win-arm64.zip` | 87.5 MiB |
| `HeiBan-Windows-Portable-0.1.0-preview.1-win-x64.zip` | 90.1 MiB |

## 尚未確認的範圍

- CUA 介面工具回報 Mac 鎖定且無法自動解鎖；已請使用者解鎖，因此本輪沒有查看 Windows 畫面、操作驗收、安裝／解除安裝驗收或效能量測。
- 未新增／執行自動測試，未執行跨平台 fixture 往返。
- x64 binary 在 ARM Windows 上成功建置，但尚未在 Intel／AMD 實體 Windows 執行；Surface／Wacom 等手寫硬體未驗收。
- 產物未 Authenticode 簽章、未 MSIX；GitHub workflow 只寫入本機，未推送或在雲端執行。
- PDF／SVG／完整便簽／富文本／Google OAuth／筆壓輪廓等移植仍在 [工作清單](WORKLIST.zh-TW.md)。這是可供後續驗收的開發預覽，不能宣稱與 Mac 全功能相同或達到「8ms／144 FPS」。

## 開發環境隔離

Windows SDK／編譯器放在 VM 的 `C:\HeiBanBuildTools`，本地編譯副本／快取放在 `C:\HeiBanBuild\source`；專案完整原始碼與可搬移發行包在本機 `windows/`。開發 VM 在本輪起始為 suspended，建置結束後恢復 suspended，避免長時間占用 Mac 資源。

## 公開文件中的日誌邊界

上述 build-logs 檔保留本機，避免上傳含機器環境的原始輸出；公開 Git 只有建置摘要、錯誤原因／修正與驗收界線。公開下載清單另見 docs/releases 的 preview.5 assets manifest，與原內部 dist 的 SHA 不同。

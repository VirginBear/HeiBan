# preview.2：Windows 啟動修復

日期：2026-10-08（Asia/Taipei）。

## 原因與重現

使用者回報 ARM64 安裝版及免安裝版同時顯示 `XAML parsing failed.`。舊版將 `new MainWindow()` 的所有例外都誤顯示成資料夾權限問題。

診斷版本紀錄確認例外發生於 `Application.LoadComponent` / `MainWindow.InitializeComponent`，作品資料夾已建立成功。Release 建置目錄有 `HeiBan.pri`，但 publish 與兩種發行包缺少它；只有 Microsoft 的執行庫 PRI 並不足夠。保持其餘檔案不變，補上建置產生的 `HeiBan.pri`，ARM64 主視窗立即正常載入。

此現象與 [Windows App SDK 發行資源遺漏紀錄 #6720](https://github.com/microsoft/WindowsAppSDK/issues/6720) 一致。本專案的原因由實際檔案比對與補檔後的首頁畫面確認。

## 程式修正

- `HeiBan.Windows.csproj`：新增 `IncludeHeiBanPriInPublish`，將實際生成的 `ProjectPriFullPath` 加入 `ResolvedFileToPublish`，缺少時直接報錯。適用所有使用該專案的 `dotnet publish` 呼叫。
- `Publish-Common.ps1`：兩種封裝共用必需檔案檢查，包含應用 PRI、WinUI／Win2D／.NET 庫與品牌素材；任何必需檔案缺少或為空即停止。
- `App.xaml.cs`／`MainWindow.xaml.cs`：區分建立作品資料夾、載入主視窗 XAML、設定主視窗等階段；完整例外及資源參照失敗寫入 Windows 暫存診斷紀錄。介面失敗不再聲稱資料夾不可寫。
- 版本升級 `0.1.0-preview.2`，檔案／組件版本 `0.1.0.2`，關於視窗同步更新。

## 實際結果

- ARM64、x64 各完成原生 Release publish、Portable ZIP 與 Inno Setup 安裝檔，整輪封裝退出碼 0。
- 四個發行檔的 SHA-256 與 sidecar 一致；兩個 ZIP 的 `HeiBan.pri` 均為 2,192,408 bytes。主程式 PE machine 為 ARM64 `0xAA64`、x64 `0x8664`。詳見 [產物清單](ARTIFACTS_2026-10-08_preview2.json)。
- Windows 11 ARM64：完整解壓新 Portable ZIP，使用 `portable.dat` 與自身 Data（未指定資料目錄 override）；CUA 截圖確認首頁、品牌 Logo、「免安裝版」標示出現。
- 同一 VM：以目前使用者更新已安裝 ARM64 版本，安裝器退出碼 0，安裝路徑 EXE 的 ProductVersion 為 `0.1.0-preview.2`，含應用 PRI、沒有 `portable.dat`；啟動後 CUA 截圖確認正常首頁。
- 已安裝新版保留開啟供使用者操作；VM 保持原本 running 狀態。安裝更新沒有刪除作品資料目錄，也沒有修改 Mac 版本程式。

## 驗收界線

本次確認的是發行資源完整性與兩種 ARM64 版本的主視窗啟動。CUA 經由 Parallels 的輸入操作未能確認新增／繪圖的回應，因此不記為互動驗收通過。沒有新增或執行自動測試，也沒有宣稱 x64 已在 Intel／AMD 實機通過。其餘移植與效能工作仍依 [工作清單](WORKLIST.zh-TW.md)。

## 使用新版

發行目錄 `windows/dist/` 的新版檔名含 `preview.2`。舊 preview.1 的 EXE、ZIP 與雜湊移至 `windows/dist/archive/0.1.0-preview.1/` 作歷史紀錄；使用者自行解壓的資料夾與 Data 不搬移或刪除。

安裝版直接執行新版安裝檔更新。免安裝版完整解壓 ZIP，雙擊內部 `HeiBan.exe`；若舊 Data 有作品，關閉黑板後複製至新版，保留舊副本。

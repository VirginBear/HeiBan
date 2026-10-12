# Parallels ARM64 開發試用版部署 — 2026-10-12

依使用者要求，將目前 Windows 開發來源部署到 Parallels Windows 測試機，使用本機可攜測試包，不經 Microsoft Store。VM為Windows 11 Pro ARM64；測試版沿用來源產品版本1.0.14.0，這次只以 `parallels-arm64-2026-10-12` 標示封裝批次，未核准正式進版。

## 產物與部署位置

- 來源commit：`148d427a47e03a09bf21431d248fe00e3e9b6d9a`，147個Windows來源檔納入候選來源清單。
- 執行 `Package-PortableTrial.ps1 -Runtime win-arm64 -Label parallels-arm64-2026-10-12`，封裝退出0。輸出 `dist/trials/HeiBan-Windows-Portable-1.0.14-parallels-arm64-2026-10-12-win-arm64.zip`，123,816,578 bytes，SHA256 `eed7341e766c423e0c6b9a7ce239974c64175c3533e58431e0f862105e4fe5e1`；壓縮檔有571個項目，Data為空，執行檔為PE32+ AArch64。
- 安裝資料夾：`C:\HeiBanPreview\Trial-1.0.14-parallels-arm64-2026-10-12`。桌面捷徑：`HeiBan Windows 1.0.14 ARM64 Trial.lnk`。VM與Mac共享工作區中的ZIP／sidecar SHA相同。
- 從舊 `C:\HeiBanPreview\Current\Data` 複製56個非lock資料檔，共2,588,837 bytes；逐檔SHA256相符。只複製到新資料夾，舊 `Current` 完整保留。
- 啟動後PID 13520的執行路徑指向新試用資料夾；`MainWindowTitle` 為「HeiBan 黑板 · Windows」、視窗handle非零且 `Responding=True`，FileVersion為1.0.14.0。

## 執行方式與界線

Windows VM僅有Windows PowerShell 5.1與.NET SDK 10.0.401。封裝腳本的Git萬用字元參數在5.1無法解析，因此只在 `C:\HeiBanBuild\current-source` 的臨時建置鏡像用陣列參數修正後封裝，沒有改工作區追蹤的Windows來源。部署腳本也將路徑分隔字元轉成 `[char]92` 後通過PowerShell parser；這是部署指令的修正，不涉及產品碼。

已核對封裝hash、PE架構、產品檔案版本、作品複製前後SHA、捷徑目標與啟動程序。未執行Core／UI測試、作品編輯／存檔回歸、性能測量、其他硬體或手冊語言檢查；啟動正常只證明此VM能開啟候選版，尚未完成使用者驗收。未安裝MSIX、未透過Store安裝、未改正式進版或提交Store。VM部署摘要見 [PARALLELS_TRIAL_DEPLOYMENT_2026-10-12.json](PARALLELS_TRIAL_DEPLOYMENT_2026-10-12.json)。

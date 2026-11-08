# Windows 1.1.3 Microsoft Store 封裝 — 2026-11-08

使用者明確要求預設圖示為彩色，並打包 1.1.3 上傳微軟商城。本批准予產品 1.1.3／套件 1.1.3.0 與必要檢查、x64＋ARM64 正式合併套件。沿用正式 SelfContained 封裝路徑。框架相依候選的安裝與升級尚未驗收。

已讀開發索引及 Windows 狀態／架構／決策／問題紀錄。開工既有三份未提交清理文件及三份 YouTube 草稿已記錄。預設改為 duotone，還原預設與缺少或未知風格的偏好也使用彩色。使用者已保存的 classic 選擇仍視為明確偏好。正式包與版本資料將逐步核對。
## 封裝前實際檢查

- 使用工作區 SDK 執行 Core.Tests Release，獨立 core-build 產物目錄，6,850 項通過。
- OptimizationChecks Release 使用獨立 optimization-build 及 optimization-output，68 項通過。
- Build-LocalizationCatalogs.py 十語 716 鍵、缺漏 0。Build-UserGuides.py 十語各 26 章 80 段。
- QA Release x64 獨立 qa-build 建置成功，0 警告、0 錯誤，39.25 秒。使用不存在的 qa-data，執行 --cursor-cane-validation-output。原生游標與藤條 516、主幾何／尺 18、主色盤／尺寸 42、螢幕 69，合計 645 項。新增斷言確認新設定與 ToolIcons 都以 duotone 啟動，0.5 秒門檻也核對成功。
- msbuild 的 PreventValidationStoreBuild 在 HeiBanStoreBuild=true 與 HeiBanValidationBuild=true 時回傳明確拒絕訊息。封裝保護守衛通過。
- 初始擷取 70 份既有正式 Store 檔案 SHA，排除會更新的最新指標 STORE_ARTIFACTS.json。版本報告與已交付包另存保留。
- 產品、FileVersion、AssemblyVersion、StoreIdentity、AppxManifest 已一致更新。原生驗證採隔離資料，正常關閉 QA。
- 十語「此版本的新增功能」和既有 runFullTrust 說明已整理於 STORE_LISTING_UPDATE_1.1.3_2026-11-08.zh-TW.md。說明涵蓋正式 1.1.2 之後的工具列、畫筆、尺規與筆色管理調整。

## 正式套件完成

來源凍結為 `8888999b522fa4ca3c650e200b9923c943df4e3e`。正式執行指令為 `Package-Store.ps1 -Configuration Release -FormalVersionApproved`，SDK 由工作區 `.build/tools/dotnet/dotnet.exe` 提供。建置日誌在 `.build/store-ea6b94b2012c41eea3374792d6f69fd3`。x64 59.87 秒、ARM64 59.55 秒，兩者 0 警告、0 錯誤。

| 成品 | bytes | SHA-256 |
| --- | ---: | --- |
| HeiBan-Store-1.1.3.0-x64.msix | 100,411,827 | `e68df0e78881157fcad0aff1fdcd505841f6144bd7c4f4c3d1f0acd6e19d45ea` |
| HeiBan-Store-1.1.3.0-arm64.msix | 97,843,258 | `661928e9426f7a0f6894e01b00d256f194f29fe59215c3f6c40a00c4bbae4156` |
| HeiBan-Store-1.1.3.0-x64-arm64.msixbundle | 198,257,121 | `94ec29777350ce54ef15ff5e27edae05f252fe1f33798a8a1fe75cfb7cfabaa3` |

套件位於 `windows/dist/store/`。上傳建議使用 x64-arm64.msixbundle。兩架構均核對 Package Identity／Publisher／1.1.3.0／最小 Windows 10.19041、runFullTrust、132 SVG 與 21 份指南檔。HeiBan.dll 兩架構 FileVersion 均為 1.1.3.0，ProductVersion 均為 1.1.3 加上凍結來源 SHA。確認執行檔 PE 架構、sourceSnapshot 516 份來源檔、CRC、sidecar 雜湊、合併包內兩應用套件 bytes、正式驗證方法排除及獨立更新器排除。既有 70 份 Store 檔案 SHA 保持。

第一次額外驗證沿用免安裝版的「舊音效不在套件」斷言而失敗。查明 Store SDK 的資源收集仍納入三份保留音效資源，已核對與原始資源 bytes 相同。這項條件不屬於本批版號與彩色預設要求，改以實際 Store 資源契約核對，其餘版本／架構／權限／來源／CRC 條件持續執行並通過。具體差異存 `.build/release-1.1.3-20261108/retained-assets.json`。

WACK、Store 安裝升級、ARM64 實體裝置驗證未執行。上傳、認證與發佈由使用者接續。原生測試是在隔離 x64 桌面版本執行，沒有將它寫為 Store 安裝驗收。

已匯出 [完整產物與驗證](STORE_ARTIFACTS_1.1.3.0_2026-11-08.json) 及 [十語更新文案](STORE_LISTING_UPDATE_1.1.3_2026-11-08.zh-TW.md)。正式二進位檔留在本機，公開與私人 GitHub 保存來源、雜湊與壓縮交接。

# Windows 1.1.4 Microsoft Store 封裝 — 2026-11-14

使用者要求將目前 Windows 1.1.4 候選打包供上傳 Microsoft Store。採用既有產品版號 1.1.4 及對應套件版號 1.1.4.0，沿用自包含 x64／ARM64 流程。已查開發索引、平台狀態、架構、決策與問題，保存原有未提交修改。

正式包包含物件翻轉、右鍵新增圖釘、展示工具調整、PDF 當頁圖片快取及螢幕畫布局部更新。版本來源包含移除區域螢幕畫布。將核對既有套件與本批套件結構。

## 封裝進度與驗證

- 既有 77 份 Store 檔案已記錄 SHA-256，排除會更新的最新指標 STORE_ARTIFACTS.json。
- 工作區 dotnet SDK 執行 Core.Tests Release，6,869 項通過。OptimizationChecks Release 使用獨立輸出目錄，68 項通過。
- dotnet build Release win-x64 的 HeiBanValidationBuild=true 建置 0 警告、0 錯誤。隔離資料啟動 --release-validation-output 與 --release-validation-exit，17 項螢幕畫布原生斷言通過，擦除局部影格與全幀參考像素相同，解析 66 份 SVG 選單圖示。
- x64 正式 Store 個別包已完成，ARM64 建置進行中。另以隔離資料執行原生游標、翻轉、雷射及快色回歸。

- 隔離 x64 的 --cursor-cane-validation-output 合計 656 項通過。--drawing-workflow-output 以既有合成文件驗證兩頁 PDF 匯入、編解碼、兩頁 PDF 匯出、PPTX 轉換與螢幕畫布工具。兩次 QA 視窗使用新的本機資料根。

## 上傳套件

來源 c3474367a242b4d6a86bdf5afc74637e700022e2。執行 Package-Store.ps1 -Configuration Release -FormalVersionApproved -DotnetPath <工作區 SDK>。兩架構 0 警告、0 錯誤，x64 91.30 秒，ARM64 65.14 秒。日誌在 windows/.build/store-00a110ae51ec4217bbc1af926c34f69d。

| 套件 | bytes | SHA-256 |
| --- | ---: | --- |
| HeiBan-Store-1.1.4.0-x64.msix | 100,424,493 | e5d8bb92cd1087a3893d6cc2e710bf5b12e2591e75356d82f3988e518bb53ee6 |
| HeiBan-Store-1.1.4.0-arm64.msix | 97,855,913 | f91dfbadfb62d914c4e7e4b1acbb1a562a832568a72b765436d8f7cc76ec2f21 |
| HeiBan-Store-1.1.4.0-x64-arm64.msixbundle | 198,282,442 | 1f7d396455ed2d0cef0b22f9b8003ac2525ce50212eec38e4fb204586d6fe6bf |

建議上傳 x64-arm64.msixbundle。驗證程式核對 520 份來源、兩個 PE 架構、版本、套件身分、runFullTrust、十語指南、CRC、包內套件一致及 77 份既有 Store 檔案雜湊。詳[驗證資料](STORE_ARTIFACTS_1.1.4.0_2026-11-14.json)與[更新說明](STORE_LISTING_UPDATE_1.1.4_2026-11-14.zh-TW.md)。

WACK、商店安裝升級、ARM64 實機、OBS、4K 延遲及大型文件記憶體未執行。上傳、送審及發佈由使用者接續。

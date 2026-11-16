# Windows 1.1.5 Microsoft Store 封裝 — 2026-11-16

依使用者指示封裝 Windows 1.1.5／套件 1.1.5.0，供使用者上傳 Microsoft Store。來源 79e3332，使用既有自包含 x64／ARM64 合併包流程。已核對開發索引、Windows 狀態及先前試用紀錄，保存工作區既有修改。

涵蓋垃圾桶手動永久刪除及 30 天保留、清除本頁選擇、原位文字編輯與格式重開、筆刷吸直及即時色、實心比例箭頭。原生驗證另讀文字修正試用紀錄，本批封裝核對與執行結果下列補記。

雙架構建置進行中，封裝前已取既有 Store 原件 SHA-256。Core.Tests Release 共 6,903 項通過。OptimizationChecks 首次因缺少獨立輸出資料夾參數而拒絕執行，已依工具參數要求重跑。原生文字重開、中央清除確認取消及筆刷圖示的先前診斷有同一份程式來源佐證。

## 封裝與核對

執行 Package-Store.ps1 -Configuration Release -FormalVersionApproved -DotnetPath <工作區 SDK>。兩架構都以 0 警告、0 錯誤完成。建置證據為 windows/.build/store-6af5cd1dcd984277a65b0a03cbf180e0。dotnet run 的 Core.Tests Release 為 6,903 項，OptimizationChecks Release 加獨立輸出目錄為 68 項。

| 套件 | Bytes | SHA-256 |
| --- | ---: | --- |
| HeiBan-Store-1.1.5.0-x64.msix | 100,452,366 | 36da846cdbab12cddef6238d480fc97e0aad49b1101411b5728745ca2085d74f |
| HeiBan-Store-1.1.5.0-arm64.msix | 97,883,826 | 50c079e24f8c245e61f9e7857b4edd23e27ddf04ce1fb7a53e13823ad85adb46 |
| HeiBan-Store-1.1.5.0-x64-arm64.msixbundle | 198,338,228 | 9325e20f9b2101334d2c3e97dc4e037556498e8ae21021e75d0e2b0c8de35bbc |

核對 526 份來源、兩架構 PE、套件及檔案版號、Store 身分、runFullTrust、嵌入套件與個別包一致、ZIP CRC、SHA-256，原有 128 份 Store 檔案雜湊一致。詳[驗證紀錄](STORE_ARTIFACTS_1.1.5.0_2026-11-16.json)與[十語更新說明](STORE_LISTING_UPDATE_1.1.5_2026-11-16.zh-TW.md)。上傳 x64-arm64.msixbundle。

原生診斷沿用本次試用來源的結果，未對正式包執行商店安裝／升級、WACK 或 ARM64 實機。此次未上傳、送審或上架。

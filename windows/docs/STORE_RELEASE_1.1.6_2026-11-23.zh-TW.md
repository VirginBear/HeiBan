# Windows 1.1.6 Microsoft Store 封裝 — 2026-11-23

## 開工與授權

使用者指示「幫我打包吧，我要上傳微軟商城」。接續已指定的1.1.6／1.1.6.0，製作正式自包含x64與ARM64合併套件供使用者上傳，不自行送審。只處理Windows；先讀開發索引、Windows規則、狀態、架構與問題紀錄。

開工git status為三份既有文件修改（CURRENT_STATUS、DEVELOPMENT_LOG、MARQUEE_AND_MANUAL_CLEANUP）及三份未追蹤YouTube文件，保留其內容。來源目前4dfbce3，包含已交付text-ribbon R3的ee6ecc6程式；未新增功能或更改產品版號。

本批先記錄既有Store產物雜湊、核對1.1.6.0尚無同名正式包，再執行共用來源／資料檢查與雙架構封裝。前批原生文字、長圖及實際握把驗證只在來源雜湊符合時引用，與本批新執行的結果分開記錄。開始時尚未完成封裝與驗收。

## 進行中紀錄

- 已先保存 `windows/dist/store` 中除可變 latest 別名外的 130 個既有檔案 SHA256，未刪除或搬動舊成品。
- 前次原生驗證的 `verification-r10/sources.json` 共 513 個來源／資源，逐檔對比全部相符。該證據是 2026-11-21 的驗證，本批不冒稱重新執行原生 App 測試。
- 封裝授權提交 `3b4f3b1`；本批並行執行獨立輸出目錄的五步開發檢查及正式 Store 雙架構封裝。套件建置批次為 `windows/.build/store-d6a49ee4e91148289a96e7cefc341302`。
- 已撰寫十語更新說明；明確保留原生文字輸入仍為橫排的限制，不宣稱原生直排游標編輯。

## 本批檢查與命令

使用工作區 .NET SDK 10.0.401、Python 3.11.9。在根目錄執行：

```powershell
$env:PATH=(Resolve-Path 'windows/.build/tools/dotnet').Path+[IO.Path]::PathSeparator+$env:PATH
./windows/scripts/Verify-Development.ps1 -OutputDirectory windows/.build/store-release-116-20261123/verification
./windows/HeiBan.Windows/Packaging/Package-Store.ps1 -Configuration Release -FormalVersionApproved -DotnetPath (Resolve-Path 'windows/.build/tools/dotnet/dotnet.exe').Path
```

五步開發檢查 exit code 全為 0，來源在檢查期間未變。架構 199 份 C#、0 違規、28 項檢查器自驗；Core 6,918 項、Optimization 68 項。十語介面每語 772 個來源、無缺譯；十份手冊各 26 節，產生檔一致。原始證據：`windows/.build/store-release-116-20261123/verification/verification.json`。

本批不改文件格式、產品行為或手冊入口，沒有新增架構決策。未重跑原生 App、硬體 IME、實測繪圖延遲；前次同來源的原生結果見 [文字驗證摘要](TEXT_RIBBON_VERIFICATION_2026-11-21.json)。正式套件的商店安裝／升級、WACK、ARM64 實機、上傳及認證均未執行。

## runFullTrust 說明（需要重新填寫時）

HeiBan is a WinUI 3 desktop whiteboard packaged as MSIX. runFullTrust is required to run HeiBan.exe as a standard-user desktop app. It uses desktop APIs for local documents, user-selected file import/export, and a screen annotation overlay. It does not require administrator privileges or install drivers or system services.

## 完成結果

雙架構建置均 0 警告、0 錯誤。兩份 HeiBan.exe 的 FileVersion 均為 1.1.6.0，ProductVersion 為 1.1.6+3b4f3b1dbfda7ac8c4fe29458e522bccaeae0400。

| 套件 | Bytes | SHA256 |
| --- | ---: | --- |
| HeiBan-Store-1.1.6.0-x64.msix | 100,481,498 | 2c53b26d89c7f7902b8a720c45570ebd11650930cf0e60fbb01fb44646d806c2 |
| HeiBan-Store-1.1.6.0-arm64.msix | 97,912,946 | dd7ffbc1598914ce3844d92447f57246870b292504d0b46488fd801fecd2855d |
| HeiBan-Store-1.1.6.0-x64-arm64.msixbundle | 198,396,479 | 74494d2015ac5b255d8106db6425a5c4ffc54ec27c9270265882a623e3ecaea9 |

供 Partner Center「套件」欄位上傳：`windows/dist/store/HeiBan-Store-1.1.6.0-x64-arm64.msixbundle`。無須分別上傳兩個架構包。套件未簽章，採現行 Store 重新簽章流程，未改本機安裝安全設定。

獨立核對命令 `python windows/.build/store-release-116-20261123/check-store.py` 成功：540 份封裝來源目前雜湊符合、130 份既有 Store 檔案未變；三個 ZIP CRC 與 SHA256 sidecar、身分、10 語資源、runFullTrust、x64／ARM64 PE、bundle 內嵌 MSIX 位元組一致。正式 DLL 未包含指定原生驗證方法，無使用者 Data、獨立更新器、PDB 或 Roslyn DLL。封裝工具另逐位元組核對 28 份法律文件、21 份指南／入門文件與 132 份 SVG 圖示。

詳 [本批驗證摘要](STORE_ARTIFACTS_1.1.6.0_2026-11-23.json) 與 [十語更新說明](STORE_LISTING_UPDATE_1.1.6_2026-11-23.zh-TW.md)。本批封裝與檢查未發生失敗；既有工作樹文件修改、YouTube 未追蹤文件、舊產物及使用者資料保持原狀。公開與私人 GitHub 分開記錄，套件本體留在本機，未另建立公開 GitHub Release。

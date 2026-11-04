# Windows 1.1.2 商店封裝 — 2026-11-04

使用者先明確指定本系列1.1.2，試用圖示與筆色調整後要求「打包吧 我要更新微軟商城的版本了」。本批准予Windows正式產品1.1.2／套件1.1.2.0、必要驗證與SelfContained x64＋ARM64 Store合併包；上傳／送審仍由使用者執行。此紀錄不表示已通過Microsoft認證。

## 開工與目前進度

已讀開發索引、Windows規則／CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY／DECISIONS、前次1.1.1發行紀錄與Package-Store腳本。git起點cc95b48，保留原三份dirty清理文件及三份YouTube未追蹤文件，狀態／patch存`.build/release-1.1.2-20261104`。舊Store檔先保存SHA，不刪舊包／不搬作品，只改Windows。版本來源已是1.1.2／1.1.2.0，無需再提高。

相對1.1.1：螢幕操作模式右鍵長按輪盤（可關閉，短按保留原軟體選單）、配對螢幕＋鼠標／畫筆模式圖示、可切換A彩色細描邊與原風格、筆身跟隨筆色、紫色形狀分類與框線選取圖示、十語指南同步。前批15 screen＋36色／identity＋132 SVG GPU及真實切工具證據有獨立來源，本批不直接套用為新跑測試。

封裝前查到Store腳本只核對MenuIcons頂層，需補遞迴檢查Duotone子目錄，確保132份SVG全進兩架構。Core／Optimization、語系與指南生成、診斷Store排除守衛、正式雙架構及ZIP／版本／身分／來源SHA／舊檔保持核對結果待逐步追加，不預填成功。WACK、Store安裝升級與ARM64實機尚未執行。


## 新跑的封裝前檢查

- `dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release --artifacts-path windows/.build/release-1.1.2-20261104/core-build`：3445 PASS。
- `dotnet run --project windows/HeiBan.Windows.OptimizationChecks -c Release --artifacts-path windows/.build/release-1.1.2-20261104/optimization-build -- windows/.build/release-1.1.2-20261104/optimization-output`：68 targeted data checks PASS。與Core使用不同artifacts目錄並行，不共用obj。
- `python windows/scripts/Build-LocalizationCatalogs.py`：十語708keys、missing0；`Build-UserGuides.py`：十語各26節80段，生成結果與來源一致。
- `dotnet msbuild windows/HeiBan.Windows/HeiBan.Windows.csproj -target:PreventValidationStoreBuild -p:HeiBanStoreBuild=true -p:HeiBanValidationBuild=true -p:ArtifactsPath=windows/.build/release-1.1.2-20261104/guard-build`：預期exit1及明確排除訊息，守衛通過，非正式封裝失敗。
- `git diff --check`／metadata核對通過；95份舊Store檔（包括已提交包／sidecar／版本報告）先取SHA。1.1.2.0未有既存正式包，不覆寫其他版本。Name／Publisher／PublisherDisplayName等與1.1.1維持相同。

十語「此版本的新增功能」及339字元runFullTrust說明存[清單更新文案](STORE_LISTING_UPDATE_1.1.2_2026-11-04.zh-TW.md)。受限Capability仍只有runFullTrust，mediumIL／不請求管理員權限。原生行為與實機回饋沿前批來源，這輪不重啟App／不把舊原生數字當新跑；WACK、Store安裝升級與ARM64實機未執行。接著凍結來源並封裝SelfContained雙架構。


## 正式Store成品核對完成

程式來源凍結：`cfb7b9d996a2837efe20af55bd076df64c445461`。正式命令：

```powershell
& windows/HeiBan.Windows/Packaging/Package-Store.ps1 -Configuration Release -DotnetPath 'D:/Game/HaiBan x64/windows/.build/tools/dotnet/dotnet.exe' -FormalVersionApproved
```

建置證據`.build/store-de1581e0578a42cfb51789ba7d5a6253`；x64 70.18秒、ARM64 64.28秒，皆0警告0錯誤。SelfContained、formalVersionApproved=true、無developmentLabel，未簽章／未代上傳／送審。兩包皆核對132 SVG（含Duotone子目錄）、21指南檔及10語、runFullTrust／mediumIL、產品身分、版本及最低Windows10.19041。

| 成品 | bytes | SHA256 |
| --- | ---: | --- |
| HeiBan-Store-1.1.2.0-x64.msix | 100095801 | `bd372eedc2f21fc3d48cac9316857826badd9217b9c591f40aa111cd31999fb1` |
| HeiBan-Store-1.1.2.0-arm64.msix | 97527337 | `590828ebd4dc7466951a8f573278d721e56433af5b2d7ea5a03ccc6d00d530ea` |
| HeiBan-Store-1.1.2.0-x64-arm64.msixbundle | 197625174 | `a7b2e60c3c4bf80f4872426f2d9f5640850912fff8264ba8bb61f7b0d697f975` |

`python windows/.build/release-1.1.2-20261104/verify-final.py`實查490來源raw-byte SHA、三成品與sidecar SHA／ZIP CRC、bundle內兩個MSIX逐byte核同；每包無使用者Data／獨立Updater／portable marker／PDB，所有驗證方法排除。四份PE（x64／ARM64的HeiBan.exe／dll）FileVersion1.1.2.0，ProductVersion1.1.2+cfb7b9d996a2837efe20af55bd076df64c445461；只是資源檢查，不是ARM64實機執行。

95份舊Store檔SHA全同，其中43份為MSIX／bundle，其餘sidecar與版本報告。驗證腳本沿舊欄名一度將95檔標oldPackagesPreserved，已明確分成oldStoreFilesPreserved=95／oldPackagesPreserved=43；分類更正不改實際SHA驗證結果。Store generic報告更新指向1.1.2.0，所有舊版本報告保留。與使用者接受的ae0bd18試用相比，App程式與素材沒有再改動，僅封裝腳本補遞迴圖示核對與本輪核准／文件。

上傳這一份即可：`windows/dist/store/HeiBan-Store-1.1.2.0-x64-arm64.msixbundle`（197625174bytes，約188.47MiB）。不需分開上傳x64與ARM64。十語更新說明與339字元runFullTrust用途見[商店清單更新文案](STORE_LISTING_UPDATE_1.1.2_2026-11-04.zh-TW.md)。本批未開Partner Center或代送審，不宣稱Microsoft已認證；WACK、Store安裝升級、ARM64實機及全部DPI／硬體延遲未執行，前批原生與使用者回饋保留原來源。

程式與紀錄分開commit後推送公開庫；私人產品節點／使用者接受試用／壓縮交接另庫更新。原三份dirty清理文件及三份YouTube未追蹤文件保留未提交，沒有刪舊檔或搬作品。dist不隨Git同步，其他電腦須另取得本套件或依來源重建。

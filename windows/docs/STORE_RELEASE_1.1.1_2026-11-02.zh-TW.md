# Windows 1.1.1 商店更新 — 2026-11-02

使用者試用object-drag-2026-11-02-r2後表示「我覺得很好」，明確要求打包上Microsoft Store，指定版本1.1.1。本批准予Windows產品1.1.1／套件1.1.1.0、必要驗證及x64＋ARM64正式封裝；上傳／送審由使用者自行操作，不代表已送審／發布。維持SelfContained，保留舊商店包與作品。

## 開工與範圍

讀docs/DEVELOPMENT_INDEX、Windows CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY及AGENTS；保存git status與既有三份dirty清理文件差異、三份YouTube未追蹤文件。來源起點44e7749，舊Store MSIX／bundle先取SHA保存至.build/release-1.1.1-20261102/old-store-hashes.json。只修改Windows版本metadata、必要發行文案／紀錄；封裝與測試結果待追加，不預填成功。

相對1.1.0：一般框選流程與順暢度修正、文件範圍圖片複製與中央成功提示、最上層物件外框點選及Ctrl多選、兩畫布獨立平移預覽與有預算的Z段快取、藤條靜音與再次點擊設定、十語指南同步。前批2423 Core／原生像素及實際拖動證據有各自來源，本批需區分新執行的檢查。

## 版本與封裝前檢查

產品Version1.1.1、FileVersion／AssemblyVersion1.1.1.0；StoreIdentity與manifest1.1.1.0。Name／Publisher／PublisherDisplayName／Store ID等均保持原值。AGENTS記錄本次使用者正式核准，不自動推定後續版號。

本輪實際執行：

- `dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release --artifacts-path windows/.build/release-1.1.1-20261102/core-build`：2423 PASS。
- `dotnet run --project windows/HeiBan.Windows.OptimizationChecks -c Release --artifacts-path windows/.build/release-1.1.1-20261102/optimization-build -- windows/.build/release-1.1.1-20261102/optimization-output`：68 targeted data checks PASS。兩項使用獨立artifacts目錄並行，沒有共用obj；log於本批.build。
- `python windows/scripts/Build-LocalizationCatalogs.py`：十語702keys、missing0；`Build-UserGuides.py`：十語各26節78段。生成內容與既有來源一致，未改使用者指南作品。
- `dotnet msbuild windows/HeiBan.Windows/HeiBan.Windows.csproj -target:PreventValidationStoreBuild -p:HeiBanStoreBuild=true -p:HeiBanValidationBuild=true -p:ArtifactsPath=windows/.build/release-1.1.1-20261102/guard-build`：預期exit1，明確「Release validation hooks must not be compiled into Microsoft Store packages.」，守衛通過；不是正式封裝失敗。
- `git diff --check`與版本metadata差異核對：來源凍結前及交付前皆通過。舊40份MSIX／bundle SHA已保留。

使用者已接受最新ec86503來源的免安裝試用行為。前批Core／原生35斷言、10幀GPU maxDiff0與實際拖動有獨立來源，見OBJECT_DRAG_AND_CANE_SETTINGS_2026-11-02.zh-TW.md；本批未重新啟動App或重跑原生測試。尚未執行WACK、Microsoft Store安裝／升級、ARM64實機、全部DPI與硬體ms／FPS量測；不宣稱已通過Microsoft審查。

十語「此版本的新增功能」及317字元runFullTrust說明已備於STORE_LISTING_UPDATE_1.1.1_2026-11-02.zh-TW.md。接著凍結來源，執行正式SelfContained雙架構Package-Store；結果另追加。

## 正式成品與核對完成

程式來源凍結：`bb15888765c115813ed6b3df53addd14aa382e55`。正式命令：

```powershell
& windows/HeiBan.Windows/Packaging/Package-Store.ps1 -Configuration Release -DotnetPath 'D:/Game/HaiBan x64/windows/.build/tools/dotnet/dotnet.exe' -FormalVersionApproved
```

本次建置證據：`windows/.build/store-680e9a1110fd49f8840df520d93ab1fa`。x64 74.71秒／ARM64 62.55秒，兩者0警告0錯誤；SelfContained、formalVersionApproved=true、developmentLabel空值，未簽章／未送審。供Partner Center上傳合併bundle，不需分別上傳兩個MSIX。

| 成品 | bytes | SHA256 |
| --- | ---: | --- |
| HeiBan-Store-1.1.1.0-x64.msix | 100040600 | `04609a38f77b2b8f44baa0a972e0356a3a4bd8ceb4e1a5794d3f9e6204c6e6d9` |
| HeiBan-Store-1.1.1.0-arm64.msix | 97472023 | `f3ad018cf186c93ef7fde5baeea5163d1437730f14b8e32592763c3c11e6fc9e` |
| HeiBan-Store-1.1.1.0-x64-arm64.msixbundle | 197514657 | `85c1400ae94430309fd4c440881238e8d71127e0c0cd6e38616470af6491e968` |

實際執行`python windows/.build/release-1.1.1-20261102/verify-final.py`：407來源raw-byte SHA、三個成品與sidecar SHA／ZIP CRC、bundle內x64與ARM64包逐byte核同、manifest身分／版本／架構／最低OS／10語與runFullTrust用途核同；每包64SVG與21個指南檔（10 HTML、10練習、manifest）均與來源相同，10個診斷方法／getter不存在於正常HeiBan.dll。40份舊MSIX／bundle仍原路徑且SHA全同。`package-inspection-final.json`保留。

四份EXE／DLL使用FileVersionInfo靜態讀取，均FileVersion1.1.1.0／ProductVersion1.1.1+來源SHA，`peversions.json`保留；未執行ARM64二進位。版本報告位於dist/store/STORE_ARTIFACTS_1.1.1.0.json（含完整sourceSnapshot），generic STORE_ARTIFACTS.json指向本版；1.1.0等歷史報告／包保留。

可上傳：`windows/dist/store/HeiBan-Store-1.1.1.0-x64-arm64.msixbundle`，197,514,657bytes（約188.36MiB）。十語「此版本的新增功能」與317字元runFullTrust短文見[商店更新文案](STORE_LISTING_UPDATE_1.1.1_2026-11-02.zh-TW.md)。未開Partner Center、未代上傳／送審或宣稱通過認證；WACK、Store安裝升級、ARM64實機及硬體延遲量測仍未執行。

公開程式碼及記錄分開commit後push；私人產品節點／壓縮交接另庫更新。未刪舊檔、未搬／覆寫作品，既有三份dirty清理紀錄與三份YouTube文件保持原內容未混入提交。dist不隨Git同步，其他電腦需另取得本套件或依來源重建。

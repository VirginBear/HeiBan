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
- `git diff --check`與版本metadata差異核對：待來源凍結時執行。舊40份MSIX／bundle SHA已保留。

使用者已接受最新ec86503來源的免安裝試用行為。前批Core／原生35斷言、10幀GPU maxDiff0與實際拖動有獨立來源，見OBJECT_DRAG_AND_CANE_SETTINGS_2026-11-02.zh-TW.md；本批未重新啟動App或重跑原生測試。尚未執行WACK、Microsoft Store安裝／升級、ARM64實機、全部DPI與硬體ms／FPS量測；不宣稱已通過Microsoft審查。

十語「此版本的新增功能」及317字元runFullTrust說明已備於STORE_LISTING_UPDATE_1.1.1_2026-11-02.zh-TW.md。接著凍結來源，執行正式SelfContained雙架構Package-Store；結果另追加。

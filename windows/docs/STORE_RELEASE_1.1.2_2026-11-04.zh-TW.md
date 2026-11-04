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

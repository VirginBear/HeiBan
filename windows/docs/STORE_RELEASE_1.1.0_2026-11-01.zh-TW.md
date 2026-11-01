# Windows 1.1.0 商店更新 — 2026-11-01

已完成產品1.1.0／Store套件1.1.0.0。供使用者自行上傳：`windows/dist/store/HeiBan-Store-1.1.0.0-x64-arm64.msixbundle`（x64＋ARM64）。原始碼與必要驗證完成；未代上傳／送審。

## 使用者核准與開工

使用者明確要求「下一個版本號1.1.0」「完整處理到打包好的檔案，要上傳微軟商城」，並要求改善更多選單圖示。採產品1.1.0／套件1.1.0.0，保留既有套件及作品。延續上架前審查，先修正三項已重現問題及輔助缺口，再統一圖示、更新十語、驗證與封裝；不代替使用者送審。

開工基準9e8babb；既有三份YouTube未追蹤文件與本輪尚未提交審查文件保留。審查探針已確認跨畫布偏好遺失、尺規反覆吸附、擦除／插入交易競爭。更多圖示根因：CreateIcon把原本開放式描邊路徑直接交給PathIcon填色，形成缺線或不規則黑塊；將改為相同原創向量的SVG描邊資產，保留入口與操作。

## 實作過程（當時紀錄）

版本及修正尚在實作；編譯、實機與封裝結果不預填成功。

- 首輪編譯發現StackPanel沒有IsEnabled、Grid.SetRow需要FrameworkElement；改為停用ScrollViewer（含編輯控制）及正確型別。後續編譯重新確認。

- 第一次獨立原生驗證實際發現冷啟動螢幕工具列重建的COM錯誤0x800F1000：未載入／隱藏的WinUI樹Parent為null，但Children仍持有固定按鈕，Detach失效後重掛報錯。改由ConditionalWeakTable記住實際Panel集合，重建／切頁先從已知集合釋放，再附加；保留弱鍵生命週期，不以丟棄／重建所有按鈕掩蓋問題。首輪GUI未通過，後續重驗。

- 第二輪原生驗證通過13斷言、1次局部／全幅擦除像素比較及63SVG解析。補驗四邊重掛、圖示實際渲染；生成整圓亦納入等待擦除的命令邊界。
- CoreChecks本輪2365通過。OptimizationChecks首次錯用專案目錄、次輪與Core共用obj並行寫入失敗（CS2012）、第三次誤用不存在的--output選項；改用正確專案與單一新輸出目錄，循序重跑，先前失敗不計為通過。

## 封裝前驗證完成

- `dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj -c Release`：本輪最終2365 PASS（含更新後十語手冊）。
- `dotnet run --project windows/HeiBan.Windows.OptimizationChecks/HeiBan.Windows.OptimizationChecks.csproj -c Release -- windows/.build/release-1.1.0-20261101/optimization-output-r4`：68 PASS，前三次命令／並行obj失敗已在上方保留。
- `dotnet build windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 --artifacts-path windows/.build/release-1.1.0-20261101/qa-build-r4 -p:Platform=x64 -p:WindowsPackageType=None -p:AppxPackageSigningEnabled=false -p:HeiBanValidationBuild=true`：0警告0錯誤。
- 獨立原生CLI：`--release-validation-output=.../gui-results-r4 --release-validation-exit`；以新的HEIBAN_WINDOWS_DATA_DIRECTORY隔離啟動。17斷言（四邊重掛、整筆尺規鎖邊、遠處不吸附、完成擦除後插入、兩次獨立Undo、過期epoch拒絕、自有視窗及計時停止）通過；實際Win2D局部擦除與全幅參考逐像素一致1次。63SVG解析及原生contact sheet繪製成功，人工檢視描邊清楚且一致。資料及圖示證據只在忽略的.build，不含使用者作品。
- `python windows/scripts/Build-LocalizationCatalogs.py`：10語694來源，缺譯0；新增直接T字串覆蓋預檢，不只核宣告表。三份新增F格式字串也補譯，所有數字占位一致。
- `python windows/scripts/Build-UserGuides.py`：十語各26章72段，含可編輯操作指南；生成檔與來源同步。
- `dotnet msbuild ... -target:PreventValidationStoreBuild -p:HeiBanStoreBuild=true -p:HeiBanValidationBuild=true`：按預期拒絕（明確Error訊息），禁止診斷hook進入Store成品；正常Store建置另驗。
- `git diff --check`：通過。舊Store所有MSIX／bundle已先取SHA，封裝後回核不刪不改。

硬體指標端到端延遲、全部視覺情境／多DPI拖動、ARM64實機、WACK與Store安裝未執行；不宣稱這些已通過或Microsoft已認證。正式包維持SelfContained。來源凍結後再執行Package-Store.ps1 -FormalVersionApproved，結果於下方追加。

## 來源凍結補正

第一輪雙架構封裝成功（257ef60），最終相容性複核發現本輪修改Portable README時移除了原本刻意保留的UTF-8 BOM。恢復Package-PortableTrial.ps1的BOM，以保留Windows PowerShell5.1中文字串相容；Store腳本原本無BOM且使用英文，不需變更。雖不影響Store執行碼，為使完整sourceSnapshot與兩架構版本一致，首輪本批1.1.0產物移至.build/release-1.1.0-20261101/superseded-store-source257保留，再由補正commit重新正式封裝；未刪改既有已發布／已提交37個套件。

## 最終商店成品

來源凍結：`fa40be99c750e6e1819a94c1b44a9cf8adc8cea9`。正式執行：

```powershell
& windows/HeiBan.Windows/Packaging/Package-Store.ps1 -Configuration Release -DotnetPath 'D:/Game/HaiBan x64/windows/.build/tools/dotnet/dotnet.exe' -FormalVersionApproved
```

最終建置證據：`windows/.build/store-52e9c86bc4f146d7acbd2d4dc2d5b8fd`。x64／ARM64 Release建置完成；SelfContained，正式核准旗標true，developmentLabel空值，尚未簽章／送審。合併包約188.31MiB，Partner Center「套件」上傳這一份即可。

| 成品 | bytes | SHA256 |
| --- | ---: | --- |
| HeiBan-Store-1.1.0.0-x64.msix | 100012407 | `8f58028ec94a0cabff90806e6eeeab4a72c7ade10ce7a6e5364b6cb07c5942be` |
| HeiBan-Store-1.1.0.0-arm64.msix | 97443736 | `d46c2243032f8a1eb17b34528ac93af065a4360e5723333626f848446079d8a8` |
| HeiBan-Store-1.1.0.0-x64-arm64.msixbundle | 197458176 | `a7799085a7ccb5f7f0a23b37d0b12425a9def99ff366d8fa13686ee01eaade66` |

`python windows/.build/release-1.1.0-20261101/verify-final.py`：390來源檔SHA、三份成品／sidecar SHA與ZIP CRC、manifest身分／版本／架構、bundle內兩包完全相同、每包63SVG與10語HTML內容一致、診斷hook未編入皆通過。37個既有套件SHA仍全同。四份EXE／DLL靜態PE讀取均為FileVersion1.1.0.0／ProductVersion1.1.0+fa40be99c750e6e1819a94c1b44a9cf8adc8cea9；未執行ARM64二進位。Windows PowerShell5.1.26100.9818實際Parser核對Portable腳本語法成功且BOM保留。

證據：`windows/.build/release-1.1.0-20261101/package-inspection-final.json`、`peversions.json`及兩個建置日誌；正式成品同目錄的`STORE_ARTIFACTS_1.1.0.0.json`保留完整來源快照與payload檢查。x64展開251,608,436bytes；六個主程式／資源檔（含resources.pri）合計4,742,080bytes，約1.9%；剩餘體積主要為執行階段，不宣稱本輪縮小下載幅度或達成特定延遲。

更新文案見[十語Store清單](STORE_LISTING_UPDATE_1.1.0_2026-11-01.zh-TW.md)。既有三份YouTube未追蹤文件原樣保留；未複製／刪除使用者作品，未清除歷史發行。原生QA使用獨立資料根，不代表Store安裝或全部硬體／使用者情境驗收。

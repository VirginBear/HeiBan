# 2026-11-06 Windows 鋼筆、商店更新與側邊工具列

使用者要求停筆拉直再縮短 0.2 秒、採 Microsoft Store 更新，以及改善左右工具列佔用空間。依 11-05 審視選擇能獨立驗證的項目。兩畫布目前共用 0.8 秒門檻。新版應用仍初始化 GitHub 更新服務，免安裝包另含約 74 MB 的獨立更新器。側邊圖文模式把分頁和工具並排，筆刷又橫排快捷色，形成三組寬度疊加。已記錄既有三份修改與三份未追蹤草稿。
實作中已將兩畫布共用門檻改為 0.6 秒，並更新原有門檻斷言。GitHub 背景服務退出應用編譯，啟動與關閉也移除更新租約和工作。封裝不再產生獨立更新器。舊音效三個檔案排除於新封裝，來源與授權留存。尺繪製改由共用 renderer 持有可重用文字格式，兩畫布各自傳入畫布 DIP 或疊加層實體像素。頂點編輯保留原點的額外資料，將 JSON 編碼移至序列化邊界。

QA 第一輪和整合後建置皆為 0 警告、0 錯誤。指南第一次把更新段落縮為一段，觸發生成器最少兩段的契約。拆分商店更新與免安裝使用說明後，十語 26 章各 80 段生成成功。Core 與 Optimization 同時使用預設 obj 導致 MSB3713 共用檔鎖，Optimization 68 項成功，Core 改順序執行。原生兩畫布回歸正在隔離資料夾驗證。

## 驗證與交付

- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/store-compact-20261106/qa-build` 最終 0 警告、0 錯誤。Core.Tests Release 6848 項，OptimizationChecks Release 68 項。Core 新增旋轉頂點與未知欄位的往返檢查。
- 獨立資料根啟動 `--cursor-cane-validation-output=…/qa-output-r2`。原生 515 + 主正形 11 + 色盤 33 + 螢幕 57 項通過。兩種顯示模式都驗四邊切換。一般畫布左右實測上限 72 DIP，螢幕畫布實測上限 74 DIP。頂部與底部快色回橫排，側邊保持筆刷下方。原生結果的停筆門檻為 0.6 秒。
- `Package-PortableTrial.ps1 -Runtime win-x64 -Label store-compact-2026-11-06-r1` 成功。來源 9489cb9b0bc479b49dfd13cd9ff718632c6fa839，產品 1.1.2，723 份 payload、418 份來源、132 SVG、十語指南、ZIP CRC、雜湊、獨立空 Data 核對通過。驗證發行組件無 GitHub 更新服務、UI 與租約呼叫，目錄無獨立 updater 與三個歷史音效檔。更新器 legacy 源碼與測試保留在舊路徑，當批未重跑 legacy updater 測試。
- 免安裝 ZIP 100,480,300 bytes，SHA-256 `1226800a1485edfc0a3cde4ba776acb0c2c504d3fcc167b429ef9903b7df748a`。與前份 133,754,447 bytes 相差 33,274,147 bytes，約 24.9%。解壓目錄從 325,758,125 降到 251,635,726 bytes，約少 74.1 MB。正式 1.1.2.0 三包及上一試用 ZIP SHA 保持。
- `Package-Store.ps1 -RuntimeMode FrameworkDependent -DevelopmentLabel store-compact-framework-2026-11-06` 產生獨立候選。x64 52,681,899 bytes，ARM64 51,346,890 bytes，bundle 104,030,823 bytes。相對正式自包含 bundle 197,625,174 bytes 約少 47.4%。兩架構檢查依賴 Microsoft.WindowsAppRuntime.2 最低 2.5.1.0、套件身分、組合內 bytes 與資源核對。候選為無簽章開發套件，乾淨機安裝、商店升級、ARM64 實機及 WACK 未執行。商店下載體積依商店實際投遞另量測。
- 前後 x64 一般發行組件依序以 `--performance-output` 與不同隔離資料根執行合成場景。一般畫布 0/300/1000/10000 物件的 stable p95 為 0.630/0.365/0.524/0.836 ms → 0.548/0.546/0.353/0.911 ms。1000 物件重建 p95 為 23.546 → 19.649 ms。單輪 synthetic 有波動，沒有取得可歸因的端到端改善數字。
- 前後兩版螢幕效能腳本皆在旋轉筆跡的「局部／完整影格」比較停止。檢查 `Render()` 可確認 `_benchmarkFullFrames` 分支使用原位 VisibleObjects，局部渲染則從 ObjectDragRenderer 套拖曳位移。兩個影格的輸入狀態不等價。螢幕 p95 及產品殘影尚未由此腳本驗證，將修正參考影格列為後續測量前提。本批尺顯示／隱藏像素比較已通過。
- 手動試用請以左右窄欄操作、切換圖文分頁、快色仍可用、拖回上方恢復橫排，以及兩畫布鋼筆停住約 0.6 秒拉直為驗收。原生診斷使用合成輸入。人手操作、不同 DPI 與實際輸入到呈現延遲未執行。

[產物與量測資料](STORE_COMPACT_TOOLBAR_TRIAL_2026-11-06.json)。

# Windows 效能第二批：視野候選索引

## 開工與範圍

使用者要求繼續開發；延續 Windows 工作清單 GO／驗證／GitHub 同步授權。2026-10-11 開工 HEAD `163e660bcc722f1ecf31f218b03accba2819d92a`，git status 只有既有未追蹤 `.vscode/`，保留不讀取、不加入提交。已讀開發索引、Windows 狀態／架構／問題與工作清單。

第一批 native 視野重建仍為主要成本。本批選 PERF-04 的渲染候選索引，一個主要策略；PERF-05 GPU 分區快取與命中／擦除／框選索引另批評估。保留原掃描 renderer 作相容退路，不以合成數字承諾 FPS。資料格式、版本、更新器、其他平台及送審 bundle 不變。

## 進行中紀錄

- 開工讀 renderer 誤用不存在的 Rendering/ 路徑，Get-Content 報錯；改讀 Engine/Direct2DCanvasRenderer.cs。
- 現有模型允許交易內直接改幾何／Z／物件清單，Generation 不足以判斷快取有效。索引需要無配置欄位掃描與文件／排序視圖身分；候選必須保留穩定全域 Z 與即時頁面／可見性過濾。
- 先增加稀疏合成場景（大量物件位於視野外），與現有密集矩陣並列；新隔離目錄保存修改前／後證據。複雜曲線、文字、延伸線及未知型別先保守列入候選，避免聲稱已具有各型別精確空間邊界。
- 目前尚未執行本批測試／量測／封裝／Git 同步；結果按實際完成追加。
- 新基準 Measure-Performance.ps1（perf-batch2-before，IncludeCoreChecks）退出0，754 Core與native success=true；加入稀疏診斷後原binary保存完整raw samples與39幅逐byte比較。基準native publish完成後才開始修改索引來源，該次source-files保存修改前實際bytes。
- 初版 ObjectViewportCache採256世界單位網格，512以下掃描、每物件最多16格、query最多4096格；密集範圍／候選超過四分之一時回原序列。每次查詢仍有O(n)幾何key掃描，沒有聲稱完全消除文件遍歷。全域複雜候選、穩定order與live頁面／visibility保留；ClearCache／換文件釋放CPU索引，不新增GPU bitmap。
- 初次 Core run（perf-batch2-core）退出0，2227 checks通過；新增預覽移動與CPU比較後待重跑。Grid cold build的配置／耗時與直接掃描、凍結bounds線性掃描分開量測；後者無mutation validation，只作下界參考。
- 第一輪CPU explore暴露失敗策略：10000直接掃描p95約0.51ms，grid約1.28ms；1000約0.07→0.14ms。不能因候選77個就宣稱收益。推測record Key逐欄EqualityComparer成本，改明確欄位比對後重測；第一輪raw保留於perf-batch2-cpu-explore，不覆蓋。
- 明確欄位比較第二轮10000約0.44→0.39ms，改善有限；增量membership更新避免單物件move全索引重建。第三轮2276 Core通過、CPU約0.35→0.34ms，但native編譯因conditional foreach無共同推斷型別CS0173失敗，隨後Xaml WMC9999屬此編譯失敗的次生訊息，無native結果；保留perf-batch2-after。改宣告IEnumerable後重跑。
- 再改善有效性掃描：BoardObject相關公開setter維護非序列化RenderBoundsVersion；每次query仍O(n)掃counter，但不讀／比較九個欄位。NaN重複setter保持stable，頁面／visibility仍live過濾、Z／list由order cache負責。Snapshot／Undo／JSON未知欄位契約不變；新counter不可當document revision或保存成功依據。
- version探測CPU10000 scan p95約0.42ms、grid約0.08ms；grid仍有candidate List／array配置，不宣稱零配置。cold索引分配約1.80MB、首次約18.73ms（單樣本／含JIT，不是p95）；不新增GPU記憶體。單物件變動採移除／插入舊新格，Z／source list改變重建，dictionary空格會移除。實際改善待最終native與重跑確認。
- 最終診斷增加完整RenderMainScene同binary開關比對、固定／多頁裁切、複雜物件全域候選與curve預覽取消；診斷finally恢复開關。正常操作自動依小／密集／超界查詢回掃描，沒有新增使用者設定入口。
- perf-batch2-final退出0，2276 Core、native success=true、57幅spatial與既有70幅strict pixels通過。Sparse10000同binary scene pan p95 6.39→4.23ms、zoom4.86→4.69ms；只屬這次合成跑次。待以反向執行次序複驗並收尾新增的setter／JSON／各安全型別檢查。
- 靜態檢視發現跳過相等double setter會吞掉+0→-0符號，改為仍保存輸入value、只有不相等才增加counter；新增signed-zero／nonserialized counter／future fields與各安全型別移入移出／轉global檢查。新增診斷環境HEIBAN_PERFORMANCE_GRID_FIRST=1可反向測完整scene reference／grid，預設正常模式不讀取此診斷設定。

## 未驗收

真筆、ARM64 實跑、實體輸入到畫面延遲、Store／WACK／MSIX 安裝更新、完整 DPI／裝置生命週期矩陣未執行。本批不發佈 Release、不操作 Store 後台。

## 收尾實際結果

- acceptance完成2324 Core／native success=true／127 strict pixels（57spatial＋既有70），零容差；此為本批新跑次，不沿用舊數字。x64／ARM64 publish退出0，兩build log無warning/error；ARM64沒有實跑。
- 最終CPU10000 p95 scan0.36124→grid0.07980ms、單物件更新0.08176ms；1000 0.06554→0.04788ms，300原fallback0.01870→0.01846ms。Cold10000 9.6476ms／1,798,376 allocated bytes，1600格／18769memberships，query400操作768000bytes；記憶體O(n)、最多16n memberships、非固定MB cap、不新增GPU資源。
- Native採不同執行次序保留全部：第一組10000scene pan6.3884→4.2346ms、zoom4.8629→4.6906；反向acceptance pan4.8220→5.4971、zoom4.4836→3.5254；同一acceptance binary第三次pan4.5852→4.4642、zoom4.5552→5.7337。沒有一致native幀率結論，PERF05仍優先。
- 最終binary HeiBan.dll SHA256 `2910a1e6ee00f0230d4e91b7e0fcb4b2d9930744c6f3b2455b1b7c9b0bc5dd3e`；第三次沒有重編譯、全新data／results、success=true且退出0。ARM64編譯完畢後才啟動，沒有同時heavy build／benchmark。
- 92份來源byte SHA核對0不符；Store bundle SHA仍`d7a49b63d88fa880b1a97b0c307361ad2cfbc9b3d58786048887093d7204ea7b`。Raw JSON保存到[證據目錄](performance/2026-10-11-batch2/README.zh-TW.md)，build/sdk/binary／data保留ignored .build，不提交。
- 文件批次apply_patch誤用ISSUE_HISTORY標題「問題紀錄」，整批verification failed；核檔案／status確認未寫入，改正為「問題與排解紀錄」重做。worklist嘗試匹配部分段落也未寫入，改新增有日期的第二批狀態、精確checklist更新。README先误讀README.zh-TW.md不存在，改讀README.md。
- 變更：Core model bounds setter／ObjectOrderCache只讀內部入口／新ObjectViewportCache／Core tests／CPU benchmarks，renderer candidate入口與清理、native spatial harness／batch diagnostics；Windows README與平台六份文件、工作清單／本日誌／raw證據。使用者功能入口不變，離線手冊未修改。其他平台、原作品與送審資料保留。

## 命令紀錄

工作目錄 `D:\Game\HaiBan x64`。所有目錄為新建，沒有覆蓋／清除舊證據。

```powershell
git status --short
& windows/HeiBan.Windows/Packaging/Measure-Performance.ps1 -OutputDirectory 'D:\Game\HaiBan x64\windows\.build\perf-batch2-before' -Label 'batch2-before-163e660-with-spatial-diagnostics' -IncludeCoreChecks
& windows/.build/tools/dotnet/dotnet.exe run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj -c Release --artifacts-path windows/.build/perf-batch2-core
& windows/HeiBan.Windows/Packaging/Measure-Performance.ps1 -OutputDirectory 'D:\Game\HaiBan x64\windows\.build\perf-batch2-after' -Label 'batch2-grid-incremental' -IncludeCoreChecks
& windows/HeiBan.Windows/Packaging/Measure-Performance.ps1 -OutputDirectory 'D:\Game\HaiBan x64\windows\.build\perf-batch2-final' -Label 'batch2-versioned-grid' -IncludeCoreChecks
# acceptance在try/finally內暫设GRID_FIRST=1並恢复原值
$env:HEIBAN_PERFORMANCE_GRID_FIRST='1'
& windows/HeiBan.Windows/Packaging/Measure-Performance.ps1 -OutputDirectory 'D:\Game\HaiBan x64\windows\.build\perf-batch2-acceptance' -Label 'batch2-final-grid-first' -IncludeCoreChecks
& windows/.build/tools/dotnet/dotnet.exe publish windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-arm64 --self-contained true --artifacts-path windows/.build/perf-batch2-arm64 -p:Platform=ARM64 -p:WindowsPackageType=None -p:WindowsAppSdkBootstrapInitialize=false -p:WindowsAppSdkDeploymentManagerInitialize=false -o windows/.build/perf-batch2-arm64/publish
git diff --check
```

三次手動CPU probe均退出0，命令是`& windows/.build/tools/dotnet/dotnet.exe run --project windows/HeiBan.Windows.Performance/HeiBan.Windows.Performance.csproj -c Release --artifacts-path <artifacts> -- <absolute-output> <label>`，實際替代值如下；輸出絕對路徑為工作目錄加表列相對路徑。

| artifacts／output | label |
| --- | --- |
| windows/.build/perf-batch2-cpu-explore／cpu.json | batch2-grid-explore |
| windows/.build/perf-batch2-cpu-explore2／cpu.json | batch2-direct-field-explore |
| windows/.build/perf-batch2-cpu-version／cpu.json | batch2-bounds-version |

增量fields第三份probe不是另run，来自perf-batch2-after在native失敗前完成的cpu.json。最初manual Core退出0／2227，after Core2276但native失敗；final2276，acceptance2324。不要把失敗after整體算成功。

第三次native用Start-Process（Hidden）啟動`windows/.build/perf-batch2-acceptance/native/publish/HeiBan.exe --performance-output="D:\Game\HaiBan x64\windows\.build\perf-batch2-repeat-results"`，HEIBAN_WINDOWS_DATA_DIRECTORY指定全新perf-batch2-repeat-data；GRID_FIRST未設、source label指向immutable acceptance。WaitForExit以60秒分段最多3次，實際退出0、success=true，finally恢復環境變數。Get-FileHash、Copy-Item與來源inventory核對成功；git diff --check退出0（只有CRLF提示）。Git同步完成後另記具體結果。

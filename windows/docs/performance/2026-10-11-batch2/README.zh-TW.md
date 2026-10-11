# Windows 第二批效能證據

起點 `163e660bcc722f1ecf31f218b03accba2819d92a`，build為HEAD加各次Windows working tree；`source-files.json`記最終92份來源byte SHA，交付前核對0不符。實作／命令／失敗見[日誌](../../PERFORMANCE_BATCH2_2026-10-11.zh-TW.md)。只放合成JSON，沒有作品、帳號、截圖或程式包。

## 證據有效性

| 檔案 | 範圍 |
| --- | --- |
| native-before.json／cpu-before.json／source-before.json／environment-before.json | 第一批renderer加稀疏診斷；native成功，原754 Core、新spatial39幅。CPU只含order/hit矩陣，不當作grid前測 |
| rejected-record-key.json | 初次九欄record比對使grid10000 p95約1.28ms，比scan約0.51ms慢 |
| explore-direct-fields.json／explore-incremental-fields.json／explore-version.json | 調整過程；手動explore的sourceCommit為null、沒有完整byte inventory，只解釋策略，不作最終可重現來源 |
| native-after-first.json／cpu-after-first.json／source-after-first.json | versioned grid第一組，2276 Core、127 pixels；未含最後signed-zero setter修正及反向scene設定 |
| native-after.json／cpu-after.json／source-files.json／environment.json | 最終acceptance，2324 Core、127 pixels，scene先grid後scan |
| native-after-repeat.json | immutable acceptance binary第三次完整native驗證，scene先scan後grid；不重編譯 |
| store-preservation.json | 原送審bundle前後SHA相同 |

失敗native編譯log保存在本機perf-batch2-after，CS0173／次生Xaml錯誤見日誌，沒有native結果。raw SamplesMs保存原執行次序；nearest-rank p95／p99不取代原始樣本。

Release .NET10.0.12、Ryzen5 2600X、RTX3050 driver32.0.16.1088、約32GiB RAM、Windows11Pro26300，main192DPI／1024×640 DIP，overlay5760×2160 physical pixels／96pixelDPI、dpiScale2。環境記供電方案／坐標限制；WinForms螢幕可能DPI虛擬化、HypervisorPresent不證明VM。真筆／ARM64實跑／實體端到端延遲／完整DPI生命週期未驗收。

## CPU 同binary候選查詢

20×20 rect、間距100世界單位，10000中77候選。80 raw樣本、每樣本5操作；p95是80個操作平均樣本，不是400次獨立操作p95。

| 物件 | ordered radius scan p95 ms | grid＋counter scan＋原cull p95 ms | 單物件move＋grid p95 ms |
| ---: | ---: | ---: | ---: |
| 0 | 0.00010 | 0.00014 | 0.00014 |
| 300 | 0.01870 | 0.01846 | 0.01858 |
| 1000 | 0.06554 | 0.04788 | 0.05166 |
| 10000 | 0.36124 | 0.07980 | 0.08176 |

10000 cold約9.65ms／1,798,376 allocated bytes（初始化含JIT單樣本，不是p95），1600 cells／18769 memberships；第一組cold18.73ms，不能當固定保證。query仍O(n)掃counter並配置候選List／array，400操作768000bytes，約1920／次，不是整App memory。arrays O(n)、memberships最多16n，非固定MB cap；不新增GPU資源。Frozen flat10000 p95=0.05346ms更低，但沒有geometry mutation validation，只作immutable synthetic下界。

## Native 結論與限制

每策略40幀、5次預熱，含1pixel readback同步。pan／zoom仍重建GPU scene；這批是candidate broad phase，不是tiles或bitmap reuse。

| 物件 | 第一組pan scan→grid ms | 反向次序pan scan→grid ms | 第一組zoom scan→grid ms | 反向次序zoom scan→grid ms |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 4.0480→3.2756 | 2.5986→1.9555 | 2.9665→3.9123 | 2.4763→2.0631 |
| 300 | 3.1891→2.7809 | 2.4160→3.1467 | 3.7091→2.8108 | 2.8863→3.0080 |
| 1000 | 4.5956→4.5863 | 2.8226→2.8281 | 4.8570→4.7141 | 2.9540→2.7276 |
| 10000 | 6.3884→4.2346 | 4.8220→5.4971 | 4.8629→4.6906 | 4.4836→3.5254 |

保留較差結果；0／300本就fallback，不能歸因grid。原dense10000 before→acceptance rebuild152.45→124.20ms、pan176.20→196.05ms、zoom230.18→209.45ms，此視野fallback，不能由此宣稱index加速或FPS達標。PERF05仍待開發，GPU／UI排程剩餘成本不能由CPU數字代替。

第三次immutable acceptance binary（scan先grid後）10000 pan4.5852→4.4642ms、zoom4.5552→5.7337ms，success=true／127 strict pixels；仍有較差结果，原始完整JSON保留，不挑最佳跑次。

2324 Core包含160個固定seed隨機視野、負坐標／邊界／型別／NaN／global／direct move／Z／list／page／preview／Cancel／Undo／Redo、JSON未知欄位與counter不持久化。127 pixels＝57spatial（含fixed／notebook clip、curve／text／sticky／arc／arrow／extension）＋原70（main9、mixed3、preview1、overlay36、stroke18、selection3）；零容差，另有curve／laser／idle契約。Hit／框選／擦除未接index，原檢查重跑，不宣稱其空間索引已交付。

## 重現

Windows互動桌面、OutputDirectory必須為新.build子目錄，避免同時build／其他benchmark：

```powershell
& windows/HeiBan.Windows/Packaging/Measure-Performance.ps1 -OutputDirectory 'D:\Game\HaiBan x64\windows\.build\my-new-batch2' -Label 'batch2-recheck' -IncludeCoreChecks
```

反向scene先設`$env:HEIBAN_PERFORMANCE_GRID_FIRST='1'`、跑完恢復原值；只由explicit diagnostics讀取。另一台電腦重新量測，不複製本機分數。Store bundle SHA仍`d7a49b63d88fa880b1a97b0c307361ad2cfbc9b3d58786048887093d7204ea7b`，版本／dist保留。x64／ARM64 publish只證明編譯，未產新安裝包／Release／Store發佈、WACK或真筆驗收。

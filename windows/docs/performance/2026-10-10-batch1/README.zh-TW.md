# Windows 第一批效能證據

來源基準：c39a0995c18a695e041330e3f458a13b249a3a7b。實作／命令／失敗與驗收邊界見 [開發日誌](../../PERFORMANCE_BATCH1_2026-10-10.zh-TW.md)。本目錄只放合成資料的測量 JSON 與來源雜湊，不包含作品、桌面截圖、帳號資訊或編譯產物。

## 檔案與有效性

| 檔案 | 意義 |
| --- | --- |
| cpu-before.json | 原始排序／命中，修正為填色矩形及可命中點後的新基準 |
| cpu-after.json | 本批實作後，acceptance 的序列量測；checksum 與 before 相同 |
| rejected-hit-fixture.json | 首輪 fixture 未填色、點落在空心矩形中央；「hit」實際未命中，排除主要比較但保留 |
| native-before-main.json | 舊原生執行檔已完成的主畫布測量；後續螢幕階段失敗不會使這些資料變成通過結果 |
| native-before-failure.json | 舊路徑 rect 收筆像素不等；strict failure 保留 |
| native-after.json | acceptance 的普通／混合畫布與螢幕註記；success=true |
| native-before-repeat-main.json／native-before-repeat-failure.json | 同一保存的舊binary重跑：仍在同一272byte rect差異失敗 |
| native-after-repeat.json | 同一acceptance binary再跑，success=true；沒有覆寫首組樣本 |
| cpu-after-earlier-serial.json／cpu-after-earlier-concurrent-native.json | 先前後測跑次；後者當時有native量測同時執行，不能當受控比較 |
| environment.json | 此同機後測的硬體、OS、驅動、供電方案與 DPI 座標範圍說明 |
| source-files.json | 後測 build 的 Windows C#／project／PowerShell 來源 byte SHA；含 dirty working tree，不是假稱由乾淨 c39a099 建置 |
| store-preservation.json | 送審 bundle 前後 SHA 相同 |

本次 .NET 10.0.12、Release x64、Ryzen 5 2600X、RTX3050（driver32.0.16.1088）、約32GiB RAM、平衡電源方案。HypervisorPresent=true 不能單獨證明程式跑在 VM。主畫布192DPI（1024×640 DIP），overlay5760×2160實體像素／96DPI、dpiScale=2；兩個螢幕，PowerShell WinForms bounds 可能經 DPI 虛擬化，不拿其 logical bounds 當每台螢幕的實體解析度／更新率。實際供電與所有螢幕刷新率未量測。前測失敗 JSON 缺少完整環境 envelope，保留此限制。

## CPU 同場景比較

每場景80個原始樣本，每樣本5個操作；SamplesMs 是該5次平均，p95是80個平均樣本的 nearest-rank，不是400個獨立操作的p95。預熱5次不計入配置量，未宣稱cold與tiered JIT全穩定。

| 物件 | 順序枚舉 p95 前→後（ms） | 命中 p95 前→後（ms） | 未命中 p95 前→後（ms） |
| ---: | ---: | ---: | ---: |
| 0 | 0.00356→0.00018 | 0.00330→0.00214 | 0.00428→0.00232 |
| 300 | 0.10568→0.02254 | 0.19252→0.03688 | 0.17084→0.05468 |
| 1000 | 0.73396→0.08794 | 0.48668→0.13554 | 0.58138→0.24806 |
| 10000 | 2.11462→0.15780 | 3.35256→0.33602 | 4.46400→1.71562 |

10000物件、400操作配置：順序62,176,200→22,400 bytes；命中333,606,400→54,400 bytes。後者仍含每次測試新 InkPoint 及 iterator；不是整個 App 的配置量。此前serial後測10000順序p95=0.58338ms、命中1.12882ms，native同時執行的跑次為0.27814／0.68958ms；保留全部資料與負載差異，不把最小值當保證。原生各場景未一致更快，不將這張表推論成實際120FPS或硬體輸入延遲。

## 原生與相容結果

每個標準場景stable／強制rebuild／pan／zoom各40個測量幀、5次預熱；含一像素readback GPU同步。sceneBuilds已改為各階段delta。before 的sceneBuilds是當時累積計數，不能直接比較兩種欄位。

第一組普通場景的rebuild p95前→後（ms）：0物件0.9276→0.7824、300物件10.5178→11.7780、1000物件27.9246→45.9979、10000物件151.2095→169.8557。前後配置量下降，但此組原生時間未呈一致收益；不省略較差結果。大作品viewport重建仍是04／05候選，需要同機重複與負載控制後再決定。

保存的前後binary序列重跑rebuild p95前→後（ms）：0物件0.7723→0.9965、300物件9.7040→8.3811、1000物件25.1931→25.4671、10000物件178.7035→156.1786。10000 pan247.1661→211.2534、zoom214.6579→206.7047；1000 pan27.4772→32.7314、zoom27.7429→29.6779。結果仍非一致改善，不能證明所有較差跑次的原因，沒有用第二組覆蓋第一組。純CPU結果可測到排序／命中的改進；大作品native繪圖仍超過16.7ms，04／05優先。

混合場景181物件＝80張image objects（4個128×128PNG共5674壓縮bytes、262144解碼bytes）＋100中文字＋12000點長筆跡。冷圖片decode／scene各只一個樣本；固定長筆跡暖繪製不是連續筆尖輸入。此場景只有後測和同binary參考像素比較，不能當批前後加速證據。單物件預覽40幀配置40,640→27,200bytes，像素相同，GPU p95沒有一致下降。

754 Core checks；普通9＋混合3＋單物件preview1＋overlay形狀36＋pen/highlighter18＋旋轉selection3＝70個嚴格像素對等比較，另檢查曲線外凸、雷射清除、idle與提交／Undo。所有像素比較保留零容差。舊copy路徑先失敗（272 bytes、最大1色階），改同device／format／96DPI的bitmap像素區域複製後通過。

螢幕original欄位是**同一後測binary的完整重繪參考**，不是舊版本前測；局部region與固定scene大部分早已存在，不能把其全幅→局部readback差距全部歸功本批。Stroke timing只計Render，同次allocation欄位計Pointer handler＋Render＋diagnostic stopwatch，兩者範圍不同。

## 重新量測目前來源

需Windows、.NET10 SDK／NuGet依賴及互動桌面。從專案根執行：

```powershell
& ./windows/HeiBan.Windows/Packaging/Measure-Performance.ps1 `
    -OutputDirectory "D:/Game/HaiBan x64/windows/.build/performance-new-run" `
    -Label "my-computer-run" -IncludeCoreChecks
```

其他電腦把OutputDirectory換成其專案的windows/.build內**全新**子目錄。脚本先保存環境／來源雜湊，依序Core、CPU、native build與原生量測；以success欄位和exit code共同判定。建立全新synthetic-data，App在初始化作品庫前拒絕既有資料根；正常使用不啟動診斷。超時保留自己的PID及結果供調查，不終止其他App。後測指令可以重跑最新來源；本輪舊基準binary只保留於原建置機，未上傳GitHub，不能在另一台電腦套用其成績。

## 未執行

真實滑鼠／筆／觸控、光學端到端延遲、120Hz、100／125／150%與混合DPI矩陣、device lost／睡眠喚醒、軟體renderer、ARM64實機、正式MSIX安裝／WACK／移轉／解除安裝、忙碌UI timer間隔、保存期間操作及各階段readback／DIB／Present獨立profile。PERF-01／02全驗收仍有缺口，04／05／07／08未實作，06只有現有copy相容修復，09未完成硬體矩陣。

# Windows PERF-01／02／03 第一批實作紀錄（2026-10-10）

## 開工

使用者貼出工作清單並指示 GO，接續第一批 PERF-01／02／03 的基準、實作與驗證。HEAD c39a0995c18a695e041330e3f458a13b249a3a7b；git status 有既有未追蹤 .vscode/，保留、不讀其內容、不納入提交。私人庫乾淨，visibility PRIVATE。已讀根規則、開發索引、Windows 狀態／架構／問題與工作清單。

本批只改 Windows；先建立新同機基準，依證據調整熱路徑及順序快取，使用合成文件與隔離資料根。保留 Store 1.0.12.0 送審套件／SHA／截圖、所有作品與歷史。下一版發布、Store 操作與全新渲染 backend 不在本批。

## 進行中

正在定位現有原生驗證入口、Core session 與 renderer 的排序／配置／失效契約，準備隔離基準建置。本批實際命令、失敗、結果及未驗收項會持續追加，不沿用以前的測試數字。

## 首輪基準／阻礙

新增 opt-in PerformanceMeasurement、CPU console 與 --performance-output 原生入口；只用合成資料／HEIBAN_WINDOWS_DATA_DIRECTORY 隔離根，正常模式不寫效能檔。原始實作仍未最佳化。CPU 0／300／1000／10000 基準退出 0；發現 hit fixture 原來落在未填色矩形內，修成明確填色／可命中點後重新取得 corrected 基準，保留首份結果。

原生 x64 baseline publish 退出 0。隔離進程退出 0，但 performance.json success=false：既有 ValidatePreviewPerformance 的矩形收筆局部／全幅像素不一致。不能把程序 exit 0 當驗證通過。正在加差異位置／數量／最大值診斷，並讓已完成主畫布階段保存獨立結果；不先放寬像素規則或宣稱 GPU 卡頓原因。

定位失敗的 Publish-Windows.ps1、BoardObject.cs 及帶 literal wildcard 的 rg 路徑已以 rg --files 修正；實際 Models 在 BoardModels.cs，封裝共用為 Publish-Common.ps1。沒有刪除檔案或使用者內容。

## 順序／配置實作與首輪回歸

實作穩定升／降 Z 快取；同 Z 保留原 list 次序，逐次無配置掃描參考／Z 捕捉交易內直接修改、同數量替換與重排。頁面／可見性在枚舉時讀取，不序列化快取；單物件預覽不排序。DamageStrokeTail 改成索引掃描尾端四點，未捨棄任何樣點。命中對 rotation=0 的唯讀樣點省去 center／rotated point 配置。

新增順序、直接 Z、重排、替換、新增／刪除、切頁／可見性、文件／list 切換、Cancel／Undo／Redo／Open 與輸入樣點不變的回歸。首次 Core 測試 build 失敗 CS7036（新增測試忘記傳 Hit tolerance），補上 8 後重跑。CPU post 首次退出 0，待完整回歸與同機數據比較。

原生 diagnostic baseline 已保存 main-performance.json：普通畫布 9 個嚴格像素案例通過。螢幕 rect 收筆 first=(1504,898)、channel=2、actual=1／expected=0，共272 byte 不同，maxDelta=1。原因仍在定位，保留 failure；不能宣稱全套原生回歸通過。

## 原生局部快取複製修復

依本機 Win2D 1.4.0 原生 header 核對 CopyPixelsFromBitmap 的整數像素區域 overload。兩 target 同 device／BGRA／96 DPI，region 是整數像素；以 GPU bitmap 區域複製替換 CanvasBlend.Copy + DrawImage 的取樣／合成路徑，保留局部 readback 與原始所有嚴格像素檢查。此修正接續 PERF-06 現有路徑的小範圍相容修復，未加入新 backend。

native-post-copy publish 退出 0；隔離新 data root 執行 performance-output，程序退出 0 且 success=true。普通畫布9、圖形／框選36、筆／螢光18、旋轉選取3 個嚴格 pixel-equivalent 幀通過；大曲線外凸、雷射清除、idle、選取提交／Undo 同次通過。沒有放寬色差容差。首次量測普通場景 dpi=192；overlay 在虛擬桌面實體像素96DPI，不能將其尺寸稱單一1080p螢幕。

Core 移除兩個捕捉 lambda（空心矩形改四邊短路、polygon 生成改局部迴圈）後再跑754項退出0。cpu-post-final 的10000場景 Order p95=0.27814ms、Hit p95=0.68958ms；80×5操作配置分別22400／54400bytes。原生大量場景重建／平移／縮放 p95 有波動、部分比前測更高，尚無證據宣稱全面加速；保留原始樣本與後續04／05調查。

額外失敗：PowerShell for(...) 後直接 pipe 為 ParserError，改先收集 rows 再輸出。scripts/Publish-Common 與私人 CURRENT_STATUS.md 的舊路徑讀取失敗，以 rg --files／實際 zh-TW 文件更正；未對錯誤路徑寫檔。

## 補足場景／可重現驗證

新增合成181物件混合場景（80圖片object、4個128×128PNG、100文字、12000點筆跡），記5674PNGbytes／262144解碼bytes、cold單樣本、warm stable／rebuild／pan／zoom／liveink與preview；混合strict3、single preview strict1通過。這些只有後測與同binary參考，不偽稱具有全部批前基準。screen保留32／80 raw samples、p95／p99、readback與UI thread input+render配置／GC；timer的16ms仍只是設定值。

Measure-Performance.ps1 實際執行兩次，repro-post-final及acceptance新根，各依序Core→CPU→native publish→performance，退出0且JSON success=true；App在storage初始化前拒絕既有診斷資料根。acceptance754Core、70strictpixel比較與其他契約通過。acceptance記90個Windows C#／project／PowerShell source SHA，交付前重核0不符。native-after.json保留該次2.11462→0.15780ms order、3.35256→0.33602ms hit，同時保存早期serial及native并行跑次；沒有把不同負載／取樣當同一受控重複。

原生x64與ARM64獨立Release publish均退出0，兩log未找到warning／error；ARM64未實跑。送審bundle在runner兩次前後及交付前Hash核對均為d7a49b63d88fa880b1a97b0c307361ad2cfbc9b3d58786048887093d7204ea7b。沒有改版號、Store manifest、產物／私人截圖或其他平台。

保存的pre-optimization native-baseline-diagnostic／acceptance binary又各序列重跑一次（不重建）。舊binary同272byte、maxDelta1 rect failure重現，後binarysuccess=true、70strictpixel再通過。10000重建p95第二組178.7035→156.1786ms，但1000幾項成本更高；第一次亦有反向結果，未宣稱原因已確認或整體FPS達標。原始第一组与重跑JSON全部另檔保留。

## 實際命令與輸出

工作目錄D:/Game/HaiBan x64，dotnet為windows/.build/tools/dotnet/dotnet.exe。所有產物在windows/.build/perf-batch1，以下為本批實際操作，不是以前數字。

- git status --short／git ls-remote origin refs/heads/main：開工HEADc39a099，既有.vscode/未追蹤，遠端相同。
- dotnet run --project windows/HeiBan.Windows.Performance/HeiBan.Windows.Performance.csproj -c Release --artifacts-path windows/.build/perf-batch1/cpu-baseline-corrected -- windows/.build/perf-batch1/cpu-baseline-corrected.json baseline：退出0，前測4場景；首輪cpu-baseline未填色錯fixture也保存。
- dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj -c Release --artifacts-path windows/.build/perf-batch1/core-post：先CS7036退出1，補tolerance後退出0／754；core-post-final與runner另有同批通過log。
- dotnet run --project windows/HeiBan.Windows.Performance/HeiBan.Windows.Performance.csproj -c Release --artifacts-path windows/.build/perf-batch1/cpu-post-final -- windows/.build/perf-batch1/cpu-post-final.json optimized：退出0（當時native同時執行，已標明）。
- dotnet publish windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 --self-contained true --artifacts-path [native-baseline／native-baseline-diagnostic／native-post-copy獨立根] -p:Platform=x64 -p:WindowsPackageType=None -p:WindowsAppSdkBootstrapInitialize=false -p:WindowsAppSdkDeploymentManagerInitialize=false -o [各自publish]：各退出0；不是Store／Installer包。
- & ./windows/HeiBan.Windows/Packaging/Measure-Performance.ps1 -OutputDirectory "D:/Game/HaiBan x64/windows/.build/perf-batch1/repro-post-final" -Label "PERF-01-02-03-final" -IncludeCoreChecks：退出0。
- 同腳本 -OutputDirectory "D:/Game/HaiBan x64/windows/.build/perf-batch1/acceptance" -Label "PERF-batch1-acceptance" -IncludeCoreChecks：退出0、754／native success=true、Store SHA不變。
- dotnet publish windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-arm64 --self-contained true --artifacts-path windows/.build/perf-batch1/arm64-compile -p:Platform=ARM64 -p:WindowsPackageType=None -p:WindowsAppSdkBootstrapInitialize=false -p:WindowsAppSdkDeploymentManagerInitialize=false -o windows/.build/perf-batch1/arm64-compile/publish：退出0，僅編譯。
- 各native用Start-Process -WindowStyle Hidden與--performance-output，設定全新HEIBAN_WINDOWS_DATA_DIRECTORY，finally還原env；舊diagnostic binary兩次相同272byte failure（另有更早的bare failure），修復後的四次執行success=true。失敗由JSON判斷，不能只看exit0。
- git diff --check：退出0，僅CRLF轉換提示；source-files逐SHA90／0差異；Get-FileHash送審bundle相同。

## 交付範圍／未驗收

新檔：ObjectOrderCache、Diagnostics/PerformanceMeasurement、Performance console project／Program、MainWindow.PerformanceBatch／PerformanceScenes、Packaging/Measure-Performance、本日誌与performance資料。修改：Core EditorSession／VectorMath／Core.Tests、App／MainWindow.initialize／Rendering／Input、Direct2D renderer、screen Render／Performance，以及Windows README／CURRENT_STATUS／ARCHITECTURE／DECISIONS／ISSUE_HISTORY／DEVELOPMENT_LOG／WORKLIST／Antigravity清單。UI功能入口與作品格式未改，診斷入口說明在performance README，不把原型列入使用手冊功能。

PERF-03本批完成；01／02已交付有證據的子項，但busy timer、保存期间操作、pointer/render/readback/present分階段及真實輸入仍未執行。04／05／07／08未實作；06僅既有copy相容修復；09的真筆／觸控、100／125／150%／混合DPI、120Hz、device lost／睡眠、軟體renderer、ARM64實機、MSIX安裝移轉卸載／WACK全部未執行。新Release／tag／Installer／Store包與後台提交未執行。原生viewport的下一步優先04／05，不預先宣稱其策略有效。

GitHub同步完成後，实际commit／remote核對另存PRIVATE HeiBan-private日誌；本紀錄不預寫已push。

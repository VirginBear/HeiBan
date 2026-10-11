# Antigravity：HeiBan Windows 下一版流暢度工作清單

2026-10-11 接續：第二批完成PERF04**渲染候選分支**（counter＋網格＋scan退路）；2324 Core／127 strict pixels／x64與ARM64編譯通過，ARM64未實跑。CPU10000候選p95 0.36124→0.07980ms，完整native pan／zoom有較差跑次，不保證FPS。Hit／擦除／框選索引、PERF05／06後續仍待辦。[第二批日誌](PERFORMANCE_BATCH2_2026-10-11.zh-TW.md)、[raw證據](performance/2026-10-11-batch2/README.zh-TW.md)。下方第一批數字保留其日期範圍。

日期：2026-10-10。狀態：**第一批已實作、仍有量測／硬體驗收待辦**。原編製時檢視基準為公開 `main` 的 `c1c10ef14cc2f09d203393a424af44f80eddd783`；使用者 GO 後從 `c39a099` 執行首批01／02／03，另修06既有copy相容問題。[實作日誌](PERFORMANCE_BATCH1_2026-10-10.zh-TW.md)、[當批原始資料／命令／限制](performance/2026-10-10-batch1/README.zh-TW.md)。接手先核最新HEAD與未提交內容，不能把本機測量當另一台電腦的結果。

## 接手規則

1. 先讀根目錄 AGENTS.md、docs/DEVELOPMENT_INDEX.zh-TW.md、Windows CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY／DEVELOPMENT_LOG，以及本文件。有私人庫權限時，另讀 HeiBan-private 的 AGENTS／CURRENT_STATUS／PRODUCT_INFORMATION。
2. 使用者本次要求製作清單，由 Antigravity 接手。實作與測試的執行範圍以使用者交付指令為準；本文件不替代授權。若允許修改與驗證，依下列分批流程執行。
3. 範圍為 `windows/`。保持 C#／WinUI 3／Win2D 基礎；新渲染方案先做可切換原型，保留相容退路。不要把小畫家的內部實作當已知事實，也不要把改語言、固定 timer 或套件格式當作流暢度保證。
4. Store 1.0.12.0 已由使用者送審，最新已知狀態為認證中、通過後立即開始發佈。保留原 bundle、SHA、建置来源 aa71e35、產物清單與私人三張截圖。新測試／建置使用新的隔離目錄，不覆寫本次送審證據、不取消或修改後台提交；後續發行另外決定版號与套件版。
5. 保留作品、未知 JSON 欄位、穩定 ID、頁面／圖釘與原稿契約。高頻預覽獨立，完成手勢才提交永久資料與一筆 Undo。不得將使用者作品帶入測試；使用合成資料與獨立資料根。
6. 每批開始先寫開發日誌，保存失敗嘗試、實際命令、來源 commit、結果與未驗收項；更新平台狀態／問題／決策，功能入口若變動同步手冊。

## 現有能力：接續使用

- `MainWindow.Rendering.cs` 已將固定場景保存在 CanvasRenderTarget，暫態筆跡／選取繪於其上。
- `Engine/WindowsInkCoordinator.cs` 已收集中間點、依 timestamp 排序／去重，保存筆壓與傾角。
- `Engine/Direct2DCanvasRenderer.cs` 已有幾何／圖片／文字快取、可見範圍排除、64 段即時筆跡快取。
- 螢幕註記已具 dirty region、固定內容快取與局部 readback／DIB 寫入；不是每次指標移動都全屏傳輸。
- `MainWindow.xaml.cs::SaveAsync` 已背景執行保存；縮圖、搜尋、偏好已有合併／延後策略。
- 現有 Performance.cs 與歷史 JSON 主要包含合成／同步測量，不能替代本輪硬體端到端結果。歷史成功數字不得直接列成新版本驗收。

## 優先順序

P0 為後續決策前置；P1 為優先調查／實作候選；P2 只有在量測顯示收益時展開。checkbox只勾已實作或有當批證據的子項，未勾項保持待辦。

| ID | 優先 | 工作 | 依賴／執行判準 |
| --- | --- | --- | --- |
| PERF-01 | P0 | 建立同機基準與可重現效能紀錄 | 所有改動之前 |
| PERF-02 | P1 | 減少熱路徑配置、重複 UI 工作與無效重繪 | 01 找出成本後 |
| PERF-03 | P1 | 快取物件繪製／命中順序 | 01；優先低風險調整 |
| PERF-04 | P1 | 大量物件的空間索引 | 03；遍歷確為瓶頸時 |
| PERF-05 | P1 | 平移／縮放的分區或分層快取 | 01；大作品重建成本高時 |
| PERF-06 | P1 → P2 | 螢幕註記像素配置／readback 與 GPU 合成原型 | 01／02；先改善現有路徑，再評估原型 |
| PERF-07 | P2 | 長筆跡與低延遲輸入原型 | 01；輸入／筆跡成本明確時 |
| PERF-08 | P2 | 保存、縮圖與 Undo 的記憶體壓力 | 01；確認與停頓相關時 |
| PERF-09 | P1 | DPI、裝置生命週期與實機相容驗收 | 貫穿各批，發行前彙整 |

目前：01已建立0／300／1000／10000與長筆跡／圖片／文字合成軟體基準及raw樣本；輸入／保存／busy分階段profile未完成。02完成有證據的排序、preview、尾點與命中配置熱點，排程未更動。03完成穩定order／相容回歸。04／05列下一批優先，06只修同device的bitmapcopy，沒有新backend；07／08與09硬體矩陣待執行。754Core、70strictpixel、x64／ARM64建置有當批結果；ARM64未實跑。

## PERF-01：基準與量測

- [x] 建立固定合成場景：空白、300／1,000／10,000 物件、長筆跡、多張圖片與文字混合；圖片尺寸／解碼後占用及筆點數要記錄，不只記物件數。混合場景本輪只有後測＋同binary参考，沒有偽稱全部都具批前基準。
- [ ] 分別測主畫布與螢幕註記：落筆、連續畫線、長筆跡、物件拖曳、橡皮擦、平移、縮放，以及自動保存期間操作。
- [ ] 記錄機型、CPU／GPU／驅動、RAM、OS、架構、DPI、螢幕數／更新率、Release／Debug、供電、資料根及 source commit。同機同場景比較修改前後，區分冷／暖狀態，保留樣本及 p50／p95／p99、樣本數、配置量／GC、記憶體、scene 重建次數／readback bytes。
- [ ] 將事件收到、開始繪製、提交畫面分開計時。軟體提交時間不等於實體筆尖到可見畫面；沒有光學／外部量測時不得寫成端到端延遲。
- [x] 優先接續 `MainWindow.Performance.cs`、`ScreenAnnotation/ScreenAnnotationWindow.Performance.cs` 的隔離驗證入口；診斷記錄採限定模式及取樣，避免逐點同步寫檔反過來製造卡頓。新增--performance-output與Measure-Performance.ps1；正常模式不逐點寫log。

**完成條件：** 原始資料／重現命令／環境可交接，指出耗時主因與候選順位。60 Hz 的 16.7 ms、120 Hz 的 8.3 ms 只作 frame budget 參考，未量測前不寫達標；預算亦須扣除輸入、合成及其他工作。

## PERF-02：配置、UI 與重繪排程

**定位：** `MainWindow.Input.cs`、`MainWindow.Rendering.cs::InvalidateCanvas／RefreshLayersIfNeeded`、`Engine/Direct2DCanvasRenderer.cs::RenderLiveStroke`、`ScreenAnnotation/ScreenAnnotationWindow.cs::Render`。

- [x] 用 01 的資料查 LINQ／ToArray、幾何尾段、臨時陣列、狀態面板與樣式刷新成本；只調整有證據的熱點，重用 scratch buffer 時明確處理可變長度及生命週期。改善order、單preview、damage尾點與命中closure；UI面板／live幾何沒有證據的改動保留原策略。
- [ ] 檢查 CanvasSurface_PointerMoved 呼叫鏈，避免每個輸入點觸發永久 scene 重建、Inspector 列表重建、保存或全文件序列化；延續既有 sceneChanged／交易邊界。
- [ ] 評估一幀合併多次顯示失效：保留全部有效輸入點，只合併畫面提交；控制排隊深度，不能用丟點來偽造流暢。
- [ ] 螢幕 DispatcherTimer 的 16 ms 不是固定 60 FPS。量測 idle、連續作畫及 UI 忙碌時的實際間隔，再决定排程調整。

**完成條件：** 同場景配置量／尾端停頓有改善，沒有新增無效重繪；筆跡、雷射消退、取消、選取、面板值及一手勢一 Undo 保持正確。無收益則保留原方案並記原因。

## PERF-03：繪製與命中順序快取

**已確認：** `Direct2DCanvasRenderer.cs::RenderObjects` 會 `OrderBy(ZIndex)`；`Core/Engine/EditorSession.cs::Hit` 會反向排序。這發生在相應渲染／命中呼叫，不代表快取命中的每幀都重新排序。

- [x] 建立每頁可取得的穩定有序視圖，在新增／刪除、圖層調整、頁面切換、Undo／Redo、文件切換時保持正確；相同 ZIndex 次序與LINQ相容。實作採整份document穩定order＋live頁面過濾，尚非每頁空間索引。
- [x] 主畫布、螢幕註記、匯出與命中共用正確的順序契約；不為暫態單物件預覽建立昂貴整頁索引。snapshot匯出保留stable-sort fallback，不跨async持有UI session view。
- [x] 若物件可直接變更 ZIndex，明確處理失效，不能只看物件數或永久 Generation。無配置O(n)參考／Z掃描捕捉交易內修改與同數量替換／重排；沒有強制模型遷移。

**完成條件：** 合成大場景排序成本下降；前後遮擋、同 ZIndex、隱藏／鎖定、置頂／置底與 Undo／Redo 的命中及輸出順序相同。

## PERF-04：空間索引

**已確認：** RenderObjects 排序後逐物件判斷是否落在可見範圍；EditorSession 的命中／擦除也有枚舉路徑。已存在的可見範圍排除保留。

- [x] 渲染分支比較256世界單位網格、原scan與frozen flat bounds下界；小／密集視野回scan。未實作四叉樹，沒有其收益證據。Cold配置與query配置／mutability成本公開記錄。
- [x] 渲染候選維持全域stable Z；rect／circle／image／tape採原保守radius，複雜／超大／非有限／延伸物件保守global，保留renderer原cull與decorations，不宣稱其精確bounds索引已完成。
- [x] 渲染索引跟隨direct geometry／preview／cancel／page／document／Undo／Redo；counter不序列化，order改變重建、geometry增量membership，其他預覽與永久交易不變。
- [ ] 在同一合成資料上比對舊掃描結果，特別是框選、套索、橡皮擦與邊界點。

**完成條件：** 大場景候選枚舉有可測改善，小場景成本可接受；沒有漏畫／漏選／錯誤擦除或跨頁污染。

## PERF-05：平移／縮放快取

**已確認：** `MainWindow.Rendering.cs` 的 SceneKey 包含 viewport X／Y／Zoom，改變時重建固定場景；尺寸與 DPI 變更亦重建 render target。

- [ ] 先量測平移／縮放下全場景重建成本，評估平移時重用圖像＋補繪邊緣、世界座標 tiles 或分層快取。挑選一種可回退方案分批比較。
- [ ] 設 GPU 記憶體預算、快取驅逐與單 tile 失效；縮放預覽可暫時重用快取，結束後以正確倍率重繪，避免永久模糊。
- [ ] 保持固定頁面裁切、背景／格線、游標縮放錨點、文字清晰度與座標契約；device lost／換文件／DPI／尺寸變化清理快取。

**完成條件：** 目標大作品平移／縮放 p95 及重建成本改善，GPU 記憶體有界；快速連續操作後沒有缺塊、殘影、錯位或過期內容。

## PERF-06：螢幕註記傳輸與 GPU 合成

**已確認：** `ScreenAnnotationWindow.cs::Render` 使用局部 `GetPixelBytes`；`NativeOverlayWindow.cs::Present` 將 bytes 複製到 DIB 並呼叫 UpdateLayeredWindowIndirect。既有 dirty region 已減少資料量，實際收益取決於作畫區域與桌面尺寸。

- [ ] 分開量測渲染、readback、byte[] 配置、DIB 複製、Present 與 region 面積。先檢查目前 SDK 能否安全重用讀回緩衝；查實際 API 與 byte 數，不假設不存在的 overload。
- [ ] 改善保守局部範圍／緩衝 reuse 時，延續舊新範圍合併、雷射 fade、取消／Undo 與曲線外凸相容行為。
- [ ] 若 readback／Present 仍占主要成本，獨立研究 DirectComposition／可合成 GPU surface 的原型，保留 layered-window 路徑與 feature flag，建立同場景比較資料。
- [ ] 原型必須保留透明背景、穿透切換、NOACTIVATE／焦點、工具列置頂順序、全域快捷鍵、多螢幕虛擬桌面座標與截圖行為。先確認這些需求再採用新 backend。

**完成條件：** 現有路徑修改須與參考畫面等價且減少配置／傳輸耗時；GPU 原型跨 backend 按明確像素容差及操作驗收，收益與相容性皆成立才轉預設。沒有收益或相容性缺口則維持原路徑。

## PERF-07：長筆跡與輸入延遲

**定位：** `Engine/WindowsInkCoordinator.cs`、`Direct2DCanvasRenderer.cs::RenderLiveStroke`、`MainWindow.Input.cs`、原生 overlay 的輸入橋接。

- [ ] 延續 timestamp 排序與64段幾何快取；量測尾段重建、穩定 blocks 重繪及高透明度 layer 的成本，避免整條筆跡每點重建。
- [ ] 真筆裝置檢查 PointerId、capture lost、pen 按鈕、筆壓／傾角與快速連續落筆；平滑演算法的座標與尾點不得因節流遺失。
- [ ] 僅在 UI thread 排隊為主因時，研究適用 WinUI 3 的獨立輸入／呈現原型；先核目前 API 的支持範圍与執行緒邊界。
- [ ] 預測筆跡若加入，只在暫態畫面使用，真樣點到達後修正；不能寫入作品或 Undo，不能把壓力資料保存等同壓感外形已完整實作。

**完成條件：** 長筆跡成本與輸入反應有同機資料支持；筆跡不倒折、跳點、接縫變深，快速落筆／抬筆／取消皆正確。缺真筆硬體時明確記未驗收。

## PERF-08：保存與記憶體壓力

**定位：** `MainWindow.xaml.cs::SaveAsync／SaveThumbnail`、`MainWindow.Rendering.cs::QueueThumbnail`、`Core/Engine/DocumentSnapshot.cs`、`Core/Engine/EditorSession.cs`。現有背景保存／typed snapshot 與縮圖延後策略已完成。

- [ ] 分開量測 UI snapshot、背景編碼／寫檔、縮圖 GPU 工作、圖片解碼及 GC；確認是否與停頓時間相關。
- [ ] 依結果比較 scratch buffer、圖片解碼尺寸策略、快照差量或 Undo 結構化交易。後兩項涉及資料生命週期，必須有獨立設計／相容驗收與退路，不能為省記憶體遺失未知欄位或原稿。
- [ ] 保留 atomic replace／備份、revision 衝突、DocumentEpoch、保存 gate、關閉前完成保存與多視窗租約；避免背景保存成功時把較新的編輯誤標已保存。

**完成條件：** 保存期間的停頓／記憶體有改善；輸入不阻塞，作品內容、未知欄位、取消、Undo／Redo與保存失敗恢復行為完整。

## PERF-09：硬體、DPI 與資源驗收

- [ ] 依可用硬體建立 x64／ARM64、60／120 Hz、100／150／200% DPI，以及多螢幕含負座標／混合 DPI 的矩陣。未具備的環境寫未執行。
- [ ] 視窗跨螢幕、DPI／尺寸變化、顯示器增減、休眠喚醒／device lost、反覆開關作品／overlay；核對筆尖與圖形坐標、裁切、焦點與記憶體回收。
- [ ] 中文 IME、右鍵多選、Ctrl+Alt+D 穿透、區域截圖、圖片／PDF 輸出與作品格式作相容驗收；修改渲染不能破壞這些入口。
- [ ] 後續新版本正式打包前，在隔離環境驗證相應 EXE／Portable／MSIX 與 WACK；保留原 1.0.12.0 套件，Store 更新／資料移轉／卸載需另外驗收，不冒稱已有結果。

**完成條件：** 有平台／裝置／操作的結果表與失敗證據，沒有宣稱未測硬體已通過；資源在切文件／關閉／重建後回到合理穩態。

## 分批交付

1. **第一批：01 + 02 + 03。** 提供基準、實際主要成本、低風險改動與前後比較，其他項目可依結果調整順位。
2. **第二批：04／05／06，依瓶頸挑選。** 每批一個主要快取／渲染策略，提供記憶體成本、失效規則、可回退路徑与相容結果。
3. **第三批：有證據才做 07／08；完成 09 矩陣。** 提供實機反應與下一版發布待辦。

每批交付需列：修改檔案、source commit、實際命令、相同環境樣本／p95、畫面／資料相容結果、未驗收項、失敗方案及其原因。保持實作／測試／封裝／GitHub 同步／Store 發布分開記錄。

## 參考

- [既有架構](ARCHITECTURE.zh-TW.md)、[歷史效能紀錄](WINDOWS_PERFORMANCE_REVIEW_2026-10-10.zh-TW.md)：用於理解已完成策略，不能沿用歷史數字作本輪驗收。
- [Microsoft：Direct2D 效能原則](https://learn.microsoft.com/en-us/windows/win32/direct2d/improving-direct2d-performance)：資源重用、固定內容快取与場景成本。
- [Microsoft：Win2D offscreen drawing](https://learn.microsoft.com/en-us/windows/apps/develop/win2d/offscreen-drawing)：render target 的增量更新基礎。

## 可交給 Antigravity 的指令

> 請接手 HeiBan Windows 下一版流暢度工作，先讀根 AGENTS.md、平台開發索引／狀態，以及 windows/docs/ANTIGRAVITY_PERFORMANCE_WORKLIST_2026-10-10.zh-TW.md。按我授權的實作／驗證範圍從第一批 PERF-01／02／03 開始，先取得新基準再修改有證據的熱點。保留已送審 Store 1.0.12.0、原套件／SHA／素材與使用者作品；只處理 Windows。後续項目按實際瓶頸決定，不預先承諾收益。每批記錄失敗／原因／命令／結果／未驗收環境，完成後同步 GitHub；商店或 Release 發布依我的另外指示進行。

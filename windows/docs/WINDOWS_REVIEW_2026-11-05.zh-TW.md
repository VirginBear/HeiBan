# Windows軟體審視與後續改善 — 2026-11-05

本批先完成Shift正形、螢幕尺恢復、圓色票與拖曳排序簡化，維持1.1.2開發系列。建議下一批先做「有量測的輸入／呈現分析」及「封裝依賴驗證」，不要把大量功能刪掉當成流暢度改善。

## 證據與範圍

審視Windows輸入、預覽／提交、共享Core、工具列、色盤、尺、螢幕呈現、更新與封裝邊界；未修改macOS/Web。掃描兩個應用程式原始目錄，排除bin/obj，含條件編譯驗證碼共184個CS、20,313行。MainWindow.Chrome.cs 1,751行、MainWindow.Input.cs 928行、ScreenAnnotationWindow.cs 712行；這是維護範圍指標，不等於執行效率或包大小。數字對應本批驗證新增後的量測快照。

先用既有graphify圖辨認工具列關係（368節點／905邊，來源75aa821，2026-10-12舊圖），再查目前原始碼；舊圖未重建，不用它證明目前沒有呼叫者。原始量測在本機`.build/shift-ruler-palette-20261105/review-metrics.json`，不含使用者作品。

上一份shape-cursor試用包實測：ZIP133,745,779 bytes；完整非Data目錄731檔325,732,774 bytes（含兩份發行說明等，與update-files.json的729個受管payload不同）。其中：

| 檔案 | bytes | 判讀 |
| --- | ---: | --- |
| Updater/HeiBan.Updater.exe | 73,844,593 | 更新器獨立self-contained單檔，含自己的.NET執行環境 |
| Microsoft.Windows.SDK.NET.dll | 26,341,408 | Windows投影相依 |
| onnxruntime.dll | 21,659,280 | SDK相依帶入，沒有因此認定可直接刪 |
| DirectML.dll | 18,700,224 | 同上 |
| System.Private.CoreLib.dll | 16,033,576 | 主程式.NET執行環境 |
| Microsoft.ui.xaml.dll | 15,324,472 | WinUI執行環境 |
| HeiBan.dll + HeiBan.Windows.Core.dll | 2,131,456 | 自有兩個主要managed程式庫 |

既有正式1.1.2.0 x64 MSIX有768個ZIP entries、未壓縮251,852,432 bytes，**沒有Updater**。此表不能把Portable的74MB更新器節省套用到Store，也不能將未壓縮相依大小直接相加當成可減少的ZIP大小。

## 本批已處理

| 問題與位置 | 實作與實際結果 |
| --- | --- |
| 兩宿主Shift線只有水平／垂直；一般形狀沒有正形入口 | Core `ShapeConstruction.ConstrainLine/Drag`共享八向投影、正方／正圓／等比例及正三角。兩host只傳座標與modifier，預覽放開才提交。保留逐點模式與Shift追加選取；Shift製圖優先於磁鐵。 |
| 螢幕尺渲染與handler仍在，但隱藏工具缺可達入口，初始固定640實體px | `ScreenAnnotationWindow.Ruler.cs`固定更多→螢幕尺→顯示／重新顯示，首次目前螢幕工作區80%寬並置中。切換走damage，不走Changed整場重建／文件generation。實際像素出現、關閉回到相同背景，隱藏尺仍有恢復入口。尚未重現使用者原本裝置的確切消失成因。 |
| 螢幕More沒有隱藏工具回收，說明固定正體中文 | `CreateScreenMenu`使用既有command map及ToolbarContentPolicy；隱藏／分頁未掛載的設定按鈕以可見More作flyout anchor。說明沿用owner目前語言選擇與fallback。 |
| 快速連續作畫時雙擊可誤切選取／編輯 | 主畫布DoubleTapped僅選取模式處理；螢幕非選取double轉普通down，雷射／藤條仍各自先處理。原生連續矩形案例工具保持rect。 |
| Screen逐點多邊預覽每move序列化JSON | 改SetCompletedInkPoints持有獨立小點列，文件邊界才編碼；不改v1文件契約，沒有宣稱已量出延遲改善。 |
| 色票方形、前後移及刪除按鈕行太雜 | 共用PaletteEditor含透明底、拖曳ghost皆圓形；去前後移UI與context排序，只留小字拖曳提示、右鍵移除。查呼叫後刪相對MoveByAsync及其專屬測試，保留絕對MoveAsync／原子保存／未知欄位。 |
| 更新測試原本缺WinUI文字依賴而無法編譯 | headless測試加LocalizationBoundary，仍連結真實更新服務；本批73 checks PASS。GUI翻譯另外驗711 keys×10語、missing0。 |
| 手冊仍提排序箭頭、固定640尺與舊版狀態 | 十語手冊／可編輯操作筆記同步新操作；26章81段，分清本機1.1.2試用與既有Store提交包。 |

## 建議下一批，依優先順序

### 1. 先量測輸入到呈現，避免用物件數猜原因

目前筆刷有獨立濕墨預覽，橡皮擦也有背景gesture／preview publisher，已不是每個move立即永久物件化。查`MainWindow.CircularEraser.cs`、`ScreenAnnotationWindow.CircularEraser.cs`、`Engine/CircularEraserGesture.cs`及`ScreenAnnotationWindow.cs:Render`。螢幕overlay仍須GPU→CPU讀回及分區Present，這是與一般畫布不同的成本邊界；不能僅看CPU平均占用率判斷。

下一步：使用現有InputLatencyTrace，固定同一機器／DPI／刷新率／作品，空白、100及5000物件各做畫線轉角、擦除、拖動；分列input、preview、render、readback、commit的p50/p95/p99及長幀數。至少比較一般／螢幕各三輪；記錄是否磁鐵、尺、透明筆畫開啟。成功：輸入路徑不做文件JSON／全場重建；p95不退步、長幀下降，畫線末端與真實指標可目視跟隨，Undo／保存仍正確。軟體trace無法單獨證明端到端低於50ms，需要高幀率影像或硬體量測。本批未做新的延遲benchmark。

### 2. 封裝減重：Portable更新器、Store共享框架分別評估

`HeiBan.Updater.csproj`及`Packaging/Publish-Common.ps1`證明更新器是第二份self-contained .NET。可做AOT／裁剪實驗候選，必須檢查Core連入的JSON／反射、下載、SHA、取消、進程等待、檔案鎖、回滾及Data保全。成功：乾淨機器不用另裝.NET即可更新／失敗恢復，且實測包縮小。不能改成依靠正被替換主程式的runtime後就宣稱安全。

Store已有framework-dependent封裝選項及舊分析，可重新在乾淨Windows與Store測試安裝／升級／離線／x64及ARM64，確認AppRuntime依賴由商店提供再決定切換。`HeiBan.Windows.csproj`現用SelfContained，ML native排除target只針對framework-dependent候選；不要手刪現包DLL。成功：dependency manifest正確、兩架構無缺檔、沒有首次啟動部署失敗，測出MSIX與實際下載大小。**本批維持既有封裝，不覆寫正式包。**

### 3. 合併尺的繪製／單位邊界

`MainWindow.Ruler.cs:DrawRuler`與`ScreenAnnotationWindow.Ruler.cs:DrawRuler`有重複刻度／文字／支點計算；每次重畫還建立兩個CanvasTextFormat。先抽共用尺外觀／幾何與明確DIP→overlay physical-pixel轉換，再由各host管互動和位置。可快取文字format，Dispose時釋放。這能降低維護與配置重複，尚不能斷言是目前延遲主因。

成功：100/150/200%DPI、多螢幕負原點及移動工具列後，刻度／hit test／旋轉支點一致；顯示與隱藏無殘影、不重建作品，不改使用者自行設定的尺長。

### 4. 工具描述與手勢逐步共用，不合併整個視窗

ToolbarUi、ToolbarContentPolicy、ToolIcons、PaletteEditor、QuickPalette、ShapeConstruction已共用。兩host持有自己的UI控制項、session與座標，不能共享同一UIElement或把全部輸入直接搬在一起。MainWindow.Chrome.cs仍1751行；下一步適合抽純資料工具描述／能力與共用幾何手勢狀態，保留host command handler。

成功：新增一個共用工具只新增一份名稱／能力描述；一般與螢幕不誤出圖釘／視角功能；輪盤、分頁、隱藏恢復及工具設定四邊停靠回歸通過。避免一次重寫渲染引擎，讓效能改善和回歸可定位。

### 5. 選取頂點編輯還有即時JSON路徑

`MainWindow.Input.cs`的vertex調整仍每move將小點列JsonSerializer.Serialize；與本批screen多邊preview已延後編碼的路徑不同。下一批可轉owned-point preview，gesture結束一次提交，同時驗鎖定、旋轉後頂點及未知點欄位。一般多邊預覽Concat/ToArray只有3～4點，優先度低於實測readback／長筆畫熱點。成功：每move沒有JSON、文件roundtrip不丟欄位、一筆Undo還原。

### 6. 可移出未來發行包的小型歷史資源

`Engine/CaneSound.cs`只使用CaneImpact1／CaneImpact2／CaneRockBreak。舊CaneSnap.wav25,004及CaneCrack.wav63,548 bytes仍由Assets廣義規則帶入；兩檔未壓縮合計88,552 bytes，僅約0.027%的目前Portable目錄。來源／生成腳本／授權及既有產物仍須保留；若排除未來publish，先更新source inventory和檢查腳本的引用，不可只刪檔。這不是主要瘦身收益，本批不做歷史資源刪除。

### 7. 建置中間檔與交付檔分開管理

獨立QA／portable publish每批會保留證據及中間runtime複本；它們是開發機空間，不等於使用者安裝包。沿用手動清理清單，核對來源／SHA／已發布Store保留後才清理明確列出的中間目錄。使用者作品、參考軟體、歷史正式包及舊試用Data一律保留。本批未執行遞迴刪除。

## 驗收與界限

實際結果、命令、失敗及產物來源見[本批開發紀錄](SHIFT_RULER_ROUND_PALETTE_2026-11-05.zh-TW.md)。本批不是全裝置效能認證；ARM64實機、Windows App Certification Kit、正式Store安裝／升級、物理Shift鍵搭配滑鼠拖曳及所有DPI組合未執行。原生host驗證注入PointerEvent／modifier測UI適配路徑，不能冒充人類按鍵手感測試。

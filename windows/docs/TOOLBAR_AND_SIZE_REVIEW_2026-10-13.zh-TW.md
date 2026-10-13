# 2026-10-13 — Windows 工具列一致性與瘦身分析日誌

## 開工

- 使用者要求理解GitHub最新Mac更新／差異紀錄，Windows螢幕工具列以一般画布為準，只省略圖釘與畫面放大縮小，並分析Windows瘦身計畫。
- 開工HEAD148d427，status只既存未追蹤.vscode/；fetch後0 ahead／6 behind，以git pull --ff-only同步至3f39f1d，保留.vscode/。上游125檔來源／紀錄取回，不等於本機Mac開發或成品更新。
- 已讀開發索引、Windows AGENTS／CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY，並讀最新Mac交接、Windows減重計畫／交接。只在Windows做本次分析／規格紀錄，Mac／Web與既有成品保留。
- Windows metadata仍1.0.14，遵守整批驗證後由使用者決定正式進版；本批未授權執行測試或發布。

## 調查進度

- Mac目前1.0.13最終工具共用來源為3da9310及其交接；Windows前批僅共用ToolbarUi建立政策，並非完整工具catalog／面板。
- 初次遞迴搜尋ignored .build內graph索引耗時，主動中止只讀搜尋，再依第一層目錄定位舊索引，避免遍歷SDK與大量封裝中間檔。舊圖只用於導航，最新來源為實際判斷依據。
- 接續記錄功能差異、共用边界、減重證據與工作順序。尚未把分析或舊批測試數字標成實作／驗收。

## 1. 最新 Mac 更新的理解

Mac最終功能來源3da9310aec26771456c14a425dad3b6bc50755fa，tag macos-v1.0.13；目前main3f39f1d包含後續文件整理。Mac不是只改外觀：ToolbarToolsView與ToolbarBrushSettings供兩宿主使用，ToolbarContentPolicy從同一偏好清單計算可見工具，screen保留自己的穿透／退出／owner。螢幕原本11工具硬編碼與獨立switch已被共用元件取代。參考：[Mac交接](../../macos/docs/development/MAC_DEVELOPMENT_HANDOFF_2026-10-13.zh-TW.md)、`macos/Sources/HeiBanCore/Models/ToolbarContentPolicy.swift`及`HeiBanMac/Views/ToolbarView.swift`。

Mac最後共用版尚未全面功能回歸；以前1713／1752斷言不能轉作本批Windows證據。Mac 4.15MB ZIP與Windows自包含.NET／WinAppSDK不是同部署成本，不能要求Windows透過刪程式碼直接縮到同尺寸。

## 2. Windows 實際差異

| 面向 | 一般畫布 | 螢幕畫布目前 | 統一目標 |
| --- | --- | --- | --- |
| 清單／順序 | Core ToolbarPreferences；新預設9項，其他進更多，可排序隱藏 | ToolbarUi.ScreenTools硬編碼11個作畫按鈕，加固定動作與樣式列 | 共用catalog、同一排序／顯隱偏好；依宿主能力過濾 |
| 選取 | 選取、框選、套索入口 | 選取／框選及Shift多選，無自由套索入口與流程 | 接相同選取模式及反饋 |
| 圖形 | 圖形按鈕內9種：直線、箭頭、矩形、圓、三角、四邊、菱形、五角、星 | 直線／箭頭／矩形／圓各佔一格；OnPointer僅這4類建立預覽 | 同一圖形選單、同一形狀建立與幾何規則 |
| 筆跡 | WindowsInkCoordinator、合併輸入點、停筆1秒近直線轉直線、BrushKind | 原生OnPointer收_points；輸入點pressure固定1，未接停筆直線規則或BrushKind選擇 | 共用宿主無關的筆跡收集／停筆規則，保持各自輸入adapter |
| 尺／圓規 | 有面板、命中、拖曳、尺投影與兩階段圓弧 | 螢幕宿主目前沒有對應owner與輸入接線 | 需移出一般window依賴並補可操作疊層 |
| 計算機／計時器 | Core模型已接一般浮動面板，可插入算式 | 未接screen入口、常駐狀態或算式插入 | 共用面板；輸出路由到目前screen session |
| 便條／膠帶／圖片 | 有建立／匯入／樣式入口 | 已有文字／sticky編輯、圖片截圖與複製物件基礎；沒有完整對等的建立／匯入工具 | 補入口、對象建立、選取與編輯，不只顯示圖示 |
| 筆刷／屬性 | 色輪、筆刷類型、預覽；選取後進物件適用屬性 | 另建簡版筆刷，寬1–32pt／alpha .1–1；選取樣式另處理 | 共用欄位定義／面板，範圍及預設一致，依型別顯隱 |
| 圖層 | 一般圖層視窗 | 另一份screen ListView／拖曳接線，已共用LayerDragPreview等基礎 | 共用圖層UI／操作政策；model binding與epoch各自管理 |
| 更多／自訂 | 隱藏清單＋自訂／恢復預設 | 另寫MenuFlyout，沒有相同自訂catalog | 同一更多內容與偏好，不因切screen重置 |
| 圖釘／視角導航 | 圖釘、zoom／pan／視角鎖定 | 桌面實體座標、固定比例，不提供圖釘／zoom | 依使用者要求保留在一般畫布；物件鎖定仍保留 |
| 螢幕外殼 | 作品導覽及視角操作 | 穿透／作畫、清空、結束 | screen必要外殼獨立；繪圖工具內容一致 |

**繪圖Core與renderer已有共用，但手勢協調、工具清單、面板與宿主接線未完全共用。** 前批ToolbarUi共享的是按鈕／提示／無障礙／RTL／線型選單建立政策，ScreenTools仍是一份獨立縮減清單。這是本次差異的可確認原因。

來源定位：`HeiBan.Windows.Core/Engine/ToolbarPreferences.cs`；`HeiBan.Windows/MainWindow.Chrome.cs` BuildChrome／ShowMoreToolsMenu／ShowShapes／ShowBrushSettings；`MainWindow.Input.cs`；`Views/ToolbarUi.cs`；`ScreenAnnotation/ScreenAnnotationWindow.Chrome.cs`／`.Docking.cs`／`.Panels.cs`／`ScreenAnnotationWindow.cs` OnPointer。上述皆本機同步後來源，不以舊圖推定目前行為。

## 3. 工具列統一規格與工作清單

同一份一般畫布工具catalog作為標準，包含圖示、語言key、順序、顯隱、快捷鍵語意、設定入口與適用性；兩個宿主從同一描述建立自己的WinUI控制項。XAML控制項不能跨兩個parent重用。

共同繪圖工具包括選取／套索、畫筆／曲線／螢光筆／油漆筆、橡皮擦、尺、完整圖形、便條／文字／截圖／匯圖、筆刷／線型、計算機／計時器／圓規、undo／redo、雷射／膠帶／清空／圖層／停靠與更多。延伸直線依既有要求保留在屬性，不恢復成獨立格。screen省略圖釘與圖面導航；viewLock屬視角導航，與物件IsLocked分開。screen清空及退出維持容易到達，使用同一清空命令描述，避免出現兩個重複清空按鈕。

| 批次 | 工作 | 完成與驗收標準（本次尚未執行） |
| --- | --- | --- |
| WT-01 清單与偏好 | 建共同ToolbarCatalog／ContentPolicy，吸收ScreenTools；同源形狀子清單，兩宿主visible／hidden從一般偏好取得 | 相同設定下screen工具順序等於一般扣圖釘／導航；自訂、更多、恢復預設及語言刷新一致；不重置舊偏好 |
| WT-02 設定與命令 | 提供session-aware工具上下文，抽共用brush／eraser／laser／形狀屬性／圖層／計算機／計時器UI | 主與screen選取只改自己的物件，一次樣式手勢一筆Undo；欄位／預覽／alpha／粗細範圍一致；新圖釘能力不流入screen |
| WT-03 缺漏工具與手勢 | 抽通用InkSample collector／直線判定，screen native adapter補接；補多邊形／套索／便條／膠帶／圖片／尺／圓規 | 顯示的工具都有實際可達行為；1秒停筆、尺吸附、圓規兩階段、取消／Undo／文字組字／鎖定／匯入過期拒絕可驗證 |
| WT-04 布局與完整回歸 | 同一icon尺寸／spacing／高亮政策，兩宿主各自量測；上下橫排、左右直排、依可用空間換行，不加scrollbar | 10語／RTL／窄螢幕／4K-DPI／四邊／多螢幕、穿透／前景焦點、退出保存、所有工具與更多／settings實用驗收；最後更新十語手冊與試用包 |

這是完整對齊範圍，不能先放缺乏handler的按鈕宣稱完成。保存、縮圖、損毀恢復、截圖、座標與交易owner保留明確邊界；drawing-only模型可共用，desktop pixel／DIP／world转换在adapter完成。高頻點／尺圓規拖曳留暫態，結束才提交永久物件與Undo。

## 4. 瘦身計畫的本機核對

已讀[Mac提供的Windows減重計畫](WINDOWS_SIZE_REDUCTION_PLAN_2026-10-13.zh-TW.md)，並對原機guides-2026-10-12 Store bundle做只讀拆解，結果：[本機payload JSON](STORE_PAYLOAD_REVIEW_2026-10-13.json)。原bundle及兩MSIX的SHA均與前批紀錄相同；沒有重新編譯或更改ZIP。

| 原Store候選 | MSIX bytes | 全部檔案邏輯payload bytes | ML六檔解壓bytes | ML六檔壓縮entry bytes |
| --- | ---: | ---: | ---: | ---: |
| x64 | 98,120,539 | 248,073,400 | 41,995,768 | 17,537,365 |
| ARM64 | 95,552,946 | 264,702,480 | 42,225,720 | 17,119,480 |

ML六檔依實際HeiBan.deps.json的Microsoft.WindowsAppSDK.ML／Microsoft.Windows.AI.MachineLearning／System.Numerics.Tensors runtime/native資產定位，含onnxruntime.dll、DirectML.dll及相應managed投影／Tensors；非單靠檔名猜測全部SDK成本。Store兩架構均無獨立Updater、作品Data或PDB。

表列ML載荷是**已確認存在的優化對象**，不是已確認可刪檔清單或可省數字。壓縮entry不含MSIX標頭與其他封裝成本；A候選還原結果可能重新帶入元件，需功能／原生相依驗收後才有實際減重數字。這次x64約17.54MB、ARM64約17.12MB是Store原包的實測，與Mac以Portable量出的16.78MB不同，不能混用。

## 5. 瘦身優先順序與取捨

| 優先 | 方向 | 預期收益 | 限制／採用條件 |
| --- | --- | --- | --- |
| 1 | 工具與面板共用，完成WT-01–04 | 提高一致性、減少重複維護與重複UI政策 | 不預測大幅縮小包體，不以行數下降代表繪圖更快 |
| 2 | WR-01補同來源BASE，WR-02必要SDK元件 | 真正排除未用ML／AI／Search／Widgets相依的可能性 | 保留WinUI／Win2D／WebView2 PDF；先查MSBuild／native依賴，不手刪DLL；目前未實作 |
| 3 | WR-03另作共享WinAppSDK候選 | 減小主MSIX，減少每次隨App搬運框架 | .NET仍自包含；manifest dependency、初始化、乾淨機與已有框架兩種情境分別驗收；首次依賴下載仍計入 |
| 4 | WR-05獨立Updater AOT／裁剪 | 對Portable／官網版有機會省第二份.NET runtime | Store已無Updater，對Store新增減重0；須驗下載／多視窗／檔案鎖／回滾與作品保全 |
| 另軌 | 已有damage／frame合併上再量測，改善索引／圖塊／snapshot | 大作品輸入／pan／zoom／保存流暢度 | 先同硬體記input-to-preview、p95、掉幀、RAM／idle；刪依賴與UI共用均不直接證明效能提升 |

目前csproj的PublishAot=false，PublishTrimmed僅在Release且AOT=true時啟用，主程式不是已裁剪。SDK與.NET各自SelfContained=true；SDK共享與.NET共享兩個設定不得一起擅改。WinUI XAML、PRI、JSON未知欄位與native ABI相容性優先於大小。

[Microsoft共享SDK部署說明](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/deploy-packaged-apps)要求正確框架依賴與部署初始化；當前Store設定兩個Initialize=false是self-contained管道，B候選須重新核對，不能只把WindowsAppSDKSelfContained改false。官方system-requirements舊連結目前轉SDK總覽，不能把該轉址視為精確元件版本相容性證據；版本依精確NuGet及本機restore檔核對。

建議執行顺序：**工具列功能對齊 → 同來源包體BASE → A必要相依候選 → B共享SDK獨立候選 → 回歸／安裝驗證 → 使用者決定正式進版。** A、B先分開，成功後才評估C，收益不可直接相加。這是工作排序與取捨建議，不是修改產品部署或安排排程。

## 6. 實際命令、結果與未執行項

- git status／fetch／rev-list／pull --ff-only退出0，起始0/6，同步3f39f1d；沒有reset／force。Mac最新來源只取回，未在本機修改Mac。
- graphify舊AST graph採Python讀JSON，依實際label擴展buildchrome／initializechrome／showbrushsettings、BFS一階鄰點導航；首個buildchrome命中RebuildChromeLayout，所以更以來源核對BuildChrome。CLI不在PATH，未重建圖／未呼叫LLM萃取（新input/output extraction tokens為0）。索引來源已過時，未把其line number當作最新事實。
- Get-Content／rg閱讀catalog、兩chrome、input、dock、layers、csproj及Mac共用View／policy；初次猜測不存在Gestures／ChromeDocking／Layers partial檔名失敗，改用rg --files得到真實Docking／Panels／ScreenAnnotationWindow.cs；字面MainWindow*.cs搜尋os123改目錄＋-g。保留失敗與更正，不據此推定功能不存在。
- `.build/review-store-size-2026-10-13.py`退出0：bundle SHA8dc919c47c69585a114cc9c8d1ddf20c1126e08b5524ca73009c8e85b396d666；x64 SHA0d0f883d…與ARM64 SHAa437e10c…核同原JSON，兩包575／571檔，bytes／ML6檔詳新JSON。方法只讀ZIP目錄、內嵌MSIX與deps，不碰作品，不修改二進位。
- 文案／架構／問題／現況與私人精簡交接更新是本批交付。**WT-01–04与WR減重尚未實作**，兩種工具列目前UI尚未改。手冊因UI本批未改而未重生；後續實作時同步十語操作说明。
- 更新索引的第一份多檔patch因猜Windows README標題為HeiBan Windows而驗證失敗，確認所有部分未套用後，讀實際標題「黑板 · Windows 原生版」重做，未覆蓋既有紀錄。
- 未執行：build、封裝、App、tests、WACK、功能／效能／硬體驗收、母語校閱、Store登入／上傳／提交／發布、Release／進版、舊檔清理。已發布／送審產物、作品與歷史不刪。

## 7. 交付與GitHub同步

公開分析提交c764d6551f2a16d0c988353cbbdf5c169853edf8（9檔358新增）已push退出0，ls-remote核同當時HEAD，status只有原.vscode/。私人必要摘要／產品review欄位分庫提交推送並核同遠端、工作區乾淨，不把私人產品資訊放公開庫。這次只有分析、規格与原包只讀量測；兩種工具列與SDK減重實作仍待下一批，沒有新試用包或功能／性能驗收。

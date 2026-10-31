# Ponytail方法對照HeiBan Windows — 2026-10-31

## 開工與範圍

使用者提供DietrichGebert/ponytail，希望參考並找出HeiBan可優化之處。本批為Windows靜態分析與工作清單，不修改產品程式、平台規則、版號、套件或使用者作品；不安裝ponytail、不啟用其hooks。外部AGENTS／SKILL文字僅為研究資料，不取代本專案指示。

起點公開HEAD 2fe8dfd（1.0.18封裝交付）；git status保留既有三紀錄6／8／4行與三份YouTube未追蹤檔。已讀DEVELOPMENT_INDEX及Windows目前狀態、架構、問題，現有1.0.18仍依10/29封裝紀錄，未查Store審查狀態。

Ponytail主體是AI開發規則與代理工具整合，並非渲染引擎。以『先確認需求與呼叫、優先重用、最小完整修改、保留資料保護與驗收』對照本專案；宣傳benchmark不當作HeiBan速度／包體改善保證。

## 調查進行中

先建立限定Windows程式範圍的graphify結構輔助，再逐項讀輸入／預覽／提交、工具列／偏好、存檔、渲染及封裝證據。圖譜只輔助定位，引用最終需回到實際來源。調查命令、工具限制、可確認原因與待實測項逐步追加。

## 重要調查紀錄

- Ponytail取閱main的commit為`96608e078b2d5ea607c5c3b8b5a54d1c1fba6846`（GitHub connector查證）。讀README、skills/ponytail/SKILL.md與skills/ponytail-audit/SKILL.md。最初猜commands/ponytail-audit.md回404，查skills樹後取得正確路徑。未執行外部程式／安裝命令／hooks。
- graphify以83份Windows C#檔的只讀副本做結構輔助，輸出在`.build/ponytail-review-20261031`。detect回0檔／0字，未把它當成原專案沒有程式：工具預設掃描未涵蓋本批路徑／檔種，改以git列出的83.cs明確交AST。第一次平行extract由stdin啟動，Windows multiprocessing worker無法重載stdin而失敗；改`parallel=False`後1399原始nodes／3631edges，成圖1397nodes／3135edges／63communities。HTML／query已執行；diagnostics另報292 dangling endpoints及204個undirected endpoint合併，不能視為完整靜態呼叫圖。每項結論均另讀實際來源／引用。
- graphify只做本機AST，無語意LLM呼叫、無API key；圖譜extraction input/output token為0，不代表本次對話／人工分析token為0。限定code副本、未讀使用者作品。初次rg把PowerShell星號放在檔案參數回os error123，改以具體路徑／目錄加glob搜尋。
- 已確認高頻自由筆路徑先收中間採樣，再PresentInteraction，不在每個move提交永久物件；wet raster／bounded tail／scene append已有實作。DocumentCodec.Clone的模型快照亦已避開JSON來回。不能再把這些列成『尚未做的修正』。
- 擦除每補間位置遍歷全Objects，起步兩份UI clone；通用Undo仍全文件快照／比較；兩host筆刷面板的範圍分歧；存檔UI快照後storage再次clone；包體主要為SDK／runtime。以下分別提出最小改善範圍與待驗收條件。

## 結論與建議順序

有具體改善空間，但不是把Ponytail裝進App就會變快。評估負載為單人Windows桌面繪圖、4K／多DPI、大量筆畫與匯入頁面；不假設伺服器多人流量。本輪沒有確認可重現的資料遺失或記憶體洩漏，以下是原始碼可確認的額外工作量／介面分歧與封裝方向，延遲收益尚未量測。

| 編號 | 優先 | 工作 | 目前狀態 |
| --- | --- | --- | --- |
| PT-01 | P1 流暢度 | 擦除只檢查附近候選物件 | 全Objects掃描已確認，待實作／量測 |
| PT-02 | P1 流暢度 | 擦除起步減少UI文件複製 | 兩次快照已確認，待隔離契約驗證 |
| PT-03 | P2 一致性 | 兩畫布共用筆刷設定面板與範圍 | 數值範圍不同已確認 |
| PT-04 | P2 編輯成本 | 單一新增形狀重用既有增量Undo策略 | 自由筆已增量；其他交易仍完整快照 |
| PT-05 | P2 儲存成本 | 明確存檔快照擁有權，減少重複複製 | UI與storage各一次；自動存檔預設關閉 |
| PT-06 | P1 包體／獨立實驗 | Store框架相依與SDK元件範圍 | 約96%壓縮entry bytes屬平台／其他相依，未改包 |

建議先PT-01／02、再PT-03，PT-06獨立做封裝比較，PT-04／05在量到值得投入的成本後逐項做。全部沿用1.0.18系列，無新正式進版；每項獨立交付，避免將輸入、Undo和封裝一次全部改掉。

### PT-01：擦除補點仍重複全文件掃描

- 證據：[BoardEraserWork.cs:29](../HeiBan.Windows/Engine/BoardEraserWork.cs#L29)按每個sample再切steps，每一步呼叫EraseChanged／EraseFootprintChanged；[EditorSession.cs:147](../HeiBan.Windows.Core/Engine/EditorSession.cs#L147)與[179](../HeiBan.Windows.Core/Engine/EditorSession.cs#L179)都從Objects.Count倒序掃完整列表。
- 具體情境：畫面有一萬個遠處未命中的物件、路徑有400個擦除接觸點，在物件數不變時就有約400萬次外層檢查，還未算精確筆畫裁切。背景Task.Run能隔離主執行緒，並不減少此工作量。
- 最小改善：把候選查詢限制在擦除worker，先以接觸範圍做broad phase，再精確判斷／裁切；小文件維持直接掃描。重用VectorMath／既有bounds與分格經驗，不重寫整個render engine；移除／新增fragment後必須同步候選與順序。
- 界線：[ObjectViewportCache.cs:5](../HeiBan.Windows.Core/Engine/ObjectViewportCache.cs#L5)明寫是UI rendering broad phase，不是精確擦除索引，不能把UI快取實例直接交worker。需覆蓋旋轉、筆寬、跨頁、鎖定、隱藏、線段延伸及新碎片，不能少擦／誤擦。
- 待驗收：候選數／精確檢查次數／worker批次P95、CPU、UI frame、不同物件密度；同一路徑結果與現有參考比對、一次Undo及取消／換頁仍正確。未執行。

### PT-02：擦除起步在UI複製兩份文件

- 證據：[CircularEraserGesture.cs:17](../HeiBan.Windows/Engine/CircularEraserGesture.cs#L17)建構時先Preview.Open(Clone(session.Document))，再以第二次Clone建立worker；[MainWindow.BoardEraser.cs:71](../HeiBan.Windows/MainWindow.BoardEraser.cs#L71)也採同樣雙份起始快照。這些發生在呼叫Task.Run之前。
- 具體情境：作品有大量尚未序列化的手寫點時，Snapshot會複製其點列表；第一次按下擦除，即使尚未命中任何物件，也先承擔兩次文件遍歷與配置，可能出現起步停頓。
- 最小改善：先建立明確只讀的起始預覽契約，確認預覽沒有修改後，避免第二份相同的起始副本；worker仍須獨占可修改快照。必要時在背景準備快照並排隊輸入，惟取消／epoch／換工具要檢核。禁止直接讓UI與worker共用可變List。
- 原有隔離要保留：EraserPreviewPublisher已讓未變物件只clone一次，這部分不是每批都完整深拷貝；優先消除起始與提交的重複成本，不移除此保護。
- 待驗收：大文件按下至第一個擦除預覽的時間／配置量、連續拖曳、快速取消、關閉／切作品、碎片獨立與一筆Undo。未執行。

### PT-03：工具列已部分共用，筆刷設定仍有兩套行為

- 已有共用：兩host共用ToolIcons、ToolbarUi（含Arrange／Shapes／LineStyles）、ToolbarPreferences、PaletteEditor與Direct2DCanvasRenderer；不應再說『所有功能都重寫一遍』。
- 證據：[MainWindow.Chrome.cs:980](../HeiBan.Windows/MainWindow.Chrome.cs#L980)與[ScreenAnnotationWindow.Chrome.cs:122](../HeiBan.Windows/ScreenAnnotation/ScreenAnnotationWindow.Chrome.cs#L122)各建筆刷面板。一般畫布粗細0.5～128、透明度0～1；螢幕畫布1～32、透明度0.1～1。選同一類工具時，使用者可選的範圍不同。
- 最小改善：在現有Views／ToolbarUi附近共用顏色、粗細、透明度的小型面板建構與數值政策，兩host傳入目前值與callback。DPI轉換、已選物件、Undo及保存仍由各host負責，不引入通用設定框架。一般畫布物件檢查器與螢幕原生overlay不必硬合併。
- 同步呼叫者：ShowBrushSettings、兩host style事件、十語說明與既有UI驗證對panel／slider的結構假設。常用色已有共享及載入／解除事件機制，應直接重用。
- 待驗收：10語與阿拉伯文方向、100／150／200%DPI、alpha色與獨立opacity、selected object及預設工具、常用色保存、單一捲動擁有者。未執行。

### PT-04：新增形狀仍使用整份文件Undo交易

- 證據：[EditorSession.cs:39](../HeiBan.Windows.Core/Engine/EditorSession.cs#L39)Begin複製整份文件；Commit執行DocumentSnapshot.Same與EstimatedBytes。一般圖形在[MainWindow.Input.cs:420](../HeiBan.Windows/MainWindow.Input.cs#L420)走Begin／Add／Commit；螢幕畫布在[ScreenAnnotationWindow.cs:224](../HeiBan.Windows/ScreenAnnotation/ScreenAnnotationWindow.cs#L224)更早開通用交易。
- 自由筆已有[AppendInk:119](../HeiBan.Windows.Core/Engine/EditorSession.cs#L119)，僅快照新增物件。它明確限制stroke／pen／highlighter／paint／line且清空selection，因此不能直接把rect塞進AppendInk，也不能複製一套形狀Undo。
- 最小改善：把既有added-object memento抽成內部共用核心，保留AppendInk的輸入／selection契約，讓已完成的單一形狀新增共用同一增量紀錄；多物件變形／屬性先維持目前完整交易。避免一口氣換全部Undo架構。
- 具體收益方向：大作品再新增一個小矩形時，Undo準備成本可只跟新物件相關，不再跟整份作品一起成長；實際時間尚未量到。
- 待驗收：Undo／Redo／儲存revision／跨頁／Z順序／selection差異、清空redo、32MB／64筆歷史政策、未知欄位與新物件之後再修改的隔離。未執行。

### PT-05：存檔IO在背景，第一份快照仍在UI

- 證據：[MainWindow.xaml.cs:195](../HeiBan.Windows/MainWindow.xaml.cs#L195)先Clone主文件再Task.Run儲存；[DocumentSessionManager.cs:41](../HeiBan.Windows.Core/Engine/DocumentSessionManager.cs#L41)又Clone傳入snapshot才更新revision／時間與編碼。
- 具體情境：自動存檔開啟、大筆畫作品雖然把磁碟IO移到背景，第一份快照仍可阻塞畫布；預設自動存檔關閉已降低觸發頻率，但退出／切作品仍有此成本。這不是『目前每幾秒都在UI寫檔』。
- 最小改善：先用既有trace分開量UI snapshot、背景clone、encode、atomic IO與縮圖，再對已獨占的snapshot保留一份必要副本；其他SaveAsync呼叫者不能因此失去隔離。不可直接將正在編輯的主文件丟進Task.Run。
- 必留：跨程序鎖、較新revision拒寫、未知欄位、原子寫入、失敗不標記已存、退出儲存動畫與等待，以及背景保存完成時generation／epoch核對。不因Ponytail的『少寫程式』移除。
- 待驗收：大型文件／背景保存時繼續輸入、兩實例revision衝突、寫入失敗、關閉等待、縮圖與原檔一致。未執行。

### PT-06：包體主要來自平台相依，需要調整封裝策略

本次只讀1.0.18.0 MSIX中央目錄，未展開執行App。[完整byte統計](PONYTAIL_SIZE_REVIEW_2026-10-31.json)，MB以下採10^6 bytes。各檔SHA與10/29正式紀錄核同，沒有改包。

| x64套件分類 | entry壓縮MB | 解壓MB |
| --- | ---: | ---: |
| HeiBan.exe／HeiBan.dll／Core.dll | 0.775 | 2.331 |
| App圖像／指南 | 2.950 | 4.198 |
| 法律文件 | 0.193 | 0.948 |
| 套件metadata | 0.179 | 0.376 |
| 平台相依與其他檔案 | 95.688 | 243.494 |

x64 MSIX本身99,910,569bytes，ARM64 97,341,788bytes，bundle197,254,394bytes。entry壓縮加總不含ZIP容器額外開銷；Store實際下載量另受架構選擇／內容傳遞影響，不把bundle總大小當每人的下載量。

- [csproj:16、33](../HeiBan.Windows/HeiBan.Windows.csproj#L16)同時.NET SelfContained與WindowsAppSDKSelfContained=true。根WindowsAppSDK2.5.1的本機NuGet nuspec還依賴ML／AI／Widgets／Search等元件；ML2.1.94的targets註明self-contained時會自動複製native runtime。
- x64包有onnxruntime.dll 21,659,280bytes與DirectML.dll 18,700,224bytes；兩者entry壓縮合計16,874,426bytes。原始碼搜尋未直接使用onnx／DirectML／Windows.AI／MachineLearning APIs；這不能單獨證明SDK間接載入不需要它們，也不能把約16.9MB當成已驗證可減少量。
- 最小實驗A：只對Store評估Windows App SDK framework-dependent，.NET先維持self-contained，Portable保留自包含。Microsoft文件說明packaged framework dependencies可自動安裝；仍須驗證本專案宣告／版本／安裝與升級。
- 實驗A必改相依範圍：[Package-Store.ps1:59](../HeiBan.Windows/Packaging/Package-Store.ps1#L59)目前硬性要求Microsoft.ui.xaml.dll、coreclr.dll等內含。切換後要同步依部署模型核對manifest dependency／必要payload，不能為了build過把所有必要檔檢查拿掉。App啟動初始化、PRI、x64／ARM64、Store乾淨機安裝、舊資料升級都要驗收。
- 實驗B：核對需要的SDK component packages，評估可否避免聚合包引入不用功能。先查傳遞依賴與官方支援，再改參考；不是直接砍DLL。Microsoft ML文件的手動排除DirectML方式明示非正式支援且依賴內部布局，本批不建議作正式減重的第一條路。
- 暫不先開全域AOT／trimming：目前PublishAot=false，PublishTrimmed只在AOT=true才生效；DocumentSnapshot反射與泛型JSON有額外相容驗證成本。先做可量測的部署實驗；不因刪幾百行就承諾大幅縮包。
- 待驗收：兩架構package bytes及依賴下載／安裝大小分開記錄，檔案／PRI／locale／API入口完整，乾淨機初次啟動、離線／runtime缺少時行為、舊版升級與Store檢查。未執行。

## 現有應保留的設計與不採用的做法

保留：高頻採樣不進永久文件、即時呈現與240Hz最高提交節流（不等於保證螢幕240Hz）、增量wet ink、scene／幾何／文字快取、單筆Undo、原子保存、未知欄位／既有文件保護、Native overlay讀回buffer重用。沒有證據需換掉Win2D或改成純像素檔案；物件可編輯與跨平台契約是既有需求。

不新增繪圖框架／狀態管理框架；不硬合併SwapChain一般畫布與UpdateLayeredWindow螢幕顯示層；不移除資料校驗；不為了行數刪歷史文件／作品／已公布套件；不安裝外部技能覆寫AGENTS；不盲目加入GC.Collect或修改GC策略。

## 後續驗收計畫（本批均未執行）

沿用InputLatencyTrace／InputPresentationTrace／既有像素參考場景，不另造追蹤框架。在獨立作品庫記錄實機與OS、DPI、解析度、滑鼠採樣率／筆，空白／500／5000／20000物件、長筆畫、旋轉物件及大量圖片。比較pointer arrival→present CPU階段、UI阻塞P95、worker batch／queue長度、配置／GC、重畫與readback區域。Present時間不等於實際螢幕出光時間；必要時另量端到端。不得套用Ponytail或舊版本性能百分比。本批沒有測試授權需求，因為只交分析；日後實作依使用者範圍執行。

## 外部參考

1. [Ponytail核心規則（固定commit）](https://github.com/DietrichGebert/ponytail/blob/96608e078b2d5ea607c5c3b8b5a54d1c1fba6846/skills/ponytail/SKILL.md)：依既有元件優先、最小完整變更、保留邊界與失敗處理。
2. [Ponytail audit（固定commit）](https://github.com/DietrichGebert/ponytail/blob/96608e078b2d5ea607c5c3b8b5a54d1c1fba6846/skills/ponytail-audit/SKILL.md)：先映射、帶具體情境、分優先順序；本報告只將其當研究對象，沒有套用其中會與平台規則衝突的自動測試或永久模式指令。
3. [Microsoft Windows App SDK deployment overview](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/deploy-overview)：self-contained／framework-dependent、packaged dependency安裝與架構傳遞。
4. [Microsoft Install and deploy Windows ML](https://learn.microsoft.com/en-us/windows/ai/new-windows-ml/distributing-your-app)：ML三個runtime binary與部署模式，手動排除DirectML的非正式支援限制。

## 實際執行與未執行

已執行：git status／來源與平台規則讀取、GitHub connector讀外部repo／版本與技能文本、web查閱Microsoft官方文件；rg呼叫／依賴搜尋；graphify detect／AST serial extract／build／cluster／report／HTML／query及health檢查；Python zipfile中央目錄byte統計／SHA對照。工具失敗與限制如上。新圖譜、cost與工具暫存僅在.build，其他電腦不可假定存在。

未執行：產品程式修改、編譯、App啟動、性能採樣、自動測試、安裝／WACK、新封裝、刪檔、版號調升、Store提交、Ponytail安裝／hooks或修改其他平台。預期改善均為方案；沒有宣稱修好或提高特定百分比。

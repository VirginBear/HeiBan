# Windows 問題與排解紀錄

## 2026-10-22 — 使用者核准Store 1.0.16.0（封裝中）

舊1.0.15.0已存在，不能覆寫舊byte作更新。使用者明確確認1.0.16／1.0.16.0後同步三處版本，以新路徑建立正式提交包。前批功能／性能的實機未驗收事項仍依歷史紀錄保留；本批只做封裝資源核對，不把使用者「準備更新」補寫成完整測試報告。 [本批日誌](STORE_RELEASE_1.0.16_2026-10-22.zh-TW.md)。

## 2026-10-22 — 常用清除、圖示與圓形橡皮擦（x64試用完成，待實機）

使用者回報兩畫布圓形橡皮擦卡頓。確認每事件同步全掃與切割，screen並反覆重建／全螢幕CPU回讀。已將幾何計算移至順序worker並按16ms發批次，只在擦中時發布快照；尚未消除大型場景重畫與screen回讀本身的成本，未取得新版性能實測。圖形圖示差異確認為PathIcon填色／Create描邊路徑差異，改共用選單。 [本批日誌](ERASER_TOOLBAR_ALIGNMENT_2026-10-22.zh-TW.md)。

## 2026-10-22 — 工作列圖示粉色底板（x64試用完成，待實機）

症狀為工作列圓角Logo外粉色方框。排除來源PNG及目前portable EXE內圖示本身含粉色；已確認Store缺unplated targetsize資源，官方說明此缺漏會加系統底板。補資源並改善多DPI ICO；截圖通道、現場Shell快取及實際改善尚待使用者核對，不能僅由資源完整宣稱粉框已實機消失。 [本批日誌](TASKBAR_ICON_2026-10-22.zh-TW.md)。

## 2026-10-22 — 自由筆跨越舊筆跡凸凹（x64試用完成，待實機）

症狀：新筆跡跨舊筆跡突然凸凹、類似被吸引／排斥。確認磁鐵開啟且自由筆每個點都查舊筆跡索引並替換座標；非僅渲染延遲。兩畫布改幾何工具才吸附，自由筆保留原輸入、跳過索引查詢／建立。最新schema2心跳P95=50.548ms、max205.9376ms，仍有排程延遲，兩次負載不同不能作受控性能比較；修正效果待實機。 [本批日誌](FREEHAND_MAGNET_2026-10-22.zh-TW.md)。

## 2026-10-22 — 真實採樣、轉角與板擦卡頓（x64試用完成，待再採樣）

使用者補充矩形轉角與板擦筆畫增多特別卡。舊trace未含板擦且無GC pause數字，不能把93次GC2等同卡頓原因。已找到板擦同步熱路徑並改背景批次，畫筆尾段未變仍重建的成本也減少。尖角因果仍需新scope採樣；永久合併筆畫只減物件數，不能涵蓋單筆角落或輸入事件等待。 [本批日誌](ERASER_AND_INPUT_QUEUE_2026-10-22.zh-TW.md)。

## 2026-10-22 — 畫筆與工具切換停頓追查（x64試用完成，待實機採樣）

症狀：畫線途中、放開／下一筆及切工具均停頓。可確認程式成本已修，尚無GC pause／CPU／GPU百分比或端到端延遲數字可歸因。圖釘舊指南25個即使畫外仍每幀new format／DrawText，現在裁切與cache。主畫布仍CanvasControl XAML排程；螢幕畫布仍CPU GetPixelBytes回讀，記為未解架構限制。 [本批日誌](INK_LATENCY_2026-10-22.zh-TW.md)。

## 2026-10-22 — 常用工具與完整無邊界指南（x64試用完成，待實機）

前批範例只有三頁筆跡／圖形，未覆蓋工具且非無邊界；新生成器使用25章全部段落、工具catalog覆蓋契約與章節圖釘。舊範例可能經使用者修改，不直接覆寫，另建v2。手冊矛盾文字同步修正；初次搜尋萬用路徑rg error123與Python cp950顯示阿拉伯文失敗，改目錄-g與UTF-8。實作測試未執行。 [本批日誌](TOOLBAR_GUIDE_2026-10-22.zh-TW.md)。

## 2026-10-22 — 四項繪圖操作改善（x64試用完成，未進版）

工具列預設全開，完全未變更的舊精簡預設升級展開，自訂顯隱／順序保留；恢復預設亦全開。首次使用加入十語三頁可編輯「操作說明 · 工具練習」作品，以固定ID與marker避免重建或覆寫。畫筆／螢光筆／油漆筆刷完成不自動選取，V可選、雙擊開詳細。新增單物件ink Undo紀錄，減少逐筆全文件快照與UI刷新；主畫布可將新筆跡接入相同viewport的scene，其他操作完整重畫。板擦沿原斜長軸縮短20%、厚度／左高右低保持，hit path／擦面共用矩陣。十語指南同步，沿用1.0.15來源metadata的開發候選，不代表新正式進版或Store更新。中途x64 build 0warning0error／56.18秒；App、實作測試、性能與硬體驗收未執行。x64免安裝drawing-flow-2026-10-22-r1封裝成功，132641278bytes／SHA256 `1d2aa0b57ab90f6fcd75570d93b07930127b4343d4fe063afd158b2c38ee9f71`，583份payload與173份來源SHA核同、十語各三頁範例齊備。舊試用27檔／24344718bytes核同接續；清理舊runtime釋放455073499bytes，原資料另保留備份。等待使用者實機驗收。[本批日誌](DRAWING_FLOW_2026-10-22.zh-TW.md)。

## 2026-10-15 — 商店套件完成與隱私文字更新

商店包`dist/store/HeiBan-Store-1.0.15.0-x64-arm64.msixbundle`已完成，195664137bytes／SHA256 `a889482ff3aa171569ce415fc285340b26742528af4306a3e0a0e3d6fa07eb96`；來源`ceed5f96a7241a9561380b4f3cfb596718fba317`。x64／ARM64分別61.69／51.11秒，均0warning／0error。218來源SHA、ZIP CRC、身分／架構、十語手冊與板擦資源核同；原12份Store套件SHA不變。使用者接手Partner Center，助手未上傳／送審／發布。本批App／實作測試／WACK未執行。 隱私文字已更新，明列本機轉換及PDF／HTML保留完整原稿（含其他頁面、隱藏物件）；目前畫面／選取匯出範圍不限制內嵌原稿，僅分享可見內容請用PNG。沒有改動既有匯出格式。

## 2026-10-15 — 使用者核准本系列商店更新（1.0.15.0封裝中）

使用者試用後明確指示再次更新Microsoft Store，採下一未使用版號1.0.15／1.0.15.0；同時更新App、manifest與StoreIdentity，保留歷史候選與上架包。包含本系列繪圖／磁鐵／PDF與PowerPoint圖片頁交換、工具列及原創鏡像板擦、十語UI／手冊與自動存檔設定。Package-Store增加FormalVersionApproved記錄旗標，預設仍未核准；本次不另增功能、不改作品格式。實作測試未執行；使用者同意更新不等於Microsoft認證通過，實際提交狀態另記。[本批日誌](STORE_RELEASE_2026-10-15.zh-TW.md)。

## 2026-10-15 — 更多板擦入口與左高右低鏡像（封裝中）

工具列更多新增「顯示板擦」勾選項，保存偏好、失敗還原；右鍵隱藏共用保存入口。保留原創PNG，僅Image中心ScaleX=-1呈現左高右低；共用12點輪廓x→1-x，抓取／提示／擦除同步。十語手冊重新產生25章62段，版本仍1.0.14候選。未執行App／實作測試，待使用者實測。[本批日誌](BOARD_ERASER_ENTRY_MIRROR_2026-10-15.zh-TW.md)。

## 2026-10-15 — 板擦透視方向不符磁吸板面

症狀：前批露出側壁與felt側層，看起來是商品圖。原因可確認為生成採斜角商品視角，並以偏移底面校準擦除。使用者要求應垂直看向板面。改以嚴格俯視原創透明圖，移除透視偏移與分離抓取面，12點alpha凸輪廓共用抓取／提示／擦除；圖片本身平面斜放，不追加旋轉。十語手冊已同步；實際擦拭、取消、Undo及4K觸點仍待使用者驗收。前批嘗試與提示保留歷史。[本批紀錄](TOP_DOWN_BOARD_ERASER_2026-10-15.zh-TW.md)。

## 2026-10-15 — 斜角板擦與水平擦除範圍不符

原木質板擦與132×40軸向矩形不適用於斜視角設計。改凸接觸面裁切，同一輪廓畫提示與轉world擦除；握柄偏移保持，透明角落不觸發。第一張依照片造型生成後，使用者要求更原創，改未附圖片的新文字生成；所有第一張校準參數均由最終紙白／霧綠圖覆寫。最終PNG外部RGB有灰值但alpha0，Runtime透明；只讀alpha校準抓取輪廓，沒有用Python處理圖像。中途編譯成功不作最終材質驗收，詳細命令／結果見斜角板擦日誌。

## 2026-10-15 — 兩排工具、部分磁鐵與系統色混入

圖文區RunLength硬限540 DIP，所以4K亦換行；改依工作區計算單行容量與箭頭分組，窄視窗不刪工具。磁鐵矩形原僅四角、無中點／中心，圓首點其實為外框角而不在圓上；加入幾何參考及兩宿主中心拖曳，不把原已存在的pointer-down snap誤記為完全未接線。首點實際操作仍待使用者驗收。

r1 build兩處Windows.UI.Text.FontWeights CS0234造成其餘XAML連鎖錯誤；改Microsoft.UI.Text後r2成功0warning／0error。實際UI發現CheckBox靜態主題別名仍用系統紫色，查本機SDK generic.xaml補控制項語意brush；r3亦0warning／0error，最終顏色及混合DPI待實測。後續截圖回傳內容與目標視窗不符，未保存、未操作背景視窗、未當新手冊圖；保留前批四圖並註記排版以目前程式為準。完整失敗／限制見本批日誌。

## 2026-10-15 — 繪圖流程、三角形預覽及巢狀工具列排解

主畫布線／形狀提交會明寫切回select，selected一出現就建立快速列；改持續繪圖及明確雙擊ID開詳細。三角形暫態同時誤用CurvePreview及平滑筆跡renderer，兩層均改成多邊形折線，永久物件格式不變。

新增labels後主示範啟動出現WinUI fail-fast（0xc000027b）；隔離UnhandledException記錄0x800F1000定位SizeChanged內重掛Select。只改Parent查詢仍失敗，加入呈現快取與重入守護，尺寸事件只量測後解決。screen四邊原生檢查再揭露清根後巢狀按鈕尚屬舊面板，以及工具無Tag被分組為palette；改清根前拆下所有工具、補Tag後，四邊labels／三點三角形／連續矩形／磁鐵原生檢查全過。舊錯誤檔保留，最終結果另有時間與screen欄位可區分。磁鐵、PDF圖片頁、Office需求與未驗收邊界見[本批日誌](DRAWING_WORKFLOW_2026-10-15.zh-TW.md)。

## 2026-10-13 — 試用封裝腳本的PowerShell 5.1解析差異（已繞過）

症狀：以Windows PowerShell 5.1呼叫`Package-PortableTrial.ps1`時，`git ls-files`路徑規格中的單引號萬用字元造成ParserError。原因可定位為該腳本語法在目前PowerShell 5.1 parser下不相容。當次命令在腳本開始前中止，沒有寫入試用輸出；改以PowerShell 7執行同一工作區腳本後，試用包成功產生。此紀錄保留相容性症狀，尚未修改腳本或承諾Windows PowerShell 5.1支援。

## 2026-10-13 — Windows 畫布選取物件後按 Delete／Backspace 無法刪除（已修復並更新本機 x64 測試版）

症狀：使用者於 Windows 本機測試時發現選取畫布物件後按 `Delete` 無法刪除，且懷疑與 Mac 鍵盤設計差異有關。
確認原因：
1. **WinUI 3 焦點鏈與輸入框焦點殘留**：`MainWindow.xaml` 的 `CanvasSurface`（`CanvasControl`）原設 `IsTabStop="False"` 且 `CanvasSurface_PointerPressed` 設 `e.Handled = true`。當開啟作品隱藏 `HomePanel` 或重繪 `SelectionBarTools` 時，WinUI 3 將焦點移至 `Root` 外層的內部 `RootScrollViewer`，導致鍵盤 `KeyDown` 事件未經過 `<Grid x:Name="Root" KeyDown="Root_KeyDown">`；此外若先點擊過 `Inspector` 的 `NumberBox`／`TextBox` 再點畫布選取物件，焦點仍留在輸入框而被 `e.OriginalSource is TextBox or NumberBox` 擋下。
2. **Mac 鍵盤與筆電 `Delete`／`Backspace` 鍵碼差異**：Mac 鍵盤上的 `Delete` 鍵在 Windows 送出的是 `VirtualKey.Back`（`Backspace`），而 `Root_KeyDown` 原僅判斷 `VirtualKey.Delete`。
3. **螢幕畫布未綁定鍵盤刪除**：`ScreenAnnotationWindow` 僅右鍵選單提供刪除，未註冊 `KeyDown` 處理 `Delete`／`Back`。
排解：`CanvasSurface` 啟用 `IsTabStop="True" UseSystemFocusVisuals="False"` 並在點擊畫布、開啟作品、結束文字／圖釘編輯及工具列操作時呼叫 `FocusCanvasSurface()`；`Root.Loaded` 將 `Root_KeyDown` 同步掛載於外層 `RootScrollViewer`；主畫布與螢幕畫布同時支援 `VirtualKey.Delete` 與 `VirtualKey.Back`（排除文字編輯狀態）。Core 2325 項測試與 x64 Release publish 通過，已更新本機 x64 測試執行檔。

## 2026-10-13 — screen補上停筆一秒轉直線（來源接線、待驗收）

主畫布已有近直線幾何辨識與停筆計時，screen原本只保留自由筆跡。新增Core共用近直線判定，screen在持筆期間每100ms觀察native overlay點列；最後一次超過12 DIP的移動後，符合長度／彎曲容差且停住滿一秒才將活動預覽端點化，放開後才提交一筆line物件。取消、完成與Dispose停timer。未build／測試／實機，DPI、滑鼠與筆裝置結果尚待驗證；尺規／圖片匯入／圓規等差異仍在。

## 2026-10-13 — 工具列來源清單重複與screen焦點每幀輪詢已整理（待實機）

先前screen工具名稱／按鍵另存於`ToolbarUi.ScreenTools`，實際能力再存於`ScreenToolbarSupported`，容易在兩份清單改漏；現已移除screen視窗私有能力清單，改由Core policy投影一般工具catalog並只暴露已接handler項目。screen填色按鈕原固定佔用一格，現放入「圖形」選單，十語手冊已同步。渲染timer原16ms取樣前景視窗，焦點恢復改250ms獨立timer並在切換／離開時同步取樣。

未解：screen功能集合仍少於一般畫布；尺／圖片／圓規／計算機／計時器等差異仍存在。套索、便條紙、膠帶與停筆轉直線已接線但未驗收。Core／renderer包體仍未變；Store MSIX的ML／AI載荷雖已靜態確認存在，但刪除相依會改SDK／native runtime，未經同來源package與功能回歸驗證，故未排除。未build或實機，以上源碼行為待編譯及使用者測試確認。[本批日誌](WINDOWS_OPTIMIZATION_BATCH_2026-10-13.zh-TW.md)。

## 2026-10-13 — 工具列差距：第一批已修正共用設定與形狀入口，主問題仍開啟

使用者授權開始WT工作後，screen開始載入一般`toolbar.json`，`ToolbarContentPolicy`共用順序／顯隱並排除pins／viewLock；screen自訂選單只列已具handler的共同工具。四個獨立形狀按鈕改成九種形狀選單，screen preview／fill支援多邊形。這處理了工具次序來源、部分工具重複UI，以及多邊形無入口的明確原因。

尚未解決：screen沒有主畫布的尺規、貼紙與圖片匯入、圓規、計算機／計時器、完整手勢（含自由套索及停筆轉直線），面板也不是同一實作；主工具列可見而screen不支援的項目仍要以能力矩陣完成，不得只新增圖示。來源目前沒有build／測試授權，因此編譯與操作結果未知。追蹤[第一批日誌](TOOLBAR_ALIGNMENT_2026-10-13.zh-TW.md)與[原始差異規格](TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)。

## 2026-10-13 — screen工具清單與一般畫布差距

使用者指出只應差圖釘／zoom。確認原因：一般ToolbarPreferences動態完整catalog與形狀選單，screen仍11工具硬編碼及独立brush／layers／更多；OnPointer只建4種基本形狀，未接一般尺／圓規／多種命令與停筆直線。共同renderer／EditorSession及button factory不等於完整操作共用。

本批只調查與列WT-01–04，問題尚未修復／驗收。只複製圖示不足，需共用能力描述／session命令、native adapter及設定；跨DPI／多螢幕／文字／Undo待驗收。搜尋大.build耗時中止，猜不存在partial檔名改rg --files，字面萬用路徑os123改目录／-g，README標題錯使整批patch未套用後依真標題重做。詳[日誌](TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)。

## 2026-10-13 — 免安裝包體分析不可直接當Store減重結論

症狀：先前通用分析以Updater82.83MB作優先候選，但使用者實際關心Store。原因：混用Portable與MSIX發行管道；Store腳本與原payloadChecks已排除Updater，優化helper新增商店節省0MB。更正：在減重報告分開比較主App相依與官網更新程式，Portable ML載荷僅作參考，不當MSIX確定減少量；待Windows端以同來源兩CPU成品拆解核對。

最新Store使用guides候選95.55MB／98.12MB（原機JSON），不沿用稍早95.45MB批次或把193.68MB雙架構bundle當用戶下載量。詳[報告](WINDOWS_SIZE_REDUCTION_PLAN_2026-10-13.zh-TW.md)。本批沒有新的App故障重現或減重修復，不以文檔完成標示元件已移除。

## 2026-10-12 — 手冊單語／過時內容／兩個開啟入口

首頁LaunchUri與作品LaunchFile各硬編碼正體中文HTML；十語介面仍開中文且label標正體中文。舊開始章一律auto-save與screen固定尺寸／scroll說明已過時。改共用LaunchFile、current language路徑及fallback，重新編排十語操作契約，修正相關說明。原HTML單行使初讀輸出截斷；Python -c嵌套引號SyntaxError未改文件，改存HTMLParser脚本讀段落退出0。沒有App／母語／RTL操作驗收；詳MULTILINGUAL_GUIDE日誌。Store同版防覆寫阻礙開發包，新增label隔離，不改版本規則。

## 2026-10-12 — 正式版號增加過早

症狀：未完成整系列開發及實機／回歸驗證，就先後建立1.0.13、1.0.14。可確認原因：助手將「希望盡快更新」及封裝成功解讀為進版授權，混淆開發候選與正式發行時點。使用者更正後採批次標籤／commit追蹤，正式进版由使用者在整批驗證後決定；候選包撤回立即上傳建議但保留原檔／SHA與歷史。未靠回寫artifact或刪檔掩蓋錯誤，沒有Store發布動作。規則已加入平台AGENTS／DECISIONS／私人交接；本批沒有新測試結果。

## 2026-10-12 — 保存模式與退出回饋

主每15秒／screen修改停止1秒後保存沒有用戶開關；snapshot與縮圖有同步UI負荷，存檔本身與IO在worker，但不能因此保證無卡頓。新增auto-save=false政策及各timer守護，關閉途中不取消已開始的原子保存。新增關閉ProgressRing及失败保留，补匯入前保存舊作品。Frame動畫仍需實機查看，文件Clone一致snapshot仍在UI線程。

r1 x64退出1、26.73秒、1warning／93errors；兩Grid.IsEnabled CS1061是根因，其餘大量Ui.Text／Ui.Tooltip是assembly未產生的連鎖XAML錯誤。改ContentControl輸入容器，r2退出0、31.31秒、0warning／0error。apply_patch半行匹配失败、遷移substring count2拒絕、Python stdout cp950乱碼與調查錯檔名皆記阶段日誌；不是App或測試失敗。尚無動畫／強制關閉／磁碟失敗／混合DPI驗收。

## 2026-10-12 — 重複chrome與高頻儲存圖示配置

工具列介面建立分兩宿主，同一畫圖Core／renderer類別共用，另NativeOverlay為螢幕穿透需求。重複button label／line menu／RTL政策改共同factory；生命周期仍保留，防止不同資料／座標混用。InvalidateCanvas每次重建SaveStatusDot控制項的原因由源碼可確認，已用state／tooltip比對抑制；實際FPS改善未量測。

graphify hidden .build corpus偵測0檔、root無graph的query --help報錯、StoreIdentity調查路徑寫錯皆已修正調查方式。graphify自動在源碼目录產生cache，確認是本批產生、無資源註冊引用後移入ignored .build；原碼及歴史不刪。詳細命令／編譯與封裝結果见階段日誌。

最終r2 x64 Release build：退出0、0警告／0錯誤、28.23秒；十份完整資源嵌入DLL、literal來源鍵無缺項為靜態檢視，非App／測試驗收。最後文字屬性展示补強由新Portable publish重新編譯，封裝證據另記。

## 2026-10-11 — 多語言建置與尚未驗收

第二輪build 17.61秒退出1、1warning／89errors：兩個MenuFlyout.FlowDirection CS1061阻斷生成assembly，連鎖XAML pass2 WMC1509／Ui附加屬性unknown及WMC9999。改MenuFlyoutPresenterStyle Setter（實際有FlowDirection的是Presenter／FrameworkElement）；不刪Ui服務來掩蓋症狀。首次53.04秒0warning／0error是修RTL前來源，後續結果另記[日誌](LOCALIZATION_2026-10-11.zh-TW.md)。

資源stdout cp950遇⋯編碼錯，生成器改UTF-8輸出；PowerShell字面萬用路徑rg及錯Common檔名調查失敗改目錄-g／Publish-Common。原生框架可能快取語言，系统檔案挑選器和低層例外保留來源語言；尚缺App實機切換／重啟／窄視窗／RTL及母語校閱，本輪不跑測試。

## 2026-10-11 — 一般畫布游標未生效、尺寸與背景選項缺漏

使用者實測一般畫布游標未生效而螢幕有效；前一輪native SetCursor／WM_SETCURSOR不能當已驗收主畫布方式。調查官方WinUI ProtectedCursor與SDK HCURSOR interop，改Canvas父容器XAML游標。原因為不同游標擁有層的推論，未做本輪runtime追蹤；硬體操作待驗收。

新建尺寸固定顯示且index0，導致infinite出現無意義尺寸、fixed預設A4。改模式顯隱與各類預設記憶；背景renderer與SVG有grid／dots／lines／staff，但Background_Click只有ChooseColor，故補共用樣式選單／transaction／epoch守護。首次build 0warning／0error，最終x64 build 0warning／0error、25.98秒，詳見阶段日誌。

盤點5份舊試用解壓目錄，其中3份已有Data，不能直接刪整包。新包封裝完成後先保留Data／未知或改動檔，確認來源範圍與正式發行排除後再刪舊runtime，清理明細另記。沒有讀取或公開作品內容。


## 2026-10-11 — 捲軸、拖曳缺乏視覺回饋與游標

使用者實際回饋：螢幕控制列捲軸、圖層只有放開閃動、形狀控制點沒有方向、粗線箭頭頭部過細、主工具列缺圖層。確認原因是中段 ScrollViewer Auto、拖曳只有文字提示、沒有 control-handle cursor 路徑、頭部硬編碼 2、layers 未納入可見工具設定。

實作換行面板、拖曳浮層與插入線、共享系統／自製游標、原生／SVG 線寬同步及工具列入口；第一次編譯 0 warning／0 error。後續靜態補 WinUI WM_SETCURSOR、取消清理與虛擬化列一致性；最終建置 0 warning／0 error、25.80 秒，詳見階段日誌。路徑讀取錯誤與工具呼叫語法錯誤未影響資料，已更正。沒有本批測試／App／實機 UI 驗收。


## 2026-10-11 — 首頁單擊、固定檢查器與工具列尺寸

症狀與確認原因：首頁 Extended 加「selectedCount > 0」顯示批次列，讓單擊進入批次操作感；Inspector 固定 XAML 同時包含工具與圖層；箭頭 fallback 尺寸依 strokeWidth 放大；螢幕工具列固定尺寸塞不下新增控制項。

排解：一般 Single／顯式 Multiple、依物件區塊顯示與獨立圖層、固定頭部預設且尺寸 slider、內容 Measure／DPI／工作區限制。腳本 XAML 第一段界線匹配到內層 Grid，尚未寫 XAML 即失敗；修精確外層邊界後續作。首次編譯未用舊尺長欄位警告，移除並重新 build。未執行實機 UI／DPI／拖曳測試，驗收缺口與逐項入口保存在[日誌](UX_ALIGNMENT_2026-10-11.zh-TW.md)。

初份 ux20 封裝後靜態排列檢查確認同側面板可能遮工具列；追加 margin 留白／可用高度重算，按 r2 新Label重新publish，不覆寫初份。r2 log 無warning/error，557 inventory／103 source hash 靜態核對及Store保全完成。沒有將封裝完成宣稱實體 UI 已驗收。

## 2026-10-11 — Trial封裝sidecar防覆寫條件

新wrapper第一包完成後，靜態檢視發現PowerShell`@($payload,$zip,$zip+'.sha256')`會拆出額外.sha256項，未正確守衛既存sidecar；payload／ZIP guard有效，未覆寫舊產物，也不影響App。改`($zip+'.sha256')`，新r2 Label重新publish／壓縮，兩包／log保留；最終557 entry SHA／93 source／空Data／PE／版本靜態核對通過。沒有因紀錄要求自行跑App測試，初包是歷史候選、最終交付r2。

## 2026-10-11 — 候選有效性成本／編譯失敗

初次grid九欄record比對10000 p95約0.51→1.28ms，候選77個並未保證收益；明確欄位／增量更新只小幅改善，改非序列化bounds counter後acceptance0.36124→0.07980ms。explore全保留；相等setter吞signed-zero由靜態檢視抓到，改保存value、只對不等值增counter。

native foreach三元式的OrderedBoardObjects與IOrderedEnumerable無共同推斷型別，CS0173導致次生Xaml WMC9999；改顯式IEnumerable。失敗沒有native結果，後續x64／ARM64無warning/error及127 strict pixels通過。完整scene平移重跑有更慢結果，原因未確認；PERF05／busy profile待開發，不把波動歸因特定GPU／timer。

## 2026-10-10 — 流暢度基準的實際失敗與未解項

初CPU fixture的空心rect中心不是hit，修成填色與可命中點後重測，錯誤樣本獨立保留。原生舊binary先後兩次在overlay rect收筆strict比對失敗：272 byte最大差1、首點(1504,898)的R channel1→0；主畫布階段先寫獨立JSON，不能因process exit0稱全驗證通過。改DrawImage copy為同device／BGRA／96DPI的CopyPixelsFromBitmap區域複製後嚴格形狀／筆／選取等通過，未放寬容差。[證據](performance/2026-10-10-batch1/README.zh-TW.md)。

Core新增test漏傳Hit tolerance造成CS7036，補8後754項通過。熱路徑兩個capturing lambda即使候選早退也分配closure，改為局部for／四邊短路；零rotation命中避免新center與point。原生大量物件重建p95仍高且跨run波動，不能將所有症狀歸因排序；04／05待後續。真筆、混合DPI、device lost、ARM64原生與MSIX／WACK未驗收。讀錯來源路徑與PowerShell for直接pipe的錯誤／修正保存在本批日誌。

## 2026-10-10 — Partner Center 無法提交的階段已解除

前次使用者概觀截圖中套件已 Validated，屬性／清單／提交選項顯示完成，價格與年齡分級未顯示完成；建議重新進入檢查儲存與產生分級。無法只凭截圖斷言所有具體欄位的錯誤原因。此次使用者貼出「Submission 1：認證中」，確認依使用者資料提交階段已往前進。尚未確認通過與上架，也未登入後台；認證若失敗，依後續報告另記原因，不預先猜測。

## 2026-10-10 — 公開來源沒有對應私人管理庫

使用者需要跨電腦讀取私人產品記錄；主庫 API 顯示 PUBLIC，現有私人清單無 HeiBan 相關庫，指定新庫查詢回 repository not found，這是建立前的正常確認。另建立 PRIVATE HeiBan-private；確認 visibility 後才 push管理文件，並以 ls-remote 核本地／遠端。沒有把公開資料夾當作私人位置，也沒有搬入作品或密鑰。後續讀取需要相同帳號／協作者權限，不能因登入公開庫就宣稱具有私人庫權限。

## 2026-10-10 — MSIX 封裝調查

正式 Store 身分已取得，前批待提供問題解除。初次 MSIX SDK build 成功，但授權檔版本點號被當 PRI qualifier（17 個含 README），另缺 mspdbcmf（1 個 symbol 警告）。不把該 build 稱為無警告。README 以純檔名連結、封裝 CLI 關閉除錯 symbols；第一次以原始路徑排除 PRI 沒命中 SDK layout，改按 PackagingOutputs TargetPath 暫時排除純文件再還原。Package-Store 字串 `$arch:` 語法錯誤修正 `${arch}`；外層純 PowerShell 不能依未設定 LASTEXITCODE 推定成功。調查／最後結果見當批日誌，保留初包與過程證據。

最後有效方案直接過濾 SDK 生成的 PRI resfile 文件行，Content payload 不變；兩架構各 0 warnings／0 errors，25 授權完整原 byte。SDK 曾將模板 19041 覆寫為專案 17763，Store build 顯式 TargetPlatformMinVersion=19041 並加包內 guard，最後实际包確認 19041。未執行商店安裝／資料移轉／解除安裝、ARM64 原生與 WACK，因此仍是送審前待驗收項，不預先稱審核通過。

## 2026-10-10 — Store 正式身分尚待提供

使用者已申辦 Partner Center，但目前只有後台網址，未取得產品套件身分。網址不能確認驗證／名稱預留／產品存在；已請使用者從 Product identity 提供三個 manifest 欄位及保留名稱。等待期間完成官方規則調查、商店準備紀錄與上一批來源同步；不使用假的 CN 或把 package identity 偵測當作 MSIX 成品。資料遷移／解除安裝保留及 runFullTrust 送審尚需實際封裝驗收。搜尋曾包含不存在的 Services 目錄，記下 rg 路徑錯誤而未推測該目錄架構。

## 2026-10-10 — 自動更新實作／驗證

主機缺 .NET SDK，`dotnet --info` 僅 .NET 8 runtime；官方腳本隔離安裝 10.0.401 後 WinUI 建置可用。合併工具下載／啟動命令自動審查拒絕；分步下載、核官方 Authenticode 再以隔離位置安裝成功。Inno 官方繁體翻譯缺 23 新訊息、有 3 過期 key；初包使用英文 fallback 並 warning，保存補齊／清理後的翻譯隨 Packaging 發行。詳見本批日誌，不隱藏初次 warning。

更新測試先抓到 regex `$` 接受結尾換行，改 `\A`／`\z`；第二次中斷來自測試以 IOException 代替實際 InvalidDataException，補正測試捕捉範圍。69 檢查通過後，追加 PE／待更新架構共 73 檢查通過。

稽核確認 preview.6 FileVersion .6 大於 stable .0，僅數字判斷會跳過正式版；改看 ProductVersion 的語意版本，隔離實際 helper 的 preview → stable 通過。另稽核 helper 起動可能早於 App 釋放交接鎖，補短期重試；安裝架構遷移時 cache 可能仍有旧 pending，交接及 PE 再核架構。後兩項不是聲稱已有使用者遇到的實測故障；以隔離 fixture 補驗證。

Portable ordinary failure rollback、父程序退出後更新、其他視窗存在延後、Data hash／未知檔保全、損壞包拒絕、獨立 Inno 安裝／升級／測試註冊移除通過。真 GitHub 新 Release、ARM64 執行、完整硬體／商店／停電恢復未驗收；不以 synthetic 或 x64 smoke 替代。

## 2026-10-10 — 公開封裝／GitHub發布

首輪新手冊比對KeyError，ZIP使用Windows反斜線而查詢用斜線，已正規化entry索引及安全路徑；重跑保留原entry／EXE逐byte、PE／手冊／無Data檢查通過。draft target使用短SHA回422，改完整commit後成功；draft尚無公開tag endpoint回404，透過release清單／ID核對，publish後tag endpoint正常。新版7assets遠端digest／size及公開HTTP200後才刪舊5下載，源與舊歷史文本保留。


## 2026-10-10 — preview.5：右鍵阻斷物件選單

症狀是螢幕右鍵直接變「操作」，無法就地調整／複製／刪除。確認Objects.ScreenRightClick直接SetDrawing(false)，源於preview.4當時要求，並非命中或剪貼簿失效。依最新指示改命中物件ShowChromeFlyout，空白不切模式；保留工具列與快捷模式入口。原生驗證走實際OnPointer(right)，確認可用複製／刪除、多選文字保持、選取不新增Undo；驗證結果另記本輪報告。


right12p5-native的result／screen-result同輪success，實際路由／可用選單、多選保持與無新增Undo通過，四包安全交付Current1.0.12.5。CUA右鍵／普通工具列點擊均未可靠反映狀態，不當作實體驗收；保留此限制，不推定是新右鍵邏輯錯誤。

## 2026-10-10 — preview.4 螢幕物件與續編輯

色圓／dash只改預設、Capturecallback寫主作品、右鍵先攔成物件選單，已依最新使用要求改為選取物件編輯／截圖留screen／右鍵直接穿透；更多保留物件操作。首頁原None＋ItemClick，缺直覺選取；改Extended／Multiple、DoubleTapped及批次垃圾桶。

r1填滿Undo檢查讀Selected，但Core Restore會清選取，native helper保留仍存在ID後修正。r2大曲線局部畫面失敗，down從舊選取改空白時沒有清舊框的damage，已補；舊大曲線測試座標非實際曲線，改端點並assert不是marquee。r3全套通過，失敗證據保留。CUA click回-10005 noWindowsAvailable，未宣稱硬體點擊通過。

最終36預覽／收筆畫面逐byte相等；圖形／框選傳輸減少99.13%，原生同步中位24.7323→1.824ms；不是硬體端到端延遲，完整實機仍待驗收。

## 2026-10-10 — 1.0.12-preview.3 操作問題

確認的原因：Wheel普通分支平移；普通select缺marquee；螢幕框選固定Intersects；多點曲線hover漏Invalidate；ActivateTool載入工具舊色／dash；樣式圖示固定dash；PathIcon open path樣本不可見；模式圖示沒明確尺寸／中段center量測；截圖只畫白框；換工具重複Cancel／native模式更新；快捷列signature未含model引用且不更新樣式。已按本輪稽核修正。

原生兩次色圓檢查失敗closed，Activate單獨未解決；測試先讓連續關閉窗口的焦點事件完成再開面板後r3／r4success，保留兩個失敗result。CUA同時兩個版本時一次點擊沒有可靠反應，沒有把它算作硬體驗收。最終Core680、ARM64原生與PDF strict通過；首輪包因收尾新增修正不能部署，重封最終76來源。完整硬體／x64實機／Installer升級仍待驗收。

## 2026-10-10 — 整體操作卡頓

- 部署核對首輪未指定--current-user，以SYSTEM執行GetFolderPath(Desktop)為空，Join-Path退出1；已完成的payload核對不可視為捷徑檢查通過。改當前使用者重跑，版本／唯一程序／捷徑與549payload逐SHA全部通過。

- 第一輪封裝開始後才更新README，ARM64 Portable內說明仍p1；增加包內README逐byteassert後失敗，未部署。從同71檔來源以既有Portable腳本重封ARM64，重新核對四包。此檔時序不影響程式／HTML手冊版本；不直接略過驗證。
- Selected getter每個物件predicate又讀SelectedId，反覆搜尋整份文件；改單次PageObjects搜尋，100次／600物件461.2657→0.6635ms。
- 每次hover重繪整scene／文字重新排版；拆GPU committed scene與暫態overlay，文字style／span快取；300物件原生中位24.6737→1.0815ms，9畫面byte一致。
- 長筆跡拖動每事件逐點JSON clone／serialize；改preview位移，收筆一次提交；40事件2,000點92.7712→0.0142ms，commit0.633ms。壓力／傾角／未知欄位／Undo保持。
- autosave可在手勢與切文件間完成，revision也可能造成假Undo；DocumentEpoch／generation守護，transaction跟隨revision；screen timer避開draft／gesture。縮圖writer序列、舊revision跳過避免舊圖覆新。
- 偏好滑桿頻繁落盤、垃圾桶同文件兩次decode；400ms合併／worker落盤、一次讀metadata／舊垃圾桶對話讀取worker。
- 新screen performance helper少Engine using：CS0103 ObjectHandles未找到，衍生WMC1509／9999；補命名空間，最後ARM64 publish成功。驗證強制top／expanded，不依QA持久偏好猜初始尺寸。
- 第一輪快取P95 27.0384ms，最終1.6779ms，VM變異尚存在；完整硬體／IME／多螢幕仍未完成。見本輪性能稽核及原始JSON。


## 2026-10-10 — 1.0.12 介面與文字修正

- 左右工具列即使要求64 DIP，原生結果仍262px（200%）。只設定PreferredMinimumWidth／Height=1未解決；先收緊檢查以免誤報。SetWindowPos加入SWP_NOSENDCHANGING避免caption追蹤寬度干預，最後實測128×1376px通過；保留失敗JSON文字紀錄。
- 導入Shapes造成Path歧義CS0104，並衍生XAML WMC1509／9999；改Ellipse單一別名後原生編譯成功。
- 草稿右鍵開面板會轉移焦點，LostFocus提交會使面板修改丟失；取消LostFocus自動提交，改由明確完成或硬操作提交。新文字完成前不進文件，Esc取消不增加永久物件。
- 只選取未拖動也呼叫MoveSelection，更新UpdatedAt並建立無效Undo；只在座標改變時移動。原生Shift雙文字選取／右鍵保留兩物件／選取不加Undo／批次樣式Undo通過。

## 2026-10-10 — 本輪原生排解與驗證界線

| 症狀 | 原因／嘗試 | 修正／證據 |
| --- | --- | --- |
| 圖層名稱像亂碼 | 原本直接顯示UUID／英文type並拆展示字串找ID | typed layer row＋中文類型／內容／Name；Core與原生資料結果核對 |
| 原生第一次建置失敗 | LoadCursor缺PInvoke | 補Win32宣告後成功；首次失敗log保留 |
| PDF程式編譯失敗 | WinRT投影屬性為ShouldPrintBackgrounds | 改正複數名後原生編譯成功 |
| RichText／preferences新檔編譯問題 | TextDocument命名空間及多個屬性以逗號宣告不合法；Validation缺Models using | 分別修正，最終ARM64／x64建置通過 |
| PDF能由Poppler開卻strict parser失敗 | 原稿raw尾記在%%EOF之後，末尾不再合法 | incremental stream/xref；pypdf strict解析、中文字／向量及原稿4物件通過 |
| SVG底線未呈現 | text-decoration寫成underline none，CSS不合法 | 只組成有效decoration tokens；原生PDF視覺確認底線 |
| 高DPI螢幕控制列可能裁切 | AppWindow.Resize收實體像素，原數字當DIP | width/height乘DPI，3024×1822桌面控制列已查看 |
| prlctl -File／偶發exec失敗 | 引號或工具Invalid argument；直接傳字串不可靠 | UTF-16LE EncodedCommand及UTF8 BOM腳本；備份exec一次重試成功 |
| 模式切換後控制列可能被透明輸入層覆蓋 | SetWindowPos重新提升TOPMOST | SWP_NOZORDER保持順序，追加原生HWND次序檢查 |
| 螢幕工具列太大、空白太多 | 初版固定1080×210 DIP、標題／大文字按鈕／狀態各佔一列 | 依使用者Mac對照改680×80 DIP兩排，可收成680×48；另存／設定／手冊／清除收更多，原生1360×160px／收合1360×96px確認，淺色半透明外觀已查看 |
| 螢幕作畫不順 | 全桌面22MB讀回／複製，33ms排程，未落筆hover仍重繪 | committed快取、局部讀回／DIB／dirty rect、16ms與訊息座標；80樣本35.62ms→0.83ms；18組像素等價與雷射消退通過 |
| 縮小控制列後設定面板放不下 | ContentDialog限制在80 DIP root | 改不限制root的Flyout；原生IsConstrainedToRootBounds=false通過 |
| 工具列背景灰暗 | Window預設dark，只有內層light | 最外層Border RequestedTheme.Light，淺色Acrylic背景；實際查看文字對比 |
| 右鍵取消作畫後無法操作既有註記 | 舊路徑無條件切穿透 | 命中物件則保留作畫並開相容複製／副本／刪除／鎖定／層級選單；native命中與交易／Undo通過 |
| 全清除需進更多與確認 | 舊Clear ContentDialog | 主列垃圾桶及Ctrl+Alt+K立即清空所有物件／雷射，一筆Undo；native清空與ID完整復原通過 |
| 首頁多選切換COMException 0x8000FFFF | None selection mode的SelectedItems為不可修改collection | 只在Multiple／Extended時Clear，再切mode；原生收藏與全選／退多選通過 |
| 備份雜湊報missing但host檔案存在 | PowerShell5.1的Resolve-Path受MAX_PATH限制，UNC垃圾桶最長>260 | 最短備份名vm/c1；32個檔案逐SHA驗證成功，原Current未替換前不刪除 |
| Parallels點擊沒有觸發按鈕 | CUA只得到外層AX且截圖只看到hover，原因未確認 | 不把CUA嘗試當全互動驗收；隔離合成fixture呼叫真實native APIs，手動硬體試用仍待 |

包裝log由Windows PowerShell5.1 Tee-Object以UTF-16寫出，收尾轉UTF-8便於閱讀。失敗與舊文字紀錄留在build-logs/archive-before-1.0.8；不含使用者作品正文。

## 先前紀錄（歷史）


## 2026-10-09 — 螢幕畫布手冊超前來源

核對MainWindow與Engine未發現透明螢幕session、視窗與入口，手冊第18節卻宣稱能從右上＋選單開啟。已將來源手冊改為preview.5尚未提供、列明規劃入口與普通截圖第16節；W-S01新增首頁／導覽／更多入口與無作品啟動流程。既有發行包沒有重封，包內舊手冊待下次封裝更新。


## 2026-10-09 preview.5 修復與原生建置

| 問題 | 原因 | 本輪結果 |
| --- | --- | --- |
| 截圖可能貼入其他程式的圖片 | 全域剪貼簿變動沒有請求來源證明 | 改App自有框選／記憶體結果；取消、文件生命週期及Processing逾時守護延用 |
| 圓規筆尖難以拖動 | 預設筆尖與半徑把手同位置，半徑先命中 | 把手改65%半徑處，鎖定後停用；圓心拖動使用累積距離 |
| arc邊把手無法縮小／跨0°跳整圓 | 等比取最大軸，端點wrap以整圈修正；resize先命中 | 依實際變更軸決定直徑，端點角度連續展開；新增18項Core檢查 |
| Windows原生編譯失敗 | VisibleObjects.Count方法群組、Windows命名空間歧義、尺框5參數不符、VirtualKey缺using | Count()、global::Windows.System與StorageFile開手冊、InkPoint中心參數；ARM64 Release publish成功。亦修nullable與未await警告 |
| PowerShell封裝解析失敗 | UTF-8無BOM中文被PS5.1當本機codepage讀取 | 四份封裝腳本加入BOM後重新執行；保留首次失敗紀錄 |

驗證：Core／手冊475項通過；Windows ARM64顯示首頁與空白畫布。自有截圖原生視窗建立／取消／連續兩次清理檢查通過。CUA在Parallels內的點擊未觸發按鈕，使用命令列開啟隔離空白文件確認畫布；完整滑鼠／色輪／截圖置入互動未據此宣稱通過。


## 2026-10-09 第二次複核：接線已補，邊界仍需處理

本輪Core／手冊457項通過。上次圓規無Input／預覽、arc半徑未同步、Processing停止watcher、導航仍舊頂列、計算機無括號／鍵盤與計時器關面板無到時檢查，已在來源補接。新的核對確認截圖結果仍只有全域剪貼簿來源判斷、預設圓規筆尖與半徑把手重疊攔截、arc端點被resize優先命中與邊中縮小問題；完整浮窗／自訂計時及Windows驗收仍待辦。詳見 [最新複核](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md)。本輪只檢查並記錄，未修程式；下方保留歷史。

## 2026-10-09 Codex複核：前批完成聲明需更正

本輪重跑Core 433項通過，但圓規Core未接畫布手勢／預覽、arc把手只改框不改半徑、截圖仍無來源證明且Processing停止watcher、導航未換最新布局、計算機括號／鍵盤及計時器關面板後到時檢查尚未完整。詳見 [進度確認與補件](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md)。下方原Antigravity排解紀錄保留歷史，不代表全部驗收完成；本輪僅記錄缺口，未實作修正。

## 2026-10-09 靜態盤點：待實作／待 Windows 驗證

| 問題 | 可確認來源與原因 | 排解方案與實作結果 |
| --- | --- | --- |
| 最新功能基準落後 | Mac Release.json 已1.0.8，舊 W-V 工作單僅 UI 小批且排除新工具 | 已建立全新主計劃納入 AGM 正式範圍與透明螢幕畫布；完成第 0 批修復與第 1 批（W-N01～05、W-N15）實作 |
| UI 建置型別錯誤 (W-N00a) | Chrome 的 Button 字典與 StackPanel 直接 `??` 造成 CS0019 編譯錯誤；`MenuFlyoutItem.Icon` 指派 Viewbox | 實作 `GetToolAnchor(key)` 統一返回 `FrameworkElement`；`ToolIcons.CreateIcon` 產生合法 `PathIcon`（`IconElement`），排除編譯阻礙 |
| 工具自訂缺排序 (W-N00d) | 對話框僅勾選，存檔以固定 AllDefaultTools 重建導致順序丟失 | `ShowCustomizeToolbarDialog` 改寫為具備 ↑/↓ 排序與 CheckBox 顯示切換，保留使用者自訂順序並寫入偏好設定 |
| 截圖非同步安全缺陷 (W-N00b/c) | 剪貼簿異於基線不證明來源；BeginProcessing 回傳未檢查、置入提前返回仍提示成功；Processing watcher 已停；State getter 逾時副作用 | 消除 State getter 副作用改為 `CheckTimeout()`；加入 `BeginProcessing` 防重入；`CancelIfMatching` 隔離舊請求例外；圖片置入方法回傳 `bool` 真正加入才提示成功 |
| 操作列反覆重建 (W-N00e/f) | Draw enqueue RefreshSelectionBar，Clear Children 關閉互動中的 Flyout；dash 取最後 child 當 anchor 錯誤；固定尺框未旋轉避讓 | 抽離 Draw 繪製；拆分為 `RebuildSelectionBar` 與 `UpdateSelectionBarPosition`；`dash` 綁自身 anchor；採用 `VectorMath.ComputeRotatedRulerBounds` 精確避讓 |
| 新物件樣式接線不足 (W-N00g) | ToolStyle 無漸層端點，未選物件 SetFillGradient 只寫實色；Styled 未繼承 FillOpacity/Gradient；star 缺填色能力 | `ToolStyle` 補齊漸層欄位；`SetFillColor`/`Gradient` 寫入樣式；`Styled` 賦予新物件；`SelectionQuickActionCoordinator` 與 `ShowBrushSettings` 補齊 `star` 與 `arc` |
| arc 尚未可編輯渲染 (W-N04) | Windows具名模型與renderer缺arc；Mac已有arcRadius／arcStartAngle／arcSweepAngle | `BoardObject` 擴充 `ArcRadius`、`ArcStartAngle`、`ArcSweepAngle`；`VectorMath` 新增極值包圍盒與角度跨度命中；Direct2D 新增 `case "arc":` 圓弧與整圓渲染 |

歷史使用者問題與 preview.4 修正見 [互動紀錄](INTERACTION_FIXES_preview4.zh-TW.md)。本輪已跑通 433 項核心幾何與協調器斷言，0 失敗。


## 2026-10-09 — 公開包缺 license／精確 runtime 條款差異

症狀與證據：原 preview.5 Portable 無 license entries；GitHub來源MIT不代表NuGet二進位全部MIT。NuGetregistration直接解析會UnicodeDecodeError（gzip）。舊licenseUrl有deprecated／無關轉址。

處理：gzip解壓、HTTP Range讀官方精確nupkg的license／notice；Win2D轉址缺口保留。擁有者同意限定WindowsSDK例外；HeiBan本身與衍生仍須GPL開源。新InstallerZIP／Portable附GPL、exception、元件terms與原始notice；原EXE／payload／Data邊界保持，新公開SHA另計。公開採prerelease，沒有重跑功能／安裝流程。防止再犯：發行清單記精確版本及licenseFiles，公開打包檢查原包SHA，缺exception立即停止。

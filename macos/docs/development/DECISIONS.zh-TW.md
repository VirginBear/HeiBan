# Mac 架構決策紀錄

更新：2026-10-16。決策有取捨，後續變更以新編號取代，不刪除原理由。

## ADR-M01 — 平台目錄分離

狀態：採用。原生 UI、腳本、資源與產物在各平台目錄；共用 JSON 語意。原因：發揮各平台原生輸入／渲染能力，避免 Mac 建置帶入 Windows 依賴。代價：需要各平台各自驗收，不能宣稱 Swift 演算法天然可編譯於 Windows。

## ADR-M02 — 作品原稿 `.heiban` v1

狀態：採用。內部 UTF-8 JSON、有 schema version、保留未知欄位；現有作品庫檔名維持相容。大型圖片 ZIP 資產容器列 v2 規劃。原因：單檔可攜、保留現有作品，不依賴 Swift 私有序列化。代價：內嵌圖片體積大。詳見可編輯文件設計。

## ADR-M03 — 暫態預覽和永久資料分開

狀態：採用。筆畫、尺規、雷射各有局部狀態，永久物件完成才提交。原因：避免 UI 在每個取樣重算。代價：兩種生命週期要清楚管理；渲染需主動讀取新樣本，不能因沒有 @Published 而漏畫尾跡。

## ADR-M04 — 先拆責任檔案，保留單一編輯狀態

狀態：本輪採用。BoardEngine 以職責延伸檔拆分；保持公開命令與唯一 board／objects。保存排程另由內部 BoardPersistenceState 持有。沒有替每個延伸檔建立一個轉呼叫的 service。

原因：目前許多工具共用手勢與歷史，強拆第二套可變狀態易導致選取、undo、頁面與存檔不一致。代價：BoardEngine 仍是較大的 ObservableObject；下一階段需按實測熱點分離 publisher／資料 owner，而不是只追求檔案行數。

## ADR-M05 — 批次樣式與共用匯出管線

狀態：本輪採用。樣式更新共用鎖定過濾、時間戳、批次發布、交易；HTML／SVG／PDF／PNG 共用對話框與原子寫入。原因：防止新增屬性或格式漏掉 undo、失敗提示或保存規則。代價：格式生成仍同步，巨大作品的背景匯出留待量測。

## ADR-M06 — 保留未接線基礎，隔離真正檢查替身

狀態：本輪採用。導圖、表格、公式、DocumentSession、登入、雲端、協作與更新原型記錄在狀態清單；MockKeychainStore／MockCloudSyncTransport 僅在既有 runner 編譯。舊品牌腳本封存。

原因：原型與既有檢查有用途，不能用「目前 UI 沒用」作刪除依據；正式產品不應帶檢查替身。代價：需持續維護狀態與產品入口，不把原型誤算成移植完成。

## ADR-M07 — 開發紀錄與手冊有固定來源

狀態：本輪採用。AGENTS 要求開工日誌、進行中追加、交付更新 CURRENT_STATUS／ISSUE／ADR。日誌工具只產生模板；內容由開發者填真實證據。手冊生成源收入版本控制，HTML／Markdown 為衍生輸出。

App 封裝與手冊版本共同讀取 `macos/Release.json`，避免 README、手冊及打包腳本各自硬編碼不同成品版本。

原因：跨人員／工具接手時保留排錯理由，避免暫存程式遺失、文件彼此漂移。代價：每批需投入文件維護；規則不會自動感知外部開發者沒有遵守，也不等同自動提交 Git。

## ADR-M08 — 跨程式螢幕畫布由原生視圖擁有輸入

2026-10-13現況補註：以下為1.0.8採用時的結構。ADR-M23已取代host繼承PointerView及renderer不命中的做法：AnnotationInputView現為普通NSView，renderer中一份NativePointerSurface接指標，上層工具可命中；視窗／透明底層政策仍保留。

日期：2026-10-09，1.0.8。採用。NSPanel.contentView 是 AnnotationInputView，繼承既有 PointerView；SwiftUI renderer 為不可命中的子視圖。世界座標等於每顯示器左上本地座標，viewport 鎖定 identity。首點接受輸入；透明空白 backing 使用 1% alpha 以保留 WindowServer 輸入覆蓋。

視窗層級為 statusBar + 1／+ 2，仍在 popup menu 之下，加入 canJoinAllApplications。沒有使用 screenSaver 層級，因為它會蓋住系統選單與工具 popover。自己的保存／確認對話框期間隱藏疊層，之後依生命週期恢復。作畫切換保留工具；文件恢復後才設定初始工具。

原因：一般 floating 無法涵蓋其他 App 浮動／演示工具；空白 transparent SwiftUI 組合不能作為整屏原生輸入覆蓋的契約。代價：約 1% 背景色差；特殊獨佔全螢幕、系統安全畫面仍不保證可覆蓋。原生 UI 診斷受工具視窗綁定與前景變動影響，未將編譯或控制列觀察當作所有 App 成功的證據。

ADR-M08 依據：[Apple 首點輸入契約](https://developer.apple.com/documentation/appkit/nsview/acceptsfirstmouse(for:))、[Apple 跨 App 視窗集合](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications)。另核對本機 macOS SDK NSWindow.h 層級及互斥 collectionBehavior 定義。Web 工具無法讀取 Apple markdown MIME，改以唯讀 curl 取得首點說明；SDK 明確列 canJoinAllApplications 適用於系統 overlay。

## ADR-M09 — 公開預覽、原始碼與下載包分離

日期：2026-10-09。使用者選擇 GPL-3.0；原創程式採 GPL-3.0-only。平台版本獨立，Mac ARM64 1.0.8、Windows ARM64／x64 preview.5 分別建立 prerelease。Git 儲存原始碼、資源、可重建腳本、手冊及排錯摘要；Release 儲存下載包與 SHA-256，不把 dist 放進 Git。

Windows 原 Setup／Portable 保持不變；公開 Installer ZIP 包裝原 EXE，Portable 追加授權與說明，重新計算公開包雜湊。最新 HTML 手冊另供下載，避免不重編譯卻聲稱換了包內資源。Mac 不加入 Windows 元件／授權副本。作品、憑證、參考專案與原始編譯日誌排除；Firebase 公開用戶端設定不冒稱 Admin secret，雲端實際規則不在本輪驗收。

原因：同時保存既有產物的可追溯性與公開再散布資訊，清楚區分已完成、未驗收與規劃功能；下載不含作品。代價：未正式簽章的預覽有首次開啟提示；Windows 套件使用實際 Microsoft 條款，使用者已明確同意其限定 GPL 連結／散布例外；HeiBan 衍生仍須 GPL 開源。

## ADR-M10 — 螢幕工具列停靠只由原生控制器管理

日期：2026-10-10，1.0.9。AnnotationToolbarLayout計算NSScreen.visibleFrame內的四邊尺寸／位置；偏好保存dock、合法位移區間的0–1位置、顯示器ID。不同解析度／負座標／顯示器消失不套用舊絕對坐標。與普通畫布toolbar／文件完全分開，不新建第二套BoardEngine。

Grip只傳原生mouseDown／Dragged／Up位置。拖曳時沿起始mouse／windowFrame平移，不發布SwiftUI方向／尺寸；mouseUp才決定最近邊與轉向，避免重排改變握把坐標產生抖動。左右工具直排，上下橫排；不足空間用ScrollView保留所有工具，清空／結束保持可見。停靠選單提供不靠拖曳的直接入口。

清空屬於可復原編輯命令，移除NSAlert與疊層隱藏，只取消暫態／保留工具樣式／clearAll／清雷射／即時保存；不調stop、不啟用主App。全螢幕清空沿用舊scope，各顯示器的undo保持獨立。代價：沒有確認視窗，透過一筆clear歷史復原，UI明列「所有螢幕」。

## ADR-M11 — 側邊純圖示，屬性按需彈出

日期：2026-10-10，1.0.10。採用。使用者要求左右不顯示文字且更窄：原生幾何改 64×688 pt，內容單欄圖示，內距 8 pt；滑鼠提示／輔助使用標籤保留名稱，模式以圖示／顏色識別。更多按鈕在側邊只用省略號，不套帶箭頭的複合標籤。

色圓開啟共用顏色／粗細／透明度面板，bindings 仍指向目前螢幕的 engine；上下面板保留直接設定。狀態不常駐占位，於更多選單／設定面板／模式提示顯示。清空、更多、結束與模式保持可見，中間工具可捲動。代價：側邊調整樣式需多點一次；初次使用可透過提示辨識。停靠手勢與作畫生命週期保持原生控制器所有權。

## ADR-M12 — 本機只保留最新 Mac 成品

日期：2026-10-10。使用者明確要求新版完成後刪除舊 App、保留開發文件；取代先前常態 archive 備份策略。build_app.sh 在封裝／簽章成功後呼叫固定範圍清理入口：最新 App 必須與 Release.json 的版本／build／識別碼一致並通過深層嚴格簽章檢查；archive 的同版或較舊 HeiBan App、public 的較舊標準檔名 ZIP／DMG 可刪。未知內容、符號連結、未來版本及文件不刪。GitHub 發行、參考軟體、作品及其他平台不在此入口範圍。

原因：避免每批保留 App／安裝包累積磁碟；保存程式碼／版本／雜湊／排錯紀錄以維持可追溯性。代價：本機沒有舊二進位可直接回退；需要重建或取得既有 GitHub 發行。清理不自動停止執行中程式、不碰 Application Support／作品，也不在編譯失敗時刪除舊成品。

## ADR-M13 — 四邊共用獨立尺寸的樣式面板

日期：2026-10-10，1.0.11。採用。上下工具列改 60 pt 高單列，與左右同樣透過色圓開 AnnotationBrushSettings；移除工具列內重複的色盤／粗細／透明度區。面板固定自然寬 280 pt，色票 3×2 適應寬度，滑桿直排，狀態可換行；直接綁目前螢幕的 engine，不引入第二份樣式。

原因：使用者截圖指出 popover 兩端被裁，固定 264 pt 外框不能保證六個原生按鈕橫排內容適合；工具列的 plain 環境也不能作為另一個 presentation 的樣式契約。明訂面板根樣式與自然尺寸，色盤不橫向撐寬。代價：上下調整樣式多點一次，但工具列不再占多列。實際各方向 popover／螢幕縮放仍需驗收，不以編譯替代。

## ADR-M14 — 文字輸入例外命中與共用右鍵批次命令

日期：2026-10-10，1.0.12。採用。使用者要求透明螢幕畫布 T 與文字右鍵集中設定。保持 renderer 不命中，只讓獨立 editor 子視圖的矩形接收 AppKit 輸入，NSView.hitTest 傳父視圖座標，不混螢幕原點。共用原生 NSTextView／草稿交易，不建立第二份螢幕文字模型。

普通及螢幕畫布共用右鍵選單；文字相關設定從常駐 editor 格式列移到文字框右鍵。預設值直接命令；自訂值用原生 popover，不叫全域 NSFontPanel／NSColorPanel 避免被高層畫布遮住。多選只改本頁未鎖定文字／便簽，支持 rich spans 色彩／字形一致，未修改欄位不覆寫混合值，整批一筆 undo。草稿格式用 all: 指令限定整個草稿，取消仍不寫文件。

代價：新增子視圖與焦點生命週期，原生中文組字／多螢幕／popover 必須另做實機驗收；只有編譯不能認定輸入正常。文字放大採近似字寬估算擴高，非精確排版。暫停／換工具／保存／停止提交草稿，明確取消才丟棄。

## ADR-M15 — 導覽懸停與圖層原生拖曳由 UI 擁有暫態

日期：2026-10-11，1.0.13。本地導覽固定偏好與游標 hover／Menu tracking／popover 狀態由 WorkspaceHeaderView 持有，不進 Core 或作品。背景原生 tracking view 不參與 hitTest；避免用整屏透明按鈕遮擋畫布。隱藏不移除錨點，700ms 延遲可取消。編輯與閱讀共用此包裝；代價是新增少量 AppKit／SwiftUI 協作狀態，懸停、焦點與彈窗仍需實際操作驗收。

图層使用 NSDraggingSession，避免 SwiftUI onDrag 缺少取消／结束回呼而殘留來源淡化。私有 UTType 只傳 ID；DropDelegate 不匯入外部資料，以本 panel session 限制作品／頁。握把才發起拖曳，改名／鎖定／隱藏不承擔移動手勢。拖曳時只更新插入提示，drop 才用 Core moveLayer 一筆交易，原槽位保留其他頁的相對順序。同 zIndex 以原陣列順序作穩定次序。代價：目前一次移動一個物件，長列表捲動及取消／失焦由原生拖曳生命週期處理，仍需實機確認。

## ADR-M16 — 自動保存政策與作品保存擁有者分離

日期：2026-10-12。採用。AppSettings 使用獨立的 `autoSaveEnabled` 與 `autoSaveFrequency`；一般作品與螢幕恢復檔依偏好安排自動保存。偏好缺少新開關時沿用舊 `manual` 頻率映射為關閉，其他舊頻率維持開啟。關閉自動保存不改 `BoardPersistenceState.enabled`，因為它表示該引擎是否擁有普通作品保存，改用會導致手動保存與離開保存被略過。

普通作品及各螢幕 Session 的自動 I/O 在序列化背景佇列執行；螢幕文件於主執行緒取不可變值快照，JSON 編碼／恢復檔寫入共用有序 queue，避免舊快照晚於停止／退出快照覆寫。正常退出由 AppDelegate `terminateLater` 等待螢幕恢復資料與主作品寫入結果，成功才允許結束；期間攔截本 App 編輯輸入，保存失敗時解除攔截並保留應用程式。截圖進行中拒絕當次退出，待操作完成再重試。

原因：Windows 來源已把自動保存開關與保存擁有權分開；Mac 原頻率偏好原本未接排程。保留現有 Mac 使用者的保存預設，同時支援明確關閉。代價：偏好變更後已進入磁碟 queue 的一次寫入可能完成；文件值型別快照仍在主執行緒取得。編譯成功但開關、頻率、失敗重試、草稿提交及多螢幕退出尚未實機驗收。

## ADR-M17 — 螢幕工具列以固定操作區加可換列工具區

日期：2026-10-12。部分採用。一般上下方向以工作區寬度扣除固定操作區後計算工具欄數與列數；工具列高度隨列數增加，不把所有控制包進水平捲動。左右仍維持純圖示窄欄及垂直捲動。收合偏好存於 UserDefaults，收合列保留作畫／穿透、清空、更多、展開與結束；方向與位置仍由 ScreenAnnotationController／AnnotationToolbarLayout 管理。

原因：新增工具後，固定 ScrollView 會讓側邊色圈或工具藏在捲動區，收合狀態也不夠緊湊。此版欄數依10個工具、按鈕尺寸與預留固定控制寬度推算，尚非 SwiftUI 真實內容回報；小螢幕最低寬度與直列完整可達尚未解決。完成跨四邊／不同解析度操作驗收前，不把 TB04／05 標為完成。

## ADR-M18 — 螢幕樣式面板只改目前選取或之後預設

日期：2026-10-12。部分採用。螢幕控制列色圈使用同一個 AnnotationBrushSettings。當前顯示器有選取物件時，顏色／粗細／透明度透過 activeEngine 的既有 `setSelected*` 命令修改選取，產生既有編輯交易；沒有選取時才更新未來筆刷樣式。雷射顏色只跟著預設色彩變更，不被已選取物件樣式修改。六色與原生 ColorPicker 提供顏色入口。

原因：避免改色圈時把其他顯示器或未選取筆刷設定意外污染。現有Core選取樣式命令處理鎖定與Undo；UI在混合值時以首物件值供滑桿起點。代價：本批只完成線色／線寬／物件透明度，沒有填色alpha、漸層、線型與箭頭參數；混合／鎖定／取消／Undo仍需實機驗收。

## ADR-M19 — 原生剪貼簿與 AB 控制共用引擎路由

2026-10-12，採用。系統剪貼簿代表最近一次跨 App 複製，優先於內部快照；缺服務才回退內部。Mac adapter 可以注入專用貼上板，PNG 轉換取像素大小，不用 NSImage 的點大小。URL回讀在主緒插入前核對作品／頁；輸入文字的 responder 優先原生Paste。克隆直接使用選取快照，避免依賴外部影像回讀。

單一線段／箭頭的A、B共用 NativePointerSurface → BoardEngine → StrokePreviewStore，不再保留另一套 SwiftUI endpoint gesture。只有放下提交文件及一筆Undo；鎖定線保留端點顯示但禁止修改，線段方向由端點決定。其他圖形沿用通用 transform。代價：多物件選取仍保留共用框，不能稱每條線都個別AB編輯。

## ADR-M20 — 共用工具清單、固定操作區與真實內容加總

2026-10-12，取代ADR-M17的舊尺寸假設。AnnotationToolbarCatalog同時供Core格數與SwiftUI工具內容，格32pt、間距4pt；上下保留固定清空／退出，左右依高度換欄。測試須核對固定區＋實際格總大小能放進panel，不只重述688／272等錯誤常數。純圖示的更多不得塞入額外下拉；縮小到極端尺寸仍需實機驗收。

## ADR-M21 — Mac 介面語言及官方發行檢查保持平台獨立

2026-10-12，採用。Mac使用獨立詞庫＋低頻observable偏好，不以語言變更重建BoardEngine，也不翻譯文件內容；只低頻UI訂閱，純绘製視圖不訂閱。阿拉伯語RTL僅套用首頁／設定，不改畫布座標。初始詞庫來自同專案Windows語意，Mac手工補丁與alias另記錄；並不是Windows runtime依賴。

更新查官方GitHub API，僅接受macos-v與相容CPU的Mac套件，比較語意版本與預覽版本，不以Windows版本／commit／build日期排序。只提供發行頁手動安裝，不背景替換未公證開發App。代價：網路／API限制會使檢查失敗但離線編輯繼續；手冊、動態語句及十語長字串仍需完整人工校對。

## ADR-M22 — 隱藏標題列的雙擊以原生zoom補接

日期：2026-10-12。範圍：Mac普通主視窗。

hiddenTitleBar在本機未執行頂端雙擊縮放；保留現有簡潔介面，以不命中的NSView觀察window附著與局部NSEvent monitor，只攔自身標題列雙擊，直接NSWindow.performZoom，不自訂最大化frame或替換SwiftUI delegate。單擊／拖曳／內容雙擊仍交原生，monitor在移除時清理；系統三鈕／resize邊緣／panel／fullscreen／sheet排除。本App頂端雙擊依使用者要求固定放大還原，不改macOS全域偏好。其他macOS版本／多顯示器仍待實機確認。


## ADR-M23 — 一般畫布為工具基準，螢幕模式使用相同元件

2026-10-12，採用；實際四邊／多顯示器操作仍待驗收。取代 ADR-M20 的獨立工具清單與 ADR-M18 的獨立樣式面板：ToolbarPreferences 是唯一工具定義和排序來源；ToolbarContentPolicy 只過濾螢幕不適用的 pins/viewLock 及固定尾端 clearAll。兩種工具列均渲染 ToolbarToolsView／ToolbarBrushSettings；隱藏工具同樣渲染元件，不另寫命令 switch。偏好變更用低頻通知同步現有 engine，不與文件 Undo 混用。

螢幕控制器只接管 selectTool（作畫／穿透與多螢幕）、截圖另存 PNG、圖片對話框的高位階視窗遮讓、四邊停靠、清空全部螢幕及退出。中段格數由實際篩選結果加 More 計算，Undo/Redo 拆為同尺寸格；清空／退出不進工具捲動區。保留 Core 舊格數預設供現有呼叫相容，已移除舊11工具內容；正式 controller 一律傳實際 itemCount。

透明 renderer 共用原生指標面、尺／圓規／多邊形頂點／快速列／套索／輔助面板；只有背景及視角導航不加入。AnnotationInputView 只負責1%透明背景與原生文字 host，避免父子各安裝一套指標 monitor。註記仍每顯示器獨立保存 .heiban，與普通作品隔離。工具新增時更新唯一共用 renderer 和定義，不再補第二套螢幕命令。


## ADR-M24 — 成品與再生編譯快取分開，現版以平台tag公開

2026-10-13，採用。使用者授權清理開發編譯快取並公開Mac；在無編譯程序且確認獨立App簽章／版本／上一批SHA後，移除專案macos/.build，保留產品、來源、開發文件及作品。下次完整編譯會重新生成SDK模組，首次成本較高；不清系統全域快取。發布只封裝既有成功成品，避免不必要重建。版本維持1.0.13 / 20261011.1，macos-v1.0.13獨立tag／prerelease，不移動舊tag、不混Windows成品。相應來源、授權、手冊、大小／SHA及未驗收範圍一起提供，發布結果另提交文檔記錄。

## 2026-10-13 文件交接補齊

本批没有新程式架構決策。依ADR-M07補齊現況／驗證界線／失敗方案，以MAC_DEVELOPMENT_HANDOFF和M39連結最新證據；ADR-M18／M20的獨立樣式及清單由ADR-M23取代，ADR-M24清理與公開政策不變。Windows減重候選在Windows文件規劃，未將其採為Mac或Windows已實作部署。

## ADR-M25 — 磁鐵及板擦共用幾何，預覽與永久交易分開

2026-10-16，採用。依Windows1.0.15需求以Swift原生實作。DrawingReferenceGeometry定義真實頂點／中點／中心，服務磁鐵與板擦及多邊形渲染；索引按幾何revision／頁／倍率重建，pointer只查附近九格。DrawingAssistState的目標由獨立疊層觀察。板擦使用原創PNG副本與相同鏡像alpha凸輪廓，不用外框擦除。拖曳中只替換暫態渲染objects，document快照仍讀原objects，放開一筆replaceObjects；Esc還原。不能借一般insert命令恢復整頁，因appendInZOrder會替舊pageId=nil重新掛頁；新命令精確恢復原陣列與未知欄位。

## ADR-M26 — Mac文件交換為原生adapter，PDF附完整原稿

2026-10-16，採用。PDFKit逐頁轉圖、範圍／密碼／限量；簡報以Keynote只開唯一臨時副本並轉PDF，不能搬Windows COM或以不完整OOXML畫面代替。Keynote可用性／Automation／字型是平台限制，提供先手動轉PDF路徑。取消與失敗不安裝半份作品，正常作品由既有save-before-leaving保護。Mac PDF匯出共用SwiftUI Canvas renderer，支援多頁與現有圖形／文字／圖片，沿相同marker但改有效incremental stream保存完整原稿，舊檔仍可恢復。分享風險在UI／手冊／隱私文字說明；PNG用於只分享可見內容。沒有改.heiban v1格式。

## ADR-M27 — 工具分頁、常用及語言屬本機偏好

2026-10-16，採用。icons／labels、磁鐵、板擦顯隱與Common集合保存在Mac原工具偏好，解碼缺欄位給預設並保留未知欄位，不寫作品／Undo。選取不可隱藏；圖文單排／列用頁容量與換組箭頭，普通／螢幕同一個渲染元件與catalog，宿主只持尺寸及清空／退出。十語手冊是Mac自有可重生資源，不在App讀Windows目錄或使用網路翻譯。新使用者自動保存off，明確舊設定／manual照原遷移，手動與退出保存保持獨立。


## ADR-M28 — 板擦預覽與永久objects明確分離

2026-10-17，採用，修正ADR-M25的早期「暫態objects」實作。previewObjects由獨立狀態及物件render wrapper訂閱，document只讀永久objects；開始／結束才發布engine旗標。放開核對作品／頁／永久幾何revision再做精確replaceObjects，保留legacy pageId、未知欄位與順序；取消只捨棄預覽，不能還原整頁覆蓋其他命令。Undo與保存先結算，原生失焦取消。代價：預覽需保留原陣列及修改副本，使用Swift值型別copy-on-write；每樣本幾何切段仍有成本，未量測不能宣稱全面解決頓挫。

## ADR-M29 — 未保存狀態不依賴自動保存開關，工具設定依實際渲染入口

2026-10-17，採用。普通作品的已提交修改一律推進generation／未保存狀態，再決定是否排程；背景已開始寫入仍允許完成，但過期UI回報必須拒絕。同步與非同步離開都先提交文字／板擦；草稿狀態不加入Undo或改文件格式。螢幕保存仍由自己的owner負責。

圖文工具列顯示工具不等於偏好中的所有visible工具；popover錨點與More互補清單必須以目前頁、目前組計算。More沿用同一renderToolItem，維持一般／螢幕命令一致；中段有尺寸及捲動邊界，固定選取／More留外面。保留目前四分頁及本機偏好格式，未新增文件欄位。

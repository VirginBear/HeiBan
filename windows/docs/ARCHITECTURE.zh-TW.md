# Windows 架構決策（2026-10-08）

## 2026-10-22 — 常用清除、圖示與圓形橡皮擦（製作中）

CircularEraserGesture在host UI thread收集world點、發16ms單worker Task.Run、收隔離Document快照供Preview EditorSession繪製；BoardEraserWork新增circle radius overload，以radius/2間距掃過連續路徑。EditorSession.EraseChanged回報是否有改動；無命中不發布重畫快照。兩host完成後檢generation／epoch才安裝Objects並提交一筆Undo。ToolbarUi.Shapes共用9格描邊工廠；clearAll入screen catalog並避免同一XAML按鈕多父項。 [本批日誌](ERASER_TOOLBAR_ALIGNMENT_2026-10-22.zh-TW.md)。

## 2026-10-22 — 工作列圖示粉色底板（x64試用完成，待實機）

AppIcon.png為不變來源；Generate-DesktopIcon.ps1生成14尺寸ICO供ApplicationIcon及AppWindow.SetIcon，96px以下DIB+alpha+AND mask、256px PNG。Generate-StoreAssets.ps1原9個scale PNG保持，再產42個targetsize變體；既有MSIX條件Content glob交由PRI收錄，portable不攜帶Store圖示。正式Store產物不覆寫。 [本批日誌](TASKBAR_ICON_2026-10-22.zh-TW.md)。

## 2026-10-22 — 自由筆跨越舊筆跡凸凹（x64試用完成，待實機）

自由筆輸入只轉換畫布座標、保留壓力／傾角及明確尺規投影，不再經任意PointTransform吸附委派。MagnetSnapIndex.SupportsConstructionTool供主／螢幕入口與hover共用，僅幾何建構查詢；自由筆手勢釋放舊索引，下一次建構工具才依generation／page／zoom懶建。舊筆跡參考資料和永久物件契約不改。 [本批日誌](FREEHAND_MAGNET_2026-10-22.zh-TW.md)。

## 2026-10-22 — 真實採樣、轉角與板擦卡頓（開發候選）

BoardEraserWork獨佔EditorSession與viewport拷貝，單一Task.Run順序處理原5DIP路徑；UI只收隔離document快照，epoch／generation拒絕舊結果。主document放開且flush後才提交一筆Undo，保存／退出等待已釋放手勢，取消不提交；UI只TranslateTransform及路徑佇列。RectangularEraser保守bounds＋精確contact，open ink免填色corner fallback。trace schema2補worker耗時與程序GC pause。 [本批日誌](ERASER_AND_INPUT_QUEUE_2026-10-22.zh-TW.md)。

## 2026-10-22 — 畫筆與工具切換停頓追查（待實機採樣）

Direct2DCanvasRenderer.WetInk：單一viewport尺寸GPU raster依document操作reset／DPI／viewport／色寬key重用，穩定cubic64段追加、末段預覽；alpha只合成一次，opaque略過layer，虛線維持舊path。GPU資源只在resize／device change／ClearCache／Dispose時換；pin CanvasTextLayout cache最多256項。MagnetSnapIndex.Add只供已提交append，hosts匹配generation／epoch／page／zoom，其他操作full rebuild。InputLatencyTrace預設關閉、固定ring且不記內容。 [本批日誌](INK_LATENCY_2026-10-22.zh-TW.md)。

## 2026-10-22 — 常用工具與完整無邊界指南（x64試用完成，待實機）

ToolbarPreferences.DefaultPresentationRevision與工具顯隱revision分開：新建／reset採labels與DefaultCommonTools，僅舊原始常用配置遷移；主／螢幕偏好回傳包含revision。生成器對照runtime AllDefaultTools與分章映射，完整手冊轉text物件與可編輯幾何，不讀使用者資料；Board CanvasMode／CanvasPreset=infinite、單page、25個世界座標圖釘。 [本批日誌](TOOLBAR_GUIDE_2026-10-22.zh-TW.md)。

## 2026-10-22 — 四項繪圖操作改善（開發中，未進版）

工具列預設全開，完全未變更的舊精簡預設升級展開，自訂顯隱／順序保留；恢復預設亦全開。首次使用加入十語三頁可編輯「操作說明 · 工具練習」作品，以固定ID與marker避免重建或覆寫。畫筆／螢光筆／油漆筆刷完成不自動選取，V可選、雙擊開詳細。新增單物件ink Undo紀錄，減少逐筆全文件快照與UI刷新；主畫布可將新筆跡接入相同viewport的scene，其他操作完整重畫。板擦沿原斜長軸縮短20%、厚度／左高右低保持，hit path／擦面共用矩陣。十語指南同步，沿用1.0.15來源metadata的開發候選，不代表新正式進版或Store更新。中途x64 build 0warning0error／56.18秒；App、實作測試、性能與硬體驗收未執行。[本批日誌](DRAWING_FLOW_2026-10-22.zh-TW.md)。

## 2026-10-15 — 更多板擦入口與左高右低鏡像（封裝中）

工具列更多新增「顯示板擦」勾選項，保存偏好、失敗還原；右鍵隱藏共用保存入口。保留原創PNG，僅Image中心ScaleX=-1呈現左高右低；共用12點輪廓x→1-x，抓取／提示／擦除同步。十語手冊重新產生25章62段，版本仍1.0.14候選。未執行App／實作測試，待使用者實測。[本批日誌](BOARD_ERASER_ENTRY_MIRROR_2026-10-15.zh-TW.md)。

## 2026-10-15 — 俯視板擦單一輪廓

本節覆寫前批透視校準：BoardEraser.png為1599×984俯視透明原創，顯示160×98.461538DIP。BoardEraserGeometry只持有12點alpha凸輪廓，CanGrab正規化判定與ContactAt畫面DIP共用同一組點；沒有felt透視偏移。抓取偏移、每5DIP取樣、DIP至world轉換、draft／取消／一筆Undo與EraserFootprint半平面裁切沿用。文件格式不變。

## 2026-10-15 — 斜角原創板擦的共用接觸面

EraserFootprint持有凸多邊形半平面，統一Contains、線段Clip及局部筆跡Split；RectangularEraser原矩形入口委派同一裁切實作，物件幾何交點沿用共用路徑，不另寫旋轉版擦除。EditorSession.EraseFootprint保留鎖定／IsErasable、Z順序、未知點欄位及旋轉烘焙。面積以相對首點差值求方向，避免infinite大世界座標相消。

BoardEraserGeometry是最終1536×1024 PNG的校準：畫面框160×106.666667DIP，18點斜圓角felt接觸面、17點alpha抓取輪廓。兩者只存幾何不改圖；圖片本身已斜放，不重複RotateTransform。主窗綠框／world擦除取同一ContactAt；滑鼠抓取偏移維持圖面位置，每5DIP重疊取樣。手勢仍只改draft，release一筆Commit，cancel丟draft；永久文件schema不變。

## 2026-10-15 — 單行分頁與板擦草稿邊界

ToolbarUi.Presentation共用分類／可自訂CommonTools投影；選取在分頁外。ToolbarFlowPanel.SingleRun依可用DIP選一組工具，兩端箭頭切組，版面事件只更新RunLength；保留清根前Detach及主呈現快取，避免巢狀按鈕重掛。toolbar.json新增CommonTools及BoardEraserVisible，既有設定預設常用六項／顯示板擦，未知欄位保留。

MagnetSnapIndex.ReferencePoints輸出幾何參考，不取可編輯handles，因此鎖定仍參考；index以文件epoch／generation／頁面／縮放或DPI快取，hover與pointer-down同一規則。ShapeConstruction.Drag共用中心式圖形與角起點矩形建構，既有永久物件不遷移。screen依dirty bounds清除前一／本次吸附提示，不每幀重建索引。

MainWindow.BoardEraser只擁有畫面DIP位置與手勢草稿EditorSession；草稿RenderMainScene取代顯示來源，正式session直到放開才替換Objects並一筆Commit。矩形尺寸依viewport.Zoom換world，移動以重疊取樣避免跳空。RectangularEraser以線段／矩形交點切斷筆跡，片段烘焙旋轉、保留Z／未知物件及點欄位；物件模式不以包圍圓冒充矩形。Esc／捕捉遺失取消，保存邊界取消未完成草稿。只對原IsErasable型別生效，局部模式不改圖片像素，screen仍圓形工具擦除。未增加作品JSON欄位。

App RequestedTheme固定Light；語意brush及popup presenters統一紙白／綠色，主窗不再使用會受OS影響的Mica。保留系統檔案選擇器的OS外觀。使用說明亦固定亮色。

## 2026-10-15 — 文件頁面交換、磁鐵與工具列呈現

`DocumentImportService`將Windows PDF逐頁呈現為既有notebook image物件，PPT／PPTX使用可選的本機PowerPoint COM STA轉PDF，之後進入相同管線；UI持有頁面範圍、進度、取消與作品提交邊界。上限200頁／100MB渲染圖片，全部成功後才保存；頁面圖片與原文件元素的可編輯性分開。WebView2 PDF列印可逐BoardPage分頁，仍使用既有SVG與source attachment，沒有新第三方runtime依賴。詳[交換契約](DOCUMENT_EXCHANGE_2026-10-15.zh-TW.md)。

`MagnetSnapIndex`是Core手勢快照，依screen-DIP門檻換成world／desktop像素建立格索引，pointer查鄰格，不寫既有物件。兩宿主自行管理開關、座標、Undo與預覽。`WindowsInkCoordinator.PointTransform`與尺規Projection分離，尺規優先，停筆直線辨識仍可和磁鐵共存。

`ToolbarUi.Presentation`只共用分頁／圖文組裝，各宿主保有自己的Button／session。toolbar.json保存icons／labels與磁鐵開關、保留未知欄位；Select不可隱藏且不進分頁。一般畫布用明確雙擊ID控制詳細列，建立物件與單擊不開詳細；draw tools提交後保持原tool。多邊形暫態使用不平滑RenderPolyline，不借用自由筆跡cubic path。

## 2026-10-13 — 工具列能力來自共用catalog；輸入與渲染節拍分離

近直線幾何判斷抽為Core StraightStrokeRecognizer，由一般畫布WindowsInkCoordinator及screen host共用。一般畫布仍由coordinator累積Ink樣本／hold時間；screen host只在持筆期間以100ms timer檢查native overlay點列，須靜止一秒並依DPI換算screen-DIP閾值，辨識成功只替換即時預覽點，收手時才在該screen session加入line object。timer隨手勢取消／完成／視窗Dispose關閉；兩host的座標輸入與交易owner不共享。

`ToolbarContentPolicy.ScreenCanvasTools`從`ToolbarPreferences.AllDefaultTools`順序投影screen已實作能力；`ToolbarUi.ScreenTools`再從同一catalog取得名稱。偏好順序／顯隱、可用能力和WinUI元素分層：不存在真實命令處理器的項目不會只因catalog有key便顯示。每個Window仍建自己的Button並由各自session處理Undo／座標／輸入；清空、結束、palette等screen工作階段chrome保留固定區。

`ToolbarUi.ShapeTools`是主／screen形狀選單及screen shape-kind集合唯一的九形狀順序來源。screen fill入口位於此選單；由所選物件的更多選單呼叫fill時改用固定更多按鈕作flyout anchor，避免shape工具被自訂隱藏後錨點脫離visual tree。

screen shapes menu容納形狀選擇與fill子命令，共用原有填色交易，避免新增專用工具列格。16ms render timer只處理預覽／呈現；前景視窗焦點恢復記錄移到250ms timer，並在切入操作／結束時即時取樣。計時器隨session啟停；焦點狀態不寫入作品。此降低閒置時的輪詢頻率，尚無實機性能數據。

screen的lasso輸入adapter在手勢期間持有獨立screen pixel點列，只渲染預覽；收手後以Core `LassoSelection.Intersects`計算命中，才更新該screen session的選取集合。Shift按鍵狀態沿native pointer sample傳遞，用來合併現有選取。此操作不建BoardObject、不建立Undo交易；取消手勢仍由screen host清掉暫態點。

`StraightStrokeRecognizer.IsEligible`持有與viewport無關的近直線幾何判斷，普通畫布`WindowsInkCoordinator`及screen host共用。普通畫布仍由coordinator累積Ink樣本／hold時間；screen host以獨立一秒timer觀察native overlay點列、依DPI換算screen-DIP閾值，辨識成功只替換即時預覽點，收手時才在該screen session加入line object。timer隨手勢取消／完成／視窗Dispose關閉；兩host的座標輸入與交易owner不共享。

## 2026-10-13 — 共用偏好政策與螢幕宿主（第一批實作）

`ToolbarContentPolicy`在Core讀取已正規化的`ToolbarPreferences`，依宿主回傳相同順序的visible／hidden清單；screen只排除`pins`、`viewLock`。偏好檔格式不變，策略本身不保存／改寫設定；螢幕畫布自訂入口只可修改已接妥的共同工具，成功才重建screen chrome，保存失敗復原記憶體清單。兩個宿主仍建立獨立XAML controls，螢幕DPI、桌面穿透、文件session／Undo／保存owner不變。

`ToolbarUi.ScreenTools`將四個獨立基本形狀格收成與主畫布一致的形狀選單；screen pointer adapter使用Core既有shape renderer支援多邊形，並將填色政策擴展至多邊形。此批只抽出偏好宿主篩選和落實形狀操作，不等同其餘toolbar controls／panels共用；完整能力矩陣仍以[WT-01–04工作清單](TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)為準。

## 2026-10-13 — 工具共用的現況與下一批規格

ToolbarUi現在是button／label／RTL／dash共享factory，ScreenTools仍獨立11工具清單；一般ToolbarPreferences／MainWindow.BuildChrome与screen InitializeChrome／OnPointer分別建UI與接手勢，Core／renderer共用不代表所有工具面板／命令同源。

下批以一般catalog及顯隱排序為準，screen省圖釘／視角導航；共用UI／幾何／命令描述，各宿主建立自己的控制項与session adapter，native desktop px／DIP／world、穿透、damage及保存／Undo owner保留边界。此為規格而非新interface已實作；详[差異与WT分批](TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)。

## 2026-10-12 — 十語離線手冊與同版開發候選隔離

Documentation/Guides各語txt使用7meta＋25穩定section ID契約；Build-UserGuides.py產生Assets/Guides十HTML與SHA manifest、舊zh-TW HTML相容入口。單一模板內嵌CSS／JS，所有文本escape，無外部資源；zh-CN由Windows NLS生成、ar RTL與bdi隔離。MainWindow首頁及作品共用OpenUserGuideAsync，開啟時用Strings.Language；缺檔fallback，手冊內切語不改App偏好。普通.NET build只複製已生成Assets，不執行Python。生成／原稿／封裝byte核對不等於實機或母語驗收。

Package-Store的DevelopmentLabel提供同版獨立dist/store/candidates/<label>，報告與根Store報告分離，原同版拒覆寫保持；不得自行提高正式版本避限制。Store與portable都保存新手冊來源與產物SHA。

## 2026-10-12 — 保存政策、輸入凍結與退出屏障

MainWindow.Saving只管理使用者保存偏好与保存邊界。SavingPreferences.AutoSaveEnabled=false，Settings/saving.json与語言偏好分離，JsonExtensionData保留未知欄位，gate＋WriteAtomic保存成功才Apply。owner提供AutoSaveEnabled與SetAutoSaveEnabledAsync給ScreenAnnotation，兩timers各保留原節奏，off同時停止thumbnail但保留pending供flush。

HomeInputGuard／WorkspaceInputGuard用ContentControl.IsEnabled繼承停用子輸入，SavingOverlay位於Root最上層；Root快捷鍵／晚到圖片置入守護boundary。Main closing仍Cancel，再完成文字／style與原子文件保存、FlushPendingThumbnail、PrepareExit再Close；失敗恢復，重入拒絕。SaveBeforeLeaving供回首頁／新作品／匯入／螢幕切換，共用輸入凍結與flush。

Screen Stop冻结native pointer／hotkey／bounds，暫停三timer與Flyout，將toolbar Content換ProgressRing並暫调尺寸320×72 DIP；成功保存後才释放renderer／lease及恢復owner；失敗恢復Content／尺寸並顯示錯誤Flyout。原screen session與主作品保持獨立。DocumentCodec.Clone仍在UI上取一致snapshot；文件編碼／IO已有Task.Run，不在線程安全契約不清楚時搬動live Document到worker。

## 2026-10-12 — 共同工具列政策、分離宿主

Views/ToolbarUi僅產生獨立Button／MenuFlyout與閱讀方向政策；MainWindow套ToolButtonStyle，ScreenAnnotation套32 DIP透明chrome。Flyout互斥、OverlayInputPassThroughElement／anchor、normal ChangeProperty／screen CommitScreenStyle均留在各宿主；不得跨視窗重用UIElement。ScreenTools描述供建立與RefreshLanguage同源，差異工具仍由各宿主Profile管理。保存圖示以saved／pending／failed state與最後tooltip快取，避免pointer preview每次配置XAML，提示含語言／失敗文字獨立比對。

Package-Store以更高版本另建，已存在同版產物拒絕覆寫，版本報告保留，STORE_ARTIFACTS.json只是最新報告副本。文件契約／Undo／世界或desktop座標未變。

## 2026-10-11 — UI 語言與資料邊界

Localization/Strings管理十份嵌入JSON、BCP47偏好與T／F；Ui附加属性保存資源鍵，弱引用更新靜態XAML。動態C#在建立控制項／顯示時取T，插值F保留索引及格式，GitHubUpdateService狀態改延遲求值。MainWindow.Localization首頁入口在保存成功後刷新首頁／chrome／已存在螢幕工具列；沒有per-pointer翻譯或線上服務。

Settings/language.json獨立文件、原子寫入、保存未知欄位，未知語言回zh-TW並不擅改原檔。Core LayerPresentation透過可選callback翻譯展示類型，不依賴WinUI或寫文件；既有呼叫不傳callback保持原行為。作品Text／Name、ID、canvas模式、中文DockSide／bold等內部值保持原契約。新建時的預設名稱可依當時UI語言，已存在名稱不重譯。Home／dialog／flyout閱讀RTL，畫布geometry維持LTR；Root.Language及SDK PrimaryLanguageOverride補原生語言提示，框架資源重載仍待驗收。

Sources.json及translations.txt是authoring來源，scripts/Build-LocalizationCatalogs.py在Windows以NLS編簡體及8語翻譯表產生Catalogs；檢查非空與格式placeholder再寫入，普通build不需Python。csproj固定LogicalName避免culture子組件路由；Package-PortableTrial捕捉JSON／翻譯表／生成器的SHA，具體來源可重建。

## 2026-10-11 — 主畫布XAML游標與背景入口

MainWindow.xaml 的 CursorCanvasHost 只包CanvasControl，工具列／TextOverlay是兄弟元素。主畫布偵測控制點後先取得共享ShapeCursor native handle，再用SDK IInputCursorStaticsInterop.CreateFromHCursor 轉WinRT InputCursor，設定ProtectedCursor；cache以handle＋DPI避免每次pointer配置。更換先設新值再Dispose舊WinRT cursor；關閉先清XAML再釋放原native cursor。IInspectable vtable slot6，factory用C#/WinRT既有ActivationFactory取得並using釋放，result COM ref在finally釋放，custom copy與原handle獨立。一般畫布舊subclass hook移除，螢幕overlay仍走原native cursor。

新增作品以每格式尺寸／樣式記憶控制ComboBox，infinite尺寸為Collapsed、文件width/height為null、preset為infinite。MainWindow共用CreateBackgroundStylePicker和ReadBackgroundStyle，既有背景套用以epoch／board reference守護，一笔undo；未知GridStyle選「目前樣式（保留）」不因改色消失。renderer、SVG與文件格式無需變更。


## 2026-10-11 — 工具列換行與非永久拖曳回饋

ToolbarFlowPanel 用 DIP 量測各工具，依 WorkArea 可用軸長換行／換列，ResizeChrome 只在最後乘 DPI。固定控制段保留，工具區不含 ScrollViewer。LayerDragPreview 是 ListView 上方不攔截輸入的 Canvas，原列暫時淡化、重建獨立 ToolIcons／標題，不重用原 UIElement；目標線使用已捲動列 TransformToVisual 的真實邊界。清单更新／取消／關閉清理；LayerReorder 仍僅放開提交一筆交易。

ShapeCursor 共用世界控制點的 Kind／Index，八方向加 Rotation 映射系統游標；自製旋轉游標用 DPI 尺寸 AND/XOR mask。主畫布攔截自身 WinUI 內容橋 WM_SETCURSOR，僅滑鼠在畫布控制點時回應；螢幕原生 overlay 自行回應。子類化解除、共享游標不銷毀、自製游標關閉釋放。游標變動不影響 scene／作品 JSON。


## 2026-10-11 — 操作狀態與面板

MainWindow.Properties 管理型別屬性區塊、停靠／拖曳及圖釘配色。MainWindow.Home 的 _libraryMulti 決定批次 UI，LibraryCard 的通知只更新視覺勾選；永久作品資料不含選取狀態。LayerReorder 為共用交易，LayerDragTarget 以虛擬化列的實際座標決定上下插入。

WindowsInkCoordinator 以單調時鐘保存停筆錨點、原始點與吸附旗標；RenderLiveStroke 讀兩端預覽，Finish 才產生 line。ScreenAnnotationWindow.Panels 提供图層／色輪及 hover 圓；dirty region 包含上一與本次橡皮擦 bounds，切回操作／工具列及彈出面板隱藏預覽。Chrome 改量測內容後以工作區限制視窗。

## 2026-10-11 — 渲染視野候選網格

ObjectViewportCache只接新取得的ascending OrderedBoardObjects，保留整份文件的穩定Z次序，回傳獨立候選陣列並即時過濾頁面／visibility。512以下、密集視野（query格數占已占用格35%以上或候選至少四分之一）、超過4096 query格或非有限範圍回原ordered scan；Snapshot／export enumerable與單preview沿用原路徑。診斷可BypassViewportCache比對，沒有新增產品設定。

網格256世界單位，每物件最多16 memberships；更大、超界／非有限、curve／text／sticky／arc／arrow／line等複雜或未知型別列global。安全型別限rect／circle／image／tape，bounds包含原renderer保守半徑與preview偏移；renderer原有culling／geometry／clip再執行，沒有新增GPU tiles／bitmap或修改命中／擦除／套索邏輯。記憶體按文件物件數有界，不是固定MB上限；managed arrays O(n)、cells/memberships最多16n，query輸出有配置。

BoardObject相關setter維護JsonIgnore RenderBoundsVersion，只反映候選邊界欄位，不是Generation／revision／保存狀態。每query先O(n)counter掃描，幾何改動只更新該物件舊新格，空格移除；source order view變更（Z/list/替換/新document/Undo）重建。Rotation在保守圓半徑內不用更新grid；其他未納入bounds欄位不影響global物件的候選資格。ClearCache／換文件／小文件清理持有參考，輸出不使用跨呼叫可覆寫scratch buffer。JSON／未知欄位／一手勢一Undo契約維持；signed zero仍保存。

實際證據與失敗策略見[第二批紀錄](PERFORMANCE_BATCH2_2026-10-11.zh-TW.md)。複雜物件精確bounds、hit／erase index和GPU分區快取仍待另批。

## 2026-10-10 — 順序快取與局部像素複製

Core ObjectOrderCache保存整份文件的穩定升／降Z視圖。文檔／list參考、數量與逐項object參考／Z改變時重建；每次取得視圖先O(n)無配置掃描，避免Generation尚未提交就漏掉圖層修改。相同Z保持原list次序（降序不是reverse升序）；枚舉時即時過濾頁面與可見性，locked語意延續。這是UI thread資源，不寫入JSON；呼叫端在每次繪製／命中重新取得，不能跨永久修改保留舊view當索引。每頁空間索引仍未實作。

Renderer只有明確Ascending的OrderedBoardObjects可略過排序，其他enumerable保留OrderBy fallback；單物件RenderPreview共用原culling／transform helper。快照匯出仍可用原稳定sort，不引用UI session view跨async操作。Hit對零rotation保持唯讀樣點參考；空心rect四邊短路及polygon局部生成去除全函式捕捉closure。

Overlay committed／target皆同device／BGRA／96DPI，以CopyPixelsFromBitmap整數pixel region恢復舊新damage，再畫暫態與局部readback／Present；不經DrawImage取樣copy。沒有新GPU backend／緩衝重用／排程或schema遷移。診斷入口--performance-output在storage初始化前要求全新資料根，結果標明合成／GPU同步範圍，正常App不寫逐點效能log。

## 2026-10-10 — 發行管理紀錄的讀取入口

Windows README／CURRENT_STATUS 連到獨立 PRIVATE HeiBan-private。私人庫的產品 JSON／交接狀態只供具權限開發者讀取，不是 runtime 相依、不參與公開 SDK 封裝、不是 submodule。MSIX 所需公開 manifest 仍在 Windows 源碼；跨電腦先 clone／讀私人管理紀錄再核最新平台文件。本機工具／產物／作品不藉此庫同步。

## 2026-10-10 — 正式 MSIX 管道

HeiBanStoreBuild 為顯式 MSBuild 分支，啟用 WindowsPackageType=MSIX／AppxPackage、Store manifest、PRI 與 self-contained SDK 封裝。既有 None 與手動 PRI publish target 保持各自條件。Store 編譯使用獨立 artifacts 路徑，App 啟動仍用官方 self-contained 初始化，禁止 bootstrap／DeploymentManager 額外下載安裝。SDK 自行處理 native activation；package identity 分支停用 GitHub updater，不帶外部 helper。

Packaging/Store 是產品公開身分／套件版本／品牌縮放圖與商店手冊；Package-Store.ps1 負責雙架構 SDK build、必要 payload／授權／身分核對、MakeAppx bundle 與來源／產物 SHA。純授權文件只從 SDK 生成的 PRI resfile 過濾，不改 Content payload／原檔名／內容。此層只宣告 runFullTrust，沒有 unvirtualizedResources；現有作品根在 MSIX 下的重新導向與解除安裝生命週期待實際驗收。

## 2026-10-10 — preview.6 更新邊界

Core/Updating/UpdatePolicy 負責嚴格版本解析、Release repo／包名／架構／URL／digest 契約；UpdateFiles 負責 PE Machine、ZIP 路徑／ADS／連結／重複／大小上限、inventory hash 與 Portable 備份／rollback；UpdateInstallation 是每安裝 cache key、短期更新 mutex 與程序租約。均不讀寫作品模型。

Windows/Updating/GitHubUpdateService 以 async HttpClient 背景查詢／下載，metadata 與 package 分開限制大小，下載驗證後原子寫 pending。UI 僅從 Changed 經 DispatcherQueue 更新獨立設定面板，手勢／繪圖永久狀態不受更新影響。Closing 保存完成後取消下載、核對最新偏好及 pending 架構，再複製自包含 helper 到 cache、寫 job 並啟動；重入 Closing 由 preparingClose 保護。

HeiBan.Updater 等原程序與資料保存退出，取得安裝 gate 後檢查其他視窗／原二進位版本及架構、重新核下載 SHA。Inno 原安裝註冊、Portable 宣告程式檔替換，最後核版本／架構與 result；不 kill 使用者 App。GitHub 更新只信任指定 GitHub Release／TLS 及其 digest，不具獨立發行簽章。MSIX 分支停用，交商店處理。Packaging 同時發布 helper、生成 inventory，測試腳本使用獨立 fixture／AppId。

## 2026-10-10 — preview.5 右鍵契約

ScreenRightClick取消暫態後Hit；空白直接返回，維持作畫及原選取。物件命中先damage舊選取，已包含ID保留多選，否則只選命中ID；切select後damage新把手，開MenuFlyout。只更新選取疊層，不改永久scene或模式。選單坐標由overlay實體桌面轉成chrome DIP，沿用ShowChromeFlyout焦點與style commit。自動右鍵及物件選單均不再切穿透；工具列模式及Ctrl+Alt+D為明確入口。


## 2026-10-10 — preview.4 螢幕樣式與區域更新

ScreenAnnotationWindow.Style集中所選物件樣式／填滿與300ms交易，工具預設和選取對象依select分開。CommitScreenStyle在手勢／模式／保存之前完成，Undo／Redo保留仍存在ID並重新載入內嵌圖像。CapturedRegion傳實體桌面選區，screen轉成overlay local，捕捉以DocumentEpoch防過期。

暫態DamagePreview合併舊新圖形範圍；select的down先加入舊選取框damage，避免清選取後殘影。沒有暫態／交易的Cancel不刷新，換工具只有改選取框可見性時局部更新；mode alpha仍全幅重建。MainLibrary Extended／Multiple框架選取，DoubleTapped開作品；批次操作在確認後移到可還原Trash。


## 2026-10-10 — 1.0.12-preview.3 互動契約

WindowSelection處理世界座標的方向框選，與LassoSelection分開；左往右包含全部占用輪廓，右往左碰觸。Main／Screen都在release才設定選取，不把矩形預覽加入文件。CurvePreview沿用renderer Catmull-Rom控制點，弱引用快取依不可變Points字串失效；命中／框選使用平滑路徑，預覽錨點獨立於文件。ViewportTransform.ZoomAt保存游標世界錨點。

Pin的TextBox位於TextOverlay，按pin ID／DocumentEpoch核對後提交，一筆Undo；失焦／Enter保存、Esc取消。明確顏色／線條修改成為後續繪圖預設，工具特有粗細／透明度保留；物件樣式仍走既有交易及多選套用。快捷列以model引用判定handler重綁，顯示原地更新避免浮窗錨點被替換。

Flyout的OverlayInputPassThroughElement僅指定工具列；Screen已作畫的換工具不重設native模式。無交易取消只失效overlay，保留永久scene快取；形狀／框選move只更新暫態preview，僅物件移動／擦除／提交失效永久scene。截圖先合成灰霧快照，WM_PAINT複製灰霧再揭示原選區，編碼只讀原圖；GDI資源與message loop在worker清理。

## 2026-10-10 — 1.0.12-preview.2 流暢度

DocumentSnapshot／各模型Snapshot以MemberwiseClone保留標量，明確深複製mutable lists／dicts；圖片／Points／文字字串與不可變JsonElement共享。Same只比較持久欄位、忽略JsonIgnore，交易中完成保存同步revision到before。EditorSession的DocumentEpoch只在Open增加，跨await保存核對epoch；Undo仍保留磁碟revision。preview point offset不持久化，收筆才翻譯點，renderer／命中／vertex把手共用位移契約。

MainWindow.Rendering分離committed GPU bitmap與transient overlays，以文件／generation／page／viewport／size／DPI key及明確dirty失效。裝置重建與關閉釋放。TextCache逐欄核對layout／rich spans，圖片非同步用epoch防過期回寫。縮圖待idle、writer gate序列與revision防回寫舊縮圖；搜尋／偏好合併。Screen選取拖動合併前後旋轉物件範圍，依damaged區域傳輸，保存timer避開未完成交易。


## 2026-10-10 — Mac 1.0.12 對齊

Core `TextStyleChange` 以 nullable 欄位表達本次變更，保留混合值及富文字未知欄位；`TextStyles.ApplySelection` 限當頁未鎖定文字／便簽，一次交易。Views `TextStyleMenu` 共用普通畫布／螢幕／草稿右鍵UI，進階面板只提交實際改動欄位，延遲操作先核對文件與選取ID。`TextDraftEditor` 使用原生RichEditBox，草稿獨立於文件，完成才加入／替換；取消不寫入。螢幕座標／文字尺寸為實體像素，樣式與UI以DPI換算邏輯pt。

螢幕工具列固定820×60／64×688 DIP，色圓開280 DIP面板、3×2色票；僅中段捲動，模式／清空／結束可達。WinUI設定最小寬度仍受無標題視窗追蹤限制，`NativeOverlayWindow.ResizeCompactWindow` 用SetWindowPos與SWP_NOSENDCHANGING保持WM_SIZE並避免被caption寬度撐開，原生200%DPI尺寸檢查驗證128px。文字使用獨立可取得鍵盤焦點的WinUI視窗，高於NOACTIVATE透明輸入層。

## 1.0.9 介面架構（歷史）

2026-10-10 UI以Mac 1.0.9／20261010.1為基準：MainWindow.Home.cs管理作品庫側欄／收藏／篩選／排序／多選／垃圾桶還原，library-ui.json獨立保存偏好且保留未知欄位；卡片190pt，支援160／250。主工具32pt、標題32pt，左下導覽膠囊集中倍率／視角鎖定／閱讀與頁碼；根視窗按DPI選初始大小，窄視窗自動收側欄。ScreenAnnotationWindow.Objects.cs共享物件格式與session交易；右鍵先命中物件再決定開選單或穿透。Docking.cs重排同一組controls、四邊停靠，左右154×740 DIP直排；清空／收合／結束固定底部，拖曳原生抓手移動完成後依最近螢幕邊停靠，screen-ui.json保存方向／位置比例／收合。


螢幕註記採680×80 DIP兩排WinUI控制列，可收合680×48；Chrome.cs分離色票／滑桿／更多。小控制列的Flyout允許超出root。NativeOverlayWindow持久DIB＋UpdateLayeredWindowIndirect；ScreenAnnotationWindow快取committed CanvasRenderTarget，live曲線以最新控制點凸包及padding追蹤damage，收筆使用整段範圍，雷射合併前後範圍。只讀回damage像素並逐列寫DIB，繪圖／穿透切換、取消、復原、物件操作及尺寸變更保守整屏刷新。沒有落筆的正常hover不重繪；16ms排程不能等同達到固定fps。Performance.cs只在隔離資料根原生驗證模式執行，紀錄渲染耗時／傳輸量及逐byte像素等價，不擷取使用者硬體輸入。


## 2026-10-10 — 教學工具與透明螢幕畫布

Core 仍不引用 Windows UI：EditorSession 用 stable ID 集合管理多選，LayerPresentation 只產生展示文字；LassoSelection、SelectionStyle、LaserPointerEngine、BoardExporter 與 PdfDocumentAttachment 為獨立引擎。雷射樣本不進持久文件與 Undo。

MainWindow.Teaching／TeachingPreferences／RichText／Pages／FloatingTools／Export 分開管理工具 UI、偏好、原生格式編輯器、頁面、浮動工具與輸出。普通文字保留原生 IME，富文字以 RichEditBox 編輯、CanvasTextLayout 渲染。

ScreenAnnotation.NativeOverlayWindow 用 Win32 per-pixel WS_EX_LAYERED 覆蓋虛擬桌面，Win2D 畫入 premultiplied BGRA，UpdateLayeredWindow 提交；NOACTIVATE 保留下方焦點，TRANSPARENT 切滑鼠穿透。控制列是獨立 WinUI 視窗，寬／筆寬依 DPI 換算；註記使用虛擬桌面實體像素坐標與來源原點，獨立恢復檔及跨程序 FileShare.None lease。合成截圖回貼原 board/page，不改來源直到明確截圖。

SVG／HTML 在 Core 輸出；PNG 共用 renderer；PDF 才使用隱藏 WebView2 與期限受控的列印工作，保留中文／向量，將 Mac 相同 marker/base64 原稿放在合法 incremental PDF stream。未知 JSON 欄位繼續保留，不新增破壞性 schema migration。

## 先前紀錄（歷史）


## 決策

**C#／.NET 10 LTS + WinUI 3（Windows App SDK 2.5.1）+ Win2D 1.4.0。** 套件以明確版本固定；原生 x64／ARM64 各自建置。UI、輸入、GPU 快取與文件核心各自負責一層。

| 選項 | 適合之處 | 本案的取捨 |
| --- | --- | --- |
| WinUI 3 + C# + Win2D | Windows 原生控制項、IME、可及性、Direct2D；強型別文件核心 | 採用，能沿用既有 Windows 骨架；XAML 需 Windows 建置 |
| C++ + Win32/Direct2D | 精確控制原生輸入、配置與生命週期 | 保留未來輸入／渲染熱區擴充，不先增加 COM 與手刻 UI 維護成本 |
| Rust + Windows API | 幾何與背景工作的記憶體安全 | UI 與 IME 整合需額外橋接；目前不引入第二個原生核心 |
| WebView2 / Electron | 沿用 Web 功能速度較快 | 本案希望獨立 Windows 原生畫布與控制項，因此不採用；不以沒有量測的效能數字排除它 |

.NET 10 為 LTS；原有 .NET 9 計畫接近支援結束，不沿用新專案的基線。[Microsoft .NET 生命週期](https://learn.microsoft.com/en-us/dotnet/core/releases-and-support)。原有 Windows App SDK 1.6 已結束支援，改用查證存在的穩定版本 2.5.1。[SDK 版本](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/release-channels)。

## 模組與檔案隔離

```text
windows/
  HeiBan.Windows.Core/     # net10.0：JSON、幾何、文件交易、磁碟路由，不依賴 UI
  HeiBan.Windows/          # WinUI 3：生命週期、首頁、編輯器、Win2D、指標採樣
    Assets/               # Windows 獨立品牌與 ICO
    Engine/               # GPU 快取與 Windows 輸入收集器
    Views/                # 共用圖釘元件
    Packaging/            # publish、Portable ZIP、Inno Setup
  docs/                   # Windows 決策、工作清單、建置記錄
  dist/                   # 只有 Windows ZIP / Setup.exe / SHA-256
  .staging/               # 每次打包獨立目錄
```

沒有任何 csproj 連結到 `macos/` 或 Swift 檔案；輸出不寫根目錄 `dist/`。平台間共享文件規格，沒有在 Windows 安裝過程讀取／搬動 Mac 作品庫。Windows CI 必須位於 GitHub 指定的 `.github/workflows/windows-build.yml`，但其路徑觸發與產物僅針對 Windows。

## 執行分工與效能設計

1. **UI 執行緒**只維持目前工具、即時手勢、選取與文件交易。每個手勢完成才記錄 Undo，不在 PointerMoved 序列化全文件。Undo 上限 64 個交易及約 32 MB 字串記錄；大型圖片的交易還需要差異式歷史以降記憶體。
2. **指標收集**使用 WinUI 的中間點，依時間戳排序並去重，避免回頭連線產生折痕。滑鼠採固定粗細，Surface 筆壓及傾角保留到資料。觸控暫不畫墨水，以避免手掌把筆劃當成另一條輸入；不宣稱已做系統級 Palm Rejection。
3. **Win2D**保存已提交世界座標幾何，平移／縮放只改矩陣。即時筆跡每 64 個穩定曲線段建立快取，尾段獨立重建。縮圖與 PNG 共用渲染器；GPU 資源在換板／裝置重建／視窗結束釋放。
4. **可見範圍**使用含旋轉與線寬 padding 的保守 AABB 排除畫面外物件。目前仍逐物件遍歷；空間索引、分區快取與延遲量測是後續性能工作，沒有宣稱百萬點滿幀。
5. **保存**在 UI 取得快照後背景寫檔，使用唯一 tmp、Flush(true)、File.Replace 與備份。成功後才更新 UI 保存世代；保存期間新編輯不被標成已保存。使用 semaphore／跨程序 file lock，磁碟 revision 較新時拒絕覆寫。
6. **首頁**正常讀小型 metadata／縮圖，缺少索引時從文件補回。錯誤有明確對話框，不靜默把未來版本或損毀文件變空白。
7. **文字輸入**使用原生 TextBox，避免手刻 IME；只在畫布 PointerWheel 接收縮放，編輯文字期間停止畫布滾輪操作。

Win2D 支援 GPU 加速，但不保證硬體／驅動條件下永遠使用 GPU。[官方 Win2D 指南](https://learn.microsoft.com/en-us/windows/apps/develop/win2d/quick-start)。

## Ink 與 AOT 的界線

原骨架名稱 `WindowsInkCoordinator` 實際是 `PointerPressed/Moved` 收集器，沒有 InkPresenter。穩定 WinUI 的 InkCanvas 仍不受支援，官方提出 Win2D＋pointer input 等替代方案。[官方支援表](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/what-is-supported)。本階段採穩定 API；獨立輸入／預測需另外建 InkDesktopHost／原生橋接原型並量測。

**暫不啟用 Native AOT、trimming 或 single-file 發佈。** JSON extension data、XAML、WinRT 投影與 Win2D 先以穩定自包含部署落地；待功能與映射驗收後再比較 AOT 啟動和大小。AOT 不等於沒有執行期，更不能由編譯選項推導固定 80ms／50 MB。[官方自包含部署](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps)。

## 發行與資料

兩種包使用同一個 self-contained publish，避免功能分岔：安裝版包入 Inno Setup，免安裝版注入 `portable.dat` 和空 `Data/` 後壓縮。免安裝版不因偶然出現 Data 資料夾而切換模式、不在無法寫入時偷用 AppData；失敗會顯示說明。

Windows Shell 依最後副檔名判定；`.blackboard.json` 不能作為複合副檔名關聯而覆蓋全域 `.json`。安裝版另提供可選 `.heiban` OpenWithProgids；內容仍符合同一 JSON 契約。解除安裝只移除程式與自身關聯，保留作品。

Portable 是資料路由策略，並不表示作業系統不留 MRU／執行歷史。正式簽章、MSIX、自動更新與 Store 發行尚未完成，不能把安裝包稱作沙盒。

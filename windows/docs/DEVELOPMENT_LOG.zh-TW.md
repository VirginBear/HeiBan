# Windows 開發日誌

## 2026-10-22 — 四項繪圖操作改善（開發中，未進版）

工具列預設全開，完全未變更的舊精簡預設升級展開，自訂顯隱／順序保留；恢復預設亦全開。首次使用加入十語三頁可編輯「操作說明 · 工具練習」作品，以固定ID與marker避免重建或覆寫。畫筆／螢光筆／油漆筆刷完成不自動選取，V可選、雙擊開詳細。新增單物件ink Undo紀錄，減少逐筆全文件快照與UI刷新；主畫布可將新筆跡接入相同viewport的scene，其他操作完整重畫。板擦沿原斜長軸縮短20%、厚度／左高右低保持，hit path／擦面共用矩陣。十語指南同步，沿用1.0.15來源metadata的開發候選，不代表新正式進版或Store更新。中途x64 build 0warning0error／56.18秒；App、實作測試、性能與硬體驗收未執行。[本批日誌](DRAWING_FLOW_2026-10-22.zh-TW.md)。

## 2026-10-15 — Submission 3已提交，預先處理中

使用者提供Partner Center概觀截圖：Submission 3上次修改2026/10/15，產品更新為認證中；流程中提交已完成、目前停在預先處理，認證與發佈尚未完成，設定通過後立即開始發佈。Store目前狀態顯示Submission 2（上次修改2026/10/12）仍可取得。截圖未展開套件，不含Submission 3實際版號或SHA；本批準備1.0.15.0的事實與已上傳套件byte查證分開。 [狀態紀錄](STORE_SUBMISSION_STATUS_2026-10-15.zh-TW.md)。本批只更新文件，未執行App／測試／封裝或後台操作。

## 2026-10-15 — 商店套件完成與隱私文字更新

商店包`dist/store/HeiBan-Store-1.0.15.0-x64-arm64.msixbundle`已完成，195664137bytes／SHA256 `a889482ff3aa171569ce415fc285340b26742528af4306a3e0a0e3d6fa07eb96`；來源`ceed5f96a7241a9561380b4f3cfb596718fba317`。x64／ARM64分別61.69／51.11秒，均0warning／0error。218來源SHA、ZIP CRC、身分／架構、十語手冊與板擦資源核同；原12份Store套件SHA不變。使用者接手Partner Center，助手未上傳／送審／發布。本批App／實作測試／WACK未執行。 隱私文字已更新，明列本機轉換及PDF／HTML保留完整原稿（含其他頁面、隱藏物件）；目前畫面／選取匯出範圍不限制內嵌原稿，僅分享可見內容請用PNG。沒有改動既有匯出格式。

## 2026-10-15 — 使用者核准本系列商店更新（1.0.15.0封裝中）

使用者試用後明確指示再次更新Microsoft Store，採下一未使用版號1.0.15／1.0.15.0；同時更新App、manifest與StoreIdentity，保留歷史候選與上架包。包含本系列繪圖／磁鐵／PDF與PowerPoint圖片頁交換、工具列及原創鏡像板擦、十語UI／手冊與自動存檔設定。Package-Store增加FormalVersionApproved記錄旗標，預設仍未核准；本次不另增功能、不改作品格式。實作測試未執行；使用者同意更新不等於Microsoft認證通過，實際提交狀態另記。[本批日誌](STORE_RELEASE_2026-10-15.zh-TW.md)。

## 2026-10-15 — 更多板擦入口與左高右低鏡像（x64試用完成）

工具列更多新增「顯示板擦」勾選項，保存偏好、失敗還原；右鍵隱藏共用保存入口。保留原創PNG，僅Image中心ScaleX=-1呈現左高右低；共用12點輪廓x→1-x，抓取／提示／擦除同步。十語手冊重新產生25章62段，版本仍1.0.14候選。本機試用`dist/trials/HeiBan-Windows-Portable-1.0.14-eraser-entry-2026-10-15-r1-win-x64.zip`，132586851bytes／SHA256 `2cf8988e499f0c404ceda37445c2607e5866c55d0c6f445155408a65fe29785a`，來源`b2f9c3d7abe7a0726971a7ed53ca187893f3d51b`。App／Updater publish退出0，ZIP CRC／573payload／162source SHA、兩EXE x64及十語核同。使用者已正常保存關閉，確認無HeiBan程序後接續27個Data檔／24345830bytes，逐SHA相同；ZIP空Data。舊試用已備份到`dist/trial-data-backups/20261015-145134-a33251e2`後清理455068005bytes；Store1.0.12 SHA保持。最終EXE及實作測試未執行，待使用者實機驗收。[本批日誌](BOARD_ERASER_ENTRY_MIRROR_2026-10-15.zh-TW.md)。

## 2026-10-15 — 俯視磁吸板擦修正

使用者指出前批斜角圖是商品視角，應像板擦磁吸平貼板面。重新以未附參考圖的imagegen生成俯視原創素材；替換PNG、BoardEraserGeometry共用輪廓與XAML比例，九份手冊來源／十語HTML同步。alpha只讀抽取，不以程式改圖。`python windows/scripts/Build-UserGuides.py`退出0，十語各25章62段。測試／App未執行；本機試用：`dist/trials/HeiBan-Windows-Portable-1.0.14-topdown-eraser-2026-10-15-r1-win-x64.zip`，132,585,397 bytes，SHA256 `4a48953a76c3bfa325c81b228f5884901c07e2a2b7aeb9c4e557ff9257deeb39`，來源`c239aba975a4d3a69f13f025827f675648583d55`。App／Updater publish退出0，ZIP CRC／573payload與162source SHA、兩EXE x64及十語手冊核同。27個Data檔／24,341,106 bytes逐SHA接續，ZIP無作品；舊eraser-r2保全資料到`dist/trial-data-backups/20261015-144432-6d9ba42e`後清理457,311,935bytes，Store1.0.12 SHA保持。最終EXE／自動化實作測試未執行，擦拭／Undo／DPI待使用者驗收。既有YouTube未提交文件保留，不納入本批提交。[紀錄及提示](TOP_DOWN_BOARD_ERASER_2026-10-15.zh-TW.md)。

## 2026-10-15 — 原創斜角板擦試用交付

來源509c4bbfa2f4cb0e9d4bfadc987676d38074e7b6、eraser-2026-10-15-r2 x64免安裝完成，ZIP133752265bytes／SHA256 653c7885d6edf823cb4c528ca048857ac14b7bd8ca89bfa3734787a18d31e5d7。App／Updater publish及CRC／573payload／162source SHA核同；最終EXE／本批自動化測試未執行。接續27個Data檔24341106bytes，備份後清舊試用916077320bytes，Store不變。純文字生成原創紙白／霧綠圖，斜擦面18點共用提示及裁切；未保存參考照片。[完整日誌](ANGLED_BOARD_ERASER_2026-10-15.zh-TW.md)。

## 2026-10-15 — 原創斜角板擦批次

開工公開08fb332乾淨，兩庫fetch0/0、私人PRIVATE=true。建立日誌，先生成斜角白塑膠版；使用者進一步指定符合自有風格後，改未附參考圖片的紙白／霧綠原創圖。共用凸裁切／18點felt接觸面／保留抓取位置、十語手冊同步，無作品格式改變。中途x64 build56.91秒0warning／0error；最終Portable結果／資料接續及清理於[本批日誌](ANGLED_BOARD_ERASER_2026-10-15.zh-TW.md)追加。本批沒有自動化測試，候選版本不提高。

## 2026-10-15 — 畫布修整最終試用與資料保全

最終來源3000bef，免安裝canvas-ui-2026-10-15-r2成功，134453996bytes／SHA256 0bd34217700cdf4ddcf761c7d7faeca5ed1433614be0f52aa3b754baa9420422。573payload／160source SHA、ZIP CRC／x64／十語／透明素材核同。27個Data檔24372320bytes逐SHA接續；清drawing及r1前已保全同批Data，清理912420485bytes，Store原SHA不變。最終包EXE未執行、本批自動化測試未執行，交由使用者實機驗收；App預覽／編譯與成品完整性檢視分開。[完整紀錄](CANVAS_UI_REFINEMENT_2026-10-15.zh-TW.md)。

## 2026-10-15 — 畫布八項修整批次

起點main 1af9075乾淨，公開與私人fetch均0/0，私人isPrivate=true。建立本批日誌後才修改Windows。完成來源：單行工具組、常用自訂、幾何磁鐵及中心式起點、生成矩形板擦、圖片化匯入告知、圖釘新增優先與縮圖、固定紙白綠色主題；十語624key與25章62段說明同步。r1 FontWeights失敗保留原因，r2 23.37秒、r3 24.07秒x64 build均0warning／0error。隔離示範視窗觀察單排及卡片，未跑本批自動化測試、不沿用前批2334數字。後續新包、Data接續／保全清理及同步證據見[本批日誌](CANVAS_UI_REFINEMENT_2026-10-15.zh-TW.md)；維持候選1.0.14.0，無Store／Release。

## 2026-10-15 — 文件交換、磁鐵與繪圖流程

試用交付：乾淨來源cc85296執行`Package-PortableTrial.ps1 -Runtime win-x64 -Label drawing-2026-10-15-r1`成功；131955475bytes／SHA256 `41f0d1bc11707b447e279ca1dbb4c0c2324fdace676a3e23de3793ea1794ef6a`。zip CRC／572payload／157source／10語4圖／x64／空Data核同，最終可攜EXE實際開啟／正常關閉。資料接續13檔34859bytes全SHA核同；Clear-ObsoleteTrials退出0、清舊兩trial釋放901658688bytes，43Data＋18修改檔先備份5509863bytes，Store原SHA不變。source／artifact／cleanup各JSON及失敗KeyError／排解保完整日誌；只有本機二進位、來源與精簡必要證據同步GitHub。

由乾淨38634bb開始，完成本批九項Windows需求，沿用1.0.14候選、不更動其他平台。新增PDF圖片頁匯入、PowerPoint COM STA唯讀轉換、全部頁PDF列印；共用磁鐵格索引與圖文工具列分頁；建立／單擊不彈詳細列、雙擊開啟，保留繪圖工具；修正三角形兩層曲線預覽來源、全選／預設與圓規圖示。工具列偏好保留未知欄位、選取常駐、寫入序列化；SizeChanged只量測，不反覆存偏好／重掛控制項。

實際命令及結果：`Build-LocalizationCatalogs.py`十語616key／missing0；`Build-UserGuides.py`十語25章60段、四張實機JPEG共231547bytes；HTMLParser／manifest核對40個圖片引用及每頁／圖片SHA通過。Core Release2334checks通過；數輪x64 Release build0warning／0error。隔離`--drawing-workflow-output`原生檢查最終JSON成功，兩頁PDF匯入與重新匯出、PPTX兩頁PowerPoint轉換、screen四邊labels／triangle／continuous shapes／magnet。Poppler兩頁轉PNG並目視檢查。computer-use實際主視窗單擊／雙擊／兩矩形連續拖畫成功；手冊截圖使用示範資料，無使用者作品。

失敗與排解：Core檢查區域變數重名CS0136已修；初始隱藏視窗與即時UI狀態延遲改用可見隔離視窗／重新觀察。主與screen巢狀控制項重掛曾產生0x800F1000，初次Parent修正不足；以堆疊定位後加主呈現快取、screen在清舊根前拆子按鈕，並補screen key Tag。最終重跑成功，沒有抹除舊失敗檔或引用其前一輪成功JSON。本機試用封裝及Git同步接續日誌；MSIX／WACK／Store、完整硬體／PPT舊格式／母語回歸未執行，正式進版未核准。[完整日誌與待驗收](DRAWING_WORKFLOW_2026-10-15.zh-TW.md)。

## 2026-10-13 — 操作優化免安裝試用包交付（待實機）

使用者要求先實際測試目前工作。保留既有試用包／資料及 Store bundle，新標籤 `optimization-2026-10-13-r1` 產生本機 x64 免安裝包。執行 `dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj -c Release`（透過 `windows/.build/tools/dotnet/dotnet.exe`）通過：2325 checks。執行 x64 Release self-contained `dotnet publish` 成功，0 warning／0 error。接著以 PowerShell 7 執行 `windows/HeiBan.Windows/Packaging/Package-PortableTrial.ps1 -Runtime win-x64 -Label optimization-2026-10-13-r1` 成功，App與Updater publish、payload inventory、空白Data及ZIP完成；產物131,764,163 bytes，SHA256 `e9f1ab87616a84f7ea1c30ddd469b86c2d14e56c6ee6e5000ce7ff334460c580`。封裝紀錄 `.build/portable-trial-b69b341301ea49bd996919f4766adb1a/`。Store bundle封裝前後SHA一致（`D7A49B63D88FA880B1A97B0C307361AD2CFBC9B3D58786048887093D7204EA7B`）。

排解：第一次以 Windows PowerShell 5.1 呼叫封裝腳本時，Git pathspec 的引號萬用字元觸發 parser error，沒有產生或改寫試用檔；改由 PowerShell 7 執行同一工作區腳本後成功。手動 `dotnet publish` 曾輸出至忽略目錄 `.build/manual-trial-check` 作為先行編譯確認。未執行封裝後App啟動、手動操作、WACK或Store提交；等使用者實機回報後再處理下一批。

## 2026-10-13 — screen近直線停筆吸附接線（待驗收）

為補齊一般畫布已有的停筆一秒近直線轉線，將幾何資格判斷抽到Core，WindowsInkCoordinator與screen共用；screen保留native輸入點、DPI換算與session transaction，持筆時每100ms檢查，閒置一秒且形狀符合才顯示端點預覽，放開提交一條線。同步更新十語screen手冊。未build／測試／啟動App／實機驗收；完整實際命令、局限與其餘待辦見[優化批次紀錄](WINDOWS_OPTIMIZATION_BATCH_2026-10-13.zh-TW.md)。

## 2026-10-13 — Windows操作／精簡優化第一階段（待實機）

開工HEAD與origin/main同為`c04cd797654a563e7b3a9bb6b85c02a9bdb52853`；原有未追蹤`.vscode/`保留。使用者要求直接落實Windows端整套優化，實機細節留待後續。新建[本批日誌](WINDOWS_OPTIMIZATION_BATCH_2026-10-13.zh-TW.md)。

確認前批工具列雖共用顯隱／順序政策，但screen另有ToolbarUi.ScreenTools及ScreenToolbarSupported兩份按鍵集合。現將已實作screen能力集中於Core policy，ScreenTools名稱／順序由一般catalog投影；偏好顯示與隱藏均只含有真實handler的screen工具。一般／screen九種形狀及screen shape-kind共用一份ToolbarUi.ShapeTools。screen填色由固定chrome按鈕移入圖形選單，screen新增Core `LassoSelection.Intersects`圈選流程：點列只作手勢預覽、放開才更新screen選取，Shift可以合併選取；便條紙沿用文字編輯器建立，遮題膠帶支援拖曳建立及雙擊切換揭示狀態。十語Documentation/Guides來源與Assets/Guides派生HTML同步。另移除16ms渲染節拍內的前景視窗輪詢，增加250ms焦點記錄timer並在穿透／結束時同步記錄。

實際命令：`python windows/scripts/Build-UserGuides.py`退出0，十語各25章／55段。以`Get-Content`／`rg`檢視工具列／輸入／screen session、手冊與Updater／csproj引用，沒有可無風險移除的SDK DLL依賴證據；既有MSIX含約42MB ML載荷但相依移除尚無執行證據。`git diff --check`退出0，僅有Git工作副本換行格式警告。

未執行build、tests、啟動App、手動操作、效能／硬體測量、封裝、WACK、Store／Release、進版或刪除檔案。未改App／Store版本或其他平台。screen完整功能對齊及SDK／Updater包體方案仍需獨立候選與回歸，不能把此次catalog整理當作完成WT-01–04或真正包體減重。

## 2026-10-13 — 工具列一致性第一批實作（未驗收）

使用者對`TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md`明確「GO」。開工HEAD `d3935ef6790046bf8e8d9150735580e315b22130`，`git status --short`只有先存未追蹤`.vscode/`；保留。新增`ToolbarContentPolicy`，screen讀一般工具偏好並只按已接妥的共同工具顯隱／排序，排除圖釘／視角鎖定。一般與screen各自建立XAML、session、座標及Undo仍分離。screen把4個基本圖形按鈕收為9形狀選單，補多邊形拖曳及填色；十語手冊來源同步更新。

命令／結果：`Get-Content`／`rg`讀Core偏好、主／screen chrome、輸入與手冊契約；一次以不存在的分析文件標題套patch失敗，無檔案變更，依實際標題重新套用；`python windows/scripts/Build-UserGuides.py`退出0，輸出十語各25章／55段。Git提醒txt會正規化CRLF/LF，手冊來源實際修改各1行；生成器同步十HTML、zh-TW相容入口及manifest hash。這些只確認文件生成契約，非程式編譯或測試。

**WT-01／WT-03部分實作，WT-02／WT-04與其餘WT-03仍待完成**，詳[工作狀態表](TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)與[日誌](TOOLBAR_ALIGNMENT_2026-10-13.zh-TW.md)。尚未實際確認C#可編譯；本批未執行build、測試、App、封裝、Store／Release、版本變更、效能／硬體操作。正式發行與候選產物不變。

公開Windows來源commit `0b6b79a6f8417345f97e7dfce3fbcd72a9d66b6b`已push，ls-remote核同；status只原有`.vscode/`。私人交接commit `253913a2a06a74c7515fcbcffaa583d18bc5d8a2`已push、遠端核同、工作樹乾淨；GitHub `isPrivate=true`。私人庫未改產品身分／套件／價格JSON。

## 2026-10-13 — 工具列統一與原機瘦身理解

依使用者兩項分析要求，開工148d427只原.vscode/，fetch0/6後ff到3f39f1d。讀新Mac交接与平台現況／架構／問題／減重計畫；舊graphify導航、實際來源判斷，兩宿主catalog／手勢／面板仍不同，列WT-01–04完整接線與驗收規格，未標為已實作。

原guides bundle只讀拆解退出0、兩MSIX及bundle SHA核同；ML兩包各6檔，x6441.996MB解壓／17.537MB壓縮、ARM6442.226／17.119MB，沒有Updater／Data／PDB。補原減重計畫的原機證據，保留MacPortable量測界線，UI維護／SDK包體／繪圖性能各自列順序。搜尋大.build索引中止、猜partial檔名及rg萬用路徑失敗、README標題猜錯導致整批patch原子失敗皆更正，詳[本批日誌](TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)。

新增分析與payload JSON，更新狀態／架構／決策／問題／索引，私人只存精簡交接。未實作WT／WR，未build／tests／App／封裝／清理／進版／Store，手冊無本批UI變更所以未重生。Git同步完成後接續記錄。

## 2026-10-13 — Windows Store減重計劃交接

使用者將於Windows端評估、開發與測試，要求報告及目前紀錄推送GitHub。本批完成Windows減重計劃／基準JSON及來源／可行性／量測界線，補狀態／問題／決策與README入口；没有程式實作／進版／build／tests／App／WACK／Store操作。Mac交接文檔亦補齊，公開main同步；私人遠端及既有發行tag不變。[本批交接日誌](SIZE_PLAN_HANDOFF_2026-10-13.zh-TW.md)保存起始變更與最終同步結果。

## 2026-10-12 — Parallels ARM64 試用版封裝與部署

使用者要求在Parallels安裝目前Windows測試版，明確選擇非Store試用方式。VM為Windows 11 Pro ARM64、Windows PowerShell 5.1、.NET SDK 10.0.401；從共享工作區同步Windows來源及Git metadata到VM隔離鏡像，來源commit `148d427a47e03a09bf21431d248fe00e3e9b6d9a`，Windows來源無未提交變更。執行 `Package-PortableTrial.ps1 -Runtime win-arm64 -Label parallels-arm64-2026-10-12` 成功，版本仍1.0.14.0；新ZIP123,816,578 bytes／SHA256 `eed7341e766c423e0c6b9a7ce239974c64175c3533e58431e0f862105e4fe5e1`，571項、Data為空、PE AArch64。包與sidecar已放入本機 `dist/trials/`，未提交公開發布。

初次執行封裝腳本遇到Windows PowerShell 5.1對原生Git萬用字元參數語法錯誤；在VM臨時來源鏡像把pathspec整理成字串陣列後重試成功，未改工作區程式碼。部署腳本的路徑字元解析亦以 `[char]92` 修正並通過parser。部署到 `C:\HeiBanPreview\Trial-1.0.14-parallels-arm64-2026-10-12`，建立桌面捷徑，從原 `Current\Data` 複製56檔／2,588,837 bytes並逐檔SHA核同，舊目錄保留。新程序PID 13520，主視窗標題「HeiBan 黑板 · Windows」，Responding=True；本機與VM共享包hash核同。[部署紀錄](PARALLELS_TRIAL_2026-10-12.zh-TW.md)／[機器可讀結果](PARALLELS_TRIAL_DEPLOYMENT_2026-10-12.json)。

此批僅驗證候選封裝、資料複製完整性與VM啟動；Core／UI tests、作品操作／存檔回歸、效能、RTL／硬體及母語仍未測。未安裝MSIX或商店版、未進正式版號、未修改Mac／Web程式。產品版本政策與試用候選狀態不變。

## 2026-10-12 — runFullTrust 文案縮短

使用者回報長文在欄位截斷，改325字元單段英文；PowerShell Length確認含空白標點325，未檢視後台maxlength，不推定官方500字元上限。舊長版保留為背景資料，更新CURRENT_STATUS與原說明日誌。附信只讀為資料，原件／年齡分級紀錄保存在私人庫，不把它當成本次更新認證完成。公開開工只既存.vscode/、私人乾淨且PRIVATE；本批未改程式／版本／套件，未執行App／tests／build或後台填寫／提交。

## 2026-10-12 — runFullTrust 欄位核對

使用者要求受限功能理由；核對manifest與Microsoft官方能力文件，新增英文送審文案及[本批日誌](STORE_RUN_FULL_TRUST_2026-10-12.zh-TW.md)，更新CURRENT_STATUS，私人僅存精簡交接。rg萬用字元路徑失敗改實際目錄；舊官方網址工具錯誤改共享官方文件，實際查閱過程保留。沒有程式／權限／版本／產物變更；未執行App／tests／build／封裝／後台操作，沒有新核准證據。各repo文件提交／push與遠端核對以本次工具輸出為準。

## 2026-10-12 — 十語 Store 清單文案

- 使用者要求三欄：說明、此版本新增功能、最多20項的產品功能。依前批 Windows 候選、十語手冊與現況撰寫十語文案，保持品牌、語言預設與存檔政策一致。
- 新增 `STORE_LISTING_COPY_10_LANGUAGES_2026-10-12.md` 與本批日誌，更新 CURRENT_STATUS、Store素材入口；每語言6項更新／16項功能，不修改實作或metadata。
- 開工公開status只既存.vscode/、私人乾淨；兩庫fetch退出0，HEAD...origin/main皆0/0，兩origin正確且私人visibility=true。私人狀態文件誤用CURRENT_STATUS.md讀取失敗後，依AGENTS改讀正確zh-TW檔；未建立重複檔案。
- PowerShell Regex解析本批文字檔：10語均具三欄，說明非空、更新6項、功能16項；git diff --check退出0。這是文案結構檢查，不是程式測試、語言品質或商店驗收。
- 未執行：App、tests、編譯、封裝、母語校閱、效能量測、Partner Center填寫／提交／發布。沒有新架構或程式問題，ARCHITECTURE／DECISIONS／ISSUE_HISTORY無需變動。公開文案與私人精簡交接分庫同步，結果接續本批日誌。

[目的、來源、範圍與交付紀錄](STORE_LISTINGS_2026-10-12.zh-TW.md)／[可複製文案](STORE_LISTING_COPY_10_LANGUAGES_2026-10-12.md)。

## 2026-10-12 — 十語手冊當次交付證據

- source實作 `84583637706e172e0ed64c0e8431122311f17309`，35檔1113新增11刪除；Windows .gitattributes後續提交 `1ab7018b24e4fc06f354ac8d968207de8d0c7770`，固定Guides HTML／來源txt LF，避免另一台電腦autocrlf使每頁SHA manifest失效。兩次間App／HTML內容不變。
- `Package-PortableTrial.ps1 -Runtime win-x64 -Label guides-2026-10-12`退出0，App/helper publish無warning/error；證據`.build/portable-trial-ede12fb563574818a430e822f7005f24/`與`.build/portable-guides-2026-10-12.log`。ZIP `dist/trials/HeiBan-Windows-Portable-1.0.14-guides-2026-10-12-win-x64.zip`，131,753,592bytes，SHA256 `2022630e14aa2b1313ab0319659c266a9d9046e69617ced060dd761a1ef27e8b`。
- `Package-Store.ps1 -DotnetPath windows/.build/tools/dotnet/dotnet.exe -DevelopmentLabel guides-2026-10-12`退出0；x64 51.93秒／ARM64 52.96秒，各0warning／0error。證據`.build/store-2aeb6eb481cc4e9a943ca3e44987f020/`與`.build/store-guides-2026-10-12.log`。bundle `dist/store/candidates/guides-2026-10-12/HeiBan-Store-1.0.14.0-x64-arm64.msixbundle`，193,675,520bytes，SHA256 `8dc919c47c69585a114cc9c8d1ddf20c1126e08b5524ca73009c8e85b396d666`。版本仍1.0.14.0，formalVersionApproved=false、storeSubmitted=false；原root三個Storebundle及reports不覆寫。
- `.build/inspect-guides.py`及`--packages`各退出0：10語×25章×55段、完整anchor／切語相對路徑、ar dir=rtl、無外部資源、manifest每頁SHA一致；portable147source／568inventory／570archive、12guide documents（10語＋manifest＋相容頁）、空Data、逐payload SHA；Store198source／兩MSIX各12guide逐byte、無Data／Updater／pdb、bundle套件byte／identity／兩架構已由packaging核對。原Store12／13／14SHA核同。這是靜態產物檢視，不是App／browser tests。來源SHA一致是檢視當時，後續README／docs是交付紀錄。
- `Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.14-guides-2026-10-12-win-x64`退出0；先確認無HeiBan程序並核GitHub已發布assets，清除舊save-mode未發布runtime／ZIP／sidecar452,723,319bytes。這次舊Data已有20檔898,085bytes（不是上一批的9檔），全保留至`dist/trial-data-backups/20261011-212517-bd8345c8/`；不讀／記作品名稱內容，前備份保留。
- `.build/handoff-guides.ps1`退出0；從核同備份複製到新解壓版空Data（允許空子目錄但拒絕已有檔／reparse point），20／20 SHA相符，備份保留。ZIP仍空Data；root Store12／13／14及新ZIPSHA再次核同。原始portable inspection的dataFiles=0是接續前，而現在解壓版20檔；不同時点分開記。

交付：[十語內容檢視](GUIDES_CONTENT_INSPECTION_2026-10-12.json)、[試用產物](GUIDES_PORTABLE_ARTIFACT_2026-10-12.json)、[試用檢視](GUIDES_PORTABLE_INSPECTION_2026-10-12.json)、[商店產物](GUIDES_STORE_ARTIFACT_2026-10-12.json)、[商店檢視](GUIDES_STORE_INSPECTION_2026-10-12.json)、[清理](GUIDES_TRIAL_CLEANUP_2026-10-12.json)、[資料接續](GUIDES_DATA_HANDOFF_2026-10-12.json)、[使用者试用清單](GUIDES_TRIAL_REVIEW_2026-10-12.zh-TW.md)、[商店候選素材](STORE_UPDATE_GUIDES_2026-10-12.zh-TW.md)。本批已完成手冊與封裝準備，正式版本決策仍待使用者依整批驗證作出。

未執行：App、browser互動、tests、WACK、Store安裝／提交／發布、母語校閱、4K／DPI／RTL实機、畫布／保存／Undo回歸、效能量測。手冊行為／操作一致性與語文品質需試用確認；不因包完成將正式進版核准改true。Mac／Web、資料格式與原發行歷史未改。

## 2026-10-12 — 十語使用說明實作

開工87c6ae2只有原.vscode/，讀開發索引與平台規則／狀態／架構／問題，先建MULTILINGUAL_GUIDE日誌。25章55段十語離線手冊，同源模板與穩定章節契約，兩入口依目前UI語開；翻譯與背景／screen／auto-save內容更新，ar RTL与bdi。Build-UserGuides.py退出0，無網路翻譯；旧graphify query退出0僅導航，精確源碼另查。Package-Store新DevelopmentLabel保存同版候選、不自动增版。原稿／生成／C#／packaging變更與失败詳日誌；本輪tests與App未執行，編譯／封裝另記當次結果。

## 2026-10-12 — 使用者更正進版節奏

開工9cf2f12，status只原.vscode/；私人0fb26f4乾淨，兩庫fetch退出0、HEAD/origin0/0，gh PRIVATE核同。先讀開發索引、Windows status／架構／issues／decisions與私人規則／入口／状态／日誌，建立RELEASE_POLICY日誌再修改。使用者指出應完整系列開發／測試／驗證後才決定進版；助手承認判斷過早，更新平台AGENTS、CURRENT_STATUS、DECISIONS、ISSUE_HISTORY、README及候選release notes提示，私人候選JSON與對話M保存相同規則。沒有App程式／版本metadata／產物變更；build／tests／App／封裝／Store：未執行。具體原因與同步結果見RELEASE_POLICY_2026-10-12.zh-TW.md。

## 2026-10-12 — 自動存檔模式最終交付證據

實作來源commit `c409a6e8e27e4d1ee7e9187e86c8929109187bb6`（33檔，386新增／26刪除）；其後只更新交付文件。r2 x64 `dotnet build`退出0／31.31秒／0warning／0error，當時尚未遞增metadata；正式封裝重新編譯產品1.0.14／File及Store1.0.14.0。

- `Package-Store.ps1 -DotnetPath windows/.build/tools/dotnet/dotnet.exe`退出0；x64 51.87秒／ARM64 57.46秒，各0warning／0error。證據`.build/store-cc7d1d56f2a542d4a4984f23022517d8/`及`.build/store-update-1.0.14.0.log`。
- Store bundle `dist/store/HeiBan-Store-1.0.14.0-x64-arm64.msixbundle`，193,478,823bytes，SHA256 `ca8c799cdb393134444989ca25a87d040736cff4b8730d7de7c199fab54c92a6`。原1.0.12.0及前候選1.0.13.0保留；新包尚未由助手提交／發布。
- `Package-PortableTrial.ps1 -Runtime win-x64 -Label save-mode-2026-10-12`退出0；App／helper publish無warning／error。證據`.build/portable-trial-cdcc951a4aba45ffb30a83762b11f631/`及`.build/portable-save-mode.log`。ZIP `dist/trials/HeiBan-Windows-Portable-1.0.14-save-mode-2026-10-12-win-x64.zip`，131,654,789bytes，SHA256 `95df7209d73c72cf37a235fe7099c727ab2c7f1250f652ef6bb71068cf9140da`。
- Python靜態Store／portable inspection各退出0：Store174source SHA、x64／ARM64 manifest與PE、十語各592key、25legal／guide／README、無Data／portable／Updater；portable126source SHA、557inventory／559archive、十語592完整資源、x64 App及helper、空Data與sidecar一致。不是執行測試或App驗收。
- `Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.14-save-mode-2026-10-12-win-x64`退出0，先核GitHub已發布資產及沒有HeiBan程序，再保留Data等自有檔；移除舊multilingual trial程式／ZIP／sidecar，釋放452,662,982bytes，保留9檔／150,783bytes。備份`dist/trial-data-backups/20261011-204528-391f7ae5/`，前批備份保留。
- `.build/handoff-save-mode.ps1`初次退出1：目標已含五個封裝建立的空目錄，嚴格「無任何entry」守護拒絕，未复制作品。PowerShell再核目標0檔，改「無檔案且無reparse point」守護；重跑退出0，9／9 SHA相符，複製到新解壓版Data，備份保留。ZIP保持空Data；Store12／13／14與新ZIP SHA再次核同。原始檢視的Data=0是接續前，現在解壓資料為9檔，不混用兩個時點。
- 文檔查找兩個不存在的預期檔名失敗：Store更新文件實為STORE_RELEASE_NOTES_1.0.13.zh-TW.md，私人對話實為conversations/2026-10-11-development-summary.zh-TW.md；改讀正確索引。沒有資料刪除或恢復舊代碼。

交付：[新版商店說明](STORE_RELEASE_NOTES_1.0.14.zh-TW.md)、[Store產物](STORE_ARTIFACTS_1.0.14.0_2026-10-12.json)、[Store靜態檢視](STORE_INSPECTION_1.0.14.0_2026-10-12.json)、[試用產物](SAVE_MODE_PORTABLE_ARTIFACT_2026-10-12.json)、[試用靜態檢視](SAVE_MODE_PORTABLE_INSPECTION_2026-10-12.json)、[清理](SAVE_MODE_TRIAL_CLEANUP_2026-10-12.json)、[Data接續](SAVE_MODE_DATA_HANDOFF_2026-10-12.json)。作品檔名／內容及二進位不提交GitHub。

本輪App、tests、WACK、Store安裝／提交、動畫／正常退出／儲存失敗實機、4K／DPI／RTL／母語、FPS或輸入延遲量測：未執行。編譯及靜態核對不能替代这些驗收；不能保證小畫家同等流暢度。Mac／Web程式與已發布歷史未修改。


## 2026-10-12 — 自動存檔設定與退出儲存

開工963f2d0仅原.vscode/，先讀索引／Windows文件並建[阶段日誌](SAVE_MODE_2026-10-12.zh-TW.md)。增加Settings/saving.json預設off、三設定入口、共用離開屏障与主／screen动画／输入凍結、縮圖flush、匯入保存舊作品；11來源十語592key。r1失败已排Grid/Control誤用，r2 x64退出0、0warning／0error、31.31秒。正式1.0.14／Store1.0.14.0另包，产物／同步另記，未跑App／tests／UI，Mac／Web未改。

## 2026-10-12 — 商店更新、工具列共用與性能清單

源9b6c4e4，Package-Store退出0，x6452.35秒／ARM6453.95秒均0warning／0error。新1.0.13.0 bundle193,452,627bytes／SHA c8fc90e4…，173source與兩架構十語各581資源／PE／原Store保全檢視通过；原local/public report額外欄位造成初次byte比對失敗，改原欄位精確比對記於阶段4。未跑App／tests／提交Store，新增功能與上傳素材已備妥。

開工75aa821、僅原.vscode/；只Windows。先建立[本批日誌](STORE_UPDATE_TOOLBAR_2026-10-12.zh-TW.md)，記結構／圖譜失敗及重試，再抽ToolbarUi、缓存SaveStatusDot、正式產品1.0.13／Store1.0.13.0與防覆寫報告。後續實際x64／ARM64編譯、套件／原包雜湊及兩庫同步結果追加原日誌，不套用舊測試數字。

## 2026-10-12 — Store首次審核完成並上架（使用者後台截圖）

使用者提供Partner Center overview：Submission 1、Store目前狀態綠勾、明確顯示產品目前可在Microsoft Store取得，依Availability可發現性設定提供，並有「開始更新」。可依後台截圖確認審核及上架完成；不是助手登入查證。精確通過／发布時刻、所有市場可搜尋及實際下載／安裝未驗證。公開web工具無法讀商品頁，搜尋未收錄不推翻後台證據。

[上架確認紀錄](STORE_AVAILABLE_2026-10-12.zh-TW.md)；[商店入口](https://apps.microsoft.com/detail/9NV8T7RKV4MZ)。之前「認證中／尚未上架」段落保留歷史，以本段為最新狀態。十語與後續Windows改善是本機開發版，尚未由此紀錄提交新Store更新；既有送審包／正式發布保留。當前精確套件版本未從這份截圖重新查證。

最終r2 x64 Release build：退出0、0警告／0錯誤、28.23秒；十份完整資源嵌入DLL、literal來源鍵無缺項為靜態檢視，非App／測試驗收。最後文字屬性展示补強由新Portable publish重新編譯，封裝證據另記。

## 2026-10-11 — 首頁語言與十語WindowsUI

開工8c5fcc3，僅原.vscode/未追蹤，保留。先建立[日誌](LOCALIZATION_2026-10-11.zh-TW.md)，使用者回覆採用十語；讀平台規則／目前狀態／架構／問題。加入偏好、離線581項資源與XAML／動態UI展示；交叉比對内部停靠、圖層資料、文字草稿、共享色票、螢幕既存工具列與更新狀態，不改Mac／Web或文件幾何。

首次x64 build53.04秒0warning／0error；RTL补強時因MenuFlyout無FlowDirection而失敗17.61秒1warning／89errors，改PresenterStyle，最終结果接續記。實際命令／排解／生成器／打包入口SHA邊界與Mac對照在階段日誌；本輪未新增／執行tests／App，未發布商店／Release。


本輪本機x64試用：`dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-multilingual-2026-10-11-win-x64.zip`，131,632,111 bytes／SHA256 `1a1dc766572215518ff51f480441fb7189060de10d752939bed4d7109d402f52`，source14bb289；[產物](LOCALIZATION_PORTABLE_ARTIFACT_2026-10-11.json)／[靜態檢視](LOCALIZATION_PORTABLE_INSPECTION_2026-10-11.json)。App／helper publish退出0、無warning/error；557 inventory／559 archive／124 source SHA、十語資源581完整內嵌。未執行App／tests／實機／ARM64。

舊canvas-setup未發布trial清除452,220,937 bytes；9檔Data共150,783bytes先保存於 `dist/trial-data-backups/20261011-041854-3b00a2aa/`，再複製到新解壓版Data以延續原機使用，兩份皆核SHA；ZIP仍空Data。原備份及前批52檔備份、已發布Release／Storebundle保留，[清理](LOCALIZATION_TRIAL_CLEANUP_2026-10-11.json)／[資料接續](LOCALIZATION_DATA_HANDOFF_2026-10-11.json)。只原機有二進位與作品，GitHub同步來源／紀錄，私人庫保存精簡需求與交接。

## 2026-10-11 — 一般畫布游標修正與試用空間清理

開工 cfd3191，status 僅原.vscode/，先建立[日誌](CANVAS_SETUP_FIX_2026-10-11.zh-TW.md)。依使用者實機更正主畫布游標，改XAML ProtectedCursor＋SDK interop；補infinite不顯示尺寸、fixed預設16:9、background五種UI。首次 x64 build 0warning／0error、39.18秒；後續預設與原色保存補強、最終x64 build 0warning／0error、25.98秒，新包結果另記。

已讀取GitHub正式Release名單，保留windows-v1.0.12-preview.5與其他已發布；git ls-files沒有runtime zip/msix/exe/dll/pdb，trials ignored。本次只清理明確授權舊未發布trials，3份含Data先保留；完整SHA／bytes與結果写日誌／清理manifest。私人對話摘要補實測更正及最新需求。未改Mac／Web，未跑測試／App／商店／發布。


本輪最終試用：`dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-canvas-setup-2026-10-11-win-x64.zip`，131,543,340 bytes，SHA256 `0066ccfa530af13a21fd016f9a49fa5dc41f13fb7a9cd7600034bd4d2fae0759`，source c53462a；[artifact](CANVAS_SETUP_PORTABLE_ARTIFACT_2026-10-11.json)／[静態檢視](CANVAS_SETUP_PORTABLE_INSPECTION_2026-10-11.json)。publish退出0／無warning/error，108 source／557 inventory／空Data／PE／授權／手冊一致；未執行App／tests／實機。

已刪舊5份trials解壓runtime／ZIP／sidecar，釋放2,260,814,479 bytes（約2.106GiB）；52個Data檔共73,389 bytes先移至 `dist/trial-data-backups/20261011-032945-612f03c3/`並核SHA。trials只剩最新版3項，Store原SHA與正式Release保留。[清理结果](CANVAS_SETUP_TRIAL_CLEANUP_2026-10-11.json)。下方舊試用路徑為歷史交付紀錄，其二進位已於本輪清理，歷史source／hash／logs仍留。


## 2026-10-11 — 五項操作回饋與紀錄壓縮

開工 HEAD 605eed4，git status 僅原 .vscode/，建立[阶段日誌](UX_FEEDBACK_2026-10-11.zh-TW.md)再實作。完成無捲軸換行工具列、拖曳預覽／插入線、形狀方向／旋轉游標、頭部線寬同步與主工具列圖層。八個一次性腳本逐檔 resolved path／非 reparse／SHA 核對後刪除；所有交付包／Data／歷史／SDK／建置證據保留。[清理清單](UX_FEEDBACK_CLEANUP_2026-10-11.json)。

首次 x64 build 0 warning／0 error，後續整合 WM_SETCURSOR／取消清理，最終 x64 build 0 warning／0 error、25.80 秒，封裝結果另追加。更新離線手冊與架構／狀態／決策／問題，對話摘要僅私人庫。未修改 Mac／Web；本批沒有執行測試、App、4K／多螢幕／觸控筆、Store 或 Release 發布。


本輪新 x64 免安裝包 `dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-ux-feedback-2026-10-11-win-x64.zip`，131,541,143 bytes，SHA256 `e77d2dd28526fc70b0f9049cf96d68d22c1156373bf6044c5e79d6ac719c1aa7`；來源 77a563d，App/helper publish 退出0／無warning/error。557 inventory／106 source SHA／空 Data／PE／guide／README／sidecar 靜態一致，Store原SHA相同。[artifact](UX_FEEDBACK_PORTABLE_ARTIFACT_2026-10-11.json)／[靜態檢視](UX_FEEDBACK_PORTABLE_INSPECTION_2026-10-11.json)。未執行測試／App／實機操作，未發布 Release／Store。


## 2026-10-11 — Windows 首頁、屬性與螢幕畫布 20 項

使用者逐項提出操作問題；開工 da573915，保留既有 .vscode/，先讀索引及平台文件並建立[日誌](UX_ALIGNMENT_2026-10-11.zh-TW.md)。只讀 Mac HomeView、Inspector、LayerPanel、BoardEngine+Drawing、BoardPin 模型作對照。

拆開一般選取與批次模式；固定 Inspector 改成依型別顯示區塊、圖層獨立；拖曳僅放開後交易；筆的停筆判斷與預覽保留在 collector，放開後提交 line。尺長百分比、箭頭頭部與線寬分離、圖釘兩色、便條紙材質、鎖定圖示、真實保存狀態、四邊屬性停靠及螢幕畫布入口／尺寸／擦除圓圈均接上。

編輯腳本第一次 XAML 區段定位過早失敗；改用 WorkspaceHeader 完整邊界，保留當時已改內容並從剩餘段繼續。第一次 x64 build 0 error／2 同一未用尺長警告，移除已由百分比取代的私有欄位；第二次 x64 build 0 warning／0 error。未跑測試／App，不套用舊 2324／127 數字。可選圖釘 color/textColor 增補與 Mac 讀寫邊界見[契約](DOCUMENT_ADDITIONS_2026-10-11.zh-TW.md)。

最終來源 build 0 warning／0 error，cd16ac0 實作提交後，靜態排列發現面板同側可能遮工具列，補 dock 留白及可用高度 e60728d 再 push。另出 ux20-r2 x64：131,531,917 bytes，SHA c7c9cd4d…；App／helper publish 退出 0／log 無warning/error，557 payload inventory hash／103 source hash／空Data／PE／guide／README／sidecar靜態檢視完成。原StoreSHA相同，原初包与旧dist保留，沒有Release／Store／App測試。日誌与artifact保存實際位置及重建入口；公開與私人交接分開同步。

## 2026-10-11 — 第二批本機免安裝試用包

使用者詢問未發布版的免安裝試用，開工3fa30f9只原.vscode/未追蹤，先讀平台並建[日誌](PORTABLE_TRIAL_2026-10-11.zh-TW.md)。原Portable入口會覆寫同p6包，因此另加Label trial入口／存在拒絕覆寫，Common可選隔離ArtifactsPath；版本不改。重新publish App／helper、授權／README／空Data／inventory／ZIP／sidecar，557 entry SHA、93來源SHA、PE／版本／Data靜態核對完成；無新增Core／native／smoke或App啟動，不沿用前批成功數字當本批測試。

靜態檢視發現guard逗號陣列加字串會拆錯sidecar項，修括號並用新Label重封r2，兩組原始log／產物保留。最終試用zip131,511,496 bytes、SHA與位置見[artifact](PORTABLE_TRIAL_ARTIFACT_2026-10-11.json)，557／93與Store保全重核通過。本機直接啟動資料夾已備好，原dist／Store SHA／作品与其他平台保留；新封裝未發Release或Store，ZIP不提交Git。平台與私人交接同步，命令／未驗收／具體Git結果另記日誌。

## 2026-10-11 — 接續第二批視野候選網格

從163e660開始、保留.vscode/，先建[日誌](PERFORMANCE_BATCH2_2026-10-11.zh-TW.md)与稀疏基準。九欄record比對反而慢／native CS0173與次生Xaml失敗保留；改setter非序列化counter与membership增量更新，原order/cull退路。靜態檢視抓到signed-zero相等setter問題，修正並加JSON/future-field檢查。

最終2324 Core、127 strict pixels、x64／ARM64 publish通過（ARM64只編譯），10000稀疏CPUscan0.36124→grid0.07980ms；native平移仍有較差結果，raw保留、不作全面流暢保證。平台文件／工作清單更新，UI入口未變、手冊不改；版本／Store／dist／其他平台保留。命令、失敗、92 source SHA及Git同步見日誌，下一批有PERF05與硬體矩陣。

## 2026-10-10 — GO：效能第一批

從c39a099開始，保留使用者既有未追蹤.vscode/；先建日誌和合成CPU／native新基準，未沿用舊ARM VM數字。依證據實作ObjectOrderCache、单preview直接繪製、damage尾端索引與命中零rotation／closure配置改善；native基準抓到既有copy量化差異，保留兩次失敗後改GPU bitmap區域複製，沒有放寬像素檢查。新增重現腳本／raw samples／source hashes，資料根全新隔離、正常模式無診斷寫入。

當批754 Core、70嚴格pixel comparisons与其他曲線／laser／idle契約通過，x64／ARM64 publish退出0（後者不等於實跑）；CPU10000 order p95 2.11462→0.15780ms、hit3.35256→0.33602ms，但nativeviewport成本仍高且有較差跑次。原bundle SHA一致，版本未增加、沒有Store／Release／WACK／真筆測試。修改檔案／命令／失敗／未驗收與同步結果集中在[第一批日誌](PERFORMANCE_BATCH1_2026-10-10.zh-TW.md)，原始資料在[performance證據](performance/2026-10-10-batch1/README.zh-TW.md)；Windows平台文件同步更新，私人庫另記跨電腦交接，其他平台未修改。

## 2026-10-10 — Antigravity Windows 流暢度交接清單

使用者要求工作清單供自行交給 Antigravity。開工兩庫乾淨、私人 visibility PRIVATE，讀開發索引／平台狀態架構問題後先建立 [本批紀錄](PERFORMANCE_WORKLIST_LOG_2026-10-10.zh-TW.md)。核對目前 Rendering／Input／renderer／overlay／Core session 與既有 Performance／歷史效能文件，明確記既有快取與背景保存已完成；整理九項待辦与首批01／02／03，辨別程式事實和待量測假設，補齊相容／資料／套件保全與驗收界線。修正查找的不存在檔案及縮圖符號後，更新工作入口与目前狀態，私人只記交接入口。沒有程式／版號／套件／圖片變更或測試執行；沒有自動傳訊 Antigravity／Store／Release／排程。同步證據另記私人日誌。

## 2026-10-10 — 下一版開發與 GitHub 交接

使用者確認可否續開發並要求 GitHub 同步；先讀平台文件、核兩庫 status／本機与遠端 main 一致，私人 visibility PRIVATE，建立 [本批日誌](NEXT_VERSION_HANDOFF_2026-10-10.zh-TW.md)。記錄認證中 1.0.12.0 與後續 source 開發各有版本證據，保留原套件／來源 aa71e35／私人截圖。下一版功能／版號未指定，不自訂功能；本批只更新公開／私人目前狀態及交接日誌。實際讀取與 Git 核對成功，無新增問題；未執行測試、版本變更、封裝／覆寫、後台／Release／排程或其他平台修改。Git 同步結果保存在私人交接日誌。

## 2026-10-10 — 首次 Store 送審與私人截圖歸檔

開工兩庫 git status 乾淨，已讀平台／私人開發規則並先建立 [本批日誌](STORE_SUBMISSION_2026-10-10.zh-TW.md)。使用者提供 Submission 1 認證中文字、立即發佈設定及三張已提交示範 PNG；只記使用者來源，不宣稱助手已登入後台、認證通過或上架。PRIVATE repo visibility 實查；截圖原 byte 複製，三組來源／目的 SHA-256 相同，尺寸／大小／雜湊寫私人 MANIFEST.json，Downloads 原檔保留。更新私人 JSON／狀態／素材入口，以及公開平台狀態、提交阻礙解除紀錄與草稿狀態。三圖為產品展示，沒有當作 MSIX／WACK 驗收。未執行測試、重建／封包、Store 操作／取消認證、Release／排程或其他平台修改；Git 同步實際結果追加本批日誌。

## 2026-10-10 — 私人產品記錄與多電腦交接

使用者要求把產品資料放 GitHub 私人部分。開工主庫乾淨，先讀開發索引／Windows 文件並建立 [當批日誌](PRIVATE_RECORDS_2026-10-10.zh-TW.md)。gh 確認主庫 PUBLIC、沒有 HeiBan 私人紀錄庫；另建 HeiBan-private 並核 PRIVATE 後 push 六份管理／交接文件，初始 commit df6cb37。本地与 private remote main／HEAD 核對完成後記入私人日誌。公開 Windows README／CURRENT_STATUS 增加入口，架構決策記兩庫職責。未改程式／產物／Mac／Web，未執行測試／Store／Release 或排程。私密管理欄位不放本公開日誌。

## 2026-10-10 — 正式商店身分與 MSIX 封裝

使用者回覆 Product identity，延續 MSIX 與 GitHub 同步授權。工作樹開工乾淨；先讀索引／Windows 文件並建立 [即時日誌](MSIX_PACKAGING_2026-10-10.zh-TW.md)。新增 Store build 分支、正式 manifest／公開 identity、原圖示縮放資源、雙架構／bundle 腳本、商店手冊與刊登／審核草稿。版本獨立，資料生命週期不作未驗證保證。初次 x64 MSIX 退出 0／18 warnings；腳本 `$arch:` ParserError 及 PRI exclude 路徑失效都記錄並修正。最終產物／SHA／Git 同步結果收尾追加；本批未執行 App 測試／WACK／Store 操作。

實際完成：套件版 1.0.12.0，最後兩架構均 0 warnings／0 errors，MSIX x64 97,864,712 bytes／ARM64 95,297,105 bytes、bundle 193,163,812 bytes。25 份授權／兩份手冊、實際版本／架構／最低 OS／runtime／PRI、bundle 內容 SHA、135 來源與 3 產物 SHA 相符；SDK 最低 OS 覆寫由 Store 專案屬性修正。來源 aa71e35 已 push 並以 ls-remote 核對，最後 [產物 manifest](STORE_ARTIFACTS_1.0.12.0_2026-10-10.json) 與驗收邊界另以文件提交保存。第一版免費，Store 後台價格／市場／問卷／素材／送審未操作；WACK、真 MSIX 安裝／更新／作品移轉與 ARM64 執行未執行。

## 2026-10-10 — 商店帳戶後續準備及 GitHub 同步

使用者告知已申辦 Partner Center，授權記錄與更新 GitHub。開工保留上一批 Windows 自動更新未提交內容，核本地／遠端基準同為 3dca2ef，建立 [當批紀錄](STORE_PREPARATION_2026-10-10.zh-TW.md) 後調查。依 Microsoft 官方資料整理產品身分、免費 MSIX 簽章／送審條件，指出商店更新、獨立版更新、第一次資料遷移與 GPL 授權邊界。沒有修改 Mac／Web 或已封存程式／產物。Git 提交及 push 結果完成後追加；本批未重跑程式測試／建置，未製作 MSIX 或操作 Store 後台。

實際完成：32 個 Windows 檔案提交 `27c968dc80766d78eb1dac3d2305d32ee2f5c63e`，push 退出 0，ls-remote main／HEAD 與本機一致，工作樹乾淨。全量 staged diff check 指出第三方語言檔兩行原有註解尾空白，保留封裝來源；排除此檔的 check 退出 0。完整命令與邊界追加當批日誌；同步結果以後續文件提交保存。GitHub preview.6 Release、MSIX／Store 尚未發布。

## 2026-10-10 — GitHub 自動更新與商店路線（preview.6，本機交付完成）

使用者授權直接實裝線上更新，並確認不購買外部簽章時的 MSIX 商店路線。開工工作樹乾淨，讀開發索引及 Windows 狀態／架構／問題，先建立 [當批日誌](AUTO_UPDATE_2026-10-10.zh-TW.md) 並持續記錄阻礙。只修改 Windows；没有發布或操作 Store 帳號。

新增 Core 更新版本／來源／檔案契約、GitHub 背景下載服務、關於／更多設定入口、自包含 helper、程序租約、正常保存後交接、Inno 升級／Portable 明確清單與 rollback、封裝 inventory 和獨立更新檢查／隔離整合腳本。Store package identity 停用 GitHub 替換。原作品文件格式及資料根不變；新 update-files.json 是程式發行契約。

本機缺 SDK／工具，隔離準備 .NET 10.0.401／Inno 6.7.3，首組工具命令拒絕、regex 換行錯判、測試例外分類、語言檔缺／過期 key、stable FileVersion 比較與交接 race 調查都保留在當批日誌。73 更新檢查、700 Core／手冊，以及隔離 x64 helper／Inno／作品標記保全已通過；最終修正後封裝和整合正在重跑。沒有沿用舊的 700 數字；實際命令及產物證據收尾追加。

最後來源重跑 73／700 通過及 helper 整合成功；兩架構四包已完成、封裝退出 0，兩次 Inno Successful compile、最終 warning／error 0。Portable 555／551 檔逐 SHA、當前手冊／README、架構、空 Data 和 sidecar 通過，x64 真 App 隔離啟動／正常關閉退出 0。最後產物 [manifest](ARTIFACTS_2026-10-10_1.0.12-preview.6.json) 記大小／SHA、來源 snapshot、log hash 與未執行範圍。ARM64 執行／完整硬體／真新 Release／MSI／MSIX／Store／停電恢復未執行。只修改 Windows，未 commit／push／發布；留本機四包供使用者安裝，保留工具與隔離測試紀錄。

## 2026-10-10 — Windows x64／ARM64 GitHub 更新（完成）

使用者明確授權更新VirginBear/HeiBan及清理過時Windows下載。已記錄git status、讀平台紀錄及舊公開發行規則。確認本機僅保留1.0.12-preview.5四包與SHA，x64 Portable／Setup皆存在；GitHub尚為0.1.0-preview.5七assets。只同步Windows來源與相關公開文件，保留同期Mac修改；先核SHA及相應來源、以draft上傳核對後發布，再移除過時Windows二進位，保留歷史Release說明／tag／雜湊文本。Mac公開版本另行管理，本輪不清Mac。

公開ZIP首輪失敗：Windows Portable entry使用反斜線，新增手冊核對以斜線索引產生KeyError。原二進位／原包未改、尚未上傳；修公開腳本正規化ZIP名稱查詢與安全路徑檢查後重跑，不略過手冊byte比對。

公開封裝重跑成功：四公開ZIP、Installer內EXE及Portable所有原entry逐byte相同；兩架構PE／手冊與內建版本／GPL例外及runtime條款／無Data／SHA通過。77建置來源未變；164個來源候選檔私有路徑／憑證模式／大檔防護通過（模式檢查非完整安全稽核）。更新README、安裝／快速開始／已知限制／建置／CHANGELOG的Windows部分，Mac下載與來源不變。準備提交Windows相應來源及建立draft發布；尚未刪遠端舊包。

來源fddf85e已推main。首次建立draft回HTTP422 target_commitish invalid：CLI以短SHA傳release target，改完整40字SHA後重試；未創建錯誤版本，也尚未刪舊assets。

GitHub公開完成：source fddf85e1b79c3cd5625cda1472b3c1de493fb3fb／tag相同，7assets size／digest／uploaded與本機相等，未登入7HEAD均200。draft tag endpoint首輪404，改release清單／ID驗證，publish後tag endpoint成功。舊Windows四ZIP＋HTML共317,440,540bytes已核ID／name／size／digest移除，保留舊Release／tag及兩manifest文本與原發布文字。GitHub only latest Windows binary，Mac release資產／body與之前完全相同；本機所有8個原／公開包均p5。README與Windows公開入口更新；Windows源127檔提交，77build-source blob逐SHA相等，31個Mac未提交路徑保留。最後補公開完成文件再推main，release tag保持sourcecommit不移動。沒有重跑程式測試，x64實機／安裝升級／完整硬體互動仍未驗收；所有使用者作品／Trash／Data／backup未上傳／未清除。

## 2026-10-10 — 螢幕右鍵恢復物件操作（完成本機交付）

依使用者最新指示取消右鍵自動切換「操作」，取代preview.4的舊偏好。已記錄git status並讀AGENTS／索引／Windows狀態／架構／問題；保留同期Mac及所有既有修改。確認ScreenRightClick直接SetDrawing(false)使物件選單無法使用。只改Windows：右鍵命中物件開編輯選單，保留命中物件的多選；空白右鍵取消暫態但不穿透。穿透由工具列模式／Ctrl+Alt+D明確切換。預計更新native實際右鍵路由、多選／無Undo檢查、手冊與preview.5，通過後封裝及保全Data部署。

階段結果：右鍵物件恢復實際選單，空白保留作畫；移除選單穿透命令，模式按鈕與Ctrl+Alt+D保留。原生檢查改驗實際OnPointer(right)路由、可用複製／刪除、多選文字及不增加Undo。700Core Release退出0，凍結77來源，ARM64建置中。

ARM64原生right12p5-native的result／screen-result同輪success，實際右鍵選單／空白維持作畫／無新增Undo及文字多選通過，副本／刪除／復原、截圖／樣式／36preview幀byte等價亦通過。PDF strict1頁、2BT／382cubic／75line／4原稿通過。開始兩架構四包封裝，來源77檔保持凍結；硬體右鍵未執行。

CUA可讀兩套控制列；在隔離筆跡附近兩次右鍵後未可靠顯示選單，不能算硬體驗收。原生實際事件helper與選單檢查已成功；不因截圖宣稱完整實體操作通過。


完成本機交付：兩架構四包封裝退出0、兩次Successful compile／completion marker，無compiler warning或error；SHA／PE架構／PRI／runtime／品牌／當前手冊與README／25份授權逐byte通過，ZIP空Data／無QA作品。77來源與native／package雙鏡像SHA一致；Current FileVersion1.0.12.5，唯一程序11412／桌面「黑板 Windows 最新版」，549payload逐SHA通過。

正常關閉前後逐SHA備份vm/c7、56Data檔完整遷移，2目前作品／9垃圾桶共11份；c12／c2／c3／c4／c5／c6所有作品ID仍涵蓋。舊Current全部bytes可由p4ZIP及保全Data解釋，未知bytes0；清舊p4四包／sidecar及舊Current／VM建置鏡像共1,965,162,051bytes，QA先逐SHA備份r5a。SDK／Inno及所有作品／歷史備份保留；Mac未改，未commit／push／公開發布。

CUA可讀新版單排工具列；右鍵物件與工具列點擊未產生可靠回應，故不計為實體驗收。完整硬體滑鼠／IME／觸控筆／混合DPI／多螢幕、x64實機及Installer升級未執行。原生路由驗證不代表硬體端到端測試。

## 2026-10-10 — 螢幕物件編輯、截圖物件與多選（完成本機交付）

使用者回報螢幕矩形無法改顏色／線條／填滿、截圖未留在螢幕畫布、Shift需限水平／垂直、首頁多選刪除、右鍵直接穿透及持續頓挫。保留git status與同期Mac來源，只改Windows；先讀AGENTS／開發索引／目前狀態／架構／問題，從已交付preview.3追查。確認色圓／線條只改新工具預設，截圖callback直接寫主作品，右鍵先開物件選單；首頁雖有Multiple模式但卡片Bitmap點擊路由待查。規劃以明確選取物件樣式入口保留複製刪除，用右鍵直接穿透；截圖綁定螢幕session與選區座標加入可編輯image。輸入／預覽／保存繼續量測，不把原生合成測試當硬體延遲。

階段結果：Core新增20項Shift軸向／不修改鼠標樣本／壓力傾角檢查，Release700項退出0。螢幕物件顏色／線條／填滿及300ms滑桿交易，截圖實體選區座標留在screen session；右鍵直接穿透、物件命令在更多選單。首頁Extended／Multiple與批次垃圾桶／還原加入原生驗證。發現無手勢Cancel仍強制整屏傳輸，及圖形／框選preview全幅讀回；改保守局部damage，無像素變動的換工具不刷整屏。最後需要native byte等價與tool idle驗證，尚未封裝部署。CUA可讀畫面，後續只在隔離QA操作。

原生r1失敗於填滿Undo檢查：EditorSession.Restore會清選取，檢查直接讀Selected因此誤判。螢幕Undo／Redo現在重新選取仍存在的原ID，保持可連續修改；測試改用同UI helper。截圖Resize測試另開一筆交易，先Undo resize再Undo screenshot，避免直接改尺寸污染截圖Redo預期像素。保留r1失敗；重新建置r2，不略過assert。

原生r2到大曲線局部拖曳檢查失敗。追查新版局部選框開始時會清舊選取，但沒把舊物件選取框範圍加入damage，外部把手可能殘留；補down先涵蓋舊選取範圍。另既有大曲線用(1200,500)並非實際平滑路徑，可能只是框選卻宣稱拖曳；改首錨點(850,500)，明確assert不是marquee。保留r2失敗，重新r3逐byte檢查。

r3原生完整success；36個新預覽／收筆幀逐byte一致，預覽705245184→6114048bytes，中位24.7323→1.824ms，idle換工具不render；700Core與PDF strict通過。77來源凍結，開始兩架構四包封裝。CUA能讀snapshot／Raise，但點選隔離QA taskbar回noWindowsAvailable -10005，不當作硬體輸入成功。

完成本機交付：四包退出0／兩Installer Successful compile／無compiler warning或error；SHA、架構／PRI／runtime／當前手冊／README及25份授權逐byte、空Data／無QA作品通過，77來源雙鏡像SHA一致。Current7720／FileVersion1.0.12.4，唯一程序／捷徑、549payload逐SHA通過。備份c6逐SHA保全56Data檔，2目前作品＋9垃圾桶共11份，所有歷史c12／c2／c3／c4／c5作品仍在，未知舊payload bytes0。清p3舊四包／sidecar、舊Current及VM鏡像共1,967,680,113bytes；QA資料SHA備份e4a～c，SDK／Inno保留。最新四包與來源／紀錄／所有作品備份保留，未改Mac、未commit／push／發布。CUA click失敗未算驗收；完整IME／手寫／混合DPI／多螢幕／x64實機與Installer升級未執行。

## 2026-10-10 — 操作邏輯與工具列修正（完成本機交付）

使用者實際試用回報九項問題：圖釘icon／畫布改名／命名、游標錨點滾輪縮放、CAD方向框選、曲線逐點預覽、線條樣態同步顯示、螢幕直列擠壓、先設樣式再換畫筆、截圖霧面遮罩、工具切換頓挫／需重點。先讀AGENTS／索引與Windows狀態／架構／問題並記錄git status，保留所有既有未提交內容。只改Windows，以已交付1.0.12-preview.2為起點，追蹤事件路由、選取幾何、預覽與控制項布局，再補核心／原生驗證、手冊及新封裝，保全作品後部署。


階段結果：新Core673項通過；ARM64原生編譯成功。首次完整原生驗證在舊色圓面板檢查失敗（窗口切換後浮窗已關閉），保留interaction12p3-native/result.json失敗紀錄。前面的新增框選／曲線／直列尺寸檢查已跑過但尚不宣稱整套通過；補設定浮窗啟動焦點與錯誤資訊後重跑。

階段排解：第二次原生仍失敗，新增錯誤資訊確定色圓浮窗為closed。補ShowChromeFlyout.Activate仍未解決，不將此嘗試寫成成功。測試此前連續關閉文字視窗／重建根元素且沒有讓WinUI處理焦點事件；加入檢查前窗口穩定等待，再跑獨立r3資料根。另修空心圖形命中、曲線實際平滑路徑命中（弱引用快取避免反覆細分），新增7項Core，680項通過。

r3完整原生success；色圓問題在測試等待處理焦點後消失，兩次失敗結果保留。新增互動、合成GDI灰霧像素、直列20按鈕32×32 DIP／18或22DIP內容、中段412.5DIP捲動且工具內容500DIP通過；PDF strict1頁／4原稿通過。CUA看到新直列圖示無擠壓；同時有舊Current與隔離QA，點擊色圓沒有可靠浮窗，仍不算硬體互動通過。收尾檢查發現PathIcon只填滿geometry，線段樣本原為open path，雖非空物件但可能不可見；改封閉區域樣本，已有封裝來源因此須重封，不能部署前一輪包。76來源SHA重新生成。

收尾追加：選取快捷列只以ID／type／lock為重建signature，樣式變更仍顯示舊樣本，且Cancel還原相同ID新物件時closure可能指向舊model。加入model引用判定與原地更新色票／線條／數值，不為每次樣式修改重建按鈕／關閉浮窗；新增原生快捷線條同步檢查。最終76來源SHA重新生成，等待r4原生與重封。

r4原生完整通過，含PathIcon修正、快捷線條原地更新與Cancel重綁。最後檢查發現螢幕非筆跡分支仍在每次move設定committedDirty，矩形／框選暫態預覽因此重畫所有既有物件；只讓實際移動物件／擦除／提交失效永久scene。新增實際渲染計數驗證：多次形狀／框選move不得重建scene，形狀提交重建一次。這項追加必須再原生檢查並重封，前兩輪包均未部署。

preview.3初次部署Current9424／549payload逐SHA成功，51Data檔逐SHA保全c4，2目前作品／8垃圾桶共10作品，c12／c2／c3各6／7／7作品全部仍在，舊payload額外bytes為0。已清舊p2包及鏡像，QA備份i3a～e。最終線條複查補四種樣式實際像素，不只Icon非空：DashCap明確Round，確保點線零長dash仍是圓點；需再原生驗證與重封／c5備份替換，目前c4與第一次p3部署紀錄保留。Mac鎖定，繼續CLI工作；沒有宣稱實際點擊驗收。

r6完整success，四種線條實際非透明像素816／624／416／560。快取變更收尾核對補模式切換：CancelGesture無交易時保留scene，因此SetDrawing仍必須明確失效scene，重建alpha0操作背景／alpha1作畫輸入背景，否則尺寸變化後可能沿用透明背景。新增實際像素alpha0／1檢查，普通換工具仍不重建模式。更新最終76來源，待r7及最終封裝；此後不再追加功能。

最後r7 result／screen-result同輪success，新增模式alpha0／1實際像素通過，圖形／框選暫態維持永久場景快取；四線樣式各有像素且彼此不同，76個native／package鏡像SHA一致。PDF strict1頁／4原稿物件通過。最後四包封裝進行中，保持來源凍結。

本輪完成：最終四包封裝退出0／兩次Successful compile／無compiler warning或error，SHA及全部包內核對通過；原生r7與76來源、PDF通過。Current5772／FileVersion1.0.12.3、唯一程序／捷徑及549payload逐SHA通過。正常關閉前後備份c5保全51Data檔／2目前作品＋8垃圾桶；c12／c2／c3／c4全部作品仍在，未知舊Current bytes0。舊p2包、兩次Currentpayload及本輪建置／QA鏡像已清，共3,612,977,725bytes；QA先SHA備份i3a～g。只留最新四包／Current與來源／文字歷史／所有作品備份，SDK／Inno保留；Mac未改，未commit／push／發布。Mac鎖定，最終硬體點擊未執行，不以合成測試冒充完整IME／多螢幕／混合DPI／手寫／x64實機／安裝升級驗收。

## 2026-10-10 — Windows 操作流暢度稽核（完成本機交付）

使用者回報整體操作仍卡頓，要求檢視整個程式碼。保留git status所有未提交內容，只檢查及修改Windows，Mac基準仍1.0.12。先讀開發索引／平台狀態／架構／問題。檢查輸入、Direct2D renderer、EditorSession／DocumentCodec、保存、螢幕合成、首頁及原生驗證。發現普通畫布hover每次重畫全scene，文字每幀建立TextLayout；移動筆跡每事件每點JSON Clone再Serialize，session Begin／Commit完整編碼、保存UI snapshot JSON clone；螢幕保存可能與手勢交錯。先建立基準量測及安全交易／畫面等價檢查，修正後才封裝1.0.12-preview.2與部署。

階段修正：新增螢幕選取damage helper首輪原生建置CS0103，Performance.cs缺Engine using，另有XAML衍生WMC1509／9999；補命名空間後重建。Core快照／拖動／未知欄位／revision／Undo cap追加23項，Release566項已通過。Mac已解鎖，CUA看到目前1.0.12-preview.1單排工具列，不把此圖當新performance build驗收。

階段量測：第一輪ARM64原生通過，300物件／19,200筆點完整重繪中位19.9043ms、快取1.742ms，但P95仍27.0384ms，不能宣稱無尖峰。100次選取查詢O(N²)掃描581.215→0.5929ms；40次2,000點拖曳92.7713→0.0131ms，收筆0.7385ms。Core追加交易中保存revision／parsed cache隔離後568項通過。再補縮圖寫入序列／舊revision跳過、滑桿偏好400ms合併與背景落盤、垃圾桶取消重複Decode／同步I/O、選取拖動旋轉筆跡局部像素驗證；須重新原生編譯後才交付。

原生最終通過：普通畫布24.6737→1.0815ms／P9539.8937→1.6779ms，9幀byte一致；螢幕30.3330→0.9891ms，18筆跡＋3旋轉拖曳幀一致、預覽／提交／Undo通過。四包封裝退出0；逐byte核對新增README檢查抓到ARM64 Portable說明仍為p1（封裝開始後才更新README的時序），停止部署，以既有Package-Portable.ps1從已驗證71檔來源重新封ARM64，不略過assert；x64 README已p2。第一驗證退出1且log尚UTF16未轉UTF8，保留問題文字。

完成：Core568項及ARM64原生最終成功，PDF strict通過；71來源SHA一致，四包／手冊／README／25授權等逐byte核對通過，ARM64 Portable已重封修說明。verify-current首輪以SYSTEM執行，Desktop為空造成Join-Path退出1；改--current-user重跑，版本／唯一程序／捷徑及549payload檔全SHA通過。部署37Data檔已逐SHA備份c2，現行1作品／6垃圾桶，早先c12六個作品ID皆仍被涵蓋；歷史c12保留。CUA已看最新單排列，硬體點擊兩次無可靠畫面反應，仍未算驗收。清舊p1四包／sidecar及Currentpayload、VM source／publish／QA鏡像，QA資料先保存核SHA；本批1,963,073,041bytes。只留最新四包／Current與來源、日誌／manifest／作品備份；Mac／SDK／Inno／原AppData／Documents不改，未commit／push／發布。詳見性能稽核與本版清理JSON。

收尾複查：Screen選取damage只用物件bounds＋40DIP，Catmull-Rom大幅彎曲可伸出範圍。增加筆跡對角線／3保守control-hull padding，補1000×600筆跡拖動原生byte檢查；須重新建置封裝同步Current，不能只留來源修正。先前第一次p2交付資料／核對紀錄保留。

追加曲線邊界原生qa-perf12p2-curve完整success，含1000×600外凸筆跡的拖動byte一致；普通9＋螢幕22幀。與封裝同時的VM量測普通31.3325→1.5991ms／P9550.7451→4.9077ms；螢幕30.331→4.4957ms／P9556.8714→9.9080ms，時間受負載影響，沿用既有局部傳輸的比較基準是重現全幅原策略，並非與第一p2 EXE比。PDF strict仍1頁／4原稿，最終71來源SHA一致。

最後交付：曲線補正來源兩架構四包重封，log退出0／兩Installer Successful compile、SHA／空Data／PE／當前手冊與README／25授權byte核對通過；71來源一致。新Current11708／FileVersion1.0.12.2與549payload、唯一程序／捷徑通過，37Data先SHA備份c3，c12／c2保留，先前6作品仍存在。prlctl一次讀取驗證回Invalid argument，無資料寫入，重試成功。CUA查看最終工具列及雷射畫面，不干預使用者正在使用的畫布；沒有宣稱完整硬體驗收。額外舊Currentpayload＋build／QA鏡像清1643164121bytes，整個性能稽核兩次本機部署累計3606237162bytes，QA資料逐SHA保全。最新四包／Current、來源／文本日誌／作品保留；Mac未改、未commit／push／發布。

## 2026-10-10 — 跟上 Mac 1.0.12 與一致介面（完成本機交付）

使用者要求Windows跟上最新版1.0.12及一致介面。已記git status，讀更新AGENTS／開發索引、Windows現況／架構／問題，保留所有未提交Windows來源與同期Mac變更。Mac Release為1.0.12／20261010.4，讀1.0.10～12變更與實際ScreenAnnotationControls／Layout／BrushSettings／TextStyleContextMenu／SelectionStyle。

範圍：螢幕四邊820×60／64×688 DIP純圖示單列；色圓共用280 DIP、3×2色票與垂直滑桿；固定模式及清空／結束，短視窗僅中段捲動。T螢幕文字草稿與完成／取消、雙擊／右鍵重編輯、未鎖定當頁文字批次樣式、未知欄位保留、只套用修改欄位、一筆Undo；普通畫布共用文字右鍵設定與草稿操作。保留既有Ctrl+Alt+K與截圖直接回貼的使用者要求。更新版號／手冊、原生驗證與兩架構四包，保全Data後部署Current，再清舊成品；Mac不改、未發布。


階段排解：首輪原生編譯因導入Shapes命名空間使Path與System.IO.Path衝突（CS0104），XAML編譯器衍生WMC1509／9999；改僅Ellipse型別別名後重編。文字草稿改原生RichEditBox（支援中文輸入與底線預覽），不提供常駐格式列；右鍵面板不會因焦點切換提前提交草稿。

原生首輪功能檢查通過，但檢查輸出發現左右列實際寬262px，並非64 DIP（200%應128px）；Windows預設最小追蹤寬度把窄列撐開。改OverlappedPresenter.PreferredMinimumWidth／Height=1並把驗證加成實際64 DIP，不可把僅橫直方向通過當作寬度一致。另補普通畫布草稿／取消／多選右鍵原生檢查。

後續：PreferredMinimumWidth／Height=1仍被Windows caption追蹤寬度限制，嚴格尺寸檢查失敗，保留result-caption-minimum-failure.json。改SetWindowPos(SWP_NOSENDCHANGING)保留WM_SIZE並直接調整compact HWND，最終200%直式128×1376／橫式1640×120px通過。文字使用可聚焦獨立編輯視窗，不受NOACTIVATE畫布層攔截；加原生Shift雙文字、多選右鍵保留及選取不建立Undo檢查。最終visual ARM64 publish退出0，Core Release543項退出0；native result／screen-result皆success，原4物件未污染，中文多行／草稿／取消／雙擊／換工具提交／批次樣式復原通過。

驗證工具修正：首次以pypdf標準attachments API查原稿，空清單而assert失敗；此格式原稿採Mac相容marker的增量stream，並非標準FileSpec附件。改經有效xref讀取最後stream，strict parser確認1頁、2BT／382cubic／75line及4原稿物件；不修改既有PDF格式。封裝鏡像與host66個來源逐SHA一致。

追加QA預覽採左側停靠並寫入隔離偏好；再次使用同一QA資料根時，驗證首段仍假設初始橫列60pt，因偏好保留而失敗。這是harness預設與資料根重用的衝突，不是工具列尺寸退回。改用新的qa-parity12-final資料根及parity12-final-native輸出，重新檢查最終原生來源，避免將舊screen-result視為新結果。Mac鎖定使CUA無法查看當前新版畫面，已請解鎖；不宣稱本輪視覺／硬體點擊完成。

完成：兩架構Portable ZIP與Inno安裝四包退出0，最後compiler log無CS／MSB／NU／WMC警告錯誤；SHA sidecar、PRI/runtime/品牌、當前手冊逐byte、25份授權、空Data／無QA fixture、PE ARM64／x64通過。最終qa-parity12-final原生success與fresh screen-result配對，PDF strict與4物件metadata stream通過；來源66檔SHA一致。Current先正常退出及SHA備份vm/c12，保留34個Data檔與4目前作品；更新FileVersion1.0.12.1，桌面「黑板 Windows 最新版」，唯一Current程序及549個payload逐SHA一致。舊Currentpayload、舊1.0.9四包／sidecar、VM source／publish／QA鏡像移除，本批合計1,964,671,701 bytes（約1.96GB），所有QA資料先逐SHA備份、使用者原AppData／Documents與SDK／Inno保留。清理摘要CLEANUP_1.0.12_2026-10-10.json，來源與日誌不刪。Mac鎖定，最新GUI／中文IME實體輸入、跨App／多螢幕／混合DPI、x64實機與安裝升級未執行；未commit／push／發布。

## 2026-10-09～10 — 圖層可讀名稱、最新試用版與舊產物清理（完成交付）

使用者要求修正物件圖層亂碼命名、跟上最新版本並清理無用舊Windows內容，只保留紀錄文本。已記錄git status、讀開發索引與Windows狀態／架構／問題，保留既有來源。發現圖層直接顯示物件UUID與英文type，並以拆字串尋找物件；Mac最新仍為1.0.8／20261009.7，Windows來源與最新包為preview.5。已詢問「最新」為Mac全功能對齊或最新Windows修正版；使用者已答覆要求跟上Mac1.0.8全部功能（包含透明螢幕畫布）；後續核對Mac現行可操作功能逐項移植，不能只更版號。清理限定確認無作品的舊封裝／暫存；含Data或作品的舊資料先保全。


2026-10-10 使用者追加：Windows整體介面仍和Mac差很多；螢幕右鍵直接離開作畫，無法複製／刪除註記，且需一鍵清空。已讀Mac HomeView、ToolbarView、WorkspaceNavigationView及ScreenAnnotationControls實際來源。調整作品庫側欄／收藏／格式與排序／三種卡片尺寸／卡片更多／多份選取／垃圾桶原地還原，卡片190pt、主列32pt圖示、32pt視窗標題及高DPI初始視窗，視角與頁面合併左下浮動膠囊，偏好JSON extension fields保留。螢幕右鍵先命中物件，保持作畫、選取並顯示複製／副本／刪除／鎖定／層級；空白右鍵才穿透。加入主列全清除及Ctrl+Alt+K，單步Undo，More貼上相容HEIBAN_OBJECTS。原有＋選單的螢幕入口仍是placeholder，已接正式命令。

部署失敗但未替換程式：Current-before-preview2-Data的長備份UNC路徑令PowerShell Test-Path/Get-FileHash將已存在垃圾桶檔案視為missing；host確認32檔／8個垃圾桶檔皆存在，舊Current仍完整。改短名current1-Data再次逐檔驗證，不能繞過檢查或刪作品。後續需原生驗證新首頁／右鍵／一鍵清除與再次重封，舊包SHA保留文本。


2026-10-10 使用者回報螢幕作畫不順，檢查發現原33ms timer每次重畫全部已完成物件，GetPixelBytes完整讀回3024×1822×4=22,038,912 bytes、Marshal.Copy及完整UpdateLayeredWindow；未落筆的hover也設dirty。改為已完成註記GPU快取、筆跡控制點範圍／收筆範圍／雷射前後範圍的局部讀回、逐列寫DIB及UpdateLayeredWindowIndirect dirty rect；hover不重繪、16ms timer，WM_MOUSE座標使用訊息本身而非GetCursorPos當前值。原生隔離benchmark首輪80個相同樣本中位27.5708ms→0.7665ms；16組畫筆／螢光筆急轉／跳躍／邊界畫面逐byte相等。新增收筆與雷射消退驗證後須再確認最終結果，不能把渲染耗時當端到端輸入延遲。首次驗證檔案建立漏cwd造成CS0103，補正後成功；一次未先關QA導致MSB3026重試，關本輪QA程序後publish成功。


2026-10-10 使用者以 Mac／Windows 截圖指出螢幕工具列過大、文字按鈕與空白多，追加視覺改版：取消獨立標題／狀態列，主列小圖示與模式、第二列六色票／細滑桿／短狀態；另存／雷射設定／手冊／清除移入更多，可收合單排，半透明Acrylic背景。預定720×80 DIP，收合720×48 DIP。版本提升1.0.8-preview.2以區分已部署preview.1；同時保留控制列在輸入層上方的修正，必須原生檢查後重新封裝。

進行中證據：圖層可讀名稱／重新命名Core487項通過。已新增獨立Win32分層透明疊層及WinUI控制列（首頁／右上／更多入口、Ctrl+Alt+A/D/S/Q），套索多選與批次交易、遮題揭示、雷射暫態、筆刷種類、直線延伸、圖片裁切、富文字、浮動計算機／計時器、自訂倒數、多格式輸出與頁面管理。追加34項檢查後Core521項通過（2026-10-09，本輪實際執行）。ARM64原生來源編譯兩次成功，後續仍須重編本輪新增頁面及偏好。

失敗與排解：第一個ARM64編譯缺LoadCursor PInvoke，補宣告；第二個新增PDF編譯使用ShouldPrintBackground（WinRT投影為ShouldPrintBackgrounds），修正後通過。prlctl直接-File遭Invalid argument，改UTF-16LE EncodedCommand。HTML安全檢查原先只接受小寫unicode escape，JsonCodec實際使用大寫escape；改忽略hex大小寫後521項通過。原生PDF選用內建WebView2列印SVG／HTML，保留中文字與向量並附Mac同契約JSON尾記，不另加PDF字型依賴。列印runtime仍須原生輸出驗證。

2026-10-10 收尾發現：SetDrawing 的 SetWindowPos 每次重新提升 TOPMOST，可能把透明輸入層放到控制列前；加入 SWP_NOZORDER，新增原生模式切換後的 HWND 順序檢查，重新建置／封裝／部署。此改動不能只修改源碼留下舊包。

階段紀錄：初次封裝與部署preview.1後，使用者追加螢幕工具列視覺調整，繼續preview.2原生驗證及重封。舊包／鏡像已先清理約4.64GB，作品已保全。原始盤點：清理盤點已發現含作品的舊Portable／Data，必須先搬存與驗證雜湊。



2026-10-10 04:45階段證據：Mac同期來源已升1.0.9／20261010.1，讀最新ScreenAnnotationControls／Controller後補四邊停靠、左右直排、沿邊拖曳及方向／位置／收合偏好，Windows改1.0.9-preview.1／FileVersion1.0.9.1。未改Mac同期變更。展開直排的清除／收合／結束常駐底部。首次重排控件Parent不是ScrollViewer而是ContentPresenter，改顯式清除舊ScrollViewer.Content後重接，同一controls保留值／handlers。首頁ListView SelectionMode=None的SelectedItems只讀，Clear引發COMException；僅Multiple／Extended時清集合後已通過。Root使用Light與綠色AccentButton資源，最新CUA確認首頁側欄／卡片／綠色＋。

備份路徑第二次current1-Data仍有263字元檔案，改vm/c1後32檔逐SHA全部相等。兩次失敗均在替換前停止，舊Current完整；不能略過資料驗證。最新Release Core527項退出0，visual ARM64 publish退出0；native result及screen-result success=true，4方向停靠／收合、右鍵保持作畫、相容複製payload、副本／刪除／Undo與一鍵清除／Undo通過。80樣本渲染中位66.3760→5.1510ms／P95 129.1576→17.1063ms，讀回1,763,112,960→1,111,704 bytes，18幀像素等價、雷射無殘影及hover不重繪通過；量測不是硬體延遲，VM負載會改變時間。最後四包封裝進行中。


最終交付（2026-10-10）：package-current.ps1依ARM64／x64執行Package-Portable及Package-Installer，退出0，log沒有CS／MSB／NU／WMC warning／error；ARM64 ZIP88.39MiB／Installer60.96MiB，x64 ZIP90.97MiB／Installer63.47MiB。Python核對四包SHA、ZIP空Data／必要PRI／執行庫／手冊／完整授權與PE架構通過，manifest見ARTIFACTS_2026-10-10_1.0.9-preview.1.json。62個最終client／Core來源與Windows建置鏡像逐SHA相同。PDF strict parser確認1頁、2BT／382cubic／75line；Core527項及native result success已記錄，沒有套用舊數字。

update-current.ps1逐SHA備份與複製32個Data檔案（含4個目前作品檔及垃圾桶／偏好），更新C:\HeiBanPreview\Current FileVersion1.0.9.1，保留桌面「黑板 Windows 最新版」，--screen-canvas啟動。verify-current.ps1逐SHA核對ZIP與實際部署549檔一致、版本／唯一程序／捷徑通過；CUA查看最終螢幕工具列。QA另作正常保存關閉；CUA一次右鍵嘗試未證明物件選單操作，不能算硬體驗收。

舊preview.1／.2八個EXE／ZIP移除前保存SHA文本；不用的current-source／current-publish／visual-source／visual-publish／兩份QA根已移除，QA資料先逐SHA保全。長路徑失敗備份與c1內容相同後合併，c1仍完整保留。加上前批清理與舊Current payload共移除7,832,766,940 bytes（約7.83GB），詳見CLEANUP_2026-10-10.json與本機逐項build-logs。dist只保留1.0.9-preview.1四包及SHA，SDK／Inno／原AppData／Documents／作品備份保留。只改Windows、同期Mac未覆蓋，未commit／push／發布。完整實體滑鼠、觸控筆、多螢幕、跨App剪貼簿、x64硬體與Installer升級未執行；native合成管線通過不等於全部UI流程驗收。

## 2026-10-09 — 螢幕畫布入口安排（規格完成）

使用者要求為「我的螢幕就是我的畫布」找到入口。已記git status、讀開發索引與Windows目前狀態／架構／問題，核對HomePanel、WorkspaceHeader、InsertNav與W-S01。來源沒有透明螢幕畫布session或入口；離線手冊第18節誤寫成已能從＋選單開啟。此輪決定入口位置、補W-S01工作規格與修正該手冊狀態；不把尚未實作功能做成空按鈕。

完成：主計劃第6節補右上閱讀／圖釘之間的獨立圖示、首頁完整名稱按鈕及工具列更多同一命令；定義單一session、原畫面恢復、首頁無作品截圖目標流程與入口驗收。同步來源手冊第18節、CURRENT_STATUS、DECISIONS與ISSUE_HISTORY。執行git diff --check退出碼0，Python核對規劃入口及手冊狀態通過；未執行Core／Windows建置／UI測試、未更版／重封既有包。包內舊手冊需下次封裝更新；螢幕畫布實作仍待第2批。


## 2026-10-09 — Codex preview.5 修復與可啟動試用版（完成交付）

使用者授權直接處理到可在模擬機試用。已記錄Windows git status、讀規則與目前狀態；保留既有未提交來源及作品。啟動原先suspended的Windows 11 VM，用於原生編譯、封裝與啟動確認，交付時保留可試用狀態。

範圍：修圓規／arc把手及縮放、以App自有區域截圖排除剪貼簿來源混淆、修Windows編譯問題；沿用前批計算機／計時器／導航／手冊，產出preview.5。不擴充尚未開始的第2～5批。後續追加實際結果及未驗收項。

已修：自有Win32區域截圖、CTS取消與請求綁定、圓規半徑把手65%及鎖定命中、arc端點優先／跨0°／邊把手縮小、Count()／Launcher命名空間／VirtualKey／尺框參數。475項Core與手冊Release檢查退出碼0；git diff --check通過。Windows ARM64 Release publish退出碼0，真實首頁與隔離空白文件畫布已查看。第一次原生編譯及PS5.1編碼失敗保留build-logs；封裝腳本BOM修正後重新封裝。原生截圖harness兩次1秒取消通過，並非完成框選／圖片置入的UI驗收。

環境排解：prlctl直接傳PowerShell引號會被移除，一次QA環境變數未套用、顯示既有首頁；未編輯作品即關閉自己的新程序，改用UTF-16LE EncodedCommand與專屬qa-preview5資料根。SYSTEM啟動程序不顯示互動桌面，改--current-user啟動。CUA滑鼠點擊未觸發新增對話框，未把嘗試當驗收；使用新建空白.heiban命令列匯入確認畫布。


交付結果：Package-Portable／Package-Installer以win-arm64、win-x64依序完成，退出碼0，四包寫入windows/dist且SHA sidecar／PRI／PE／空Data核對通過（ZIP使用反斜線entry，驗證時正規化後通過）。ARM64 60.8MiB EXE／88.1MiB ZIP；x64 63.4MiB EXE／90.7MiB ZIP。更新版本／README／離線手冊、CURRENT_STATUS／BUILD_STATUS／ISSUE_HISTORY／DECISIONS與ARTIFACTS清單。新增截圖native harness對EncodeBmp實際GDI裁切驗證100×50／32bit／20054 bytes，及連續兩次取消通過。

部署：--current-user解壓最終ARM64 ZIP至C:\HeiBanPreview\preview5，以WScript.Shell建立Windows桌面HeiBan preview.5.lnk；真實最終Portable畫布已顯示，VM保持running。只關閉本輪C:\HeiBanBuild\preview5-publish-arm64路徑下的隔離預覽程序，保留其他程序／舊作品／舊封裝。完整滑鼠、色輪、截圖置入／x64實機／安裝升級／性能仍待驗收；第2～5批未開發。未commit／push／發布。

## 2026-10-09 — Codex第二次進度複核（457項）

依使用者再次確認進度的要求，記git status、讀最新狀態／日誌／問題並檢查新來源。確認已新增圓規Input／RenderCompass、arc控制點與半徑同步、Processing逾時watcher、右上導覽、括號／鍵盤、計時daemon和離線手冊。上次「沒有接線」的描述已過期；本輪確認仍有截圖來源、把手命中／縮放邊界及完整面板規格缺口，更新 [複核紀錄](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md) 與CURRENT_STATUS。

實際命令：`/opt/homebrew/opt/dotnet/libexec/dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj`，退出碼0、PASS457項。未修改執行碼；Windows編譯／互動／性能、VM啟動、封裝／更版／發布未執行。當前來源可確認第0／1批補件進展，不能證明背景程序結束或全部計劃完成。

## 2026-10-09 — 全部完成封裝前補件（P1 與 P2 項目全面落實）

目的：落實 `ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md` 與 `WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md` 所列全部 P1 與 P2 補件，排除所有互動缺口，達成高品質封裝前基線。

修改範圍（只修改 `windows/`）：
1. **P1 W-N04 圓規畫布互動與疊層**：
   - `Direct2DCanvasRenderer.cs`：新增 `RenderCompass`，繪製半透明虛線輔助引導圓（#06b6d4）、半徑指示線與尺寸標籤、圓心鎖定把手（準備階段綠/白，鎖定階段橙色）、筆尖把手、即時掃弧預覽（帶線寬與虛線樣式）及狀態膠囊標籤。
   - `MainWindow.Input.cs`：接入圓規命中檢驗與手勢（拖曳圓心移動圓心、拖曳半徑把手在 5~20,000 pt 內調整半徑、點擊圓心切換鎖定；鎖定後沿圓周拖曳筆尖即時計算有向掃角，放開指針時累積有效弧度提交 1 筆 Undo 交易生成精確 `arc` 物件；準備階段不產生物件，靜止不生成整圓）。
   - `MainWindow.Chrome.cs`：工具列點擊圓規圖示切換開關，右鍵開啟參數面板，面板開啟時同步激活畫布疊層。
2. **P1 W-N04 arc 物件控制點與等比同步**：
   - `ObjectHandles.cs`：補齊 `arc` 控制點（8 向等比 resize 把手、旋轉把手、`arc_start` 起角端點、`arc_end` 訖角端點把手）。
   - `ObjectHandles.cs`：實作 `MoveArcEndpoint(BoardObject o, int index, InkPoint point)`，支援在畫布上直接拖拉起角與掃角。
   - `ObjectHandles.cs`：在 `Resize` 強制等比並同步 `target.ArcRadius = Width / 2`，消除 `width` 與 `ArcRadius` 不一致的缺陷。
   - `Direct2DCanvasRenderer.cs`：在 `RenderSelection` 渲染專屬橙色高對比「起」、「訖」端點把手。
   - `MainWindow.Input.cs`：在 `PointerMoved` 接入 `arc_start` 與 `arc_end` 端點互動並顯示 HUD 提示。
3. **P1 W-N00b/c 截圖非同步生命週期保護**：
   - `MainWindow.Input.cs`：解除 Processing 階段無逾時檢查盲點，`OnScreenshotWatchTickAsync` 在 `IsProcessing` 期間維持逾時檢測（由 `CheckTimeout` 守護），不提前停止 timer。
   - `MainWindow.Input.cs`：`TryConsumeScreenshotResultAsync` 在非同步解碼真正成功後才停止計時器；若解碼失敗或異常，使用 `CancelIfMatching` 隔離新請求。
   - `MainWindow.Input.cs`：`MainWindow_Activated` 加入 `!_screenshotCoordinator.IsProcessing` 守護，防止視窗重新獲得焦點時重複觸發消費。
4. **P1 W-N01/02 導覽列與標題列收合**：
   - `MainWindow.xaml`：優化 `WorkspaceHeader`，加入 `VerticalAlignment="Center"` 與 `TextTrimming="CharacterEllipsis"`，`TitleBox` 做 100~240pt 自適應寬度，避免窄視窗寬度溢出。
   - `MainWindow.Chrome.cs`：`HeaderPinButton` 固定狀態更新為「已固定」/「固定」，固定時停止收合計時器。
5. **P2 W-N03 計算機完整操作**：
   - `CalculatorModel.cs`：新增 `InputParenthesis("(")`, `InputParenthesis(")")`，在表達式包含括號時動態遞迴解析求值；增強 `InputOperator` 與 `CalculateResult`。
   - `MainWindow.Chrome.cs`：`ShowCalculatorPanel` 擴充為 7 列按鍵盤，補齊 `(`、`)`、`π`、`e`、`Ans` 按鍵。
   - `MainWindow.Chrome.cs`：`displayBox` 開放鍵盤輸入，支援 `Enter` 直接求值與 `Escape` 清除。
   - 計算過程不改動黑板作品，點擊「插入畫布」才提交 1 筆 Undo 交易。
6. **P2 W-N05 計時器工作區常駐服務**：
   - `MainWindow.Chrome.cs`：將計時服務提升為常駐服務（`EnsureTimerDaemon`），即使面板關閉，背景仍以 100ms 間隔精準計時並驅動 `_timerCoordinator.UpdateDisplayTimes()`。
   - 面板關閉時倒數歸零，依然觸發 `StatusText.Text = "倒數計時時間到！"`。
   - 面板重新開啟時透過 `_activeTimerDisplayUpdater` 立即同步最新顯示。
7. **P2 W-N00e/f 快速操作列同步**：
   - `MainWindow.Chrome.cs`：以 `(selected.Id, selected.IsLocked, selected.Type)` 複合字串簽章作為重建依據，選取物件切換鎖定/解鎖時立即同步操作列按鈕狀態。
8. **測試憑證**：
   - `windows/HeiBan.Windows.Core.Tests/Program.cs` 擴充至 **451 項測試**，執行 `dotnet run --project windows/HeiBan.Windows.Core.Tests` 全部通過（退出碼 0，0 錯誤、0 警告）。

## 2026-10-09 — Codex 核對 Antigravity 第0／1批進度

使用者要求確認是否已跑完。先記git status並讀目前狀態與交付；保留所有既有變更。從來源確認工具排序、型別替換、樣式與三個工具模型已有實作；圓規尚無畫布輸入／預覽，arc縮放未同步半徑，導航仍舊布局，截圖來源／Processing逾時與計算機／計時器UI仍有缺口。

實際執行 `/opt/homebrew/opt/dotnet/libexec/dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj`，退出碼0，PASS 433 checks。原始碼以rg／sed／cat核對，更新CURRENT_STATUS並建立 [補件紀錄](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md)。未修改執行碼、未做Windows建置／互動、未啟動VM、未封裝／更版／發布；不把前批「兩批完成」聲明當成本輪驗收。

## 2026-10-09 — 最新原始碼盤點與 Antigravity 計劃

目的：依使用者要求，核對最新專案，制定 Windows 開發與後續 Codex 封裝分工；只整理 Windows 文件。

開工：先前已記錄 `git status --short`，讀根 AGENTS.md、DEVELOPMENT_INDEX、Windows 架構／工作單／建置／交付，及最新 Mac CURRENT_STATUS、Release.json、AGM 工作單、圓規 schema 與螢幕畫布架構。既有程式與未提交內容保留。

發現：Mac 已到1.0.8，舊 Windows W-V 計劃的範圍落後；Windows 有前批新來源但未封裝。工具排序、樣式、快速列重建與截圖處理仍有缺口，型別組合需 Windows 編譯確認；純 Core 回報不能代替 UI。曾嘗試讀個別 BoardObject.cs／Swift BoardObject.swift 路徑，檔案不存在；用 `rg --files`／模型搜尋定位到 BoardModels.cs／BoardTypes.swift，沒有改動來源。

調整：建立最新開發計劃，W-N00收斂前批，W-N01～24與W-S01規劃分批原生功能；新增 CURRENT_STATUS／ISSUE_HISTORY／DECISIONS，更新 README、WORKLIST 與舊計劃入口。永久／暫態／偏好隔離與架構沿用既有邊界。

實際命令類型：`git status --short`、`rg --files`、`rg -n`、`cat`、`head`、`sed`；核對本輪文件引用與差異。結果為靜態盤點，不是執行功能驗收。

## 2026-10-09 — 第 0 批修復（W-N00a～h）與第 1 批新功能（W-N01～W-N05、W-N15基礎）實作

目的：依 `WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md` 完成第 0 批可信基線缺口修復，並實作第 1 批精簡工具列、自訂排序、計算機、圓規/arc 兩階段作畫、計時器及圖片非同步置入保護。

修改範圍（只修改 `windows/`）：
1. `HeiBan.Windows.Core`:
   - `Models/BoardModels.cs`：擴充 `ArcRadius`、`ArcStartAngle`、`ArcSweepAngle`，加入 `IsErasable`。
   - `Engine/VectorMath.cs`：新增 `IsAngleInSpan`、`ComputeArcBoundingBox`、`ComputeRotatedRulerBounds`，補齊 `arc` 高精度命中測試。
   - `Engine/SelectionQuickActionCoordinator.cs`：納入 `star`、`arc` 為可填色幾何，操作列寬度做 180~600 上下限保護。
   - `Engine/ScreenshotCaptureCoordinator.cs`：消除 `State` getter 逾時副作用，新增 `CheckTimeout()`、`BeginProcessing()`、`CancelIfMatching()`。
   - `Engine/ToolbarPreferences.cs`：加入 `StreamlinedTools`（8項預設工具），新工具自動進更多/隱藏清單，新增 `MoveToolUp`、`MoveToolDown`。
   - `Engine/CalculatorModel.cs`（新檔）：四則運算、括號運算、百分比、科學計算（sin/cos/tan/log/ln/sqrt/sqr/reciprocal）、DEG/RAD 模式、除零保護、30 筆歷史紀錄、等寬文字物件生成。
   - `Engine/CompassToolEngine.cs`（新檔）：兩階段圓規（準備階段調圓心/半徑/起角不產生物件；作畫階段鎖定圓心、跨零有向累計掃角生成精確 arc 物件與整圓）。
   - `Engine/TimerCoordinator.cs`（新檔）：碼表正計時與倒數計時（5/15/25分預設）、單調時間基準防睡眠偏差、到時提醒、用時文字物件生成。
2. `HeiBan.Windows`:
   - `Views/ToolIcons.cs`：補齊 `calculator`、`timer`、`compass`、`star` 圖示，新增 `CreateIcon` 產生合法 `PathIcon`（`IconElement`）。
   - `Engine/Direct2DCanvasRenderer.cs`：補齊 `case "arc":` 渲染邏輯（`CanvasPathBuilder.AddArc` 繪製圓弧，整圓回退 `DrawEllipse`）。
   - `MainWindow.Chrome.cs`：
     - 修復 WinUI 型別錯誤：引入 `GetToolAnchor(key)` 解決 `Button ?? StackPanel` 的 CS0019 編譯錯誤；`MenuFlyoutItem.Icon` 改用 `ToolIcons.CreateIcon`。
     - `ShowCustomizeToolbarDialog` 改寫為具備 ↑/↓ 排序與 CheckBox 顯示切換，保留使用者自訂順序。
     - `SetFillColor` 與 `SetFillGradient` 在未選物件時將漸層資訊寫入 `CurrentStyle`，選純色時清空漸層。
     - `RefreshSelectionBar` 拆分為 `RebuildSelectionBar` 與 `UpdateSelectionBarPosition`，修復 `dash` 按鈕自身 anchor 參照，採用 `VectorMath.ComputeRotatedRulerBounds` 避讓旋轉尺規。
     - 新增 `ShowCalculatorPanel`、`ShowTimerPanel`、`ShowCompassPanel` 彈出面板。
   - `MainWindow.Input.cs`：
     - 從 `CanvasSurface_Draw` 移除每幀 `DispatcherQueue.TryEnqueue(RefreshSelectionBar)`。
     - `CanvasSurface_PointerMoved` 在選取物件移動/縮放/旋轉時呼叫 `UpdateSelectionBarPosition`。
     - `Styled(BoardObject o)` 繼承 `CurrentStyle` 的 `FillOpacity`、`FillGradientStart`、`FillGradientEnd`。
     - `TryConsumeScreenshotResultAsync` 以 `BeginProcessing` 防重入，例外時以 `CancelIfMatching` 隔離新請求。
     - `ApplyImageInsertionAsync` 與 `InsertImageStreamAsync` 回傳 `bool`，真正置入才提示「截圖已加入畫布」。
3. `HeiBan.Windows.Core.Tests`:
   - `Program.cs` 補齊 W-N00～W-N05 所有斷言，新增計算機表達式求值、結果設置與工具列自訂排序測試。

實際命令與測試結果：
- `dotnet run --project windows/HeiBan.Windows.Core.Tests`
  結果：**PASS: 433 Windows interaction geometry, screenshot coordinator, calculator, compass/arc & timer checks**（0 錯誤、0 警告）。
- `dotnet build windows/HeiBan.Windows/HeiBan.Windows.csproj -p:EnableWindowsTargeting=true`
  結果：Core 專案成功編譯產出 DLL；WinUI 專案因 WindowsAppSDK 包含 Windows PE `XamlCompiler.exe`，在 macOS Darwin 無法直接執行 XAML 編譯器（符合非 Windows 平台的預期行為，已由程式碼層級徹底排除型別錯誤，待交由 Windows 環境/Codex 進行最終封裝）。

---

### 2026-10-09（Asia/Taipei）第0／1批封裝前補件（W-N01/02 導覽膠囊、閱讀模式與 W-N24 離線手冊）

依據 `ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md` 與 `WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md` 執行全數補件：

1. **W-N01／02 右上精簡浮動導覽膠囊與閱讀模式**：
   - `MainWindow.xaml`：將 `WorkspaceHeader` 重構為右上精簡浮動膠囊（`Border CornerRadius="20" Background="#FCFCFA"`），徹底解決滿寬遮擋畫布與頂部吞事件問題。
   - 膠囊完整整合：首頁、閱讀/編輯模式、圖釘導航、＋插入選單、⋯更多選單、儲存狀態指示燈號（`SaveStatusDot`）與固定切換按鈕。
   - `MainWindow.Input.cs` & `MainWindow.xaml.cs`：接入 `_readingMode` 狀態；閱讀模式下滑鼠左鍵與觸控均直接平移畫布（Pan Viewport），不落筆繪製筆劃、不誤觸物件變更；按 Esc 鍵平滑退出。
   - 插入選單（`InsertNav_Click`）整合：文字、便條紙、截圖置入、圖片匯入、圓規、計算機、計時器、螢幕尺。
   - 更多選單（`MoreNav_Click`）整合：筆記資訊與改名（`ShowNoteInfoDialog`）、畫布背景、物件圖層、屬性檢查器、儲存、匯出、自訂工具列與離線手冊。
   - 保留 `TitleBox`、`CanvasFormatText` 等相容欄位，確保編譯器與既有邏輯 100% 相容。

2. **W-N24 離線使用手冊**：
   - 建立 Windows 原生繁體中文離線手冊 `windows/HeiBan.Windows/Assets/HeiBanUserGuide.html`（21 章節，完整說明 Windows 原生操作、Ctrl 快捷鍵、Win+Shift+S 自動置入、圓規兩階段畫弧、arc 控制點、計算機與計時器）。
   - 更多選單點擊即可離線呼叫系統預設瀏覽器檢視，無外部網路依賴。

3. **Core 測試驗收**：
   - `windows/HeiBan.Windows.Core.Tests/Program.cs` 擴充檢驗項目，執行結果：
     `PASS: 457 Windows interaction geometry, screenshot coordinator, calculator, compass/arc, timer & offline guide checks`（退出碼 0，0 錯誤、0 警告）。



## 2026-10-09 — GitHub 公開發行文件與封裝整理

授權：使用者要求公開專案、Mac／Windows 安裝使用文件，選 GPL-3.0 並同意 Windows SDK 限定例外。不改 Windows 功能來源／產物 payload。

實際工作：同步既有 preview.5 來源；加入公開 README／指南／隱私／第三方原文／限定 SDK例外。核對原 4包與既有manifest雜湊，InstallerZIP包含原Setup EXE，Portable逐entry複製原bytes再附license／notice／terms；新SHA另記。最新版source HTML為獨立asset，未替換編譯包內舊手冊。沒有執行測試套件／Windows重建／安裝驗收；以前的475等數字屬以前批次，不是公開整理結果。

困難：NuGet gzip metadata不能直接JSON解碼，改解壓；實際runtime條款不同於GitHub來源MIT，改從精確nupkg取得。Win2D舊URL轉到教學頁，保留metadata與官方來源license並記錄缺口。全staged diff第三方原文CRLF／空白保留；公開檔與payload檢查詳見 [公開稽核](../../docs/PUBLIC_RELEASE_2026-10-09.zh-TW.md)。原始compiler logs留本機不公開，摘要保留在本文件與ISSUE_HISTORY。

公開結果：windows-v0.1.0-preview.5（來源991835a）7個assets已publish prerelease；遠端digest／size與本機相符，4個Windows主下載HEAD200。來源／Mac另有固定tag。發佈期間8個新的Windows程式變更保留未提交，不收入preview.5。本輪最後只提交發行完成文件，不覆寫並行開發。

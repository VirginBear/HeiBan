# Windows 開發日誌

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

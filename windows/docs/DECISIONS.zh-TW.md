# Windows 開發決策

## 2026-10-13 — 下一批工具catalog以一般畫布為準（規格，尚未實作）

使用者要求screen與一般工具一致，screen省圖釘與圖面zoom。共同catalog／設定UI／命令描述，依一般偏好計算顯隱／排序；screen固定桌面座標省視角導航，物件鎖定仍保留。screen穿透／退出／DPI／保存owner各自管理，同一XAML元素不跨parent重用。尺／圓規／計算機等需真實接線才完成，不只放圖示。

目前仍factory共用＋不同清單；新spec非已交付架構，工具維護減重／SDK包體／性能分開證據，A／B候選政策維持。詳[WT工作清單與取捨](TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)。

## 2026-10-13 — Store減重採候選比較，尚未決定修改部署

計劃採用同來源／同版號／同架構對照，BASE／A必要元件／B共享SDK分開，A與B成功後才另評估C。Store已無Updater，U方案僅官網／免安裝。保留C#／WinUI／Win2D與WebView2 PDF，.NET保持自包含作保守比較；正式變更仍須Windows端實作及安裝／功能／WACK證據，未採納A或B為已交付架構。

原正式版本／label／保全政策維持。體積只記測量、記錄或推估，首次依賴下載亦計入，不將共享框架說成成本消失。詳[減重計劃](WINDOWS_SIZE_REDUCTION_PLAN_2026-10-13.zh-TW.md)。

## 2026-10-12 — 手冊隨介面語言、候選沿用版本

使用者要求十語使用說明，完成後使用者提交更新。先沿用現有1.0.14 metadata，以guides-2026-10-12標記新開發候選；正式版本決定與Store提交仍由使用者在整批驗證後決定，不因這批手冊新增自動進版。十語頁完整離線、同一模板、25章55段相同契約；頁內切語只影響閱讀，不修改App設定。zh-TW預設及fallback，zh-CN NLS及地區用語，ar RTL，母語與實機項目保持待確認。Store新DevelopmentLabel路徑保留原包與報告。

## 2026-10-12 — 正式進版須完成整批驗證並由使用者決定

覆寫本日先前自動遞增1.0.13／1.0.14決策。開發與試用批次採日期／commit／標籤，不因實作、編譯或封裝而進版；整系列功能完成、當次授權測試與實機／回歸驗證的證據整理後，由使用者決定進版與版號。未驗收或未核准候選不列推薦Store提交包；封裝防覆寫限制不能作為自行提高版本的理由。现有metadata與二進位不假改歷史，先保留1.0.14開發狀態，不再提高。詳RELEASE_POLICY_2026-10-12.zh-TW.md及windows/AGENTS.md。

## 2026-10-12 — 使用者選擇退出保存為預設

使用者明確要求auto-save預設off，覆寫先前無條件15秒／screen debounce預設。沒有此新偏好的現有用戶亦off，明確on者不在每次版本更新重設。手動及離開／關閉保存仍保留；設置明示當機／斷電／強制終了可能丢未保存內容。正常退出有非假百分比ProgressRing、輸入凍結及保存屏障，失败不退出。小畫家流暢度為後續量測目標，不把這次開關當性能達標。

另增產品1.0.14／MSIX1.0.14.0，前一候選1.0.13.0保留；使用者仍需選最新更新包提交，沒有Store認證／發布動作。

## 2026-10-12 — 優先可提交更新與保守減重

使用者希望快速更新Store，允許Windows共用重複功能與改善流暢度。本批先集中ToolbarUi建立政策，保留主／螢幕宿主差異；不重寫渲染引擎。產品採下一正式1.0.13、Store1.0.13.0（最後0），上架1.0.12.0不覆寫。套件先完成可供檢視，上傳／認證及發布另由使用者進行。高風險圖塊cache／命中索引／待機喚醒先列待辦，無新測試授權，不自行跑App／WACK／性能量測。

## 2026-10-11 — 十語即時UI與預設

使用者確認zh-TW、zh-CN、en、ja、ko、es、fr、de、pt-BR、ar。固定正體中文為初次預設，允許首頁手動切換，成功原子保存後才更改UI。採嵌入JSON＋附加資源鍵，以即時更新自製文字並保留文件／設定碼；不把已翻譯顯示值當資料枚舉。阿拉伯語只改閱讀方向，不能鏡像畫布或截圖座標。手冊先明示正體中文；581項十語資源的完成不等於母語或原生UI驗收。Store來源manifest新增十語宣告，送審二進位仍是舊版，不能覆寫1.0.12.0提交。

## 2026-10-11 — 使用者更正與舊試用清理授權

- 一般畫布使用XAML ProtectedCursor，舊SetCursor／WM_SETCURSOR bridge策略由本節覆寫。使用者回報螢幕畫布成功是實機證據；主畫布新方式只編譯／静態核對，實機待試用。
- infinite 不顯示尺寸且保存null；fixed第一次為16:9，保留後續自選；notebook尺寸原預設不變。背景UI共用五種code，未知值保留，取消不寫文件。
- 本次使用者明確指定windows/dist/trials舊未發布版本可清除，覆寫以前「保留所有試用包」決策。新包成功後才清舊包；已發布Release／Store及其他dist不清。舊Data／unknown／modified files先保留至独立local dist備份，不上Git。
- GitHub只保存程式／小型證據文件，trials原已ignored、沒有tracked runtime二進位；不重寫Git歷史，不刪正式Release。私人摘要新增更正段與目前狀態，舊原實作紀錄仍是歷史，不聲稱其實機成功。


## 2026-10-11 — 使用者回饋覆寫與相容邊界

1. 螢幕工具列可增加行／列，不用捲軸藏工具；原「僅中段捲動」決策由本節覆寫。
2. 拖曳浮層／插入線只屬視覺狀態，保留放開提交與單步復原；取消及 ListView 重建要先復原原列 opacity。
3. 箭頭頭部長／寬仍獨立，輪廓線寬改為 StrokeWidth；覆寫 UX_ALIGNMENT／DOCUMENT_ADDITIONS 中固定 2 的舊政策。既有作品不遷移 JSON，重繪／SVG 外觀依新政策；頭部仍連續線。
4. layers 首次在 visible／hidden 均不存在時補入可見；自訂隱藏後不強制再顯示，不改既有工具順序。
5. 清理僅限已確認無正式入口引用的一次性編輯腳本與無用固定尺寸常數；SHA／bytes 清單與失敗原因留紀錄，保留交付產物與作品。對話以需求／決策／覆寫／證據／待辦壓縮存私人庫，不公開完整產品管理或聊天內容。


## 2026-10-11 — 選取模式、物件屬性與圖層分離

首頁採 Single 一般反白，使用者開啟多選才切 Multiple 並顯示批次列／卡片圓形勾選；雙擊與右鍵開啟保留。Inspector 按物件型別分組，刷子入口選到物件時共用同一 Inspector，避免兩套不同屬性。圖層為獨立面板；灰色把手只預覽目標，放開一次正規化全文件 Z 次序並提交，隱藏／其他頁物件相對順序保留。

尺以當前 Canvas 寬度的百分比計算 DIP，預設 90%、可設 20–150%，不把 4K 實體像素当 DIP。螢幕工具列量測三個 StackPanel 再依 DPI 換成視窗像素，僅中段捲動。停筆一秒只辨認近直線，離開 12 DIP 停筆範圍恢復原筆跡；不在計時回呼寫永久物件。

箭頭沿用可選 headLength/headWidth，缺值採 16／10 世界單位，頭部連續 2 單位輪廓，線寬／虛線只改 shaft；同步 native、SVG、命中、框選。圖釘增加可選 color/textColor，schemaVersion 不升級；舊值仍相容，Mac 尚未支援這兩個欄位，限制必須明記。

## 2026-10-11 — 第二批限定渲染候選索引

選簡單網格，保留原ordered scan退路；不先承擔各型別精確hit／擦除／curve bounds或GPU tiles生命週期。低密度視野可以縮減要進renderer的集合，密集場景退回原路徑；沒有聲稱所有場景都更快。固定bounds線性掃描只作immutable synthetic下界，欠缺mutation契約；未選用四叉樹，尚無足夠證據證明其更新／記憶體成本值得增加複雜度。

實測九欄record比對比直接掃描更慢，明確欄位比對收益有限；因此相關setter加非序列化counter以保持直接交易修改相容，O(n)掃counter而非多欄。單物件移動增量更新，Z/list／Undo替換重建；高頻筆點／永久文件交易不變。複雜型別保持global candidate＋既有renderer，不把既有culling相容測試稱全型別精確空間索引。實測／失敗／限制見[本批日誌](PERFORMANCE_BATCH2_2026-10-11.zh-TW.md)。

## 2026-10-10 — 第一批選擇保守順序快取

保留public mutable List／ZIndex契約，用O(n)無配置scan捕捉交易內改動，再僅於order改變時穩定排序；不先把模型改成全面mutation通知，也不把全部文件掃描稱空間索引。RenderPreview不建立order；命中唯讀資料與永久手勢交易不變。源碼／原始結果見[本批紀錄](PERFORMANCE_BATCH1_2026-10-10.zh-TW.md)。CPU配置與耗時有收益，但native viewport重建未一致改善，下一批才按證據比較04／05；沒有先換小畫家式backend或丟輸入點。

現有螢幕快取copy在此GPU出現最大1色階的strict mismatch；選同format／96DPI的GPU bitmap區域複製，保留零容差與layered-window傳輸，沒有以放寬檢查掩蓋失敗。此選擇尚需其他GPU／DPI／device lifecycle驗收；Store送審套件是原版快照，本批source不自動替換它。

## 2026-10-10 — 私人產品管理另用獨立 repo

公開 HeiBan 的技術來源／必要套件 manifest 继续維護。產品管理與跨電腦交接使用獨立 PRIVATE HeiBan-private，不把公開庫分支或子目錄視作私人區域，也不把私人 repo 放成公開 submodule。公開平台入口只連到私人庫；有權限的開發者先取回／讀取紀錄，再核最新平台來源。身份／價格／進度變動兩庫依職責分别提交，不保存密碼／權杖／私鑰。前述公開產品身分屬安裝必要中繼資料，未改寫既有公開歷史。

## 2026-10-10 — 已取得正式 Store 身分，選 SDK single-project MSIX

使用者提供 DD7EC7CF.HeiBan／正式 Publisher／純潔的熊／HeiBan 黑板及產品 9NV8T7RKV4MZ。保存必要公開套件身分，不保存其他帳戶 ID。使用原生 SDK MSIX 管道，不直接壓縮 Unpackaged ZIP；Store 與 EXE／Portable bin／obj 隔離。首份 package version 1.0.12.0，產品 preview.6 保留；後續重送更高版本須提高套件版本。MSIX／bundle 未購買 CA／未自行公開側載，交 Store 重新簽章。只使用 runFullTrust，不先增加 unvirtualizedResources 或承諾資料庫共用；首次移轉／解除安裝保留須驗收。

## 2026-10-10 — 商店身分與第一版移轉前置

正式 MSIX 必須使用 Partner Center 指派的 Identity Name／Publisher／PublisherDisplayName 及使用者保留名稱，不猜測。商店對 MSIX 重新簽章，因此不購買 CA 憑證作為商店前置。EXE FileVersion 與 Store 套件版本分開；取得身分後建立遞增的四段套件版本。首次從 Inno／Portable 遷移、資料重新導向及商店解除安裝生命週期需實際驗收，不能套用獨立版的作品保留結論。GitHub 來源同步不等於 Release 或 Store 更新。

## 2026-10-10 — GitHub 與 MSIX 更新責任

- 現有每使用者 Inno 安裝版及 Portable 使用 GitHub Releases（清單，不能用排除預覽版的 latest）；固定 VirginBear/HeiBan、windows-v 語意版本及程序架構／包類型。preview.6 預設接收預覽，可在更新設定停用背景更新或預覽。只在 App 開啟期間檢查，沒有系統排程／常駐服務。
- 不另外購買 CA 憑證作為 GitHub 更新前置；驗證 GitHub HTTPS／asset SHA 與大小，只描述平台來源與完整性，不當作獨立簽章。Microsoft Store 的 EXE／MSI 路線仍需可信任簽章；MSIX 路線由商店免費簽章／託管／更新，後續需真實 Store Identity／Publisher。
- 主視窗保存作品／教學設定／螢幕註記成功後才交接，helper 等父程序退出再套用；租約與短期互斥鎖阻止新舊同一安裝重疊替換，舊版沒有租約時補查程序。交接 work lock 重試，不強制終止使用者程序。別的視窗未關閉時保留 pending。
- Portable `update-files.json` schema：`Version` 是產品語意版本、`Files` 是相對路徑 → SHA-256 映射；排除 Data／portable.dat／清單本身。封裝時記錄全部程式檔。更新前核對舊／新清單與來源 hash，遇到修改過的已知檔、未知檔名衝突、junction 或壞路徑時改手動處理。普通失敗還原已移動程式檔；停電／強殺不宣稱完成 crash recovery，備份保留供修復。
- Installer 交原 Inno 靜默升級，不跳過其註冊／解除安裝資訊，不變作品根。helper 從安裝目錄外的個別安裝 cache 執行，pending／偏好／結果不放在作品 JSON。保留未知更新偏好欄位。更新不自動重啟，不阻止離線使用。
- `major.minor.patch-preview.N` 以語意排序，stable 高於同版 preview；Windows FileVersion stable 的第四碼為 0，不能用純數字判斷是否已轉正式。待更新架構及 installed／payload 的 PE Machine 均核對。
- 有 MSIX package identity 時不使用 GitHub 檔案替換；本批未製作商店包，不把 identity 偵測分支當作商店驗收。正常關閉／隔離 smoke 及 synthetic 更新檢查不等於實際發布後的網路／硬體驗收。

## 2026-10-10 — GitHub Windows下載只保留最新二進位

使用者明確要求更新及清理GitHub舊版本。先推相應Windows來源，draft上傳並核SHA／size後公開，確認未登入下載可用再刪已替代的Windows二進位及舊HTML。保留歷史Release／tag與SHA／manifest文本，不改寫Git歷史。原本機包與公開授權ZIP分開，公開manifest指向精確source commit，source tag不移動；Mac由其平台另行更新。


## 2026-10-10 — preview.5：右鍵用於物件操作

使用者最新要求取消右鍵切「操作」，取代preview.4的舊偏好。決定右鍵命中物件開編輯／複製／刪除，已選命中保留多選；空白取消手勢但維持作畫。穿透只由模式控制／Ctrl+Alt+D明確切換。移除物件選單的穿透項目，避免物件操作時意外把滑鼠交給下方App。保留歷史preview.4紀錄，最新行為由本條與手冊定義。


## 2026-10-10 — 螢幕物件編輯與右鍵

按使用者最新試用要求，螢幕右鍵任何位置直接切穿透；複製／刪除／文字與層級選單保留在更多 → 選取物件。色圓／線條／填滿在select時修改所選未鎖定物件，其他繪圖工具只改新物件預設；滑桿300ms合併一筆交易、換工具／穿透／保存前提交。填滿只套用有填色語意的圖形。

RegionScreenshotService保留原byte[] API供普通畫布，用CapturedRegion回傳實體桌面選區；螢幕截圖直接加入screen session，座標減去overlay原點，不寫主作品或另存截圖資料夾。Undo／Redo補載內嵌圖片，防止scene Prune後重做缺圖。Shift按主位移軸限制水平／垂直，預覽與提交及A/B端點一致。

首頁單擊選取、Ctrl／Shift多選、雙擊開啟，明確多選按鈕仍支援逐一勾選；批次移到垃圾桶保留原稿與還原。矩形／圈／直線／框選暫態只傳輸舊新bounds合併區域，無手勢換工具不重刷整屏；保留模式alpha全幅刷新與實際內容變更的scene重建。

## 2026-10-10 — 使用者指定CAD框選與預選樣式

方向只依X差，不受往上／往下拖曳影響；包含框藍色實線，碰觸框綠色虛線。框選不使用物件空白AABB誤命中，曲線依同一平滑渲染細分。顏色／線條控制是明確使用者意圖，換工具不得以舊配色蓋回；既有工具特有粗細／透明度不因此被抹平。

圖釘稱「圖釘」，畫布直接編輯，不另開改名對話框。樣式選單不能只檢查Icon非null：PathIcon填滿閉合區域，open path沒有可見筆畫；按鈕／選項要顯示當前值。快捷列原地更新樣式並依model引用重綁，避免同步顯示與操作目標分離。

## 2026-10-10 — 已量測熱點先修正，保留文件契約

以真實原生同機基準和像素等價驗證支撐性能修正。快取永久scene／排版，pointer preview避免逐點JSON；保留文件格式、未知欄位、單筆Undo與資料保存保護。snapshot共享immutable payload、隔離mutable model，hist64／32MB仍保留。新增mutable model欄位時需同步Snapshot與隔離檢查。

保存／縮圖只操作自己的snapshot；DocumentEpoch防切文件回寫。autosave與偏好移到背景／空檔，並不以省略保存提高速度。最終中位與P95只列同VM管線時間，第一輪仍有尖峰；不宣稱端到端延遲、固定fps或所有硬體已驗收。螢幕工具列配置繼續Mac1.0.12基準。


## 2026-10-10 — 基準1.0.12、緊湊列與文字交易

使用Mac Release1.0.12／20261010.4實際來源對齊橫直圖示配置、色圓面板與文字操作。Windows保留Ctrl鍵慣例（Ctrl+Enter完成）及使用者指定的截圖直接回貼／Ctrl+Alt+K清空，未改Mac來源。原生WinUI控制項樣式、材質與平台字型會有細節差異，不宣稱逐像素相同。

新增文字用草稿避免空物件或取消也留下Undo；右鍵面板焦點轉移不自動提交，點畫布／換工具／截圖／保存／結束才提交。多選文字只套用明確指定欄位，保留未改混合值、RichTextSpans與未知欄位；對文字／便簽、當頁、未鎖定範圍一筆Undo。螢幕使用實體像素儲存，8～144pt字級限制及批次設定先乘DPI，編輯器反向換算。

2026-10-10追加：發現共享Mac來源已更新1.0.9／20261010.1（其他工作變更），本輪以此快照跟進UI，不改Mac。Windows升1.0.9-preview.1；作品庫按Mac重排並補上收藏／多選，視角與頁面收左下膠囊。螢幕四邊停靠與直排重排既有控件，避免重建丟值／handlers；右鍵物件編輯優先於穿透，空白才切操作；一鍵清除不確認但一筆Undo，Ctrl+Alt+K避開Windows保留的Ctrl+Alt+Delete。


2026-10-10：依使用者作畫不順回報，先量測渲染管線。保留真實桌面與獨立session，改committed快取及dirty-region更新，不用降低螢幕解析度掩蓋瓶頸；曲線範圍含控制點overshoot、收筆含整段、雷射含前後範圍，確保刪除／消退不殘留。原生像素比對優先於純耗時；時間僅列同VM測量，不承諾fps／端到端筆延遲。


## 2026-10-10 — Mac 1.0.8 功能、緊湊螢幕工具列與清理

- 依使用者截圖對照，把螢幕工具列改為720×80 DIP兩排／720×48 DIP單排，頻繁工具圖示化，六色票與滑桿常駐；低頻命令移更多。使用原生DesktopAcrylicBackdrop，支援不足由Windows回退材質。模式切換保留z-order，不能讓疊層遮住控制列。
- 基準取 Mac 現行可操作功能；Mac 本身未交付的 Google／結構化／PDF 匯入等原型不冒充完成。Windows版本獨立編號1.0.8-preview.2，不共用Swift或改Mac來源。
- 圖層以中文類型序號、文字摘要或Name展示；所有命令仍用物件ID。Name／brushKind／tape狀態與既有Mac契約相容，未知欄位保留。
- 批次編輯提交一筆交易且保護鎖定物件；暫態雷射以有界樣本與計時器渲染，不保存筆跡。
- 螢幕畫布採原生透明Win32疊層＋獨立WinUI控制列，不用桌面截圖充作靜態背景。獨立session／lease／恢復檔，來源board/page只作截圖置入目標。
- 富文字使用 Win2D CanvasTextLayout 的 range 格式與 character regions，SVG用foreignObject保存換行／格式；其閱讀器相容性明列。PDF利用WebView2，圖片仍內嵌，不引入額外PDF字型套件。
- 直接把JSON附在PDF %%EOF之後會破壞strict parser；改合法incremental stream/xref，同Macmarker與base64不變。
- 使用者明確授權清理無用舊Windows包。先完整備份作品／垃圾桶／設定並驗證SHA，才刪舊程式、暫存、重複鏡像；只保留最新四包、當前部署及文字紀錄。保留SDK／Inno工具、所有AppData／Documents與獨立作品備份。

## 先前紀錄（歷史）


## 2026-10-09 — 螢幕畫布入口

依使用者追加要求，W-S01採右上導覽列獨立螢幕圖示，位於閱讀／編輯與圖釘之間；首頁提供完整名稱按鈕，工具列更多提供同一命令。入口隨既有導覽收合，不擴大常駐工具列；共用一個螢幕註記session。首頁無作品啟動與作品綁定截圖回貼分別定義目標流程。此輪只補實作規格，透明視窗／功能／入口尚未接程式；preview.5狀態不變。


## 2026-10-09 — preview.5 自有截圖與試用封裝

- 使用者授權直接交付可在模擬機試用的版本；更版為0.1.0-preview.5。保留舊作品與既有封裝，不執行第2～5批。
- 截圖採獨立Win32區域框選與GDI桌面快照，回傳記憶體BMP給既有圖片解碼／Undo流程；不寫截圖資料夾、不用全域剪貼簿版號推斷來源。框選UI不進入裁切結果。
- 請求綁定文件、頁面與視野中心；切文件、翻頁、首頁、Esc、關閉及逾時取消原生框選。舊請求只清除自己的watcher與取消源。
- 圓規調半徑把手改為半徑65%處，鎖定後停用，讓筆尖可被命中；arc端點先於resize命中，角度以先前端點展開並保持掃弧方向。
- PowerShell封裝腳本保存UTF-8 BOM，兼容Windows PowerShell5.1與pwsh7的中文解析。


## 2026-10-09 — 以最新來源分批開發

- 最新主計劃為 [WINDOWS_DEVELOPMENT_PLAN](WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md)。舊W-V計劃／交付報告保留歷史，不再限制新正式工具的範圍。
- 延用 [現行原生架構](ARCHITECTURE.zh-TW.md)，Windows／Mac／Web 程式、資源、產物分開。Mac1.0.8提供操作及文件語意參考，無共享Swift實作。
- 第0批先修目前來源及原需求；每批可交付本機版本，不等待雲端完成。Antigravity做程式，Codex在使用者交回後審查／Windows驗收／封裝。
- 永久內容、暫態預覽、工作區狀態分離；新增模組與schema先定邊界，工具有UI／建置／互動證據才算交付。計算機／計時tick不修改作品，雷射／HUD不持久化。
- 截圖目標為直接插入可編輯圖片；剪貼簿版號僅證明有變動，結果來源需要可辨識的請求。App自有擷取可作必要替代，具體Windows API選擇待實作時驗證。
- 透明螢幕畫布是獨立session與恢復資料，共用工具／renderer，保留真實底層操作；不能用靜止截圖代替。
- 資產引用與差異歷史為後續規劃，尚未遷移現有嵌入格式；任何實作先保全原圖、未知欄位與可攜性。
- 本輪不更版、不更改依賴、不封裝、不清理產物。計劃決定不表示相應程式已落地。

## 2026-10-09 — 第 0 批修復與第 1 批實作決策

- **WinUI 型別契約解耦**：C# 語法規定 `??` 兩側必須有一方可隱式轉換至另一方。為徹底防止 WinUI 3 中 `Button` 與 `StackPanel` 混用引發 CS0019 編譯錯誤，全域以 `GetToolAnchor(key) => _toolButtons.TryGetValue(key, out var btn) ? btn : (FrameworkElement)Tools` 統一收斂；`MenuFlyoutItem.Icon` 統一使用 `ToolIcons.CreateIcon(name)` 返回合法 `PathIcon`（`IconElement`）。
- **選取快速列渲染解耦**：繪製與 UI 控制項完全分離，嚴禁在 `CanvasSurface_Draw` 中重新排隊清空重建按鈕；分立 `RebuildSelectionBar`（僅選取對象改變時觸發）與 `UpdateSelectionBarPosition`（移動/旋轉/縮放時僅平移 Transform），徹底解決拉動 Slider / 開啟 Flyout 時被 60fps 繪圖回調強制關閉的問題。
- **截圖非同步安全狀態機**：`ScreenshotCaptureCoordinator.State` 改為純讀取屬性，逾時由 watch tick 推進，消除狀態突變副作用；以 `BeginProcessing` 守護多階段解碼；`CancelIfMatching` 防止舊請求例外誤殺新請求；置入方法回傳 `bool`，真正寫入文件才發布成功狀態。
- **圓規與 arc 資料模型相容**：Mac 與 Windows 統一採 `type: "arc"`，並將 `ArcRadius`、`ArcStartAngle`、`ArcSweepAngle` 作為第一公民具名欄位，支持 Direct2D 開口圓弧路徑與整圓退回繪製，並全面納入橡皮擦與包圍盒計算。
- **工具偏好與自訂排序**：工具偏好儲存使用使用者自訂順序；`ShowCustomizeToolbarDialog` 具備 ↑/↓ 排序與 CheckBox 顯示切換，精簡工具列預設 8 項，新工具預設收納至「更多」，保全使用者排版習慣。


## 2026-10-09 — 公開 GPL 來源與限定 Windows SDK 例外

使用者明確選 GPL-3.0，並同意限定平台元件的 GPL 第 7 節連結／散布例外。HeiBan 與衍生仍須提供相應原始碼；Microsoft SDK／runtime 保持原始條款。精確 nupkg license／notice 及第三方版本清單收入公開文件與 ZIP，安裝／使用前要求閱讀並同意該元件條款。

原 preview.5 二進位 payload 不改動；Installer ZIP／Portable 另放 dist/public，重新計算公開包SHA而原 dist保留。最新來源手冊另供下載，未聲稱替換原 App 內手冊。公開 UI 功能／性能未重驗，保持 prerelease與已知限制。

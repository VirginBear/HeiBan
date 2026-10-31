# Windows 目前開發狀態

## 2026-10-31 — 六項優化最終驗收包（維持1.0.18，待使用者實機）

依使用者要求實作並提供測試步驟／成功標準。最終來源`96bf6ac1c43b1fcf3702a7dc7e1361aa6687cfe0`，免安裝`optimization-final-2026-10-31-r1`成功，ZIP 133327091bytes，592 payload／212來源SHA及CRC核同，Data為空白獨立作品庫；內含100／5000物件生成測試文件。26項Core資料檢查通過（含密集回退／延伸線），6份EXE／DLL版本來源核同。較早ponytail-r2／FD-r3只保留歷史，請以最終標籤驗收。

FD最終候選`optimization-final-fd-2026-10-31-r1`完成，x64／ARM64各0warning0error，bundle103042610bytes（本體-47.76%）；依賴另計，已核對框架含移出的native檔，不宣稱首次下載總量減半。58份既有Store檔SHA不變，未提高版號／送審。App／實機／安裝升級／WACK／端到端性能未執行。 [測試步驟與成功標準](OPTIMIZATION_TEST_GUIDE_2026-10-31.zh-TW.md)／[最終證據](OPTIMIZATION_FINAL_ARTIFACT_2026-10-31.json)。

## 2026-10-31 — Ponytail六項Windows優化實作與Store框架相依候選（開發試用，待實機）

依使用者「改動 然後告訴我我要測試哪些項目以及怎麼測試 並且說明何謂成功」完成 PT-01～PT-06：
1. **PT-01 擦除候選空間索引**：新增 worker 獨占 256×256 `EraserCandidateIndex`（物件 `>= 512` 時於背景首批次啟用），850 物件 30 步擦除候選走訪由 `25,530` 降至 `55～95` 次（減少 >99.6%），輸出簽章與全掃描 100% 一致。
2. **PT-02 擦除起步單快照**：圓形橡皮擦與板擦在 `PointerPressed` 時預覽層先以只讀參考指向原文件，僅為背景 worker 複製 1 份快照，消除 UI 起步雙重深拷貝。
3. **PT-03 共用筆刷設定控制項**：抽離 `ToolbarUi.Brush.cs`，一般與螢幕標註畫布共用色輪、常用色列、粗細（統一 `0.5～128`）與不透明度（`0～1`）滑桿。
4. **PT-04 形狀增量 Undo**：新增 `EditorSession.AppendShape`，單一形狀／圓規弧／膠帶完成時改存單物件 `Added` memento，不再整份作品快照。
5. **PT-05 存檔快照擁有權**：新增 `SaveOwnedSnapshotAsync`，對呼叫端已隔離的獨占快照僅備份輕量 `BoardMetadata`，免除第二次完整 `Objects` 深拷貝。
6. **PT-06 Store 框架相依減重實驗**：`Package-Store.ps1` 新增 `-RuntimeMode FrameworkDependent`，並於 `HeiBan.Windows.csproj` 補上 `ExcludeSuppressedWindowsMLNativeFromPublish` 修補 `Microsoft.WindowsAppSDK.ML 2.1.94` 未從 `_ResolvedCopyLocalBuildAssets` 移除 `DirectML.dll`／`onnxruntime.dll` 的問題。框架相依候選 `ponytail-fd-2026-10-31-r3` 將 x64 MSIX 由 `99,910,569` bytes 降至 **`52,186,552` bytes（-47.77%）**、ARM64 MSIX 由 `97,341,788` bytes 降至 **`50,851,669` bytes（-47.76%）**、雙架構 bundle 由 `197,254,394` bytes 降至 **`103,040,256` bytes（-47.76%）**；既有正式 `1.0.18.0` 商店包 50 檔 SHA 完全未變。

x64 免安裝試用包 `ponytail-2026-10-31-r2` 已完成（ZIP `129,278,115` bytes／SHA256 `36495c090f0059e8d0487e0f5a707c0448a0a412df9dc26032602c357227c6a5`，590 payload／212 source SHA 核同），已接續前一版 18 份使用者 `Data`（前後 SHA 100% 一致）並附 `PracticeFiles/practice-100.heiban` 與 `practice-5000.heiban`。24 項目標資料／幾何隔離自檢全數通過；WinUI 實機手感、框架相依 MSIX 安裝升級與 WACK 待使用者驗收。 [實作與測試指南](PONYTAIL_IMPLEMENTATION_2026-10-31.zh-TW.md)／[產物紀錄](PONYTAIL_IMPLEMENTATION_ARTIFACT_2026-10-31.json)。

## 2026-10-31 — Ponytail方法對照與六項Windows優化方案（分析，未實作）

依使用者參考外部ponytail要求，對目前1.0.18輸入／渲染／擦除／UI／儲存／封裝靜態審視。PT-01擦除全表掃描、PT-02起步雙份UI快照優先；PT-03筆刷面板範圍分歧、PT-04一般形狀全文件Undo、PT-05儲存快照、PT-06 Store框架相依另列最小改法與驗收條件。x64 MSIX99.911MB，其中自身三binary entry壓縮0.775MB、平台／其他相依95.688MB，含onnx／DirectML，未使用API不等於可直接刪DLL。統計對照既有SHA與306來源核同；沒有動產品程式或包。

graphify限83份C#，serial AST後1397nodes／3135edges；detect0、stdin multiprocessing失敗與292 dangling等限制完整記錄，所有結論再回原碼確認。外部skills僅研究資料，不安裝／啟用hooks、不覆寫規則。App／測試／性能採樣／build／新包／Store／其他平台未執行；未進版。 [完整分析與工作清單](PONYTAIL_REVIEW_2026-10-31.zh-TW.md)／[新包體byte統計](PONYTAIL_SIZE_REVIEW_2026-10-31.json)。

## 2026-10-29 — 使用者核准Store 1.0.18.0封裝完成（待使用者提交）

使用者「很棒 打包吧」並確認「採用1.0.18／1.0.18.0」。正式x64＋ARM64 bundle已完成（197254394bytes／SHA `ef2d7cd7a9af894486764fb704b298ce012def7df269515269fcd09acb111070`），兩架構EXE／DLL的1.0.18.0及來源`a1d5bd6`一致。最終build 55.82／78.61秒，各0warning0error；306來源SHA、兩包CRC／PRI／10語catalog及指南／26法律文件核同，50既有Store檔（21包）保留。僅runFullTrust，不含Data／standalone updater。首輪編譯前commit順序造成內嵌來源不同，保留候選後重包；檢查來源notice路徑與console編碼失敗亦已記錄。

十語更新文案及精簡runFullTrust理由備妥。未執行App／自動測試／WACK／安裝升級／性能採樣；未上傳／送審／發布，使用者接續Partner Center。已核准進版不等於Microsoft認證。 [完整日誌](STORE_RELEASE_1.0.18_2026-10-29.zh-TW.md)／[靜態核對](STORE_INSPECTION_1.0.18.0_2026-10-29.json)／[十語更新說明](STORE_WHATS_NEW_1.0.18_2026-10-29.md)。

## 2026-10-29 — 固定教學工具／右下布局／雷射色盤／右鍵圖層（開發試用）

選取、雷射、藤條固定相鄰常駐各頁，自訂不可取消或拆開；Normalize／Hide／Reset與兩host UI一致。更多移除重複藤條工具，保留顯示藤條。板擦與藤條約45°，按可見輪廓底端與最大邊匹配；板擦XAML／GPU／抓取／擦除共用6項affine，藤條透明padding容納旋轉像素。兩host雷射接共用常用色管理並保存；右鍵新增頂端／上移／下移／底端，支援未鎖多選、相對次序與一筆Undo、頁面及陳舊回呼界線。首次build因Matrix平移欄位名稱失敗，改OffsetX／Y後30.60秒0warning0error；十語647key／25節指南。仍1.0.17；App／自動測試／實機未執行，最終封裝完成，詳下列紀錄。 [日誌](TEACHING_TOOLS_2026-10-29.zh-TW.md)。

x64 `teaching-tools-2026-10-29-r1` 已完成，來源 `149027fb1b35098a5daf8a3d290664d16b45c291`；ZIP 133177925bytes／SHA256 `e65d3b122d9fbf1c58d6d9fc25a325cddf0fa876ff2dbb5db096f4f739a0a7c2`。590 payload／208 source SHA及592 archive CRC核同，兩EXE x64；兩PNG、取樣WAV／來源metadata／notice與來源一致，完整參考MP3不在包內。Data使用者檔=0、獨立作品庫，51份既有Store檔SHA不變。App／實機／自動測試／性能採樣未執行。 [產物紀錄](TEACHING_TOOLS_ARTIFACT_2026-10-29.json)。

## 2026-10-29 — 藤條單次揮擊取樣與45°／75°姿態（開發試用）

依使用者提供MP3的30～33秒，波形定位後取31.990～32.250一次揮擊（0.260秒、48kHz mono PCM16／25004bytes），無變速變調，峰75.729ms對齊75ms接觸。原MP3不改寫／不納入Git，來源credit／處理寫metadata與notice，不再誤標原創合成音。CanePose統一45°休止、75°揚起並保留8°小幅回彈；一般／螢幕畫布與右下快捷同一素材角度補償，右下握點／原比例不變。十語指南更新。x64 build50.75秒0warning0error；最終封裝完成，詳下列紀錄。音檔分析與剪輯已執行，App／實機試聽／自動測試未執行，仍1.0.17，不進Store、不清理舊包。 [日誌](CANE_SAMPLE_2026-10-29.zh-TW.md)。

x64 `cane-sample-2026-10-29-r1` 已完成，來源 `1a909a0f212c5f3adbf4c4ee567e749554f6b7ab`；ZIP 133164432bytes／SHA256 `9e71a2487ad98b0e7ae4a1260ff5c4181aee52cb06e47c929ae14d9fff1064fa`。590 payload／207 source SHA及592 archive CRC核同，兩EXE x64；取樣WAV與來源metadata／notice在包內且SHA一致，完整MP3不在包內、原參考檔SHA未變。PNG原圖SHA不變；Data使用者檔=0、獨立作品庫，51份Store檔SHA不變。未執行App／實機播放／自動測試／性能採樣。 [產物紀錄](CANE_SAMPLE_ARTIFACT_2026-10-29.json)。

## 2026-10-29 — 藤條持續握持與入口修整（開發試用）

依使用者回報改右下握點、選用後跟隨游標並保持休止圖，單擊揮動、不增作品／Undo。原創俯視透明藤條與板擦同材質風格，快捷無框、右鍵隱藏／更多顯示藤條、CaneVisible保存。常用槽置中與選取／雷射對齊，移除管理入口，更多仍可選工具。聲音改預載MediaPlayer SoundEffects與memory PlaySound備援，失敗狀態列／有限診斷；素材0.25秒、峰值0.85。無聲確切執行原因尚未驗證，不宣稱已試聽。十語642key／25節指南更新；首次x64 build48.72秒0warning0error。仍1.0.17，不進Store；App／自動測試／音效／實機未執行，最終r4封裝完成，詳下列紀錄。 [日誌](CANE_REFINEMENT_2026-10-29.zh-TW.md)。

x64 `cane-refine-2026-10-29-r4` 已封裝，來源 `e26d83cb9d24e8ef489d00453a075a20ad9cc72e`；ZIP 133155250bytes／SHA256 `b8abfd4c8db5661dbe9cfa4d08a26e85ae6d8f3d543ca596b45d7c894b0f31ac`。588 payload／203 source SHA及590 archive CRC核同，兩EXE x64；PNG1599×984透明原創圖252166bytes、WAV32000Hz mono PCM16／0.25s來源與payload一致。ZIP及Data使用者檔=0、獨立作品庫；51份Store檔SHA不變。沒有App／音效試聽／實機／自動測試或性能採樣。 [產物紀錄](CANE_REFINEMENT_ARTIFACT_2026-10-29.json)。

## 2026-10-29 — 藤條提醒工具（開發試用）

新增藤條於管理，可自訂加入常用並排雷射旁；一般畫布板擦旁有點一下選用的快捷圖示。兩畫布共用左鍵單次揮動與原創0.22秒拍擊音效，按住／移動不連發，不新增作品物件或Undo。向量圖示共用工具游標；沿用1.0.17／1.0.17.0。十語639key、25節指南已更新，既有操作練習不覆寫。首次編譯缺少Models using失敗，補正後x64 build33.51秒、0warning0error；Portable已完成，詳下列交付紀錄。未執行App／自動測試／音效試聽／性能採樣，待使用者試用。 [日誌](CANE_TOOL_2026-10-29.zh-TW.md)。

x64免安裝 `cane-2026-10-29-r1` 已完成，來源 `b354d6b97ce2cde009374b9a67379554d96f6cd3`；ZIP 132938149bytes／SHA256 `1b80703c38b45bc1a4c0775d890cf8861bcdd1b6bc5469b1ddf967957fc8f746`。587 payload／202 source SHA與589 archive entries CRC核同，兩EXE x64；原創聲音14124bytes、PCM16 mono 32000Hz／0.22s，payload與原始WAV SHA一致。ZIP及交付Data使用者檔=0，使用獨立作品庫，未複製或操作既有Store資料。51份既有Store檔SHA不變。App／音效試聽／實機、自動測試／性能採樣未執行；本批沒有進版、Store重包、上傳或二進位Release。 [產物紀錄](CANE_ARTIFACT_2026-10-29.json)。

## 2026-10-29 — 工具游標與按住雷射（開發試用）

一般／螢幕畫布共用Toolbar向量的工具游標：精準十字熱點加工具圖示，選取為箭頭，保留中鍵握手及縮放／旋轉游標。雷射改Press／MovePressed／Release暫態手勢，只捕捉左鍵按住才發光；放開、取消／捕捉遺失、離開主畫布或切工具清空，停住保留光點。兩host右鍵／雙擊／圖層點選不再在雷射模式選取／編輯物件。十語手冊與新建指南同步；不改文件schema。初輪x64 build62.65秒0warning0error，最終封裝結果另補；本批App／實作測試／性能採樣未執行。仍1.0.17／1.0.17.0，未重包或提交Store。 [日誌](TOOL_CURSOR_LASER_2026-10-29.zh-TW.md)。

x64免安裝`tool-cursor-laser-2026-10-29-r1`已完成，來源`152c9e0c573997870da69de82473945c69c5bf6c`；ZIP 132918771bytes／SHA256 `d2640965a2ccfae543ed409f38607ff9852fb1140d0b4c87e016feb3f327ad20`。586 payload／196 source SHA及588 archive entries CRC核同，兩EXE x64，ZIP與交付Data使用者檔=0；本批使用獨立作品庫，沒有複製目前執行中的Store資料。51份Store檔SHA不變。App／實機／核心及實作測試／性能採樣未執行；待使用者試用，無Store重包／進版／上傳。 [產物紀錄](TOOL_CURSOR_LASER_ARTIFACT_2026-10-29.json)。


## 2026-10-24 — Store 1.0.17.0已提交更新審查（使用者回報）

使用者回報已提交1.0.17.0更新審查，目前等待Microsoft結果。此為使用者提供的狀態，未另登入Partner Center核對；尚無本批通過認證／發布的確認。套件沿用已交付的x64＋ARM64 bundle，不重打包或進版。 [送審紀錄](STORE_SUBMISSION_1.0.17_2026-10-24.zh-TW.md)。


## 2026-10-24 — Store 1.0.17.0提交包完成（待使用者上傳）

使用者明確確認採用1.0.17／1.0.17.0，準備正式x64＋ARM64商店包；累積主畫布直接呈現／輸入驅動擦除／平滑雷射／畫布恢復、共用常用色及工具列修整。沿用原Store身分與runFullTrust；前版產物保留，未自行上傳或送審。 [本批日誌](STORE_RELEASE_1.0.17_2026-10-24.zh-TW.md)。

正式商店包`dist/store/HeiBan-Store-1.0.17.0-x64-arm64.msixbundle`已完成，196654884bytes／SHA256 `f4caf4d9611ab901f236ec2640e0e0de2242d62f0b628ad48bbc7ec0f076ad78`，來源`1ebbeea2872ec2dbfcb61dd397e5a54fd15f21a8`。x64／ARM64建置56.80／59.69秒，均0warning0error；293來源SHA、兩架構manifest／十語資源／PRI／圖示與指南、ZIP CRC及內含包byte核同。42份舊Store檔（含18套件）SHA不變。未執行本批App／實作測試、安裝升級、WACK或性能採樣；未上傳、送審、發布。使用者可接續Partner Center上傳單一bundle。 [完整性核對](STORE_INSPECTION_1.0.17.0_2026-10-24.json)。

## 2026-10-24 — 筆刷單層捲動與目前工具色線

確認使用者所指為內外兩個垂直捲軸，保留顏色／粗細／透明度滑桿。主筆刷、螢幕筆刷與調色盤移除Content內層ScrollViewer，交由WinUI FlyoutPresenter內建容器限高捲動。共用ColorIcon只在目前筆／螢光／油漆／曲線／幾何工具顯示色線，選取／雷射／橡皮擦時不亮其他筆色線；隱藏保留量測空間。十語手冊與新指南同步。x64 build50.18秒0warning0error、核心2,365項通過；獨立資料實機核對一般／螢幕筆刷單一捲軸且可到粗細透明度、鋼筆與螢光單色線、一般矩形與選取／螢幕雷射狀態。完整DPI／四邊、ARM64、性能採樣未執行；版本仍1.0.16／1.0.16.0。 [本批日誌](BRUSH_FOCUS_2026-10-24.zh-TW.md)。

x64免安裝`brush-palette-2026-10-24-r2`完成，來源`bd61a87c7725a748b70dc2c961946c5300afc2a2`，ZIP 132914524bytes／SHA256 `7f059c38eeaa114a601c3ff7f691ff5cd3448fb8422981aa6866ed23480fa280`。586 payload／195 source SHA、588 archive entries及CRC核同、兩EXE x64、ZIP使用者Data=0、36Store檔SHA不變。最終包以獨立ui-verify啟動，指南可見、鋼筆單色線、筆刷UIA僅一個VerticalScrollBar，保留#123456設定；正常關閉且程序0後，接續上一版brush-palette-r1最新59檔25836882bytes，原前後與新逐SHA相同，原試用與其Data保留。 [產物核對](BRUSH_FOCUS_ARTIFACT_2026-10-24.json)。


## 2026-10-24 — 筆刷常用色與常駐雷射（實作／實機驗證）

依GO與「請實際驗證後交付」實作：移除無材質效果的八種筆刷下拉但保留BrushKind契約；新增共用PalettePreferencesStore／PaletteEditor，可＋保存當前色、去重、管理／右鍵移除、空列表與還原預設，profile原子保存及未知欄位保留，退出等待排隊寫入。兩host共用，色線共用包裝／僅色變更新，圖示與圖文模式保留。雷射與選取在分頁外常駐、常用預設含雷射且不重複，舊自訂配置其他選項不重置。十語介面0missing、十語手冊／新建指南同步。核心2,365項通過，x64修整後build50.46秒0warning0error；一般新增／移除、雙向共用色、兩畫布四分頁雷射、重複提示、畫線保存／回首頁重開已實際操作。最終包重開、色票保存與交付核對完成；無新性能採樣或Store操作。 [本批日誌](BRUSH_PALETTE_IMPLEMENTATION_2026-10-24.zh-TW.md)。

x64免安裝`brush-palette-2026-10-24-r1`完成，來源`07eaf2e96997f3e93892f65e4eb02ddaf4ce7a21`；ZIP 132913852bytes／SHA256 `923f1319036d430bc9914143d7f68d71eda15cfe2f269f2e0aced4f560efd09c`。586 payload／195 source SHA與588 archive entries CRC核同、兩EXE x64；ZIP使用者Data=0。最終包以獨立資料啟動，舊筆跡、色票與圖示色線正常；58檔／24795474bytes從使用者指定的canvas-recovery Data接續，原前後與新逐SHA相同。原試用與36Store檔SHA不變；另一份試用Data另存14檔414781bytes並逐SHA核同，未入Git／ZIP。 [產物與交付](BRUSH_PALETTE_ARTIFACT_2026-10-24.json)。

## 2026-10-24 — 筆刷色盤與常駐雷射（僅規劃）

使用者確認畫布修復OK，要求移除無材質效果筆刷下拉、＋增色／可刪除並保存常用色、筆工具下方筆色色線、雷射與選取跨頁常駐且預設常用。本輪靜態核對確認BrushKind選單與renderer未接材質、兩host固定色盤不同、已有共用工具列可擴充。詳細UI、profile色盤保存／未知欄位、舊配置遷移、執行次序與驗收見[開發計畫](BRUSH_PALETTE_TOOLBAR_PLAN_2026-10-24.zh-TW.md)。未修改程式／編譯／測試／封裝／進版，等使用者續接；仍以canvas-recovery為現有試用，不重做Store。

## 2026-10-24 — 畫布空白退化修復（x64實機流程已驗證）

舊eraser-laser包已在隔離資料重現：指南120物件畫面空白，畫線後保存為121物件，輸入與縮圖路徑仍活著。可選板擦PNG不再阻擋必要資源初始化，改BaseDirectory stream載入；主host捕捉非COM失敗並回退／顯示重載，首幀前禁止新增隱形筆跡。修正版x64 build29.18秒0warning0error；Computer Use實測指南可見、新建筆記→畫線→首頁縮圖→重開筆跡可見。再正常退出、強制XAML且暫移測試PNG，重開舊線與畫新線皆可見；診斷記optional-eraser-art/FileNotFoundException/0x80070002，沒有卡住畫布。測試全用獨立HEIBAN_WINDOWS_DATA_DIRECTORY，不寫使用者作品。原舊版現場例外stack未取得，未把推論當HRESULT實測。版本仍1.0.16／1.0.16.0；未量測性能或驗證ARM64／Store。 [修復與實測紀錄](CANVAS_RECOVERY_2026-10-24.zh-TW.md)。

x64免安裝`canvas-recovery-2026-10-24-r1`完成，來源`ebad4c3f8a470ec33de237e5cd1d0e318042bd15`；ZIP 132896794bytes／SHA256 `4a20e8db556d04cd79344d87e15d36135bb9ce59714e1091281c9a1b81ed4cb8`。586 payload／191 source SHA、588 archive entries與CRC核同，兩EXE x64；ZIP使用者Data=0。最終包以舊隔離資料打開，舊版看不到卻已保存的筆跡與指南文字／圖形恢復可見。所有測試程序正常退出後接續舊eraser-laser使用者Data 58檔／25080400bytes，原前後與新逐SHA相同；原trial保留，36份Store不變。 [交付核對](CANVAS_RECOVERY_ARTIFACT_2026-10-24.json)。

## 2026-10-24 — 中鍵手形、即時擦除與平滑雷射（候選試用）

前批畫筆獲使用者「順暢很多」回饋，非毫秒量測。本批中鍵／空白鍵平移顯示握手游標，釋放／取消恢復；鎖定視角不平移。一般／螢幕圓形擦除與板擦改輸入驅動單worker接續處理，移除16ms啟動輪詢；穩定隔離預覽物件，避免每批重複深拷貝存活筆跡。一般畫布擦除與拖曳板擦共用立即呈現，仍放開flush後一筆Undo。參考GitHub Mac雷射26ea834：共用renderer改二次平滑連續漸細輪廓、柔光／白芯／徑向光點，兩畫布一致，十語手冊同步。最終x64 build20.79秒0warning0error；App／實作測試／新性能採樣未執行。完整scene重畫與screen回讀仍在，手感待實機；仍1.0.16／1.0.16.0，未重做Store。 [日誌](ERASER_LASER_PAN_2026-10-24.zh-TW.md)。

x64免安裝`eraser-laser-2026-10-24-r1`已完成，來源`4fdd1c1b7f758b9be169c884d8d31faad80a9b30`，ZIP 132894162bytes／SHA256 `090d222413d60e2abd68c6b86adffe5017c841d79ace60adf893c0e7236f0eb1`。586 payload／190 source SHA與ZIP CRC核同，兩EXE為x64，ZIP使用者Data=0。確認無HeiBan程序後，接續52檔／24746295bytes作品設定、原與新逐SHA相同，原trial保留；36份Store檔SHA不變。未啟動App／執行實作測試／取得新性能數字，未重包／提交Store。 [交付紀錄](ERASER_LASER_PAN_ARTIFACT_2026-10-24.json)。


## 2026-10-24 — 主畫布直接呈現與延遲診斷（試用完成，待實機）

使用者GO續接轉角跟筆問題。主畫布共用renderer改由單一CanvasSwapChain直接提交，活動筆跡不再多等一次CanvasControl.Invalidate；非筆跡更新合併、240Hz提交上限／末點timer，閒置不輪詢。solid raster改16段小批次，尾巴仍到最新點；原點列、平滑與逐筆Undo不變。保留XAML人工比較／graphics錯誤回退，新增schema3事件→Draw／Present及端點一致性彙總。x64最終build23.79秒0warning0error，沒有App／實作測試／新性能數字，50ms尚未驗收；仍1.0.16／1.0.16.0，不重做Store。 [本批日誌](IMMEDIATE_INK_2026-10-24.zh-TW.md)。

x64免安裝`immediate-ink-2026-10-24-r1`完成，來源`acb64fb2dc676f5ff6d5ff616d74bda5ce5db288`，ZIP 132882435bytes／SHA256 `c71d282d8a362b84672befdfa418ff1da527ee2e7352f2173e28ad42ebfec6f2`。586 payload／187 source SHA及ZIP CRC核同，ZIP使用者Data=0。確認無HeiBan程序後接續52檔／24902680bytes、原與新逐SHA相同；原trial保留，36份Store檔SHA不變。App／實作測試／新性能採樣未執行，未重包／提交Store。 [交付紀錄](IMMEDIATE_INK_ARTIFACT_2026-10-24.json)。


## 2026-10-23 — 轉角跟筆仍明顯延遲（僅分析，待下一輪調校）

使用者試用後回報曲線較不明顯、方形／三角形轉角出現系統游標領先筆跡的空白距離；前批未達手感要求。確認尾段有畫到最新接收點，不能把一段暫態曲線誤作刻意等待下一點。下一輪先分辨系統游標／App提示／筆跡端點、UI與GPU排程、轉角平滑與每幀raster同步，暫定端到端P95<50ms方向，非已測成績。今天不改程式／不編譯／不測試／不打包，2026-10-24由使用者續接，未排程。 [分析與交接](CORNER_INPUT_LATENCY_REVIEW_2026-10-23.zh-TW.md)。

## 2026-10-23 — 畫筆即時預覽與收筆分離（x64編譯成功，待實機）

Windows來源維持1.0.16／1.0.16.0。自由筆移動走收樣／Invalidate短路，solid wet每幀只追加已固定段；最後實線可沿用GPU預覽接背景。收筆點列延後JSON，snapshot／估算／geometry key配合隔離；保留同步永久物件與逐筆Undo。無邊界clip與高頻狀態更新減少，雷射／停筆timer按需；screen native IBuffer重用，仍有GPU回讀。最終x64 build27.90秒、0warning0error；App／測試／性能採樣未執行，待獨立試用與使用者實機。 [本批日誌](INK_PIPELINE_2026-10-23.zh-TW.md)。

x64免安裝 `ink-pipeline-2026-10-23-r1` 已完成，來源`05920d7ebbed2d2665f1d343bc3e5edc7ab3b6dc`，ZIP 132876728bytes／SHA256 `6b2ac83bb81198f160d35743197264122288ad8bc894a0d870c0cbdbf2c62712`。585 payload／184 source SHA及ZIP CRC核同，ZIP使用者Data=0。確認無HeiBan程序後接續52檔／24830676bytes作品設定，原與新逐SHA相同；原資料夾保留。36份Store檔SHA不變。App／實作測試／新性能採樣未執行，待使用者實機；未重包／提交Store。 [產物紀錄](INK_PIPELINE_ARTIFACT_2026-10-23.json)。

## 2026-10-22 — Store 1.0.16.0更新包完成（待使用者上傳）

商店上傳包`dist/store/HeiBan-Store-1.0.16.0-x64-arm64.msixbundle`已完成，196597450bytes／SHA256 `57080fb301f2557bae8977f863877c7b91a40bae4eabed96f6f4813c9040e0be`，來源fa2582325c90483185e09f5d1583e48dc6106e16。x64／ARM64建置耗時00:01:55.58／00:01:47.10，各0warning0error；281來源SHA、ZIP CRC、套件身分／架構／內含包SHA、十語手冊／指南與42個targetsize圖示核同，兩架構實際resources.pri識別深／淺色unplated。原12份舊Store套件及28份歷史檔SHA均不變。未執行App／實作測試／WACK或Store安裝升級；助手未上傳／送審／發布。 [本批日誌](STORE_RELEASE_1.0.16_2026-10-22.zh-TW.md)。

## 2026-10-22 — 常用清除、圖示與圓形橡皮擦（x64試用完成，待實機）

清除本頁加入常用預設與一次性追加遷移，保留其他自訂；screen清除接入同一catalog，收合只用原按鈕。兩畫布共用九宮格描邊圖形選單，修screen PathIcon填色造成圖示差異。圓形橡皮擦改共用16ms背景順序佇列／隔離preview、放開flush一筆Undo，取消與epoch/generation拒收，保存／退出等待已放開手勢；核心減少每段配置與反解析。中途build50.74／23.33秒均0warning0error；最終eraser-toolbar-2026-10-22-r1 x64封裝成功，來源7848fbd，ZIP132870905bytes／SHA256 `6ca95bff81af5075a04d25fb5739f3e017425b23f64ade876570bc4990bdb07e`。585payload／183source核同，52檔作品設定接續。未執行App／實作測試，手感待使用者驗收。 [本批日誌](ERASER_TOOLBAR_ALIGNMENT_2026-10-22.zh-TW.md)。

## 2026-10-22 — 工作列圖示粉色底板（x64試用完成，待實機）

依截圖追查粉色方框；原PNG及既有EXE圖示沒有粉色、具透明度，但商店資源缺targetsize與深／淺色unplated變體。新增14尺寸×3變體共42個Store PNG，桌面ICO由單256px補為14尺寸、32bit alpha與小圖AND mask；原Logo PNG不改。Store來源已修，既有已發行MSIX未重建，須下次商店更新才帶入。同系列1.0.15／taskbar-icon-2026-10-22-r1 x64試用已封裝，ZIP132859405bytes／SHA256 `b79c70162358c742cf217f7f6875e5da08a8656fd670b3c228cd2c160be85e8f`；585payload／180source核同，52檔作品設定接續。SDK MakePRI可識別14尺寸及兩種unplated；Shell外觀未實機驗收。 [本批日誌](TASKBAR_ICON_2026-10-22.zh-TW.md)。

## 2026-10-22 — 自由筆跨越舊筆跡凸凹（x64試用完成，待實機）

已確認現有偏好啟用磁鐵，一般／螢幕畫布把自由筆每個輸入點吸附到舊筆跡，造成交叉凸凹。兩入口共用幾何工具政策；自由畫筆／螢光筆／油漆筆不吸附、不建立磁鐵索引，形狀第一點與圓規定位仍保留。尺規投影與停筆直線辨識維持；十語指南同步，不覆寫既有可編輯指南作品。同系列1.0.15／freehand-magnet-2026-10-22-r1已封裝，來源f239b52，ZIP132782470bytes／SHA256 `df7cb73e56ad7bdaf32753f488245555e437eacfee3e52d11f3008c7b582287a`。585payload／179source SHA核同，52檔／24767478bytes作品設定接續；App／實作測試未執行，待使用者驗收。 [本批日誌](FREEHAND_MAGNET_2026-10-22.zh-TW.md)。

## 2026-10-22 — 真實採樣、轉角與板擦卡頓（x64試用完成，待再採樣）

收到使用者151.18秒真實採樣：UI心跳P95=113.21ms／max673.92ms，GC0/1/2=828/292/93；未含板擦處理scope，不能由PointerMove快速就宣稱輸入正常。板擦改16ms背景順序批次、TranslateTransform移動、隔離snapshot發布，放開等待最後批次一筆Undo；取消與舊epoch拒收。擦除保守排除與低配置判斷；畫布合併Invalidate、筆跡暫停尾段cache。新trace補板擦／wet／重建及GC實際pause。未永久合併同樣式筆畫，保留編輯語義；仍1.0.15，eraser-input-queue-2026-10-22-r1 x64已封裝，132778376bytes／SHA256 `29b61b9c8c28d2863cfbb9fa28fbe8c5055f3f4495511fb828d5eda0e756a9fc`。585payload／179source SHA核同，52檔24767438bytes作品設定接續。新候選App／實作測試未執行，待用相同採樣入口確認實際改善。 [本批日誌](ERASER_AND_INPUT_QUEUE_2026-10-22.zh-TW.md)。

## 2026-10-22 — 畫筆與工具切換停頓追查（x64試用完成，待實機採樣）

使用者回報拖曳畫線與工具切換仍頓，本批追查UI／繪圖資源路徑並修正：solid wet ink改重用單張viewport GPU raster、只追加64段穩定片段；磁鐵只追加新筆參考點；新筆避免JSON立即反解析；圖釘視野裁切與layout cache；導航圖示狀態快取。新增明確手動啟用的本機耗時採樣入口。仍1.0.15，未正式進版；中途x64 build 39.59秒0warning0error，x64 ink-latency-2026-10-22-r2封裝完成，132774049bytes／SHA256 `335dfec93f44b37f66ca983d997925e09911a867ae124febc5ebaea7eed785af`，585payload／178source SHA核同；52檔24767375bytes作品設定核同接續，原資料另備份。附手動Capture-InputLatency.cmd，尚未啟動App或實機採樣，不宣稱性能達標。 [本批日誌](INK_LATENCY_2026-10-22.zh-TW.md)。

## 2026-10-22 — 常用工具與完整無邊界指南（x64試用完成，待實機）

常用預設加入筆刷／線條樣式，預設圖示與文字；只升級舊未更動預設，保留自訂選擇。操作說明改十語單頁無邊界筆記，完整25章／29項工具、可編輯筆跡圖形與25個章節圖釘。v2使用獨立作品ID與marker，不覆寫v1範例。來源仍1.0.15，x64 toolbar-guide-2026-10-22-r2已封裝，132760672bytes／SHA256 `82aefc4b7410ff39127f36093a7a598879d09313f9f180061d116bc97f841334`；583payload／173source核同，ZIP無使用者Data。38檔24479726bytes核同接續，舊runtime清理、原作品另留備份。App／實作測試未執行，待使用者實機驗收。 [本批日誌](TOOLBAR_GUIDE_2026-10-22.zh-TW.md)。

## 2026-10-22 — 四項繪圖操作改善（x64試用完成，未進版）

工具列預設全開，完全未變更的舊精簡預設升級展開，自訂顯隱／順序保留；恢復預設亦全開。首次使用加入十語三頁可編輯「操作說明 · 工具練習」作品，以固定ID與marker避免重建或覆寫。畫筆／螢光筆／油漆筆刷完成不自動選取，V可選、雙擊開詳細。新增單物件ink Undo紀錄，減少逐筆全文件快照與UI刷新；主畫布可將新筆跡接入相同viewport的scene，其他操作完整重畫。板擦沿原斜長軸縮短20%、厚度／左高右低保持，hit path／擦面共用矩陣。十語指南同步，沿用1.0.15來源metadata的開發候選，不代表新正式進版或Store更新。中途x64 build 0warning0error／56.18秒；App、實作測試、性能與硬體驗收未執行。x64免安裝drawing-flow-2026-10-22-r1封裝成功，132641278bytes／SHA256 `1d2aa0b57ab90f6fcd75570d93b07930127b4343d4fe063afd158b2c38ee9f71`，583份payload與173份來源SHA核同、十語各三頁範例齊備。舊試用27檔／24344718bytes核同接續；清理舊runtime釋放455073499bytes，原資料另保留備份。等待使用者實機驗收。[本批日誌](DRAWING_FLOW_2026-10-22.zh-TW.md)。

## 2026-10-15 — Submission 3已提交，預先處理中

使用者提供Partner Center概觀截圖：Submission 3上次修改2026/10/15，產品更新為認證中；流程中提交已完成、目前停在預先處理，認證與發佈尚未完成，設定通過後立即開始發佈。Store目前狀態顯示Submission 2（上次修改2026/10/12）仍可取得。截圖未展開套件，不含Submission 3實際版號或SHA；本批準備1.0.15.0的事實與已上傳套件byte查證分開。 [狀態紀錄](STORE_SUBMISSION_STATUS_2026-10-15.zh-TW.md)。本批只更新文件，未執行App／測試／封裝或後台操作。

## 2026-10-15 — 商店套件完成與隱私文字更新

商店包`dist/store/HeiBan-Store-1.0.15.0-x64-arm64.msixbundle`已完成，195664137bytes／SHA256 `a889482ff3aa171569ce415fc285340b26742528af4306a3e0a0e3d6fa07eb96`；來源`ceed5f96a7241a9561380b4f3cfb596718fba317`。x64／ARM64分別61.69／51.11秒，均0warning／0error。218來源SHA、ZIP CRC、身分／架構、十語手冊與板擦資源核同；原12份Store套件SHA不變。使用者接手Partner Center，助手未上傳／送審／發布。本批App／實作測試／WACK未執行。 隱私文字已更新，明列本機轉換及PDF／HTML保留完整原稿（含其他頁面、隱藏物件）；目前畫面／選取匯出範圍不限制內嵌原稿，僅分享可見內容請用PNG。沒有改動既有匯出格式。

## 2026-10-15 — 使用者核准本系列商店更新（1.0.15.0封裝中）

使用者試用後明確指示再次更新Microsoft Store，採下一未使用版號1.0.15／1.0.15.0；同時更新App、manifest與StoreIdentity，保留歷史候選與上架包。包含本系列繪圖／磁鐵／PDF與PowerPoint圖片頁交換、工具列及原創鏡像板擦、十語UI／手冊與自動存檔設定。Package-Store增加FormalVersionApproved記錄旗標，預設仍未核准；本次不另增功能、不改作品格式。實作測試未執行；使用者同意更新不等於Microsoft認證通過，實際提交狀態另記。[本批日誌](STORE_RELEASE_2026-10-15.zh-TW.md)。

## 2026-10-15 — 更多板擦入口與左高右低鏡像（x64試用完成）

工具列更多新增「顯示板擦」勾選項，保存偏好、失敗還原；右鍵隱藏共用保存入口。保留原創PNG，僅Image中心ScaleX=-1呈現左高右低；共用12點輪廓x→1-x，抓取／提示／擦除同步。十語手冊重新產生25章62段，版本仍1.0.14候選。本機試用`dist/trials/HeiBan-Windows-Portable-1.0.14-eraser-entry-2026-10-15-r1-win-x64.zip`，132586851bytes／SHA256 `2cf8988e499f0c404ceda37445c2607e5866c55d0c6f445155408a65fe29785a`，來源`b2f9c3d7abe7a0726971a7ed53ca187893f3d51b`。App／Updater publish退出0，ZIP CRC／573payload／162source SHA、兩EXE x64及十語核同。使用者已正常保存關閉，確認無HeiBan程序後接續27個Data檔／24345830bytes，逐SHA相同；ZIP空Data。舊試用已備份到`dist/trial-data-backups/20261015-145134-a33251e2`後清理455068005bytes；Store1.0.12 SHA保持。最終EXE及實作測試未執行，待使用者實機驗收。[本批日誌](BOARD_ERASER_ENTRY_MIRROR_2026-10-15.zh-TW.md)。

## 2026-10-15 — 俯視磁吸板擦（x64試用完成，待實測）

依使用者視角更正，以imagegen純文字原創生成平貼板面的紙白／霧綠板擦。只有板面內約20度斜放，沒有商品側視／felt側層。1599×984透明PNG等比顯示160×98.461538DIP；抓取、提示與擦除共用12點alpha凸輪廓，取消前批透視偏移。維持1.0.14開發候選；十語手冊已更新。本機試用：`dist/trials/HeiBan-Windows-Portable-1.0.14-topdown-eraser-2026-10-15-r1-win-x64.zip`，132,585,397 bytes，SHA256 `4a48953a76c3bfa325c81b228f5884901c07e2a2b7aeb9c4e557ff9257deeb39`，來源`c239aba975a4d3a69f13f025827f675648583d55`。App／Updater publish退出0，ZIP CRC／573payload與162source SHA、兩EXE x64及十語手冊核同。27個Data檔／24,341,106 bytes逐SHA接續，ZIP無作品；舊eraser-r2保全資料到`dist/trial-data-backups/20261015-144432-6d9ba42e`後清理457,311,935bytes，Store1.0.12 SHA保持。最終EXE／自動化實作測試未執行，擦拭／Undo／DPI待使用者驗收。未執行App或本批測試，擦拭／Undo／DPI待使用者實機驗收。[本批日誌](TOP_DOWN_BOARD_ERASER_2026-10-15.zh-TW.md)。

## 2026-10-15 — 原創斜角板擦（x64試用完成，待實測）

本機最新：`dist/trials/HeiBan-Windows-Portable-1.0.14-eraser-2026-10-15-r2-win-x64.zip`，133,752,265 bytes，SHA256 `653c7885d6edf823cb4c528ca048857ac14b7bd8ca89bfa3734787a18d31e5d7`，來源`509c4bbfa2f4cb0e9d4bfadc987676d38074e7b6`。同名資料夾HeiBan.exe可直接試用，接續27檔／24,341,106 bytes，逐SHA相同；ZIP無作品。App／Updater publish成功，CRC／573payload／162source SHA及x64核對成功；最終EXE未啟動，擦除／Undo／DPI待使用者測試。舊canvas-ui及未交付eraser-r1在保全Data後清理916,077,320bytes，備份`dist/trial-data-backups/20261015-142945-46188019`，Store原SHA保持。[封裝](ANGLED_ERASER_PORTABLE_ARTIFACT_2026-10-15.json)／[檢視](ANGLED_ERASER_PORTABLE_INSPECTION_2026-10-15.json)／[接續](ANGLED_ERASER_DATA_HANDOFF_2026-10-15.json)／[清理](ANGLED_ERASER_TRIAL_CLEANUP_2026-10-15.json)。

依使用者最新要求，以未附參考圖片的imagegen文字生成取代商用外觀相似版；紙白外殼、霧綠握柄／底線、深灰felt，原始照片沒有入專案。新圖長邊約向右上20度，擦除使用同方向的18點圓角接觸面，不是水平矩形或正包圍框；160×106.67DIP圖框等比顯示，拖曳保留抓取位置、透明角不啟動。物件及局部筆跡、草稿／取消／一筆Undo契約延續。十語手冊同步，作品JSON不改。[本批紀錄與生成提示](ANGLED_BOARD_ERASER_2026-10-15.zh-TW.md)。

中途build成功0warning／0error，最終原創來源的Portable App／Updater publish亦成功；未執行本批自動化測試／App／硬體驗收，候選仍1.0.14.0，待使用者實測擦面／游標接觸位置。

## 2026-10-15 — 八項畫布實測修整（x64試用已交付，待使用者驗收）

最新本機試用：`dist/trials/HeiBan-Windows-Portable-1.0.14-canvas-ui-2026-10-15-r2-win-x64.zip`，134,453,996 bytes，SHA256 `0bd34217700cdf4ddcf761c7d7faeca5ed1433614be0f52aa3b754baa9420422`，來源 `3000bef3f589ee3cce22732e970e959c00d28c1e`。同名資料夾可直接執行HeiBan.exe，已接續上一版27個資料檔／24,372,320 bytes，逐檔SHA相同；ZIP仍空Data。App／Updater publish成功；ZIP CRC、573payload／160source SHA、兩EXE x64、十語與透明板擦資源核同。舊drawing及本批r1已在備份27個Data檔後清理912,420,485 bytes；備份在`dist/trial-data-backups/20261015-090554-21b70b56`，Store1.0.12原SHA保持。[封裝](CANVAS_UI_PORTABLE_ARTIFACT_2026-10-15.json)／[檢視](CANVAS_UI_PORTABLE_INSPECTION_2026-10-15.json)／[接續](CANVAS_UI_DATA_HANDOFF_2026-10-15.json)／[清理](CANVAS_UI_TRIAL_CLEANUP_2026-10-15.json)。

圖文工具列改單排／單列，按工作區延伸，窄視窗用工具組箭頭；選取常駐。常用分頁可在自訂卡片中勾選，screen自訂亦有共用常用偏好。磁鐵含起點hover提示與完整形狀參考點；圓／菱形／五角／星形改中心拖曳，兩宿主共用建構幾何。一般畫布新增生成木質板擦、矩形擦除／一筆Undo／設定顯隱。PDF／簡報匯入增加醒目圖片化限制說明；圖釘先新增再搜尋，清單以實際配色繪製。全App固定紙白／綠色，不隨Windows亮暗主題；OS選檔器仍由系統控制。

十語UI624key、手冊25章62段；四張舊批實機圖保留並明示排版差異。r2及r3 x64 Release build成功（0warning／0error），隔離視窗觀察單排、板擦、自訂卡片；未跑本批自動化測試或硬體完整回歸，板擦擦除／Undo、第一點實際吸附、4K／左右停靠／十語母語仍待驗收。最終Portable已完成來源及內容核對，未啟動此最終ZIP的EXE或跑本批自動化測試；1.0.14.0仍為開發候選，舊版2334checks不當本批通過數字。[本批完整紀錄](CANVAS_UI_REFINEMENT_2026-10-15.zh-TW.md)。

## 2026-10-15 — 文件交換與繪圖九項需求（來源及本機針對性驗證完成，待使用者試用）

最新x64試用包：`dist/trials/HeiBan-Windows-Portable-1.0.14-drawing-2026-10-15-r1-win-x64.zip`，131,955,475 bytes，SHA256 `41f0d1bc11707b447e279ca1dbb4c0c2324fdace676a3e23de3793ea1794ef6a`，來源`cc852963a8ea3d7bda629a806c33940e9842562a`乾淨工作樹。完整解壓後執行HeiBan.exe；原機同名解壓目錄已接續最近optimization試用Data13檔／34859bytes，逐檔SHA相同，ZIP仍為空白Data。App／Updater publish成功；579 ZIP項、572payload／157source SHA、兩EXE x64、10語／4圖全部核同，最終可攜EXE隔離啟動及正常關閉成功。舊兩份未發布試用已清理901658688bytes，43個Data檔與18個修改過檔案先保存至`dist/trial-data-backups/20261015-075635-9700515c`並核SHA；Store1.0.12 bundle前後原SHA一致。[封裝](DRAWING_WORKFLOW_PORTABLE_ARTIFACT_2026-10-15.json)／[檢視](DRAWING_WORKFLOW_PORTABLE_INSPECTION_2026-10-15.json)／[接續](DRAWING_WORKFLOW_DATA_HANDOFF_2026-10-15.json)／[清理](DRAWING_WORKFLOW_TRIAL_CLEANUP_2026-10-15.json)。下方舊試用路徑是歷史，相關舊runtime已清除，作品與必要修改檔仍保留。

PDF／PPTX／PPT可由首頁匯入為鎖定圖片筆記頁，PDF不需Office，簡報需本機桌面PowerPoint；一次最多200頁／100MB渲染圖片。筆記PDF新增全部頁面選項。磁鐵共用Core索引；主／螢幕畫布保留繪圖工具，三點三角形用直線預覽。建立／單擊只顯示控制點，主畫布詳細列以雙擊開啟。工具列有icons及四頁圖文模式、選取常駐、自訂全選／預設、改版圓規圖示；十語UI616key及手冊25章60段／四張實機圖。

本輪Core Release2334項通過、x64 Release build0warning／0error；Windows原生兩頁PDF匯入／序列化／兩頁PDF匯出、兩張PPTX轉換，及screen四邊圖文排版／三點三角形／連續形狀／磁鐵成功。主畫布以computer-use實際單擊／雙擊與兩次矩形拖畫確認。Poppler檢視PDF兩頁內容與頁序；十語四圖連結及manifest SHA核對通過。曾發生主／screen巢狀工具列重掛XAML錯誤，已依堆疊修正並重跑成功，失敗歷程保留。仍需使用者實際簡報、PPT舊格式、字型／加密、觸控筆、混合DPI／多螢幕、RTL與完整回歸；未做WACK、MSIX封裝、Store／Release或正式進版。[日誌](DRAWING_WORKFLOW_2026-10-15.zh-TW.md)／[交換與設定契約](DOCUMENT_EXCHANGE_2026-10-15.zh-TW.md)。

## 2026-10-13 — 操作優化可攜試用包已提供（待使用者實機驗收）

本機免安裝試用 ZIP：`dist/trials/HeiBan-Windows-Portable-1.0.14-optimization-2026-10-13-r1-win-x64.zip`，131,764,163 bytes，SHA256 `e9f1ab87616a84f7ea1c30ddd469b86c2d14e56c6ee6e5000ce7ff334460c580`。解壓後雙擊同名目錄中的 `HeiBan.exe`；請在新資料夾操作，試用包內 `Data` 為空白，舊測試目錄與 Store bundle 保留。Core Release 2,325 項檢查通過；手動 x64 Release self-contained publish 成功；封裝腳本完成 App／Updater publish、更新清單、ZIP 與 SHA sidecar。Store bundle 封裝前後 SHA 均為 `D7A49B63D88FA880B1A97B0C307361AD2CFBC9B3D58786048887093D7204EA7B`。程式版本維持開發候選 `1.0.14.0`，未提交 Store／GitHub Release。使用者尚待檢查主／螢幕畫布操作及刪除按鍵；此包是試用交付，不代表整批實機驗收。

## 2026-10-13 — 操作與精簡優化、鍵盤 Delete／Backspace 刪除物件修復（已更新本機 x64 測試版）

使用者要求開始Windows操作邏輯／程式精簡工作，並於本機 x64 測試版補上「選取物件後按 `Delete` 刪除物件」（含相容 Mac／筆電鍵盤傳送的 `Backspace`／`VirtualKey.Back`）。工具列policy現在把screen能力集合與一般ToolbarPreferences catalog交叉產生，不再另維護一份ScreenTools key／名稱表；顯示與隱藏只接受已有screen handler的項目。screen填色入口移入共用「圖形」選單，移除一個固定專用按鈕；套索、便條紙、遮題膠帶及停筆一秒近直線吸附已有screen來源接線。直線幾何判斷抽為主／screen共用Core來源。輸入渲染的16ms timer不再輪詢前景視窗；另以250ms焦點記錄timer服務還原操作。

針對鍵盤刪除物件：修正 WinUI 3 `CanvasSurface` 未設 `IsTabStop="True"` 導致開啟作品或更新工具列後焦點退回 `Root` 外層 `RootScrollViewer`、或點擊畫布未移開屬性面板 `TextBox`／`NumberBox` 焦點的問題；主畫布與螢幕畫布均支援 `VirtualKey.Delete` 與 `VirtualKey.Back` 刪除選取物件（文字與圖釘改名編輯狀態下除外）。

`HeiBan.Windows.Core.Tests` Release 2325 項檢查通過；`HeiBan.Windows` `win-x64` Release self-contained publish 0 warning／0 error，已同步更新本機測試目錄 `windows/dist/trials/HeiBan-Windows-Portable-1.0.14-guides-2026-10-12-win-x64` 與 `dist/HeiBan-Windows-Portable-x64`（既有 `Data` 作品檔案 100% 保留），版本維持 `1.0.14.0`。完整目的、原因與命令見[優化日誌](WINDOWS_OPTIMIZATION_BATCH_2026-10-13.zh-TW.md)。

## 2026-10-13 — 工具列一致性第一批實作（未驗收）

依使用者「GO」開始 WT 工作：新增Core `ToolbarContentPolicy`，螢幕畫布讀一般畫布同一份 `Settings/toolbar.json`，支援工具依一般偏好顯示／隱藏與排序；screen host capability policy 排除圖釘與視角鎖定，不影響物件鎖定。screen也有自己的「更多→自訂工具列」，只呈現已接妥的共同工具，保留各自WinUI控制項、桌面輸入與文件session。

螢幕畫布原四個形狀按鈕併成一般畫布同樣的九形狀選單，補上三角形／四邊形／菱形／五角形／星形拖曳預覽與填色。十語使用手冊來源與生成HTML同步描述偏好與形狀入口。此為WT-01／WT-03部分工作，**不代表全部工具列一致**：尺規、貼紙／匯圖、圓規、計算機、計時器、更多命令及面板仍待session-aware接線與差異檢視；共享筆刷／擦除／雷射面板及版面完整對齊也未完成。

本批只做來源與手冊產生器工作；`python windows/scripts/Build-UserGuides.py`退出0，回報十語各25章／55段。未執行build、測試、啟動App、封裝、Store操作或效能量測；所以程式編譯、主／screen互動、偏好失敗復原、十語RTL、DPI／多螢幕均未驗收。版號及原有候選／商店產物不變。詳[第一批實作日誌](TOOLBAR_ALIGNMENT_2026-10-13.zh-TW.md)。

## 2026-10-13 — Mac最新来源／工具與體積原機分析

公開main從148d427 fast-forward至3f39f1d（6筆），原.vscode/保留。Windows兩canvas已共用Core／renderer与ToolbarUi factory，screen仍11工具硬編碼、另一份設定／圖層UI，缺尺／圓規／計算機／計時器／完整形狀等接線。使用者要求一般catalog為準，screen省圖釘／視角導航，已列[WT-01–04規格與瘦身順序](TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)；本批只分析，尚未改UI。

原guides Store包只讀拆解且SHA核同：x64 ML六檔41,995,768bytes／壓縮17,537,365；ARM64 42,225,720／17,119,480，無Updater／Data／PDB。[本機JSON](STORE_PAYLOAD_REVIEW_2026-10-13.json)。ML存在已確認，安全移除／確定省量未確認；WT／WR待實作，1.0.14仍未核准metadata。本批未build／App／tests／封裝／進版／Store或清理成品。

## 2026-10-13 — Store減重分析與Windows端接手計劃

已完成[Windows版本減重分析計劃報告書](WINDOWS_SIZE_REDUCTION_PLAN_2026-10-13.zh-TW.md)及[基準JSON](PACKAGE_SIZE_BASELINE_2026-10-13.json)。最新guides商店候選ARM64 MSIX95.55MB／x64 98.12MB來自原Windows封裝紀錄，本Mac沒有MSIX重新拆解。Store已排除Updater，該優化對商店新增節省0MB；優先評估SDK必要元件引用，另比較SDK共享框架／.NET仍自包含。Portable參考ML42.23MB／壓縮16.78MB不代表MSIX保證可省。

WR-01–05是待Windows端評估／開發／測試的工作清單；本批沒有修改程式／版本／套件／產物，沒有執行build／App／tests／WACK／Store提交。1.0.14仍為未核准正式進版的開發候選。計劃、對照、拒絕條件及同步證據見[交接日誌](SIZE_PLAN_HANDOFF_2026-10-13.zh-TW.md)。

## 2026-10-12 — Parallels ARM64 試用版已部署

依目前 Windows 來源 commit `148d427a47e03a09bf21431d248fe00e3e9b6d9a` 建置 1.0.14.0 原生 ARM64 可攜試用包，標籤 `parallels-arm64-2026-10-12`。ZIP 位於 `dist/trials/HeiBan-Windows-Portable-1.0.14-parallels-arm64-2026-10-12-win-arm64.zip`，123,816,578 bytes／SHA256 `eed7341e766c423e0c6b9a7ce239974c64175c3533e58431e0f862105e4fe5e1`；PE架構為AArch64，571項封裝內容，ZIP不含作品Data。Parallels Windows 11 ARM64已部署至 `C:\HeiBanPreview\Trial-1.0.14-parallels-arm64-2026-10-12`，桌面捷徑「HeiBan Windows 1.0.14 ARM64 Trial」。由舊 `C:\HeiBanPreview\Current\Data` 接續56個檔案共2,588,837 bytes，逐檔SHA核對；舊目錄保留。新程序PID 13520、主視窗「HeiBan 黑板 · Windows」，Responding=True，執行檔版本1.0.14.0。未透過Microsoft Store安裝或改動商店套件。[部署證據](PARALLELS_TRIAL_DEPLOYMENT_2026-10-12.json)／[本批日誌](PARALLELS_TRIAL_2026-10-12.zh-TW.md)。完整功能、回歸、作品操作與效能測試仍待實際試用，不因啟動成功視為整批驗收。

## 2026-10-12 — runFullTrust 送審欄位說明

已核對Store manifest為FullTrustApplication／packagedClassicApp／mediumIL，需保留runFullTrust；提供[325字元短版英文說明與證據](STORE_RUN_FULL_TRUST_2026-10-12.zh-TW.md)，涵蓋桌面執行、本機檔案、螢幕註記、快捷鍵及主動截圖。短文依使用者回報截斷縮短，未宣稱官方欄位上限。未變更權限、版本、產物或後台，核准仍依本次Microsoft審查。

## 2026-10-12 — 十語商店清單文案

已提供正體中文、簡體中文、英文、日文、韓文、西班牙文、法文、德文、葡萄牙文（巴西）、阿拉伯文的[完整商店文案](STORE_LISTING_COPY_10_LANGUAGES_2026-10-12.md)：每語言有說明、6項本次新增功能、16項產品功能。文案以目前 Windows 候選功能為範圍，未加入未交付功能或效能保證；預設正體中文／自動存檔關閉與前批一致。這是可貼入後台的更新草稿，尚未母語校閱或填入 Partner Center；不變更程式、版本、產物、既有上架狀態或候選核准狀態。正式進版／提交仍依整批驗證與使用者決定。[本批日誌](STORE_LISTINGS_2026-10-12.zh-TW.md)。

## 2026-10-12 — 十語手冊候選已封裝，待實用確認

版本沿用1.0.14，不新進版。最新免安裝`dist/trials/HeiBan-Windows-Portable-1.0.14-guides-2026-10-12-win-x64.zip`，131,753,592bytes／SHA256 `2022630e14aa2b1313ab0319659c266a9d9046e69617ced060dd761a1ef27e8b`；同名解壓版HeiBan.exe已接續20檔898,085bytes、20SHA核同，備份保留，ZIP空Data。舊未發布save-mode trial清理452,723,319bytes。App/helper publish退出0、无warning/error，靜態147source／568inventory／570archive、十語25章55段与12guide files核同。

Store最新同版候選`dist/store/candidates/guides-2026-10-12/HeiBan-Store-1.0.14.0-x64-arm64.msixbundle`，193,675,520bytes／SHA256 `8dc919c47c69585a114cc9c8d1ddf20c1126e08b5524ca73009c8e85b396d666`。x64 51.93秒／ARM64 52.96秒各0warning/error，兩MSIX各12guide byte matched、198source核同；原Store12／13／14不变。舊root1.0.14.0不含本批手冊，不混用。來源portable8458363、Store1ab7018（只追加LF屬性），未提交／正式進版未核准。App／browser／tests／母語／硬體未驗收。[完整日誌](MULTILINGUAL_GUIDE_2026-10-12.zh-TW.md)／[試用項目](GUIDES_TRIAL_REVIEW_2026-10-12.zh-TW.md)／[提交素材](STORE_UPDATE_GUIDES_2026-10-12.zh-TW.md)。

## 2026-10-12 — 十語使用說明（開發候選）

手冊十語來源／生成資源已完成：各25章55段，離線搜尋、章節導覽與頁內切語，ar RTL；首頁／作品入口共用並隨介面語言開啟。內容同步新版自動存檔與圖層／screen操作，缺檔回正體中文，手冊選語不回寫App偏好。版本仍1.0.14，候選採guides-2026-10-12標籤；同版Store新包使用独立candidates路徑。編譯／封裝與檢視結果接續[本批日誌](MULTILINGUAL_GUIDE_2026-10-12.zh-TW.md)。母語／App實機／RTL／整批驗收未完成，正式進版及提交由使用者決定。

## 2026-10-12 — 進版節奏更正（最高優先）

使用者要求整系列開發、測試與驗證完成後才決定進版。停止因單批修改／編譯／封裝自動提高正式版號；後續以日期、commit與試用標籤累積開發，提供整批驗證結果後由使用者明確決定版本。現有1.0.13／1.0.14包是未核准正式進版的開發候選，1.0.14未完整驗收，撤回「可立即上傳最新版」建議。來源metadata暫沿用1.0.14，不再自動提高；原已發布／送審產物、歷史與作品保留。下方交付／上傳紀錄是當時結果，正式進版政策以本段為準。[規則與原因](RELEASE_POLICY_2026-10-12.zh-TW.md)。本次僅更正紀錄，未執行tests／App／編譯／封裝／Store操作。

## 2026-10-12 — 1.0.14自動存檔模式交付

最新版本機商店候選 `dist/store/HeiBan-Store-1.0.14.0-x64-arm64.msixbundle` 已完成；包含1.0.13的十語／操作改善及本批存檔模式。x64／ARM64封裝編譯各0warning／0error，source c409a6e。免安裝 `dist/trials/HeiBan-Windows-Portable-1.0.14-save-mode-2026-10-12-win-x64.zip`亦完成，同名解壓資料夾HeiBan.exe可供使用者試用。首頁齒輪／作品更多「設定」自動存檔預設關閉；開啟沿用一般15秒與螢幕1秒debounce，手動及離開／正常退出仍保存；退出動畫與失敗保留視窗已實作但未實機驗收。

舊未發布multilingual trial清除452,662,982bytes，9檔／150,783bytes先備份再接續新解壓版，9／9 SHA核同；ZIP仍空Data、原備份與Store12／13／14保留。靜態Store174／portable126source SHA、十語592key完整資源核同。未執行App／tests／WACK／硬體或Store提交。[完整日誌與性能待辦](SAVE_MODE_2026-10-12.zh-TW.md)／[商店上傳素材](STORE_RELEASE_NOTES_1.0.14.zh-TW.md)。下方舊版路徑為歷史，最新包以本段為準。


## 2026-10-12 — 自動存檔預設關閉、退出儲存動畫

首頁「設定」／作品更多「設定」控制一般與螢幕畫布自動存檔，新偏好缺省false，已明確保存的選擇沿用。off不排定作品保存／縮圖timer；on維持主15秒與螢幕1秒debounce。主Ctrl+S／螢幕更多「儲存註記」、離開作品／螢幕與正常退出保留儲存；退出顯示ProgressRing、阻止新編輯、保存後才關閉，失败保留內容與視窗。Settings/saving.json原子保存未知欄位，與作品契約分離。

新增11UI來源，592key×10離線資源，未母語驗收；r2 x64編譯退出0、0warning／0error、31.31秒（增版前程式）。產品1.0.14／Store1.0.14.0另製，1.0.13.0保留，不改已上架状态。新包結果接續[阶段日誌／Mac比對](SAVE_MODE_2026-10-12.zh-TW.md)。App／tests／存檔失敗／動畫／DPI／硬體未實跑，不能宣稱小畫家流暢度。

## 2026-10-12 — 商店1.0.13.0更新準備與工具列共用

更新包已完成：`dist/store/HeiBan-Store-1.0.13.0-x64-arm64.msixbundle`，193,452,627bytes／SHA256 `c8fc90e49c2cb1517e4d7a84f9c03a106083dc2053bd05a3cd533c07893320ad`，來源9b6c4e4。x6452.35秒／ARM6453.95秒各0warning／0error，封裝退出0；十語manifest＋各581key內嵌、173來源SHA及原包保全靜態核對通过。未提交／發布新版、未執行App／tests。[上傳素材](STORE_RELEASE_NOTES_1.0.13.zh-TW.md)／[artifact](STORE_ARTIFACTS_1.0.13.0_2026-10-12.json)／[inspection](STORE_INSPECTION_1.0.13.0_2026-10-12.json)。

Windows產品1.0.13／File與Assembly1.0.13.0／Store1.0.13.0。原1.0.12.0上架狀態保持歷史；新包仍未提交。共用ToolbarUi按鈕／提示／無障礙名稱／Flyout閱讀方向／四種線條樣式，螢幕工具描述集中；兩宿主維持各自布局、座標、穿透與保存生命周期。繪圖核心原本就共用Direct2DCanvasRenderer／EditorSession等類別，沒有另一套畫圖引擎。

存檔圖示改只在狀態轉換時重建，語言／失敗提示仍即時刷新，減少高頻InvalidateCanvas的XAML配置。編譯／包體靜態檢視接續記在[本批階段日誌與後續效能清單](STORE_UPDATE_TOOLBAR_2026-10-12.zh-TW.md)；沒有本輪FPS／UI／硬體驗收。包體大部分為.NET／WinAppSDK，共用UI不保證大幅縮小MSIX。

## 2026-10-12 — Store首次審核完成並上架（使用者後台截圖）

使用者提供Partner Center overview：Submission 1、Store目前狀態綠勾、明確顯示產品目前可在Microsoft Store取得，依Availability可發現性設定提供，並有「開始更新」。可依後台截圖確認審核及上架完成；不是助手登入查證。精確通過／发布時刻、所有市場可搜尋及實際下載／安裝未驗證。公開web工具無法讀商品頁，搜尋未收錄不推翻後台證據。

[上架確認紀錄](STORE_AVAILABLE_2026-10-12.zh-TW.md)；[商店入口](https://apps.microsoft.com/detail/9NV8T7RKV4MZ)。之前「認證中／尚未上架」段落保留歷史，以本段為最新狀態。十語與後續Windows改善是本機開發版，尚未由此紀錄提交新Store更新；既有送審包／正式發布保留。當前精確套件版本未從這份截圖重新查證。

最終r2 x64 Release build：退出0、0警告／0錯誤、28.23秒；十份完整資源嵌入DLL、literal來源鍵無缺項為靜態檢視，非App／測試驗收。最後文字屬性展示补強由新Portable publish重新編譯，封裝證據另記。

## 2026-10-11 — Windows 十語介面

首頁側欄「語言」提供正體中文（預設）、簡體中文、英文、日文、韓文、西班牙文、法文、德文、葡萄牙文（巴西）、阿拉伯文。保存成功即時更新首頁及工具列，重新啟動沿用Settings/language.json；不跟隨OS改預設。581個自製UI字串各有十語離線資源，範圍含首頁／新建作品、一般／螢幕畫布、屬性／圖層、共用文字、更新設定與提示。

作品名稱／文字／ID／文件碼／中文內部停靠值與幾何不翻譯。阿拉伯語導覽、對話與彈出選單RTL，畫布LTR；手冊／法律文保留正體中文及原文，入口明示。WinUI內建ColorPicker／系统選檔及原始例外不保證隨即時切換，需實機查核；母語校閱、長字串／RTL／窄視窗、偏好重啟與磁碟失敗、App／tests均未執行。只做x64編譯／本機封裝，ARM64本輪未建置；詳見[階段日誌及Mac比對](LOCALIZATION_2026-10-11.zh-TW.md)。來源Store manifest宣告十語，原1.0.12.0送審套件保留，下次正式MSIX需增版另提交。


本輪本機x64試用：`dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-multilingual-2026-10-11-win-x64.zip`，131,632,111 bytes／SHA256 `1a1dc766572215518ff51f480441fb7189060de10d752939bed4d7109d402f52`，source14bb289；[產物](LOCALIZATION_PORTABLE_ARTIFACT_2026-10-11.json)／[靜態檢視](LOCALIZATION_PORTABLE_INSPECTION_2026-10-11.json)。App／helper publish退出0、無warning/error；557 inventory／559 archive／124 source SHA、十語資源581完整內嵌。未執行App／tests／實機／ARM64。

舊canvas-setup未發布trial清除452,220,937 bytes；9檔Data共150,783bytes先保存於 `dist/trial-data-backups/20261011-041854-3b00a2aa/`，再複製到新解壓版Data以延續原機使用，兩份皆核SHA；ZIP仍空Data。原備份及前批52檔備份、已發布Release／Storebundle保留，[清理](LOCALIZATION_TRIAL_CLEANUP_2026-10-11.json)／[資料接續](LOCALIZATION_DATA_HANDOFF_2026-10-11.json)。只原機有二進位與作品，GitHub同步來源／紀錄，私人庫保存精簡需求與交接。

## 2026-10-11 — 一般畫布游標與作品／背景設定

使用者實機確認上一版螢幕游標有效，但一般畫布無效；不能把上一輪編譯成功當作主畫布游標驗收。現改 CursorCanvasHost.ProtectedCursor，SDK CreateFromHCursor 轉WinRT cursor，移除舊Win32橋hook。無邊界新作品無尺寸；fixed 首次16:9（1920×1080）仍可改，notebook 維持A4，各格式記住本次對話框選擇。背景既有繪圖／匯出已支援五種，這次補新建與既有作品共用UI。

[阶段日誌／Mac對照](CANVAS_SETUP_FIX_2026-10-11.zh-TW.md)。首次 x64 build 0 warning／0 error、39.18秒；後續預設記憶／取消保留補強，最終x64 build 0warning／0error、25.98秒；封裝接續記錄。本批未執行測試／App／實機UI。使用者明確授權刪除舊未發布trials以減少空間，先保留作品Data，保護最新版與已發布／Store包；不刪Git歷史。聊天摘要仍放PRIVATE。


本輪最終試用：`dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-canvas-setup-2026-10-11-win-x64.zip`，131,543,340 bytes，SHA256 `0066ccfa530af13a21fd016f9a49fa5dc41f13fb7a9cd7600034bd4d2fae0759`，source c53462a；[artifact](CANVAS_SETUP_PORTABLE_ARTIFACT_2026-10-11.json)／[静態檢視](CANVAS_SETUP_PORTABLE_INSPECTION_2026-10-11.json)。publish退出0／無warning/error，108 source／557 inventory／空Data／PE／授權／手冊一致；未執行App／tests／實機。

已刪舊5份trials解壓runtime／ZIP／sidecar，釋放2,260,814,479 bytes（約2.106GiB）；52個Data檔共73,389 bytes先移至 `dist/trial-data-backups/20261011-032945-612f03c3/`並核SHA。trials只剩最新版3項，Store原SHA與正式Release保留。[清理结果](CANVAS_SETUP_TRIAL_CLEANUP_2026-10-11.json)。下方舊試用路徑為歷史交付紀錄，其二進位已於本輪清理，歷史source／hash／logs仍留。


## 2026-10-11 — 操作回饋追加五項

螢幕工具列移除 ScrollViewer，工作區不足改換行／換列；主／螢幕圖層拖曳加入原列淡化、圖示名稱預覽與插入線；形狀八方向縮放及圓弧旋轉游標；箭頭頭部輪廓跟隨 StrokeWidth（覆寫上一階段固定 2 的策略，幾何長寬仍独立）；主工具列 layers 入口及保留隱藏偏好的遷移。

[階段紀錄／Mac 比對](UX_FEEDBACK_2026-10-11.zh-TW.md)保存原因、修改檔案、命令、清理與驗收界線。對話的精簡交接摘要保存私人庫。本批 x64 build 初次 0 warning／0 error；整合補強後最終 x64 build 0 warning／0 error、25.80 秒，封裝結果接續記錄。測試、App、4K／DPI／滑鼠實機均未執行。已交付 ZIP、Store bundle、SDK、Data、歷史保留；僅清理八個一次性腳本，見[清單](UX_FEEDBACK_CLEANUP_2026-10-11.json)。


本輪新 x64 免安裝包 `dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-ux-feedback-2026-10-11-win-x64.zip`，131,541,143 bytes，SHA256 `e77d2dd28526fc70b0f9049cf96d68d22c1156373bf6044c5e79d6ac719c1aa7`；來源 77a563d，App/helper publish 退出0／無warning/error。557 inventory／106 source SHA／空 Data／PE／guide／README／sidecar 靜態一致，Store原SHA相同。[artifact](UX_FEEDBACK_PORTABLE_ARTIFACT_2026-10-11.json)／[靜態檢視](UX_FEEDBACK_PORTABLE_INSPECTION_2026-10-11.json)。未執行測試／App／實機操作，未發布 Release／Store。


## 2026-10-11 — Windows 20 項操作調整

已接上首頁開啟／一般選取／圓形多選、停筆一秒直線預覽、百分比尺長、依物件分類屬性、箭頭頭部獨立尺寸、個別圖釘配色、延伸入口移入屬性、紙張便條視覺、上下視角鎖定同步、独立圖層與拖曳排序、雷射再次點擊設定、存檔勾號／虛線圓、屬性四邊停靠；螢幕畫布增加橡皮擦預覽、內容量測工具列、圖層與調色盤。

最終本機 x64 試用：`dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-ux20-2026-10-11-r2-win-x64.zip`，131,531,917 bytes，SHA `c7c9cd4d23e300f8c3e68b5ecbac763432e4fbcde782aba8ded075cce0f252e3`；同名資料夾直接啟動 HeiBan.exe。[產物](UX20_PORTABLE_ARTIFACT_2026-10-11.json)／[靜態檢視](UX20_PORTABLE_INSPECTION_2026-10-11.json)。來源 e60728d，App／helper publish 退出 0、log 無 warning／error，557 inventory／103 source SHA／空 Data／PE／手冊／sidecar 核對完成。補強四邊面板留白以避免蓋工具列；第一份候選與舊包均保留。

第一輪／第二輪 x64 build 已退出 0，第二輪 0 warning／0 error。本批未執行 Core／native／實際 UI 操作測試；20 項實體滑鼠、4K DPI、多螢幕驗收仍待使用者試用。完整入口、類型矩陣、原因、命令與限制見[本批紀錄](UX_ALIGNMENT_2026-10-11.zh-TW.md)。本機免安裝另以 ux20 標籤製作，來源版號維持 preview.6；沒有發 Release 或改 Store 送審版。

## 2026-10-11 — 第二批本機x64免安裝試用包可用

使用者要求未發布版本仍可試用，已另製作`dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-perf2-2026-10-11-r2-win-x64.zip`與同名直接啟動資料夾。完整解壓、雙擊HeiBan.exe，作品存自己Data。Label区分同version歷史包，沒有覆寫原dist或Store1.0.12.0；ZIP只在本機，未發GitHub Release／Store。初包保留，最終r2補強封裝guard後重出。

App／helper self-contained x64 publish与封裝退出0、無warning/error，557 payload逐SHA／空Data／PE／版本／sidecar／93來源SHA核對完成；本批未執行新App／Core／native／smoke測試，前批2324／127是歷史來源驗收。原bundle SHA相同，ARM64本批未封裝。來源／檔案／命令／限制见[本批紀錄](PORTABLE_TRIAL_2026-10-11.zh-TW.md)、[產物清單](PORTABLE_TRIAL_ARTIFACT_2026-10-11.json)。Git同步封裝入口與紀錄，不包含本機ZIP／作品。

## 2026-10-11 — 第二批渲染候選索引

完成PERF04渲染分支：大而稀疏視野採網格，保留stable Z與live頁面／visibility，小／密集／超界回原scan、複雜型別保守global。非序列化bounds counter、交易內geometry增量更新、Z/list／Cancel／Undo替換重建。Hit／擦除／框選沒有接index，PERF04整項仍待辦；PERF05 GPU分區未實作。

本批2324 Core、127幅零容差pixels、x64／ARM64 Release publish通過、無warning/error訊息（ARM64未實跑）。Sparse10000 CPU p95 scan0.36124→grid0.07980ms、單物件更新0.08176ms，cold／配置成本另記。完整scene pan兩組6.3884→4.2346、4.8220→5.4971ms，不一致，不能宣稱整體FPS／端到端延遲达標；dense pan仍約196ms。下一批PERF05優先但需新基準／GPU預算設計。

[日誌](PERFORMANCE_BATCH2_2026-10-11.zh-TW.md)、[raw資料／限制](performance/2026-10-11-batch2/README.zh-TW.md)。版本／送審bundle SHA／私人三圖保留；無新Installer／MSIX／Release／Store操作／硬體矩陣驗收。既有.vscode/保留不讀／提交，其他平台未改。

## 2026-10-10 — 流暢度第一批實作與同機證據

使用者對九項清單指示 GO，完成首批的軟體基準、熱路徑配置改善及穩定 Z 順序快取。命中保留 locked／同 Z 次序，交易內直接 Z／list 修改、切頁、Cancel／Undo／Redo 均涵蓋；單物件 preview 不排序，筆跡 damage 索引掃描尾端四點不丟輸入。另修現有 overlay bitmap copy 色階差異，所有像素規則維持零容差。

本次754 Core checks、70個嚴格像素比較及其他曲線／雷射／idle契約通過；x64與ARM64 Release publish退出0，ARM64僅編譯未實跑。10000物件CPU順序p95 2.11462→0.15780ms、命中3.35256→0.33602ms；配置量明顯下降。原生大量場景重建／平移／縮放p95未一致改善，不能宣稱整體FPS提升。PERF-01／02仍缺busy timer、保存期间操作與實體輸入／DPI驗收；04／05是下一批優先候選，06只做現有copy相容修復，07／08與09硬體矩陣仍待執行。

[實作日誌](PERFORMANCE_BATCH1_2026-10-10.zh-TW.md)、[原始樣本／重現命令／限制](performance/2026-10-10-batch1/README.zh-TW.md)、[更新工作清單](ANTIGRAVITY_PERFORMANCE_WORKLIST_2026-10-10.zh-TW.md)。建置與資料全部在新隔離.build目錄；Store 1.0.12.0原bundle SHA前後一致，未更版／重封Store包／發GitHub Release／操作Partner Center。現有.vscode/保留且不提交；Mac／Web與私人產品素材未修改。

## 2026-10-10 — Antigravity 流暢度工作清單已編製

使用者要求列出可交接的修改工作。已依當前來源整理 [九項工作清單](ANTIGRAVITY_PERFORMANCE_WORKLIST_2026-10-10.zh-TW.md)，含現況、優先順序、依賴、定位、修改策略及驗收條件；第一批為 PERF-01 基準、02 熱路徑與排程、03 排序快取。空間索引／分區快取／GPU 合成／獨立輸入／保存記憶體皆依量測與相容驗收展開，不預先承諾收益。尚未執行本輪實作／效能測試／建置／封裝或 Store 操作；送審 1.0.12.0 保留。[編製紀錄](PERFORMANCE_WORKLIST_LOG_2026-10-10.zh-TW.md)。

## 2026-10-10 — 可接續下一版 Windows 開發

目前 Store 1.0.12.0 仍以使用者提供的「認證中」為最新已知狀態；可以開發下一版，GitHub source 更新不會修改已上傳的套件。保留送審 build source aa71e35／原始套件／產物 SHA／私人三張截圖作該版本證據。下一版功能與版本號尚未指定，本批只更新交接紀錄，沒有改程式／提高版本／重封包／測試或 Store 操作。後續正式更新需遞增套件版並另行提交認證。[交接紀錄](NEXT_VERSION_HANDOFF_2026-10-10.zh-TW.md)。

## 2026-10-10 — Store Submission 1 已送審，認證中（使用者提供）

使用者貼出 Partner Center「產品提交：認證中」及「通過認證後立即開始發佈」，已自行完成首次提交；尚未確認通過或已上架，助手未登入後台查證。前次套件 Validated／提交按鈕問題與此次進度見 [本批紀錄](STORE_SUBMISSION_2026-10-10.zh-TW.md)。三張經使用者授權的 Store 示範截圖原 byte 保存於 PRIVATE HeiBan-private，不放入公開程式庫；可跨電腦 clone／pull 取回。當前等待認證結果，未啟用查詢排程。未重封包、執行 App／WACK 測試或修改其他平台；下方「尚未送審」為前批歷史狀態。

## 2026-10-10 — 跨電腦私人產品紀錄已建立

使用者要求私人保存產品資訊，已建立 [HeiBan-private](https://github.com/VirginBear/HeiBan-private)，GitHub visibility 核對 PRIVATE。包含完整產品紀錄、Store 策略／待辦與多電腦交接；開發者需有權限，先讀私人庫 README／AGENTS／PRODUCT_INFORMATION／CURRENT_STATUS，再讀本平台文件。公開庫只保存技術必需識別與讀取入口，不複製私人管理欄位；沒有改程式／重封包／執行測試或 Store 操作。[本批紀錄](PRIVATE_RECORDS_2026-10-10.zh-TW.md)。

## 2026-10-10 — 正式 MSIX／bundle 封裝完成，尚未送審

使用者提供 HeiBan 黑板正式 Product identity，並確認第一版免費。Windows Store SDK single-project MSIX 明確 build 模式，原 EXE／Portable 路線分開。首份套件版 1.0.12.0／產品 preview.6；最後 x64／ARM64 建置各 0 warnings／0 errors，兩份 MSIX 及一份雙架構 bundle 產出。實際包身分、最低 OS 19041、PE Machine、25 份授權與手冊原 byte、不帶作品／helper／symbols、bundle 內 MSIX SHA 通過，135 個來源／3 產物 SHA 相符。[產物清單](STORE_ARTIFACTS_1.0.12.0_2026-10-10.json)。

來源 `aa71e3584ff91b9f5832f9abec66980049d34aa4` 已 push，ls-remote HEAD／main 相同。見 [本批紀錄](MSIX_PACKAGING_2026-10-10.zh-TW.md)、[商店草稿](STORE_LISTING_DRAFT.zh-TW.md) 與 [隱私草稿](PRIVACY_POLICY_DRAFT.zh-TW.md)。未簽章包供 Store 送審，未購買 CA。商店安裝／資料遷移／更新／解除安裝／WACK、ARM64 執行、送審／上架未執行；本批未執行 App 測試。下方「身分待提供」與「尚未產生 MSIX」均為前批歷史，不是目前狀態。

## 2026-10-10 — Partner Center 已申辦，商店準備與來源同步

使用者告知已申辦帳戶，要求紀錄並更新 GitHub。已建立 [商店準備清單與當批日誌](STORE_PREPARATION_2026-10-10.zh-TW.md)，整理正式 MSIX 所需三項產品身分與保留名稱、免費商店簽章、送審素材及資料遷移驗收。尚未檢視私人後台或取得身分，MSIX／Store 送審未完成。本批同步上一批 Windows preview.6 來源；下方「未 commit／push」為上批結束時狀態，實際同步結果以本批日誌為準。GitHub 公開下載仍為 preview.5，未新增 Release。

Windows preview.6 自動更新來源與紀錄已 commit／push：`27c968dc80766d78eb1dac3d2305d32ee2f5c63e`。本機 HEAD 與遠端 main／HEAD 核對一致，push 後工作樹乾淨；本段結果另以文件提交保存。只同步來源不會讓既有安裝版收到新版本。

## 2026-10-10 — 1.0.12-preview.6 GitHub 自動更新（完成本機交付，未發布）

Windows 來源升至 1.0.12-preview.6／FileVersion 1.0.12.6。首頁關於 → 更新設定、畫布更多 → 檢查更新與更新設定；GitHub 版啟動約十秒後及開啟期間每六小時背景檢查／下載，支援停用與預覽管道。按 Windows tag、語意版本、程序架構及 Installer／Portable 篩選，HTTPS 固定 repo／轉址白名單、size／GitHub SHA-256 驗證。

保存成功後交給自包含 helper，等待父程序退出及同一安裝所有視窗關閉。Installer Inno 靜默升級；Portable 宣告檔案清單及 hash 預檢、備份／普通失敗 rollback，保留 Data／portable.dat／未知檔。新增關閉重入防護、交接鎖重試、待更新與已安裝 PE 架構核對、preview → stable 語意比較。Package identity 下不執行 GitHub 更新，由 Store 管理。

本批最後來源 73 更新檢查及 700 Core／手冊檢查實際通過，隔離 x64 真 helper／真 Inno 流程（含鎖重試、preview→stable、其他視窗延後）通過；最終 x64 真 HeiBan 隔離啟動／正常關閉退出 0。兩架構 EXE／Portable 四包封裝退出 0、compiler warning／error 0，Portable x64 555／ARM64 551 個 inventory 檔逐 SHA、架構／手冊／README／空 Data／sidecar 通過。見 [最終產物與來源 SHA](ARTIFACTS_2026-10-10_1.0.12-preview.6.json)。ARM64 本機執行、真正 GitHub 新 Release 發布後更新、完整硬體操作／Store 封裝及送審未執行。MSI／MSIX 未產生，未 commit／push／發布，公開版本仍 preview.5；舊版需先手動裝含更新功能版本。SHA 驗證不是 Authenticode，未購買簽章憑證。見 [本批紀錄](AUTO_UPDATE_2026-10-10.zh-TW.md)。

## 2026-10-10 — GitHub Windows 1.0.12-preview.5（已公開）

x64／ARM64各提供Installer ZIP及Portable ZIP，[新版下載](https://github.com/VirginBear/HeiBan/releases/tag/windows-v1.0.12-preview.5)。相應source fddf85e已推main且tag一致，77build-source blob保持相等；公開Portable原entry／Installer原EXE逐byte相同，7assets遠端size／digest與本機相符，7個未登入下載HEAD均200。

GitHub舊Windows四ZIP及舊HTML已清除，保留歷史Release／tag、原說明及2個manifest文本；本機只留p5原4包及公開4ZIP。Mac來源／公開Release與所有作品／備份保留。沒有為本次上傳重跑程式測試，沿用已核SHA不變的700Core／ARM64原生／PDF成果，x64實機及完整Installer升級仍未驗收。下方「本機交付，未發布」為之前工作的歷史邊界。[公開紀錄](PUBLIC_RELEASE_2026-10-10.zh-TW.md)、[遠端雜湊](GITHUB_ASSETS_1.0.12-preview.5_2026-10-10.json)、[遠端清理](GITHUB_CLEANUP_2026-10-10.json)。


## 2026-10-10 — 1.0.12-preview.5 右鍵物件操作（完成本機交付）

最新Windows為1.0.12-preview.5／FileVersion1.0.12.5。依最新指示取消螢幕右鍵自動穿透：右鍵物件開調整／複製／個別刪除選單，命中已多選物件保留整組；空白右鍵取消暫態但維持作畫，選取不新增Undo。穿透由模式按鈕或Ctrl+Alt+D切換。下方preview.4及更早條目保留歷史偏好，不代表最新操作。

700Core Release及本輪ARM64原生result／screen-result同輪success，實際右鍵選單／空白不切模式／文字多選、副本刪除Undo通過；樣式、截圖、36preview幀byte等價回歸及PDF strict通過。77來源雙鏡像SHA一致，兩架構四包退出0／兩次Successful compile，包內版本／當前手冊／README／授權／空Data與SHA核對通過。

模擬機Current唯一程序11412、捷徑及549payload逐SHA通過；56Data檔SHA保全vm/c7、2目前作品＋9垃圾桶共11份，歷史c12至c6作品全部涵蓋。已清p4舊包／payload與建置鏡像1,965,162,051bytes，QA備份r5a；SDK／Inno／所有作品與歷史備份保留。未改Mac，未commit／push／發布。CUA右鍵／工具列點擊未產生可靠回應，未算硬體驗收；完整硬體／IME／多螢幕／混合DPI／手寫／x64實機與Installer升級未執行。

[右鍵修正紀錄](WINDOWS_RIGHT_CLICK_REVIEW_2026-10-10.zh-TW.md)、[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.5.json)、[清理紀錄](CLEANUP_1.0.12-preview.5_2026-10-10.json)。

## 2026-10-10 — 1.0.12-preview.4 螢幕物件與多選（完成本機交付）

本輪只改Windows。色圓／線條／填滿在選取工具下直接改已完成物件，支援未鎖定多選及滑桿合併Undo；截圖成為螢幕session原位置圖片，尺寸／旋轉／Undo／Redo，沒有寫主作品。Shift限直線／箭頭水平或垂直，包含A/B端點；首頁單擊選取／雙擊開啟、Ctrl／Shift或明確多選，批次垃圾桶／還原。右鍵直接穿透，物件命令在更多 → 選取物件。

Core Release700項通過，最終原生r3 result／screen-result皆success及PDF strict成功；77來源與native／package鏡像SHA一致。新36預覽／收筆幀逐byte一致，傳輸705245184→6114048bytes，中位24.7323→1.824ms（同步render，非硬體輸入延遲）；idle換工具不render。兩架構四包封裝退出0，兩次Successful compile、無compiler warning／error；SHA、架構、PRI／runtime／品牌／當前手冊／README及25份授權逐byte通過，ZIP空Data／無QA作品。

CUA可讀模擬機，但切換隔離QA click回noWindowsAvailable -10005；未算硬體點擊驗收。完整中文IME、手寫、混合DPI、多螢幕、x64實機及Installer升級未執行。前期r1／r2失敗與修正保留，見[本輪稽核](WINDOWS_SCREEN_OBJECTS_REVIEW_2026-10-10.zh-TW.md)。Mac未改，未commit／push／發布。


最終Current為1.0.12.4，唯一程序7720／捷徑及549payload逐SHA通過。正常關閉前後SHA備份vm/c6，56Data檔完整保留、2目前作品／9垃圾桶共11份，歷史c12／c2／c3／c4／c5作品全部仍在。舊Current全部bytes可由舊封裝與保全Data解釋，未知bytes0；更新前亦檢查未知payload檔案。只留最新四包／Current，已清舊p3包／payload及建置鏡像共1,967,680,113bytes；QA先SHA備份e4a～c，SDK／Inno／所有作品保留。見[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.4.json)及[清理紀錄](CLEANUP_1.0.12-preview.4_2026-10-10.json)。

## 2026-10-10 — 1.0.12-preview.3 操作修正（完成本機交付）

最新 Windows 為1.0.12-preview.3／FileVersion1.0.12.3，Mac基準1.0.12／20261010.4。圖釘圖示／原位改名、游標位置滾輪縮放、CAD雙向框選、第一／第二點曲線預覽、顏色／線條跨工具保留、目前線條樣本、直列不擠壓、截圖灰霧已修；切工具關浮窗、暫態預覽不重建永久scene、模式切換正確重建輸入alpha。詳見[本輪稽核](WINDOWS_INTERACTION_REVIEW_2026-10-10.zh-TW.md)。

Core680項通過，最終ARM64原生r7 result／screen-result皆success，包含Win2D四線像素、兩階段曲線、GDI遮罩、圖釘Undo、20按鈕尺寸、暫態快取及模式alpha0／1；PDF strict通過。76個native／封裝來源SHA一致，兩架構四包SHA、架構、PRI／runtime、當前手冊／README及25授權逐byte通過，ZIP空Data／無QA作品。

模擬機Current已更新、唯一新版程序與桌面「黑板 Windows 最新版」，549payload檔逐SHA通過。正常關閉前後備份vm/c5，51Data檔保留、2目前作品／8垃圾桶，歷史c12／c2／c3／c4作品全部仍在；移除舊Current前其全部bytes可由舊payload與保全Data解釋，未刪未知資料。最新四包見[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.3.json)。

Mac鎖定使最後實體點擊未驗收；完整手寫、中文IME、混合DPI、多螢幕、x64實機與Installer升級未執行。Mac來源未改，未commit／push／發布。舊包／鏡像清理及所有資料保全見[清理紀錄](CLEANUP_1.0.12-preview.3_2026-10-10.json)。

本輪舊包／payload／鏡像合計移除3,612,977,725bytes（檔案大小總和），只留最新四包；QA資料先逐SHA備份i3a～g，SDK／Inno及使用者資料保留。

## 2026-10-10 — 1.0.12-preview.2 流暢度修正

此輪只改Windows，Mac基準仍1.0.12／20261010.4。修普通畫布scene／文字排版快取、Selected O(N²)掃描、長筆跡JSON快照／移動、隱藏圖層重建與保存交錯；縮圖／偏好／搜尋改空檔或合併背景工作。螢幕選取拖動局部讀回、手勢中延後保存；維持單排／四邊配置、右鍵物件選單、Ctrl+Alt+K清空／復原與截圖回貼。

Core Release568項通過；原生ARM64 result／screen-result皆success，9普通畫面＋22螢幕幀逐byte等價。最終300物件重繪中位31.3325→1.5991ms，螢幕30.331→4.4957ms，非硬體延遲。第一輪仍有快取P95尖峰；完整硬體／IME／混合DPI／x64實機與Installer升級未完成。[稽核報告](WINDOWS_PERFORMANCE_REVIEW_2026-10-10.zh-TW.md)與[量測數據](PERFORMANCE_1.0.12-preview.2_2026-10-10.json)。

交付完成：兩架構四包SHA／架構／PRI／runtime／品牌／當前手冊／README及25份授權逐byte核對通過、ZIP空Data／無QA作品。ARM64 Portable88.44MiB／Installer61.00MiB；x64 Portable91.02MiB／Installer63.50MiB，精確大小與SHA見本版manifest。

模擬機Current更新至FileVersion1.0.12.2，唯一程序與桌面「黑板 Windows 最新版」，549檔與ZIP逐SHA一致；CUA已查看最終新單排工具列及雷射顯示。正常關閉舊程式前後備份vm/c3、37個Data檔完整保留，現行1份作品／6份垃圾桶；先前c12的6個作品ID均仍存在於此次Data，c12亦保留。資料位置不因封裝改動。

舊p1四包／sidecar、舊Current payload及建置／QA鏡像移除，本批初次交付與曲線補正重封合計3,606,237,162 bytes（約3.61GB），QA資料先逐SHA備份；SDK／Inno／原AppData／Documents及所有作品備份不刪。歷史SHA與文字日誌保留。[封裝清單](ARTIFACTS_2026-10-10_1.0.12-preview.2.json)／[清理紀錄](CLEANUP_1.0.12-preview.2_2026-10-10.json)。


## 2026-10-10 — 最新本機版本 1.0.12-preview.1

Windows **1.0.12-preview.1**（FileVersion1.0.12.1）以Mac **1.0.12／20261010.4**為基準。螢幕工具列改單排820×60 DIP、直式64×688 DIP純圖示，色圓開獨立280 DIP色彩／粗細／透明度面板（3×2色票、垂直滑桿）；短畫面只捲中段，模式及清空／結束可達，去掉固定文字／狀態列與多餘空白。作品庫側欄／卡片及左下視角膠囊延用Mac配置。

補T螢幕文字、Enter換行／Ctrl+Enter完成／Esc取消、雙擊重編輯；普通畫布／螢幕／草稿共用文字右鍵設定，字級8～144、顏色、字型、對齊、透明度及粗斜底線。Shift／框選可多選，批次只改指定欄位、保留混合值與未知富文字欄位、限當頁未鎖定文字／便簽、一筆Undo。僅選取不增加Undo。保留右鍵物件操作／空白穿透、一鍵全清除與Ctrl+Alt+K，以及截圖直接回貼。

本輪Core／手冊**543項**通過；ARM64原生中文草稿、取消／雙擊／換工具、多選右鍵及樣式復原、四邊尺寸、透明層與控制列次序、原作品未污染、Win2D／向量PDF通過。200%DPI實測橫列1640×120px、直列128×1376px，66個來源逐SHA一致。完整對照及限制見[功能表](MAC_1_0_12_PARITY_2026-10-10.zh-TW.md)。

四包已封裝，見[產物與SHA](ARTIFACTS_2026-10-10_1.0.12-preview.1.json)。模擬機已更新C:\HeiBanPreview\Current，桌面「黑板 Windows 最新版」，唯一新版本程序及549個payload逐SHA一致。現有34個Data檔案（含4目前作品）先備份再遷移核對，其他作品／AppData／Documents保留。Mac來源未改；未commit／push／發布。

Mac鎖定使本輪CUA畫面確認未執行；原生合成驗證不等於真實指標／中文IME／多螢幕／混合DPI／觸控筆驗收，x64實機與Installer安裝升級未執行。

本批清理合計1,964,671,701 bytes（約1.96GB），只留最新四包／Current，作品及文字歷史均保留。見[清理摘要](CLEANUP_1.0.12_2026-10-10.json)。

## 1.0.9 交付紀錄（歷史）

## 2026-10-10 — 最新本機版本 1.0.9-preview.1

最新來源及試用封裝改為 Windows **1.0.9-preview.1**（FileVersion 1.0.9.1），對齊 Mac 1.0.9／20261010.1 可操作功能。新增Mac配置作品庫側欄／收藏／篩選／排序／卡片／多選、左下視角膠囊，及四邊停靠／左右直排／可收合的透明螢幕畫布、中文／可改名圖層、多選／套索、膠帶／雷射、富文字與便簽風格、裁切／射線、浮動工具與自訂倒數、頁面／視角管理、多格式匯出。螢幕物件右鍵可複製／副本／刪除／鎖定／層級；主列垃圾桶及Ctrl+Alt+K一鍵全清除，可復原。完整對照見 [功能表](MAC_1_0_9_PARITY_2026-10-10.zh-TW.md)。

螢幕繪圖已改已完成筆跡快取、局部像素讀回／上傳及16ms排程，未落筆懸停不重繪。同一VM原生80樣本舊策略中位66.38ms→5.15ms，18組畫筆／螢光筆／收筆像素比對與雷射清除無殘影通過；這不是實體輸入延遲測量，見 [效能紀錄](SCREEN_CANVAS_PERFORMANCE_2026-10-10.json)。

本輪實際 Core／手冊527項通過，ARM64原生建置與真實 Win2D／PDF／screen API 管線通過；中文 PDF 能以 strict parser 開啟並保留向量及可編輯原稿。透明控制列已查看，未宣稱完整指標／多螢幕／觸控筆／x64 實機或安裝升級通過。

最新四包位於 windows/dist；模擬機部署固定 C:\HeiBanPreview\Current，桌面「黑板 Windows 最新版」。Portable Data 由舊試用版保全後遷移；其他舊作品保存在 windows/recovered-user-data/2026-10-10，AppData／Documents 原作品不刪除。本機舊 preview 包／建置暫存清理約7.83GB，文字紀錄保留；GitHub舊公開版不變，未commit／push／發布。本輪建置／產物／清理的實際結果見 [BUILD_STATUS](BUILD_STATUS.zh-TW.md)及產物清單。

## 先前紀錄（歷史）


更新：2026-10-09。

## GitHub 公開預覽整理

原始碼已公開；本次只整理文件與下載包，不修改 Windows 功能、不重建／不執行測試套件。原創採 GPL-3.0-only 加 [限定 Windows SDK 例外](../LICENSE-WINDOWS-EXCEPTION.txt)，使用者已同意。公開 Installer ZIP 包裝原 EXE，Portable 保持 payload 並加入原始授權；ARM64／x64 各兩包，另附最新版來源 HTML。新公開雜湊見 [下載清單](../../docs/releases/windows-0.1.0-preview.5.assets.json)，原 dist manifest 保留。7個 assets已公開為prerelease，遠端digest／大小及4個主要下載HEAD已核對；來源tag指向991835a。發佈期間後續程式變更未收入該tag，保留本機供後續開發。實際發佈證據見 [公開稽核](../../docs/PUBLIC_RELEASE_2026-10-09.zh-TW.md)。

## 原 preview.5 開發批次與驗收（歷史）

**最新可試用封裝：0.1.0-preview.5**。Codex已整合Antigravity第0／1批來源、修復Windows原生編譯、截圖與圓規／arc邊界，完成ARM64／x64自包含Portable ZIP與安裝檔；不是第2～5批全部功能完成。見 [建置與驗收範圍](BUILD_STATUS.zh-TW.md)、[產物清單](ARTIFACTS_2026-10-09_preview5.json)。

- Windows 11 ARM64模擬機內已查看首頁、隔離空白文件畫布與最終Portable畫布。新版在 `C:\HeiBanPreview\preview5`，Windows桌面捷徑「HeiBan preview.5」，模擬機保留running供使用者試用。Portable作品保存在該資料夾的Data，不覆蓋舊作品。
- Core／手冊 **475項檢查通過**；原生截圖harness確認100×50 BMP裁切與兩次框選取消／清理。四包SHA-256、ZIP必要PRI／執行庫／品牌／手冊、PE架構與空Data檢查通過。
- 第0批：截圖採App自有區域框選，完成直接置入圖片物件，不另存截圖資料夾。請求綁定文件／頁面／視野，取消與逾時處理保留；快速操作列、樣式、工具排序沿用前批修正。
- 第1批：右上浮動導覽／收合、計算機括號與鍵盤／插入、圓規畫布預覽與掃弧、arc起訖控制點與等比縮放、背景計時器、圖片基礎與離線繁體中文手冊已有來源並收入本版。
- 本輪追加：半徑把手改65%位置，鎖定後不攔截筆尖；arc端點優先命中、跨0°連續、邊把手可縮小。修正Count()、命名空間、VirtualKey、尺框呼叫及PS5.1中文腳本編碼。
- **仍待驗收／開發**：完整滑鼠拖曳／色輪／A-B端點／圖片旋轉／尺支點／截圖置入操作、完整浮窗及自訂計時設定、x64實機、安裝升級／解除安裝、手寫硬體與性能。CUA在Parallels內的點擊未觸發新增視窗，不能據此宣稱UI回歸全部通過。
- W-S01入口位置已定：右上導覽列閱讀模式旁的螢幕圖示、首頁完整名稱按鈕，工具列更多備援；功能本體與可操作入口尚未實作，詳見主計劃第6節。來源手冊第18節已更正為規劃狀態；既有preview.5包內舊手冊文字待下次封裝更新。
- 第2～5批仍未完成：雷射／遮題／透明螢幕畫布、結構化筆記、媒體與管理、隱私與線上。下一輪按 [開發計劃](WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md) 推進。

本版沿用preview.4的直線／箭頭A-B、圖片把手、選取顏色、作品列收合與尺邊支點來源。歷史複核見 [Antigravity進度紀錄](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md)，歷史完成聲明不等於全部互動已驗收。

維護：[開發日誌](DEVELOPMENT_LOG.zh-TW.md)、[問題紀錄](ISSUE_HISTORY.zh-TW.md)、[決策](DECISIONS.zh-TW.md)、[架構](ARCHITECTURE.zh-TW.md)。

# Windows商店更新、工具列共用與效能 — 2026-10-12

## 階段1：開工與授權

使用者希望盡快更新商店，確認作品／螢幕工具列是否重複實作，若重複希望程式減肥，詢問更多流暢度想法。開工公開75aa821，status僅既有.vscode/保留；已讀根規則／開發索引／Windows狀態／架構／問題。只修改Windows，原上架1.0.12.0、已發行及作品保留。

本批先稽核共用層，再抽可保守共用的UI政策，避免把不同座標／資料生命周期混合。準備更高版本MSIX更新包供使用者上傳，實際提交／發布未執行；未授權測試不跑，编譯／封裝及靜態稽核另記實際結果。

已採graphify技能，根graph不存在，本機graphify已安裝；限定兩工具列及核心偏好／圖示的code-only corpus，無doc／image／私密資料語意抽取、無API。公開商品網址（AU參數）仍web工具not accessible，依上一批使用者後台已上架證據，不推定AU實際下載驗證。

## 階段2：結構證據、實作與發行決定

graphify初次detect因hidden .build路徑排除得到0檔，改偵測原始10個ScreenAnnotation C#＋MainWindow.Chrome／ToolbarPreferences／ToolIcons三檔；實際13檔12,714字，code-only AST建圖368nodes／905edges／9communities、0 input／output model tokens。GRAPH_REPORT corpus警告沿用第一次10檔4,279字，不能當最終13檔總數。最終用graph JSON的community與score_all重新取cohesion原值：0=0.06530825496342738、1=0.05555555555555555、2=0.07017543859649122、3=0.08735150244584207、4=0.09176788124156546、5=0.17894736842105263、6=0.17647058823529413、7=0.18333333333333332、8=0.2545454545454545；覆寫初次抄寫的近似值。這只是有限corpus結構，不是性能量測。

查詢詞從圖譜詞彙選toolbar／chrome／renderer／session／overlay；`graphify query ... --budget 2000` BFS找到201節點，輸出截斷保留限制。MainWindow→ToolbarPreferences、ScreenAnnotationWindow→NativeOverlayWindow為EXTRACTED關係；源碼再確認兩宿主各有Direct2DCanvasRenderer／EditorSession实例，共用類別而非共用同一份作品。圖譜／cache封存至ignored `.build/toolbar-graph-2026-10-12/`，不將一次性分析加入公開程式。未執行圖譜benchmark／UI／tests。

兩套Chrome建立方式確實分開，但Core物件／文件／Undo、Windows renderer、ToolIcons、文字選單／草稿、圖層展示與拖曳已有共用。一般世界座標／panzoom／作品保存，螢幕desktop pixel／DPI／Win32穿透與獨立註記保存不可合併生命周期。

抽出Views/ToolbarUi：每次建立獨立Button，共用tooltip／accessibility name、Flyout閱讀方向及四種線條樣式；螢幕11工具描述只保存一份供建立與語言刷新。兩宿主各自style、anchor／pass-through、undo／commit維持原規則。保留MainWindow.DashStyles其他四個引用。不是整套工具列同一個UIElement，也不把Host互斥處理移入共同層。

MainWindow.InvalidateCanvas會每次呼叫UpdateSaveStatusLight，原碼每次重建Grid／Ellipse或TextBlock及Brush。改state／tooltip比對，只有saved／pending／failed轉換重建圖示；失敗訊息／語言不同仍更新tooltip。不宣稱FPS或MB改善數值。

Windows正式產品1.0.13／File與Assembly1.0.13.0／Store1.0.13.0。Package-Store新增同版本產物拒絕覆寫及versioned STORE_ARTIFACTS備份，原1.0.12.0與報告保留。套件內十語與前批操作改善一併編入；目前是準備更新，未提交／認證新版。

私人庫讀完規則／README／PRODUCT_INFORMATION／狀態／日誌，status乾淨，gh repo view確認PRIVATE，fetch退出0；公開fetch退出0。第一次讀錯Packaging/StoreIdentity路徑失敗，改正Store/StoreIdentity；graphify query --help在root未有graph報錯，改在隔離圖譜cwd查詢成功，沒有App／測試失敗。

## 後續效能工作清單（本批未實作）

1. 平移／縮放：MainWindow.Rendering.SceneKey包含視角，每步會重建已提交場景；評估圖塊cache／拖動暫時轉換，手勢結束補高品質，守護縮放／DPI／背景及選取準確度。
2. 大作品命中／框選／橡皮擦：將既有渲染空間索引延伸到候選查詢，保持世代／bounds／undo／可見性更新契約，避免遍歷全部物件。
3. 待機：螢幕16ms tick還輪詢焦點與橡皮擦；改事件喚醒／節流前須維持hotkey、跨螢幕焦點與雷射尾跡。一般計時也含停筆吸附，不能直接停掉。
4. 圖片／縮圖：按可見區載入、縮圖下採樣及GPU記憶體預算；大型原圖／撤銷和匯出保留原稿，不能破壞文件。
5. 更深UI共用：雷射／筆刷／屬性面板有相近控制項，但即時preview／按套用與DPI單位不同，先寫契約再抽builder。程式碼行數减少主要降低維護成本；MSIX多數大小来自.NET／WinAppSDK，不能保證大幅縮包。

交付待填：新x64／ARM64編譯與封裝實際結果、舊bundle雜湊保全、公開／PRIVATE推送。App／實機操作、十語母語校閱、4K／DPI、Store安裝及WACK均未執行。

## 階段3：編譯與封裝開始

`windows/.build/tools/dotnet/dotnet.exe build windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 --artifacts-path windows/.build/toolbar-update-r1`，log為.build/toolbar-update-r1.log；實際顯示建置成功、0警告／0錯誤、58.58秒。初次呼叫只輸出stdout遺漏session id，故本次不冒稱取到該process退出碼；後續讀完整build尾端確認成功。無App或測試。

`git diff --check`退出0。原1.0.12.0 bundle重新Get-FileHash核SHA仍d7a49b63d88fa880b1a97b0c307361ad2cfbc9b3d58786048887093d7204ea7b，記作封裝前保全證據。程式／候選版本先提交，再以Package-Store隔離build記精確source commit，最後補產物證據與同步。

## 階段4：完成封裝與靜態檢視

來源提交`9b6c4e48563c6cfc95a4e7d1de3ecd2be8d0b825`，15檔179insert／36delete（含共用類別、版本／紀錄）；公開fetch後HEAD/origin/main原0/0，原.vscode保留。抽共用會新增共同層，不以總行數下降或包體下降作成果。

`Package-Store.ps1 -DotnetPath D:/Game/HaiBan x64/windows/.build/tools/dotnet/dotnet.exe`退出0。隔離`windows/.build/store-ef8b9caee06949efa992eb132ce34b64/`：x64 build52.35秒、ARM64 build53.95秒，各0warning／0error，SDK PackageSuccessfullyCreated；主log `.build/store-update-1.0.13.0.log`。不是ARM64執行或App驗收。

新bundle：`windows/dist/store/HeiBan-Store-1.0.13.0-x64-arm64.msixbundle`，193,452,627 bytes，SHA256 `c8fc90e49c2cb1517e4d7a84f9c03a106083dc2053bd05a3cd533c07893320ad`。x64 MSIX98,009,085bytes／ARM64 MSIX95,441,505bytes，各SHA與sidecar见[產物報告](STORE_ARTIFACTS_1.0.13.0_2026-10-12.json)。sourceSnapshot捕捉當時173檔；本批後續README／docs更新屬交付紀錄，不修改已封裝App。

Package-Store檢視manifest identity／1.0.13.0／OS19041、必要runtime、25份法律原文／手冊／StoreREADME、無Data／Updater／portable.dat／debug、bundle兩架構與内含MSIX SHA皆通过。額外`inspect-store-1.0.13.py`（ignored）最終退出0：173來源SHA在檢視當時一致、兩MSIX的十語manifest含全部預期語言、DLL十份JSON原始bytes嵌入各581keys、EXE PE machine x64 0x8664／ARM64 0xaa64、無AppxSignature、三sidecar及artifact SHA一致。[靜態報告](STORE_INSPECTION_1.0.13.0_2026-10-12.json)。

額外檢視初次退出1：嘗試把舊local report與公開report逐byte比對，公開歷史增有validationLimits／firstReleasePrice／buildEvidence三項，故不相等。核對原local全部JSON欄位與公開歷史相同後，改檢視全部原欄位，最終通过；不是舊套件損壞。封裝後原bundle SHA仍d7a49b63…，versioned舊report保存；保留舊Store包、正式Release、trials／Data與備份。

官方MSIX上傳／清單語言文件已查阅：至少一个完成清單，可移除未準備的介紹語言而不移除App支援；[新增功能與上傳步驟](STORE_RELEASE_NOTES_1.0.13.zh-TW.md)供使用者貼入。此前Core性能bench數字未重跑、不套用；本輪没有App／tests／WACK／Store安裝／母語／4K-DPI驗收、Store上傳／提交／發布／排程，也沒有新GitHub Release。

圖譜cache兩個自動生成源碼目录已核workspace内並Move-Item封存至ignored `.build/toolbar-graph-2026-10-12/cache-side-effects/`，沒有刪除源码／作品／交付包。rg第一次查MainWindow.cs錯檔名，改MainWindow*.cs查到MainWindow.xaml.cs兩shared實例（L46／49），ScreenAnnotationWindow.cs L22／23；文字／圖層共用引用亦核實。

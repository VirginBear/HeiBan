# Windows物件拖曳與藤條重點設定 — 2026-11-02

使用者要求：已選用藤條時再次點工具列藤條可選靜音；物件拖曳晃動明顯卡頓需查流程。僅Windows，維持1.1.0開發批次；保留作品、已送審包與原有三份dirty清理文件／三份YouTube文件。開工讀平台狀態、架構、問題與git status；工作中保存差異至.build/object-drag-20261102。沿先前graphify導向檢視當前MainWindow.Input／Rendering與EditorSession，不依10/12舊圖宣稱目前行為。

## 查明原因／準備實作

一般物件移動每個PointerMoved走PreviewMoveSelection後InvalidateCanvas(true)：雖筆跡JSON延後提交，仍修改document bounds、掃描SelectedObjects、反覆設定游標及SelectionBar XAML，再整景重建。使用低priority Invalidate另加一次排程。放開再RefreshEditor／Prune。螢幕也走同一bounds預移動，每sample改committedDirty。需要把平移與resize/rotate分開，平移僅保存獨立offset、靜態繪圖段快取，保留選取物件原始Z遮擋；放開一次位移與Undo，取消不觸碰作品。快取必須有像素預算與資源釋放，不可每個圖層各配置無上限4K bitmap。

實作與測量待追加；不先宣稱零延遲或改掉所有resize/rotate成本。

## 實作進度

新增Core ObjectDragPreview：一次保存原物件參考／繪圖順序與可移動選取，Move僅設定相對起點的offset，Current檢查document／epoch／generation／page，放開才Begin＋Move＋Commit。兩host共用ObjectDragRenderer，靜態段最多兩張bitmap且總額64MiB，超額或GPU維度超限改command list；動態段僅套viewport位移，保留中間與上層遮擋，同Z順序不變。靜態段只建立一次，不在每frame排序。一般拖動不更新游標／SelectionBar、不整景dirty／屬性重建；螢幕沿原局部damage/readback路徑合成共用cache，取消強制恢復原committed畫面。resize／rotate／vertex仍用既有專用手勢。

Core2423（新增15）通過，含1000個preview sample無document／transaction變化、一次commit／undo／redo、取消無回復負擔、跨epoch／頁拒絕、原Z段與locked保留。前兩次QA build均0警告0錯誤；第二次後檢查自訂紅筆fixture發現SetCompletedInkPoints不負責bounds，已補明確X/Y/Width/Height再建QA，避免測到不正確的測試資料。十語702keys無缺漏、每語26節78段指南生成成功。

## 實際驗證（正常封裝前）

- `windows/.build/tools/dotnet/dotnet.exe run --project windows/HeiBan.Windows.Core.Tests -c Release --artifacts-path windows/.build/object-drag-20261102/core-build`：2423 PASS，含15新增斷言；`corechecks.log`。
- `python windows/scripts/Build-LocalizationCatalogs.py`／`Build-UserGuides.py`：702keys／missing0、十語26節78段指南重建。
- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/object-drag-20261102/qa-build`：最新r3 0警告0錯誤；前三輪成功log均保留。輔助rg使用不存在的猜測路徑／PowerShell wildcard曾失敗，改rg --files定位，不影響內容。
- ProcessStartInfo指定自有QA exe、尚不存在的`HEIBAN_WINDOWS_DATA_DIRECTORY=.../qa-data-r1`及`--object-drag-validation-output=.../qa-results-r1`，僅合成測試作品。原生23斷言：0bitmap預算command-list備援與64MiB上限兩種路徑，各5種位移，10幀與完整重畫逐byte比較maxDifference=0；每個cache只建立1次、原Doc未動；半透明、分散選取、前中後遮擋皆保留。
- 螢幕生產OnPointer adapter12斷言：8次move逐次Render、文件／transaction不變、靜態cache只建1次；取消保留原Doc，放開一次commit與一筆Undo還原。未另外做螢幕完整像素oracle，不能把前述320×240離屏精確比較當全部螢幕DPI結果。
- Sky實際拖動5004物件fixture中的紅筆：1 move、1 preview frame，cacheBuilds=1、previewUnchanged=true、rebuildDuring=0、oneCommit=true、correct=true。`qa-results-r1/gestures.json`全成功；驗證的是路由與工作次數，不是高頻滑鼠／顯示延遲ms。
- Sky選藤條，再點同工具按鈕，確實出現只有「藤條靜音」的設定選單；點選後讀toolbar.json caneMuted=true。關窗第一次因使用者輸入保護未送出，重新觀察後Alt+F4正常關閉PID15960，未強制覆蓋輸入。
- 未執行：端到端ms／FPS、全DPI、多螢幕／GPU記憶體壓力、ARM64實機、resize／rotate性能改造、新Store包／送審。起始建立cache與放開提交仍有一次工作，不宣稱所有情境完全無延遲。沒有重跑前批Optimization68，不套用舊數字。

## 正常包檢查後補強

第一份正常r1封裝核對通過（654 payload／244來源／CRC、觀察器排除），但交付前檢查發現：非同步圖片資源載入完成只InvalidateCanvas，獨立拖動static cache可能仍保留未載入的畫面到放開。補ResourcesChanged同時釋放拖動GPUcache，下一frame依現有preview重建；不改offset／文件。原生23＋screen12驗證在前一程式commit執行，此一行失效處理由r2正常Release建置涵蓋，未冒稱已做圖片載入中拖動的實機回歸。r1未交付、保留不覆寫，最終另包r2。

## 最終正常免安裝交付

- 最終程式來源`ec86503f951316d69a5b96ea2fbb82177f6390c2`，正常Release x64／產品1.1.0、EXE與DLL FileVersion1.1.0.0，ProductVersion含同來源SHA。前述原生驗證程式來源為`613708c6d3680a9577b681c3a163250dd9223c68`，兩者僅多ResourcesChanged快取失效一行；不混同驗證範圍。
- 實際命令：將`.build/tools/dotnet`加到當次程序PATH後執行`windows/HeiBan.Windows/Packaging/Package-PortableTrial.ps1 -Runtime win-x64 -Label object-drag-2026-11-02-r2`，App＋Updater publish成功。證據`.build/portable-trial-4555ae1e844740909eb1ba323714d4a4/publish.log`。
- EXE：`windows/dist/trials/HeiBan-Windows-Portable-1.1.0-object-drag-2026-11-02-r2-win-x64/HeiBan.exe`；ZIP同名加`.zip`，133339702bytes，SHA256`900d82009c7eb47f500a58080e7c13e1f13cd934dfc4d89c75ce757bf24025bd`，sidecar一致。
- `python windows/.build/object-drag-20261102/Verify-Portable-r2.py`：654 payload本機／ZIP逐byte SHA核同、244來源raw-byte SHA、ZIP CRC、64SVG與10語HTML／練習／manifest核同；8個診斷方法／getter不含於正常HeiBan.dll。`portable-verification-r2.json`保留。
- 正常包未啟動，使用全新獨立空白Data，不自動搬／覆寫原作品；由使用者試用。dist不入Git，其他電腦不能假設有此EXE。r1為未交付中間試用包，保留不覆寫；本輪不刪除任何舊檔。
- 已送審`HeiBan-Store-1.1.0.0-x64-arm64.msixbundle` SHA仍`a7799085a7ccb5f7f0a23b37d0b12425a9def99ff366d8fa13686ee01eaade66`；未進版、未製作／上傳／送審新Store包。

## 使用者驗收

1. 選用藤條，再點工具列同一顆藤條：應出現「藤條靜音」勾選項；切換後動畫保留、設定重開保留，一般與螢幕畫布一致。更多與右下右鍵入口仍可用。
2. 選筆畫／形狀，按住左鍵來回平移，觀察筆畫是否跟手、是否還有連續停頓。移動到其他物件下方／上方時，應依原圖層遮擋，不突然浮到最上。
3. 放開後Ctrl+Z一次應回到原位；多選物件應一起復原。拖動中Esc應取消、物件回原位且不新增Undo；切換螢幕畫布也可同測。
4. 本批專門優化平移，resize／rotate仍是各自路徑。尚未量測端到端ms／FPS，多DPI與剛載入圖片時的拖曳可再回報；不宣稱零延遲。

公開原始碼／驗收日誌與私人壓縮交接分開推送；原有dirty清理文件與YouTube文件保留，不混入本批提交。

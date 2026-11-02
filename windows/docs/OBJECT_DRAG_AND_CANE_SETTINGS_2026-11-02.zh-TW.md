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

# 真實採樣、轉角與板擦卡頓 — 2026-10-22

## 開工
- 基準a24f82a；保留三份平台文件18行YouTube未提交內容與三份YouTube新文件；只處理Windows，同系列1.0.15，不自動進版。
- 使用者完成手動採樣，回報筆畫轉矩形角特別卡、筆跡稍多板擦也卡；提議同筆刷／色／粗細合成同元件。先讀採樣與實際路徑，不直接合併永久筆畫造成Undo／選取／局部擦除語義改變。
- 已讀入口、平台狀態／架構／問題／決策。沒有額外授權測試，本批讀既有手動採樣，不自動生成操作或執行測試。

## 已取得真實採樣
- 使用者本機input-latency-20261022-181012.json，151.1769秒；GC0/1/2=828/292/93。程序工作集342446080bytes。GC為整個程序累計，尚不能證明哪些階段觸發或停頓長度。
- PointerMove49106次（保留最近2048），P95=0.1853ms／max12.3403ms；CanvasDraw4456次P95=4.628ms／max28.6185ms；SceneRender P95=4.5911ms。ToolSwitch8次max1.5541ms，BrushPanel0次，ScreenRender0次。不能把零次解讀為零成本。
- UI heartbeat P50=35.5735ms、P95=113.2147ms、P99=207.1019ms、max673.922ms，16ms目標下有嚴重排程延遲；它不是幀率，包含inactive／OS排程。現有CPU scopes快但不含事件排隊、XAML版面／未包覆的板擦，需追未覆蓋處。
- 板擦原每個指標事件都按5DIP細分擦面，逐子步掃全文件、逐點旋轉複製、局部碎片即時序列化；同時每子步Invalidate全scene。已確認會隨總點數與子步放大，且舊採樣沒有包到BoardEraser_Moved，不能拿PointerMove數字替板擦背書。

## 實作進度
- 板擦指標只記錄路徑與TranslateTransform，不每次Canvas.SetLeft/Top觸發XAML排版。16ms timer每次只發一個背景批次，原5DIP擦面採樣保留；worker獨佔draft與Viewport拷貝，UI只收隔離snapshot。未命中不發新snapshot／重畫背景，完成才一筆Undo。取消、捕捉遺失、舊epoch結果拒收，釋放後最後批次在儲存／正常退出前等待，避免覆寫其他編輯。
- RectangularEraser先保守bounds排除（含旋轉、真端點與cache curve bounds）；unrotated筆跡重用點列、移除open stroke的13次內部填色回查。EditorSession擦面倒序走物件避免每子步ToArray，局部新段保留owned點列；精確擦面與未知欄位仍依既有契約。
- 畫布Invalidate合併待畫請求；solid筆暫停時重用相同尾段geometry，減少轉角停住時反覆建銷；Draw才清排程旗標，不丟永久筆畫。
- 新採樣補EraserMove／EraserApply（worker）／EraserCommit、SceneRebuild、WetInkRender，schema2加整個程序managed allocated bytes／GC實際累計pause及最後GC heap。舊資料不含這些，不能反推GC暫停時間。
- 不把同樣式筆畫永久合併：現有主scene已把完成筆畫一起快取，減少物件數並不涵蓋單筆轉角或輸入排隊。保留逐筆Undo／選取／局部擦除，先以處理／快取層批次達到使用者要減少重複工作的目的。尚未新增可見的樣式群組功能。

## 中途結果與參考
- 中途x64 Release build成功36.53秒，0warning0error；之後補有延伸線不作bounds拒絕、新碎片owned list避免再clone，最終封裝重新編譯，不把中途build當最終性能數字。
- 官方參考：https://learn.microsoft.com/en-us/windows/apps/develop/performance/keep-ui-thread-responsive （輸入／版面共用UI thread、長工作移出）；https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.input.pointerpoint.timestamp （時間戳是boot microseconds，本批未以不同時基相減冒充端到端延遲）。
- 不含名稱或內容的作品數量檢視只描述測試後保存狀態，使用者已清空的作品不能反推採樣期間筆畫數；未引用它作當時負載證明。

## 最終封裝、資料與未驗收
- `Package-PortableTrial.ps1 -Runtime win-x64 -Label eraser-input-queue-2026-10-22-r1`最終publish／封裝成功；來源8d79577e670942d133de4ffa2840c302443f63ed。ZIP132778376bytes／SHA25629b61b9c8c28d2863cfbb9fa28fbe8c5055f3f4495511fb828d5eda0e756a9fc。CRC、585payload／179source SHA、x64 PE、十語指南與採樣launcher核同，ZIP使用者Data=0；詳ERASER_INPUT_PORTABLE_ARTIFACT／INSPECTION_2026-10-22.json。
- `eraser-input-handoff.ps1`確認同路徑新舊試用沒有執行，接續52檔24767438bytes，逐檔SHA符合，不改作品內容。`Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.15-eraser-input-queue-2026-10-22-r1-win-x64`先備份Data與未知檔再刪舊runtime／ZIP，釋放456336763bytes、保留24770261bytes（包含原數值採樣）；原始數值採樣也以SHA核同存PRIVATE repo。Store1.0.15.0原SHA仍a889482ff3aa171569ce415fc285340b26742528af4306a3e0a0e3d6fa07eb96，已發布歷史不刪。
- 本批實際做了讀使用者既有採樣、碼路徑分析、編譯封裝、靜態檔案完整性及資料接續。未執行新版App／自動或實作測試／新實機採樣／GPU trace／DPI與Undo回歸驗收，沒有改善後性能數字。正式版號不變、沒有Store／Release。
- 待使用者用同一Capture-InputLatency.cmd重現轉角／連續筆／板擦物件與局部模式、正常退出，再比較schema2；同時驗收快速放開、Esc、捕捉中斷、保存／離開邊界、Undo、跨頁與未知欄位保留。新增背景擦除的取消及完成邊界只經源碼檢視，未假稱已實機通過。

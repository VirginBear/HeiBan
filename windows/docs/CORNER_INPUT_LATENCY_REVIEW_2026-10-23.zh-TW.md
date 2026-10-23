# 2026-10-23 — 轉角跟筆延遲分析／下一輪調校交接

## 範圍與當前結果

使用者實際試用後回報：曲線較不易察覺，但自由筆畫方形／矩形／三角形時，系統游標先轉彎、筆跡落後一段空白距離，筆尖範圍提示也需交叉比對。這是負面手感驗收，前批優化尚未達使用者要求。沒有影片、輸入到顯示的量測或新trace；不能替使用者換算實際毫秒。

本批僅分析／文件，不改程式、版本、偏好或產物。檢視HEAD 109ad6ad085aaa253661d98a7cee2168bfcd8ce2；最新試用來源05920d7ebbed2d2665f1d343bc3e5edc7ab3b6dc。保留既有三份文件6／8／4行未提交差異及三份YouTube新文件。明日指2026-10-24；由使用者續接調校，沒有建立排程。

## 已確認的程式事實

| 層次 | 目前路徑 | 不能據此推論 |
| --- | --- | --- |
| 系統游標 | 由Windows顯示；App另畫筆尖範圍 | 系統游標與App內容一定在同一畫面時刻更新 |
| 輸入 | MainWindow.Input.cs取GetCurrentPoint給_mouse，GetIntermediatePoints送collector，時間排序與舊樣本排除 | 資料抵達事件時沒有排隊／最新點一定無誤，仍需核對 |
| 暫態筆跡 | WetInk.cs的最後尾段SegmentPath畫至points.Count-1 | 保留一段可變代表故意少畫最後一段；目前沒有這個等待 |
| 平滑 | SegmentPath採相鄰點Catmull-Rom轉cubic | 平滑失真等同時間延遲；轉角可能overshoot／變圓，需要另外比對 |
| 畫面 | CanvasControl.Invalidate合併請求，Draw同時合成scene／wet／hover | Invalidate立即顯示，或Draw CPU耗時等於GPU／螢幕可見時間 |

目前RenderHover是在同一Draw畫的雙圓範圍提示，沒有移動視覺動畫；使用者所稱虛線圈是否即此提示，尚無畫面佐證。須比較「系統游標→App筆尖中心」與「App筆尖中心→筆跡最後端點」兩段差距。若兩個App元素同幀仍不同位置，單純UI排程不能完整解釋，需先查樣本／座標、尺規投影、線條虛線樣式及端點繪製。自由筆磁鐵已排除，不重新假設它仍啟用吸附。

來源：MainWindow.Input.cs（Draw／PointerMoved）、MainWindow.Rendering.cs（Invalidate／scene）、WindowsInkCoordinator.cs（收樣／時間排序）、Direct2DCanvasRenderer.WetInk.cs（穩定段／尾段）、Direct2DCanvasRenderer.cs（SegmentPath／RenderHover）。

## 優先假設，尚非已證實根因

1. **輸入到畫面排程**：UI事件／XAML Draw／GPU提交／桌面合成及顯示，與系統游標有時間差。這能解釋游標先轉彎；不由函式平均耗時判定已排除。
2. **提示與取樣不一致**：同一事件的目前點與collector最後接收點需比對timestamp／pointerId／座標／投影。GetIntermediatePoints官方契約包含目前點；不可直接加畫一個重複點當修正。
3. **轉角平滑**：固定平滑在急轉彎處可能偏離原始折線；以原始點尾段作診斷，再決定保角條件。它不代表已找到所有時間延遲。
4. **每幀GPU同步**：前批solid改每Draw寫raster，可能增加drawing-session flush／同步成本，尚無GPU量測。不能因尾段計算變少，就認定一定更快；需要與原批次策略比較。
5. **螢幕畫布**：native buffer重用沒有消除GPU回讀／GDI合成；應與一般畫布分開分析。

## 2026-10-24 調校順序（今天未實作／未執行）

1. 先加入明確可關閉的診斷顯示／採樣：同幀比較目前點、最後接收點、實際尾段端點；時刻分成事件樣本、事件抵達、Draw開始／結束。只保存時間／距離彙總，軌跡／作品不寫日誌。核對timestamp時基，不能直接和Stopwatch相減。
2. 比較尾端直接折線與現行平滑；拐角先忠實到最新點，再平滑已固定部分。必須保留原始取樣與同一筆Undo，收筆不能跳位；診斷結果再決定是否做自適應保角。
3. 比較每Draw追加raster與較小批次；分辨CPU幾何成本及GPU同步。保持透明交疊、4K／DPI、畫布邊界正確，不能只追平均FPS。
4. 若樣本端點正確而整個App仍落後，再原型獨立的即時筆跡輸入／呈現路徑，減少對主UI版面排程的依賴。先查WinUI3相容性及生命週期，不直接將UWP InkPresenter當可替換元件。
5. 預測輸入排最後；直線外推在突然轉角可能畫錯方向，不能用預測或把圓圈移到落後端點掩飾真正延遲。

## 工作目標／量測界線

- 使用者提出50ms作首輪上限，可作暫定目標，並非通用人體接受標準。評估的是輸入到筆跡可見的延遲，非網路Ping往返時間。
- 暫定在約定的畫布／顯示器條件下以P95 < 50ms、盡量接近1–2個顯示刷新週期為調校方向；另記P99／最大停頓，不能只看平均。60Hz每次刷新約16.7ms，120Hz約8.3ms，為算術參考而非已量測成績。
- 軟體timestamp到Draw／Present的時間仍非實際螢幕發光時間；需要端到端證據可用外部高幀率錄影或相應呈現追蹤。錄影幀率限制須明列；不以一般截圖或CPU scope代替。
- 轉角偏差與時間延遲分開驗收。矩形、三角形、急停反向、連續短筆、不同速度／筆寬／透明度、4K及60／120Hz分開記錄；今天沒有要求使用者補做這些項目。

## 本批命令、失敗與未執行

git status／rev-parse／diff --numstat、PowerShell Get-Content、rg靜態追查及Microsoft官方文件查閱。初次rg把萬用字元放字面檔名退出1，改目錄-g後完成。程式修改、編譯、測試、App啟動、新性能採樣、打包／Store操作全部未執行。沒有新增測試腳本或改寫前批性能數字。文件狀態更新不代表手感問題已修復。

## 官方來源

- [Windows App SDK GetIntermediatePoints](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.xaml.input.pointerroutedeventargs.getintermediatepoints?view=windows-app-sdk-1.8)：歷史取樣包含目前事件。
- [保持UI執行緒回應](https://learn.microsoft.com/en-us/windows/apps/develop/performance/keep-ui-thread-responsive)：事件／版面共用UI排程。
- [UWP Windows Ink](https://learn.microsoft.com/en-us/windows/uwp/ui-input/pen-and-stylus-interactions)：低延遲wet ink架構參考，非WinUI3現成替換承諾。

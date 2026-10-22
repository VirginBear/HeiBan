# 畫筆與工具切換停頓追查 — 2026-10-22

## 開工
- 基準dd4cb4f，原三份平台文件18行YouTube未提交內容與三份YouTube新文件保留；只修改Windows，不進版。
- 使用者實機回報：連續筆跡、筆刷與工具切換仍頓，前批改善不足。要求追原因並可查其他繪圖軟體設計。先做程式路徑與官方資料比對，不推論硬體不足或已證明GC／GPU瓶頸。
- 已讀入口、平台狀態／架構／問題／決策與Windows規則。沒有graphify圖譜；本批是直接缺陷修正，沿具體呼叫路徑查碼。
- 未新增／執行實作測試或App自動操作；後續記錄查得原因、修改、實際封裝及未驗收項目。

## 調查進行中
- 官方Direct2D文件指出GPU資源建銷與Flush有成本、應重用、避免重算靜態內容；Win2D CanvasControl屬XAML控制，swapchain可避開XAML刷新排程但需額外架構。UWP InkPresenter低延遲背景執行緒案例不可直接當WinUI3現有能力。
- 現有WindowsInkCoordinator自己收集UI指標，並非Windows InkPresenter；CanvasControl繪製、XAML工具、序列化仍共用UI thread。前批delta Undo減少全文件複製，但尚不足證明筆跡低延遲。

## 可確認的程式成本與修改
- 使用者補充「拖著畫線時就會卡，放開或換工具也會」。未把此回報當成CPU／GPU／GC量測。
- 原RenderLiveStroke快取幾何blocks，但每幀仍DrawGeometry所有blocks與新建tail，且不論opaque都開opacity layer。改兩畫布solid筆跡：單一可見視窗GPU raster重用、只追加已穩定cubic片段、末段即時預覽；半透明筆只合成一次避免接點變深，不透明筆略過opacity layer。虛線／套索沿用舊path行為，縮放／DPI／裝置／顏色粗細變更重建；一筆結束不釋放重配整張raster，資源重設與關閉才Dispose。
- CanvasDraw原迴圈對所有圖釘每幀new CanvasTextFormat+DrawText（包括指南畫面外25個圖釘），改視野外略過／CanvasTextLayout有界cache。導航圖示只在鎖定／閱讀／語言／工具列控制項身份改變時建立，保留圖文label；同字標籤不重複設定。
- 原新筆畫Generation改變後magnet full rebuild掃全作品所有筆跡點。新增Append Ink已提交單物件增量Add，僅exact generation／epoch／page／zoom匹配才用；Undo／編輯／刪除仍full rebuild，兩畫布一致。
- 新筆畫原先Serialize Points後render立即Deserialize同一字串。SetCompletedInkPoints保留獨立owned點列與既有JSON契約；讀舊文件、未知欄位及snapshot隔離維持原邏輯。中途點批次正常逆序直接遍歷，非單調來源才排序，不改筆跡採樣密度。
- 新增InputLatencyTrace（HEIBAN_INPUT_TRACE明確啟用），固定2048樣本ring記CPU handler／draw submission時間、thread allocation、GC次數與UI heartbeat；不記文字、路徑作品名、座標或影像。只正常關閉寫指定本機檔，不上傳；關閉時無heartbeat timer。這不是實作測試，也不等於GPU／端到端筆尖延遲。
- 尚未實際採樣，沒有CPU／GPU／GC瓶頸比例或P95可引用；現有螢幕畫布仍有GetPixelBytes→layered-window CPU readback，另列架構限制，不宣稱本批消除。

## 官方參考與適用邊界
- https://learn.microsoft.com/en-us/windows/win32/direct2d/improving-direct2d-performance （資源重用、layer與batch、靜態內容cache）
- https://learn.microsoft.com/en-us/windows/apps/develop/win2d/using-win2d-without-built-in-controls （WinUI3用CanvasSwapChainPanel／HWND；CanvasControl受XAML排程，swapchain較低延遲也有資源成本）
- https://learn.microsoft.com/en-us/windows/uwp/ui-input/pen-and-stylus-interactions （UWP InkPresenter wet/dry input案例，本App非原生InkPresenter，不把UWP InkCanvas當WinUI3直接替換件）

## 中途建置與採樣入口
- `dotnet build windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 --no-restore`成功，0warning／0error，39.59秒。此為中途來源；最終portable仍重新編譯，不作性能提升量測。
- solid live raster以64段為單位追加，保持原預覽分段接點並避免每幀新增GPU flush；live tail最多65段。bbox計入cubic控制點最大步距，透明筆clip不截斷大跨度曲線。
- 試用包附Capture-InputLatency.cmd／Collect-InputLatency.ps1，只在使用者手動啟動此入口時量測真實操作；正常啟動HeiBan.exe不啟用採樣。已有同一路徑程式執行先停止採樣啟動；正常退出寫本機JSON。不自動執行本批尚未授權的實作測試。

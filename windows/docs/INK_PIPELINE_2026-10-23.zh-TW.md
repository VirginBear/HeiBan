# 2026-10-23 — 畫筆即時預覽與收筆工作分離

## 開工／範圍

- 使用者先提出「繪畫中只顯示，放開後物件化」的分析方向，隨後提供另一份 AI 分析並明確要求直接編寫程式。
- 開工來源：`4ab8e488adf398a79af3bb6b8485cf90dca0ddab`；Windows 1.0.16／1.0.16.0。本批不提高正式版號。
- 保留三份平台文件既有未提交內容（6／8／4行）及三份 YouTube 新文件；只改 Windows。既有作品、試用資料、Store 產物保留。
- 已讀開發入口、Windows AGENTS／狀態／架構／決策／問題紀錄。另一份 AI 分析只作待核對假設，不把推測直接記成性能因果。

## 調查中已確認

1. 兩畫布自由筆已在放開後建立永久物件；拖曳不逐點寫入主文件／Undo。
2. 一般畫布輸入與 CanvasControl Draw 共用 UI 排程。實線預覽有 GPU raster，但穩定段以64段為批次，尾段最多65段；非實線每幀重畫已快取幾何區塊，並非每幀重新建立整條曲線。
3. 收筆 SetCompletedInkPoints 立即序列化；AppendInk 的 snapshot／反射記憶體估算及渲染 Points 快取鍵，是延後序列化時必須一起處理的邊界。
4. 圖層延後刷新及自動存檔已有手勢保護；不把這兩項誤記成已證實的繪畫中刷新缺陷。
5. 核對 ShapeCursor.Update 確實呼叫 LoadCursor／SetCursor；CursorCanvasHost 已快取相同的 WinRT cursor，不是每事件重新配置 InputCursor。新畫筆移動路徑避開整段形狀游標處理。
6. 螢幕畫布 GetPixelBytes 仍有 GPU 回讀與每幀配置；緩衝重用不能消除 GPU→CPU 這個邊界本身。

## 執行與困難（持續追加）

- 已執行 git status／diff --numstat、rg 與 PowerShell Get-Content，核對自由筆輸入、預覽、收筆、snapshot、延後維護。
- 部分初次 rg 使用不存在的 Storage／InputLatencyTrace 路徑與字面萬用檔名，退出1／2；改以 rg --files 與目錄 -g 找實際位置，沒有修改檔案或執行測試。
- 本批實作、建置、交付與實機結果待後續記錄；此處不沿用前批測試數字。

## 官方參考

- [Microsoft：保持 UI 執行緒回應](https://learn.microsoft.com/en-us/windows/apps/develop/performance/keep-ui-thread-responsive)：事件、layout 共用 UI 排程；CPU 工作需明確安排，不因 await 自動變成背景計算。
- [Win2D IBuffer 局部回讀](https://microsoft.github.io/Win2D/WinUI3/html/M_Microsoft_Graphics_Canvas_CanvasBitmap_GetPixelBytes_3.htm)、[Microsoft IBufferByteAccess](https://learn.microsoft.com/en-us/windows/win32/api/robuffer/ns-robuffer-ibufferbyteaccess)：以既有緩衝取代每幀新 byte[]，不宣稱移除了 GPU 回讀。

## 實作結果（封裝前）

- 一般畫布 PointerMoved：捕捉中的自由筆直接收 intermediate points 並合併 Invalidate，跳過 handle／DPI／cursor／重複 world delta。尺規投影仍由 collector 明確保留。
- WetInk：實線每 Draw 一次追加新定型段，尾段只剩最後一段；虛線保留64段phase邊界但穩定部分只寫一次。raster 只合成筆跡範圍，透明筆維持一次 opacity 合成。
- 一般畫布收筆：保留一筆同步 Undo／永久物件；新筆記憶體持有點列、延後 JSON，snapshot／估算／渲染 cache key 共同避免偷偷提早觸發。最後實線可重用 GPU 預覽 append 到 scene；多筆排隊／虛線／失配皆走原稿 fallback。
- 無邊界畫布移除兩處全尺寸 clip layer；Invalidate 不再刷燈，Draw 亦在作畫中略過燈號刷新，收筆後仍更新。
- 雷射／停筆辨識 timer 改按需啟動；雷射16ms、畫筆停筆檢查100ms，閒置停止；相同樣本數的失敗直線辨識不反覆全掃。停筆約1秒功能保留。
- 螢幕畫布用 native IBuffer 容量重用及直接 memcpy 到 DIB，減少大 managed 陣列；GetPixelBytes GPU同步與完成場景重建仍存在。
- 手動 trace 新增 InkEncode／InkSnapshot／WetRasterAppend／ScreenReadback scopes；預設關閉，不記軌跡／作品內容，沒有自動執行。
- [記憶體／文件契約](INK_STORAGE_CONTRACT_2026-10-23.zh-TW.md)說明 null／未知欄位、snapshot ownership、歷史預算與延遲編碼邊界。

## 實際命令與排解

1. 系統 `dotnet build ...` 退出1：`C:/Program Files/dotnet/dotnet.exe` 沒有SDK。沒有安裝或更動全機環境。
2. 改用既有 `windows/.build/tools/dotnet/dotnet.exe`，在 windows 目錄依 global.json 建置 Release／win-x64／Platform=x64／WindowsPackageType=None，artifacts `.build/ink-pipeline-20261023-r1`。首輪成功59.90秒、0error／2個相同 CS9191 warning。
3. QueryInterface 第二參數由 ref 改為對應 in 後，相同建置命令成功27.90秒、0warning／0error。最終 log 在上述 artifacts/build-final.log。
4. `git diff --check` 退出0；僅 LF→CRLF 工作樹提醒。沒有把這項靜態檢查記為實機測試。

## 尚待實機／架構限制

- 拖曳長實線、轉角、連續短筆、換筆／顏色／粗細、虛線／透明重疊、固定畫布邊界與4K／縮放需使用者核對。
- 保存／重開、逐筆Undo／Redo、移動／局部擦除、未知欄位及文件 round-trip 未執行驗收。
- UI／CanvasControl 仍共用排程；保留原稿 fallback 的完整重建與 screen GPU readback 仍可能停頓。不能用局部 CPU scope 推論 GPU／顯示延遲或承諾零延遲。
- 這批先降低已確認同步工作；沒有在未量測下直接移植 UWP InkPresenter／重寫獨立 render thread。

## 未執行

App 啟動、實作測試、實機性能採樣、Store 上傳／送審／發布未執行。未宣稱已達小畫家手感或零延遲。

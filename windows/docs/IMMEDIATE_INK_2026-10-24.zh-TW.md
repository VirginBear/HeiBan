# 2026-10-24 — 畫筆直接呈現與延遲診斷

## 開工／範圍

使用者GO續接10/23轉角延遲分析。基準7545239；Windows來源仍1.0.16／1.0.16.0，不進正式版、不改Store產物。保留三份狀態文件原6／8／4行差異與三份YouTube未追蹤文件。只處理Windows。

## 進行中發現

- collector與最後cubic端點均包含最新接收點；沒有已證明的固定一點等待，磁鐵亦已排除自由筆。
- 主畫布CanvasControl.Invalidate依XAML更新節奏。官方Win2D建議高頻低延遲用CanvasSwapChain／CanvasSwapChainPanel，手動負責尺寸、DPI、device lost及生命週期。
- 方案：共用同一套場景／筆跡renderer，換單一繪圖host，活動筆跡事件直接提交；其他UI更新仍合併排程，閒置不跑繪圖迴圈。保留環境變數切回CanvasControl比較，不能把CPU提交數字當螢幕可見延遲。
- 不使用預測或移動筆尖來掩蓋延遲；文件點列與平滑幾何語義不變。優先解決呈現排程，轉角形狀失真與時間延遲分開驗收。

## 命令／目前結果

已執行git status、Get-Content及rg靜態追查、官方文件查詢。一次rg literal wildcard失敗（error123），改目錄-g。尚未修改程式／編譯／測試／啟動App。後續結果即時追加。

## 官方參考

- https://learn.microsoft.com/en-us/windows/apps/develop/win2d/using-win2d-without-built-in-controls
- https://microsoft.github.io/Win2D/WinUI3/html/M_Microsoft_Graphics_Canvas_CanvasSwapChain_Present_1.htm

## 未驗收

實際游標到筆跡、轉角／透明筆、縮放／DPI、device lost、螢幕畫布GPU回讀仍待實機。50ms為暫定方向，沒有新量測成績。

## 中途實作／失敗記錄

新增ImmediateCanvas共用ICanvasResourceCreatorWithDpi與renderer，主畫布以一個swap chain手動Draw／Present(0)；活動筆直接提交，普通更新低優先合併，240次／秒提交上限與單次timer保留最後點，閒置停止。尺寸／DPI變更ResizeBuffers，卸載解除XamlRoot事件／timer與GPU物件；graphics COM錯誤切CanvasControl，原繪圖邏輯共用。HEIBAN_RENDER_PATH=xaml可人工比較。這一輪沒有獨立輸入執行緒、預測或更換文件點列／平滑契約。swap chain雙緩衝額外顯存不能宣稱減少記憶體。

新增schema3 opt-in診斷：PointerBatchToDraw、PointerBatchToPresent、SwapChainPresent；端點與游標距離只保留max／次數，尺規投影另計，sample timestamp僅與同時基timestamp比較。仍無OS輸入佇列到螢幕發光量測；沒有保存座標。

初次整合Python在windows cwd誤加windows前綴，退出1；其後build看到尚未整合的enum，25.63秒2error／0warning。改正路徑完成接線後build 33.78秒0warning0error。保留兩份log，不將失敗當作完成。

檢視新的直接提交頻率後，solid wet cache改16段小批次以減少offscreen drawing-session flush；未入cache的尾巴仍直接畫到最新點，不等批次才顯示。HEIBAN_WET_BATCH=1..64用於人工比較，dash維持64段phase。新增Compare-XamlRendering.cmd，與一般Capture入口維持相同batch16，避免兩變因混比；尚未執行。

## 最終編譯與檔案範圍

本機SDK命令：`windows/.build/tools/dotnet/dotnet.exe build HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 -p:WindowsPackageType=None --artifacts-path .build/immediate-ink-20261024-r1 --nologo -v:minimal`。最終build-final.log：23.79秒，0warning／0error。未執行App／實作測試／性能採樣。

程式：Views/ImmediateCanvas.cs；MainWindow.xaml／Input.cs／Rendering.cs；Engine/WindowsInkCoordinator.cs及Direct2DCanvasRenderer.WetInk.cs；Core/Diagnostics/InputLatencyTrace.cs、InputPresentationTrace.cs。封裝：Collect-InputLatency.ps1／Compare-XamlRendering.cmd／Package-PortableTrial.ps1。文件：本日誌、平台五份索引及INPUT_LATENCY_CAPTURE。新增host只改主畫布；screen只共用wet batching，仍native readback／GDI路徑，不能說兩畫布均改swap-chain。

交付前git diff --check通過（只有既有LF／CRLF提示）；私人庫visibility已核PRIVATE。36份Store檔有開工SHA基準，待封裝後比對。來源維持1.0.16，不進版；還沒有runtime驗收與50ms結果。

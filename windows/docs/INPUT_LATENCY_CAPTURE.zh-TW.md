# 真實畫筆操作的本機耗時採樣

一般使用仍直接開啟 HeiBan.exe。只有想提供卡頓資料時才啟用採樣：

1. 正常儲存、關閉這份試用版，避免同一作品庫同時開兩份程式。
2. 在試用資料夾雙擊 **Capture-InputLatency.cmd**。這會開啟可操作的 HeiBan；照常畫線、連續起筆、切換工具，約半分鐘至一分鐘即可。請優先重現實際卡頓，不需刻意畫複雜作品。
3. 正常關閉 HeiBan。資料夾會留下 **input-latency-呈現路徑-batch數-日期時間.json**，可提供給開發者分析；若強制結束可能沒有報告。

報告只含各操作的次數、CPU 耗時分位數、執行緒配置量、GC 次數、介面心跳間隔及程序記憶體量。沒有筆跡座標、文字、作品名稱、檔案路徑、畫面或帳號資訊；不會自動上傳。採樣使用固定大小的記憶體環，不逐次寫硬碟；未啟用時不建立採樣環與心跳計時器。

## 判讀界線

- `PointerMove`、`InkCommit`、`ToolSwitch`、`BrushPanel` 是對應處理函式在 CPU 上的時間；`CanvasDraw` 與 `SceneRender` 包含送出繪圖命令的成本。
- `UiHeartbeat` 是要求約16ms的介面計時器實際間隔，會受系統排程、切換視窗等影響，不能當作螢幕幀率。
- 各階段有巢狀呼叫，時間與配置量不能直接相加。分位數取最近最多2048次，最大值與計數累積整次工作階段。
- GC 次數屬於整個程序；增加不代表一定造成卡頓。工作集也不是顯示記憶體使用量。
- 這份報告不是 GPU 執行時間、筆尖到畫面的端到端延遲，也不等於硬體驗收通過；若資料指向 GPU／合成排程，仍需對應工具進一步採樣。

## 板擦與轉角補充採樣

新版報告schema2增加EraserMove／EraserApply／EraserCommit、WetInkRender與SceneRebuild，以及程序累計GC pause與總配置量。EraserApply在背景工作執行緒，不能當作UI被阻塞的時間。請分別操作連續畫線、矩形轉角、板擦物件模式及局部模式，正常退出後再提供數值檔。GC pause屬整段程序，不等於單一操作的因果證據。

板擦拖曳時，圖示先跟隨滑鼠，計算分批在背景進行；放開會等待最後批次完成後提交一筆復原操作。Esc或捕捉中斷取消，原稿保留。這些調整保留獨立筆畫與既有作品格式，沒有永久合併同樣式筆畫。

## 2026-10-24：主畫布呈現比較（schema3）

新版直接開HeiBan.exe使用swap-chain呈現，採樣仍需自行雙擊Capture-InputLatency.cmd。想比較原XAML呈現，先正常關閉，再雙擊Compare-XamlRendering.cmd；兩者使用相同batch16。請分別在相近作品與縮放下畫方形／三角形轉角及曲線，並分別正常退出。這些是人工採樣入口，沒有自動測試／上傳，平常不需要啟用。

- PointerBatchToDraw：最新一批活動自由筆事件抵達到開始繪製；多批次合併時只記最新批，不代表所有歷史事件的等待分布。
- PointerBatchToPresent：同批事件到swap-chain Present返回；原XAML路徑沒有此數值，不能把缺項當0ms。
- SwapChainPresent：Present呼叫本身CPU耗時／背壓，不是GPU執行或螢幕發光時間。
- presentation.renderPath與fallbackHresult：確認使用的路徑及是否遇graphics錯誤回退。solidWetBatchSize記錄實際cache批量。
- maxEndpointGapDips／maxTimestampGapMs比較目前事件與collector最後樣本，只有次數／最大差距、不保存座標；尺規投影另計。這不是從螢幕影像測到的端點，不能宣稱涵蓋OS輸入佇列或真正端到端延遲。

需單獨比較cache策略時，可自行執行Collect-InputLatency.ps1 -Executable .\HeiBan.exe -RenderPath swap-chain -WetBatch 1；不要同時切換兩個變因。環境只對該次啟動生效，不改作品／設定。助手本批沒有執行以上App或採樣。

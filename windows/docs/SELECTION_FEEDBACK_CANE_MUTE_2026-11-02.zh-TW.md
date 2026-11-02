# Windows點選範圍、截圖提示與藤條靜音 — 2026-11-02

使用者要求：點物件範圍即可選取命中最上層一個，Ctrl逐次多選；截圖成功後中央顯示「畫布已截圖」；藤條可靜音。僅Windows，維持1.1.0同版開發試用，保留已送審包、作品與原有三份未提交清理紀錄／三份YouTube文件。開工保存git status與差異至.build/selection-feedback-20261102，讀平台狀態／架構／問題。沿既有graphify導航（10/12快照已舊）定位，實際修改以當前source為準。

## 進行中

待查明：精確幾何命中與選取框handles的優先順序、Ctrl toggle和拖曳交易邊界；中央提示使用非互動短暫UI；靜音偏好跨兩畫布保存且不停止藤條動畫。測試與封裝結果逐步追加，不預先宣稱。

## 已確認與實作

保留EditorSession.Hit精確幾何給原功能，另增HitSelection／PointSelection：旋轉local bounds與畫面等效容差、依實際繪製順序反向（含同Z順序）、當頁／隱藏篩選，線／箭頭保留箭頭頭部及延伸線精確備援。一般與螢幕左點／雙擊／右鍵採同源點選規則；Ctrl繞過既選物件handle並toggle，普通點已選群組延至放開折回單選，拖過3DIP仍保留群組移動。擦除及方向框選不套用新的外框命中。

中央非攔截輸入提示只在Clipboard.SetContent＋Flush成功後顯示，2秒自動收起；取消／失敗不觸發。CaneMuted在toolbar偏好保存，隱藏owner及screen同步，更多與右下藤條右鍵共用選項；音訊主播放及fallback均守衛，靜音立刻Stop，動畫不改。十語701keys無缺漏；每語26節76段指南生成成功。

第一輪Core2408通過。首輪診斷build缺T的using static，導致C#錯誤及XAML大量後續型別解析錯誤；第二次輔助修正因Python read_text未指定UTF-8遇cp950解碼失敗，build重複相同錯誤。以apply_patch補using後重建第三輪，不把後續XAML錯誤數當96個獨立故障。輔助讀檔輸出亦遇過cp950無法編碼，後續明確PYTHONIOENCODING=utf-8與檔案encoding；未變動使用者資料。最初自動編輯把pending click分支插到Move而非Release，在編譯前審diff定位並移回Release，保留原手勢else鏈。

## 實際驗證（封裝前）

- `windows/.build/tools/dotnet/dotnet.exe run --project windows/HeiBan.Windows.Core.Tests -c Release --artifacts-path windows/.build/selection-feedback-20261102/core-build`：2408 PASS，含25個新增斷言，`corechecks.log`。
- `python windows/scripts/Build-LocalizationCatalogs.py`與`Build-UserGuides.py`：十語701 source keys／missing0；26節76段指南／10個練習作品同步生成。沒有重跑上一批Optimization68，不能套為本批結果。
- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/selection-feedback-20261102/qa-build`：第三輪0警告0錯誤，`build-r3.log`；前兩輪失敗均保留。
- 用ProcessStartInfo以自有QA exe、尚不存在的`HEIBAN_WINDOWS_DATA_DIRECTORY=.../qa-data-r1`及`--selection-feedback-validation-output=.../qa-results-r1`啟動。原生7斷言：成功截圖才顯示中央提示／2.2秒後收起、靜音與取消靜音寫盤讀回、兩host同步、靜音Play不產生音訊請求。另經螢幕生產OnPointer adapter合成Ctrl事件驗證6斷言：空心topmost、Ctrl增／減、普通點選回單選、不改文件generation／Undo、群組拖曳（兩物件皆位移20）。`result.json`全通過。
- Sky實際一般畫布滑鼠三次空心內部點選：預先多選outer/top→top單選；再點outer未重疊內部→outer；再點重疊內部→top。每次只一個，generation0／undo false。之後實際「更多→藤條靜音」切換，live.json與toolbar.json為true、音訊guard與screen偏好同步true。
- Sky實際「管理→畫布範圍截圖」：畫面中央可見綠色圓角提示與✓「畫布已截圖」，不攔截畫布輸入；Alt+F4正常關閉PID18360，獨立程序已退出。工具列重建後舊UI索引失效的一次點擊未執行，重新觀察使用新索引後正常操作。
- 未執行：主畫布真實硬體Ctrl按鍵連點（工具無按住修飾鍵click介面，Ctrl規則由Core與螢幕生產adapter測）；使用者實聽音效、全DPI、端到端延遲／FPS、ARM64執行、Store封裝／送審。本輪正常試用另建，不能把QA當正常交付。

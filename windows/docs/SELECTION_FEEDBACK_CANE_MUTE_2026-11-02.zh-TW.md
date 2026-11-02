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

## 正常免安裝交付

程式來源`6ffc073378bf96c4039a2e2808c8df57bf3790f0`，產品1.1.0／FileVersion1.1.0.0，ProductVersion帶來源SHA。沒有新Store包、上傳／送審、進版或清理舊檔。

- 實際命令：為當次PowerShell PATH加入`.build/tools/dotnet`，執行`windows/HeiBan.Windows/Packaging/Package-PortableTrial.ps1 -Runtime win-x64 -Label selection-feedback-2026-11-02-r1`，正常Release App＋Updater publish成功。完整publish.log在`.build/portable-trial-874ee2df5587421caa6e4c0b239e9bff`。
- EXE：`windows/dist/trials/HeiBan-Windows-Portable-1.1.0-selection-feedback-2026-11-02-r1-win-x64/HeiBan.exe`。
- ZIP同名加`.zip`，133328659bytes，SHA256`2ff63d9d23df560597ac39a1d2a0d795221327cac416be003fa6bcec28602bba`，sidecar一致。
- 執行`python windows/.build/selection-feedback-20261102/Verify-Portable.py`：654 payload在本機與ZIP內的SHA核同、237來源raw-byte SHA核同、ZIP CRC通過，64SVG與十語HTML／練習／manifest核同；六項diagnostic方法／getter不存在於正常HeiBan.dll。
- 正常試用為獨立空白Data，未啟動，由使用者接續實測；不自動搬移或覆寫任何作品。UI驗證用獨立QA組態，上述結果不混同此正常包的實機驗收。dist不隨Git同步。
- 已送審`HeiBan-Store-1.1.0.0-x64-arm64.msixbundle` SHA仍`a7799085a7ccb5f7f0a23b37d0b12425a9def99ff366d8fa13686ee01eaade66`。

## 使用者驗收方式

1. 畫兩個有重疊的空心圖形。用選取點內部空白：應選中該範圍最上層一個；Ctrl點其他物件應增加選取，Ctrl再點已選者應取消它，普通點應回單選。已多選群組仍可拖著一起移動。可對細線／筆畫間隙與旋轉物件再試。
2. 按「管理→畫布範圍截圖」：有邊界直接成功、無邊界先框範圍；複製完成後中央顯示✓「畫布已截圖」約2秒，繼續操作不被擋住。取消不應新增成功提示。
3. 「更多→藤條靜音」勾選，或右下藤條右鍵選單切換。揮動仍有動畫、應無音效；換螢幕畫布與正常退出重開應保留。取消勾選後恢復音效（實際聲音由使用者驗收）。

公開程式／記錄與私人壓縮交接分開push；開工已有未提交清理及YouTube文件保持原內容，不混入本批。

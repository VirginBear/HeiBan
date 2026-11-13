# Windows 1.1.4 開發批次 — 2026-11-13

使用者暫訂 1.1.4，要求物件水平／垂直翻轉、右鍵新建圖釘、雷射覆蓋視窗、修正選取色票、恢復較早的藤條揮聲、改右鍵副本文字，以及固定工具輪盤。已讀 Windows 維護紀錄及封裝規則。原有三份未提交清理紀錄與三份草稿已記錄。

## 實作與檢查進度

- Core 以物件中心儲存兩個可選反射旗標，與既有旋轉共同套用於 Win2D、SVG、精準命中、磁鐵與擦除。圖片原資料及裁切座標直接保留。一般及螢幕右鍵共用一筆復原交易，圖釘沿用既有視角記錄。
- 雷射移至紙張裁切層外。快捷色票與管理色票分離色塊與選取外圈，圈線寬度不參與按鈕版面。
- 藤條重用既有 0.26 秒揮聲。接觸動畫、敲擊聲與第三擊裂紋排在按下後 120 ms。輪盤切換只記最近使用工具及形狀，固定格位透過設定或套用預設修改。
- 十語目錄重新產生（720 個鍵，缺漏 0），十語操作指南重新產生（26 節、各 83 段）。
- 首輪 Core、Optimization、WinUI 診斷編譯共遇到 CS0127：批次替換同時碰到既有 DeleteSelected。已還原該方法的原始行為，並調整測試區域變數名稱避免衝突。重新執行檢查。

- 第二輪 Core 6866、Optimization 68 通過，x64 診斷編譯 0 警告／0 錯誤。首輪原生離屏測試已讀到兩軸反射與紙外紅色光點，重用 RenderTarget 時未先清空上次合成，導致放開後檢查失敗。修正診斷每幀清空並重新測試。
- 檢閱文件快照比較時發現它略過所有標有 JsonIgnore 的屬性，含可選欄位的 WhenWritingDefault。已使它只略過 Always，並補單獨翻轉未旋轉圖片的一步復原測試。

## 回歸與原生驗證

- 使用 windows/.build/tools/dotnet/dotnet.exe 執行 `dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release --artifacts-path <scratch>/core`，6869 項通過，包括兩軸反射、鎖定、快照／復原、SVG 與裁切原圖。
- `dotnet run --project windows/HeiBan.Windows.OptimizationChecks -c Release --artifacts-path <scratch>/opt -- <scratch>/opt-output-r2`，68 項通過。固定格位、明確拖曳排序、兩種畫布配置及預設值。
- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:Platform=x64 -p:HeiBanValidationBuild=true --artifacts-path <scratch>/qa-build`，0 警告／0 錯誤。獨立測試資料根執行 `HeiBan.exe --cursor-cane-validation-output=<scratch>/native-output-r2`，656 項通過（主517、翻轉／雷射7、正形18、快色45、螢幕69）。Win2D 渲染讀回像素、選中色票中心／尺度、四個音效的呼叫與靜音。
- 音訊檔取樣讀取確認原揮聲有訊號，120 ms 為程式內排程間隔。未實際聽音或量測裝置輸出延遲。右鍵點選和圖釘定位待手動試用。未執行 ARM64、Mac／Web 交叉呈現、WACK、Store 建置／提交。

## 免安裝交付

執行 `Package-PortableTrial.ps1 -Runtime win-x64 -Label interaction-2026-11-13-r1`。Windows 產品版本 1.1.4／檔案 1.1.4.0，來源 `643f9cc2e438fe5879b5af81f3b1ccd75d785215`。正式 Store manifest 與套件 1.1.3.0 保留。

- ZIP `windows/dist/trials/HeiBan-Windows-Portable-1.1.4-interaction-2026-11-13-r1-win-x64.zip`，100,508,505 bytes，SHA256 `d3f6a9aee75c68918992fa83174655752bdce2355bedd926892cdcf7378b5e3f`。
- 本機 `python .build/interaction-114-20261113/verify.py`（於 repo 根由 windows 子路徑呼叫）確認 419 份來源、724 份內容、ZIP CRC、x64 PE、獨立空白 Data、十語指南、四份音效、原揮聲來源 SHA、QA 入口排除。首次核對以系統 cp950 讀來源 JSON 出錯，改明確 UTF-8 後全部通過。三份 1.1.3.0 Store 成品與上次 1.1.2 ZIP 雜湊一致。
- 正式 Portable 執行檔未啟動。原生驗證由相同產品來源的 x64 診斷建置執行。使用者原有作品、試用包及未提交修改保留。未建立商店提交或 GitHub Release。

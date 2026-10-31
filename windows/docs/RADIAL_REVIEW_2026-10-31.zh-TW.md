# Windows 輪盤、擦除與程式整理報告 — 2026-10-31

## 範圍與結果

維持產品 **1.0.18／1.0.18.0**，本批是待實機驗收的開發試用，不是新正式版或 Store 送審。只改 Windows；使用者作品、已交付產物、macOS 及既有未知文件欄位保留。

- 共用右鍵輪盤：Core 持有／交換／幾何、Win2D 扇形與原有向量圖示、自訂 drop 視窗均共用；兩畫布只保留輸入座標／命令 adapter。
- 一般及螢幕各保存八格；螢幕第八格固定「操作」。0.22 秒長按或快速向外撥選，亮框與 20% 圖示放大，右鍵放開切換，中心／Esc 取消。交換繪圖工具時原格放回前一工具；設定／Undo 等命令不交換。
- 更多→右鍵工具輪盤，將真實上方工具列圖示拖進扇形；重複工具以交換換位。也有可鍵盤操作的工具選單和預設。一般畫布圖形工具群可用最近的形狀，亦可在設定直接選直線、箭頭等。
- 螢幕右鍵雙擊由作畫轉操作穿透，Ctrl+Alt+D恢復。單次短右鍵等待系統雙擊時限後才開原物件選單；雷射／藤條不因此選取。剛完成或取消輪盤後的下一個原生 double 訊息會當作新輪盤起手，避免快速連用誤觸模式切換。
- 設定在獨立 `Settings/radial.json`，兩配置與未來 JSON 欄位保留；空閒 350ms 後原子寫入、正常退出等待完成，不在每次指標更新存設定。讀不懂的設定先保留 unreadable 副本再寫新設定。

## 找到並調整的成本

|來源|確認的原因|本批調整|驗證邊界|
|---|---|---|---|
|螢幕橡皮擦每批預覽|原事件直接強制 fullDamage 與 committedDirty，Render 重建／回讀整張桌面。3840×2160 BGRA 一次約33.18MB|聯集消失舊物件與新片段的保守界限，加入裝飾 padding；以重用 GPU 暫存面重畫相交層，精確複製到 committed，利用既有局部 readback|damage 與 survivor 資料測過；GPU 像素與手感待實機。大筆跡／延伸線仍可能需要大範圍或全畫面|
|擦除首次發布|初次 publisher 會複製所有存活 worker 物件|以原本凍結 UI 預覽 seed 對照；未變物件引用不換，僅新片段 clone，worker 可變物件不交給 renderer|快照隔離／舊預覽不變／最後物件消失／無界線回退已測|
|工具游標首次 cache miss|每種工具／尺寸重新 new 並 dispose 軟體 CanvasDevice|使用 Win2D 共用 software device，仍保留每工具原生 cursor 快取及失敗回退|兩架構編譯通過；未量測冷啟動毫秒|
|損傷邊界重複程式與檔案混放|selection／preview helper 混在 Performance 檔，與 stroke／render 重複合併 damage|正式函式移入 damage partial，四處改共用 clamp／union；不再註記成僅測試可用|行為邊界保留；未刪驗證基礎|
|工具狀態與輪盤不同步|鍵盤／右鍵選取等直接改 tool，不都經 toolbar activation|兩 host 的持有狀態集中追蹤，非高頻 pointer hot path；工具列 drag handler 用 weak table 只掛一次|工具交換、alias、重複格、預設及跨重開設定測過|

完整 Windows 來源清單掃描涵蓋 **144 個 C# 檔案**，詳見 `WINDOWS_SOURCE_AUDIT_2026-10-31.json`。先用既有 graphify 關聯圖定位，再核對現行來源；舊圖未重建，不將舊節點當作目前呼叫的證明。精確20行重複掃描為0組，只代表字面片段，不能推論沒有語意重複。此輪詳讀輸入→worker→preview→scene→readback，以及工具列／保存／資源釋放邊界，未宣稱逐行形式驗證所有程式。

## 體積與後續優先序

新增輪盤需要必要程式與翻譯；本批不以原始碼行數下降當作性能改善，發行 ZIP 會列實際 bytes。上一批已另做 framework-dependent Store 候選；其 runtime 可能另下載，不能直接把 bundle 本體差額當初次安裝總節省。未改目前正式商店依賴模式。

1. 實機先核對局部擦除是否有殘影、下層消失或4K停頓；與相同文件舊試用做對照。
2. 若仍慢，量測 worker queue、首筆隔離 clone、每批物件掃描與超長單筆造成的大 damage；再決定增量索引／tile。保留所有輸入點和既有一手勢一 Undo 契約。
3. 內建診斷測試可規劃獨立開發組態。這批先分開正式 damage helpers，保留現有測試入口；不直接刪掉被測試及工具引用的程式。
4. 其餘 WinUI panel／text／native cursor 已有快取或釋放機制，沒有只憑名稱或檔案大就刪除。未採動態相依 trim／AOT 的高風險改動。

## 已執行驗證與未驗收

- `dotnet run --project windows/HeiBan.Windows.OptimizationChecks/... -c Release --artifacts-path windows/.build/radial-20261031/check-build -- windows/.build/radial-20261031/checks-r2`：**62項通過**。含原有候選索引／Undo／未知欄位／保存衝突與新增輪盤／序列化／damage檢查。
- Release `win-x64 / Platform=x64` 與 `win-arm64 / Platform=ARM64`：**皆零警告、零錯誤**。使用本機 `.build/tools/dotnet/dotnet.exe`，獨立 artifacts 目錄。x64 28.51秒，ARM64 32.58秒，屬該次建置耗時而非程式性能。
- `python windows/scripts/Build-LocalizationCatalogs.py`：十語每語653來源，missing=0。
- `python windows/scripts/Build-UserGuides.py`：十語、每語26節／67段；隨包 HTML 和全工具無邊界練習資料同步。既有使用者練習作品不覆寫。
- App／實機／GPU逐像素對照／螢幕錄影端到端延遲／實際拖放／Store/WACK：**未執行**，不可把 Core 次數、傳輸面積或編譯當作手感已驗收。

失敗與修正、實際封裝命令／來源／雜湊會接續記在 `RADIAL_AND_ERASER_2026-10-31.zh-TW.md`；實際測法與成功標準見 `RADIAL_TEST_GUIDE_2026-10-31.zh-TW.md`。

## 最終交付

來源 `e443b4919ee9468e15d60037f5ab0fef7a2e95a3`，試用標籤 `radial-eraser-2026-10-31-r1`。ZIP 133,364,604 bytes，較上一包增加37,513 bytes。592 payload／220來源SHA及CRC核同；細項見 `RADIAL_ARTIFACT_2026-10-31.json`。最終來源ARM64再編通過、免安裝x64 publish成功；GUI仍待實測。

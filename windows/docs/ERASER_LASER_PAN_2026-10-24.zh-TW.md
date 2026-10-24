# 2026-10-24 — 拖曳手形、擦除呈現與連續雷射

## 開工

使用者確認前批一般畫布「順暢很多」，屬主觀正面回饋，未提供毫秒量測。新要求：中鍵拖曳手形、確認並改善板擦／橡皮擦延遲、參考GitHub最新Mac雷射。基準c3d5b30；git fetch後origin/main一致，Mac雷射來源26ea834cfe65d1a479b7cb549980461645ef6bf0（僅讀取參考）。只改Windows，維持1.0.16／1.0.16.0，不提高正式版本／提交Store。

保留三份平台文件原6／8／4行差異與三份YouTube新文件。開工已讀平台索引／架構／狀態／決策／問題；36份Store檔有SHA基準。

## 已確認原因與界線

- 畫筆改善後，擦除仍16ms timer啟動worker、UI收到preview後Invalidate低優先重畫，沒有沿用直接提交。初始雙snapshot與每批整份snapshot使未編碼筆跡點列及geometry key重建；DocumentCodec.Clone在此為記憶體snapshot，不是JSON往返。
- 主畫布擦除每次preview仍完整scene重畫，screen仍GPU回讀／GDI；本批不能把所有延遲歸給單一等待。
- Mac新雷射以連續二次曲線、按時間漸細輪廓、柔光／白芯／徑向光點避免分桶端帽珠狀。Windows現為逐樣本DrawLine，將以共用renderer供兩畫布。

## 進度

已執行git status／fetch／log、Get-Content及rg。初次literal wildcard rg與兩個猜測檔名讀取失敗，已依rg實際定位。尚未編譯／啟動App／測試；進行中追加結果。

## 進行中：第一批實作

- 中鍵／空白鍵拖曳使用自製 DPI 手形游標，放開／取消復原；鎖定視角仍不移動。加入獨立 pan 的 move/release 分支，避免雷射或套索模式中鍵拖曳誤執行工具。
- 圓形／板擦從 pointer 直接啟動單一背景工作，逐批接續處理；取消與文件 epoch/generation 檢查、完成一次 undo 交易均保留。一般畫布擦除結果與接觸提示走 PresentNow。
- 新增 worker→UI 預覽發布器：每個存活物件只做第一次隔離複製，替換片段才建立新複本，後續預覽保留 geometry key；絕不將 worker 的可變物件送 UI。移除片段同步移除暫存映射。
- 板擦拖曳時以同一張既有圖在畫布立即呈現，與 XAML／實體擦拭輪廓共用仿射變換；閒置仍保留 XAML 呈現與輸入命中。
- 共用 Windows 雷射改成二次中點平滑、連續漸細輪廓、柔光、白芯與徑向光點。參考 Mac 的模式壽命；螢幕畫布損傷區擴及柔光外緣；新增選用 LaserRender CPU 診斷，不記錄筆跡。
- 數次讀取以錯誤字面 wildcard 或不存在路徑失敗，後改實際位置讀取；未據此更動／刪除檔案。首個修補腳本因 cwd=windows 卻含 windows 前綴而未執行，隨後在專案根目錄補做。
- 首輪 build 27.80 秒失敗：Laser partial 少 Models using（ViewportTransform）；引發本機組件未生成及後續 93 個 XAML 連鎖錯誤，合計 94 error／1 warning。修正原始 C# 缺漏後再編譯，沒有修改無關 XAML。
- 待編譯、封裝、使用者實機驗收。尚未宣稱擦除延遲量測結果或 50ms 達標。

- 修正後 x64 build 25.57秒、0 warning／0 error。續補十語手冊的平移游標與雷射模式／消退說明；更新離線 HTML 與初始指南資產，不覆寫使用者既有指南作品。

## 最終原始碼與命令紀錄

- 變更集中於ShapeCursor／MainWindow.Input（pan與立即呈現）、CircularEraserGesture／BoardEraserWork／EraserPreviewPublisher／主與screen host整合、MainWindow.BoardEraser與ToolArt partial、LaserPointerEngine與共用renderer Laser partial、InputLatencyTrace新增LaserRender。十語指南來源／HTML／初始作品資產同步；架構、決策、文件契約及平台三紀錄更新。
- `python windows/scripts/Build-UserGuides.py`：10語、每語25章64段；僅讀寫內建資產，不讀／覆寫使用者作品。
- `windows/.build/tools/dotnet/dotnet.exe build HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 -p:WindowsPackageType=None --artifacts-path .build/eraser-laser-20261024-r1 --nologo -v:minimal`（cwd=windows）：修正後25.57秒成功；最後含GPU板擦fallback及手冊資產20.79秒成功，均0warning0error。
- 編譯失敗與錯誤路徑修補已記上節；三份build log保留在ignored scratch。未刪除使用者資料、已公布歷史／Store包，未修改Mac程式。
- App、實作測試、效能採樣、端到端延遲、ARM64本批編譯、Store封裝／WACK／送審皆未執行。下一步用獨立x64試用label交付。

## 待使用者驗收

1. 中鍵按下即顯示手形，拖曳不誤啟動當前雷射／套索；放開／失焦恢復，視角鎖定不平移；4K／DPI游標尺寸。
2. 大量筆跡下圓形與斜板擦跟手，局部／物件模式範圍正確；跨長路徑、釋放最後一點、取消、Undo／Redo、保存重開。
3. 主／螢幕雷射三模式、柔光與白芯、變色／粗細、不同縮放／DPI；主畫布離開重進不拉橋線，screen柔光消退無殘影。
4. 預覽仍需全scene重畫，screen還有16ms render／GPU回讀／GDI，首次手勢仍有雙隔離快照；本批減少等待與配置，不宣稱解決所有負載。

## 封裝與交接完成

- 來源 `4fdd1c1b7f758b9be169c884d8d31faad80a9b30`，`Package-PortableTrial.ps1 -Runtime win-x64 -Label eraser-laser-2026-10-24-r1` 成功；紀錄 `.build/portable-trial-38912b502868483cafd4589eaaa43734`，App／Updater publish完成。
- ZIP `windows/dist/trials/HeiBan-Windows-Portable-1.0.16-eraser-laser-2026-10-24-r1-win-x64.zip`，132894162bytes，SHA256 `090d222413d60e2abd68c6b86adffe5017c841d79ace60adf893c0e7236f0eb1`。
- ignored `inspect_delivery.py` 核對586 payload、190來源SHA、588個archive entries與完整ZIP CRC、兩EXE x64；archive沒有使用者Data。此為產物核同，不是功能測試。
- Get-Process與複製前後再次確認無HeiBan程序；以extended-length路徑完整枚舉／複製最新immediate-ink試用Data，52檔24746295bytes，原資料前後與新資料逐SHA相同。只有統計進公開紀錄，不含作品名稱／內容；原試用不刪除。
- 36份Store檔與開工SHA一致。App／實作測試／新性能採樣未執行，手感仍待使用者。原6／8／4行未提交平台差異及三份YouTube新文件保留。
- 公開交付摘要見ERASER_LASER_PAN_ARTIFACT_2026-10-24.json；私人庫另記必要產品交接及壓縮對話。未上傳試用binary到GitHub，不更動Mac來源／正式版號／既有商店包。

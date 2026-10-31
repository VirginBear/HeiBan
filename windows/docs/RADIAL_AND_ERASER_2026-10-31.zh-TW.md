# 右鍵工具輪盤／螢幕擦除／Windows程式整理 — 2026-10-31

使用者要求：按住右鍵拖選、亮框放大、放開換工具且槽位換回原工具；上方圖示可拖入自訂；螢幕輪盤有操作入口，普通／螢幕配置分開保存；螢幕右鍵雙擊由作畫轉操作；改善螢幕橡皮擦嚴重卡頓並大規模程式檢查整理。Windows限定、維持1.0.18，保留正式包與作品。git狀態保留三文件6／8／4行及三份YouTube未追蹤文件。

## 開工／進行中

讀index／目前狀態／架構／問題／平台規則及現有擦除、native輸入流程。輪盤採共用Core狀態／命中與Renderer，兩種配置分開記憶；短右鍵物件選單需保留，長按與雙擊辨識不可衝突。編輯輪盤採非模態視窗，才能拖真正上方工具列圖示；螢幕操作槽固定不可覆寫。擦除先追預覽發布至scene／damage／readback，避免單做背景演算法卻每批全螢幕重畫及回讀。先記錄發現再實作，GUI／實機不預填通過。

## 實作進行紀錄

- 確認螢幕 `CircularEraserGesture.PreviewChanged` 每批設 `_dirty=_fullDamage=_committedDirty=true`，`Render` 重建整張 committed 並回讀全螢幕；局部擦除沒有使用原本已存在的區域呈現能力。
- 改為保守聯集「消失舊物件＋新增片段」的畫面範圍。未變物件以凍結 UI 預覽引用重用；worker 物件不外洩。無邊界延伸線等無法界定幾何回退全畫面。
- 區域補畫採獨立可重用 GPU 暫存面，清空後重畫相交各層，再做精確像素複製與局部 readback。放棄直接在 opacity layer 裡以透明 Copy fill 清除的草案：其透明合成語意有疑慮，未採作交付路徑。暫存面在桌面尺寸／裝置重建、停止、Dispose 釋放。
- 正常工具、鍵盤／右鍵選取轉換集中更新輪盤持有狀態；只更新小型記憶體設定。350ms 空閒才寫入獨立 `Settings/radial.json`，正常關閉等待最終保存。作畫不序列化輪盤設定。
- 長按閾值 0.22 秒；移動超過 10 DIP 可快速撥選；中心 32 DIP 取消。靠邊移盤但沒有主動移動時不會誤選。螢幕保留固定操作格；上一手勢若為輪盤，後續原生 double 訊息不當作雙擊操作，避免快速連用輪盤誤切模式。
- 一般畫布保留短右鍵物件選單；螢幕短右鍵延至系統雙擊判定時間後，避免雙擊先打開選單。雷射／藤條仍不由短右鍵選取物件。Escape／捕捉中斷取消輪盤；不取消已放開、仍在完成中的擦除。
- 自訂使用非模態視窗；既有 toolbar 控制項附加一次 drag source，輪盤 drop 只接受自家型別與已實作工具白名單。固定操作格不接受覆寫；相同工具拖到另一格會交換，不留下重複。
- 編譯第一輪失敗：`CS0136 dpi` 局部名稱遮蔽；其後 94 個 XAML 附帶錯誤為 metadata 編譯失敗連帶結果，非 94 個獨立 UI 缺陷。已改為 `wheelDpi`。第二輪缺少 `HeiBan.Windows.Models` using，補正後第三輪 Windows Release x64 編譯零警告／零錯誤。
- 隔離 Core 檢查 r1：59 項通過，含原有 26 項及新增輪盤／設定／預覽 damage。證據位於 `.build/radial-20261031/checks-r1`。這是資料／幾何驗證；尚未啟動 App、GPU 像素對照或實機手感驗收。
- 游標首次建立改用 Win2D 共用軟體裝置，保留原生 cursor 快取與失敗回退；不再每個新工具／尺寸建立及銷毀一個 D3D 裝置。未宣稱量測到幾毫秒改善。

## 來源固定前核對

- r2資料檢查 **62項通過**；新增連用／取消輪盤不誤當雙擊、幾何群快捷不被曲線覆寫。`checks-r2/results.json`為本批實跑結果，未沿用之前26項的數字。
- `build-final-x64.log`／`build-final-arm64.log`皆0警告0錯誤；後續補上CommandPath共用圖示別名（brush/settings、clearAll/delete、viewLock/lock），正式封裝會再編譯，ARM64另重編核對。
- 指南第一次生成失敗：來源新增radial列放在末尾，但generator嚴格要求META+SECTIONS順序；將九語radial列移至workspace後，第二次與最終生成成功。git diff --check指出九份作者文字有EOF空白行，清理後通過。十語每語653來源missing0，指南26節67段。
- 結構清單＋精確20行重複掃描讀取144個Windows C#來源；引用舊graphify關聯圖導航並核對現行方法，沒有把舊圖當更新後驗收。沒有20行字面重複不等於沒有可整理的邏輯；手動合併四處damage union，並把正式DamageSelectedObjects／DamagePreview從Performance檔移出。
- 未啟動App、不自動關閉使用者程式；本批沒有搬移或覆寫作品。試用包將附空白獨立Data及生成測試文件，供使用者驗收。

- 關閉路徑最後核對：螢幕文字完成也可能改工具，將輪盤最終保存移至FinishScreenText／CancelGesture之後，並再次停止偏好計時器，避免在最後狀態之前就宣稱保存完成。正式封裝採此後續修正來源。

## 最終封裝與靜態核對

- 固定來源 `e443b4919ee9468e15d60037f5ab0fef7a2e95a3`。`Package-PortableTrial.ps1 -Runtime win-x64 -Label radial-eraser-2026-10-31-r1 -PracticeFilesDirectory "D:/Game/HaiBan x64/windows/.build/radial-20261031/checks-r2"` 成功；PATH先指定本機 `.build/tools/dotnet`。
- 最終ARM64來源編譯 `--artifacts-path windows/.build/radial-20261031/build-arm64 -p:Platform=ARM64 -p:WindowsPackageType=None -p:AppxPackageSigningEnabled=false`：0警告0錯誤，42.10秒。免安裝publish亦成功，Main EXE／DLL的ProductVersion為1.0.18+上述來源；Core保留本身1.0.0庫版本且來源SHA相同。
- ZIP `133364604` bytes；SHA256 `65196f7e4d108006f0dcd03effa0a3aa6a8fb7a2f7f3df657ef9ba331eb726d8`。592 payload SHA、220 source SHA、ZIP每檔bytes與CRC核同；十語HTML均有radial節，隨包QuickStart仍infinite；100／5000生成文件數目正確，Data未含使用者檔案。
- ZIP相較上一試用增加37,513 bytes（約36.6KiB），本批重點是執行工作量／共用程式，沒有宣稱下載體積縮小。
- 核對腳本第一次因Path.with_suffix把版本中的小數點當副檔名，找錯ZIP路徑而停止；改為完整資料夾名加「.zip」，第二次全部核對通過。此失敗未改動應用程式或產物。
- 證據：`.build/radial-20261031/package.log`、`.build/portable-trial-15b3ebb0d00a42ed88af9385a783e26f/publish.log`、`build-frozen-arm64.log`、`verify-package.py`，正式摘要 `RADIAL_ARTIFACT_2026-10-31.json`。
- App啟動、實機拖拉、GPU逐像素、端到端延遲、WACK／Store送審：未執行。資料不搬移，沒有覆蓋舊試用、已發布套件或使用者作品。新試用標籤與來源供跨電腦重建；產物未上傳GitHub。

# Windows 畫布操作與一致外觀 — 2026-10-15

## 開工
- 基準：main / 1af9075；git status --short 無輸出，工作區乾淨。
- 範圍：Windows 八項實測回饋；維持 1.0.14 開發候選，不提交 Store / Release。
- 本批：單排圖文工具列、起點及形狀磁鐵、常用自訂、生成板擦與矩形擦除、匯入圖片化告知、圖釘排序及縮圖、固定一致淺色介面。
- 先查閱開發入口、平台規則、狀態、架構、決策與問題紀錄。保留既有試用資料與正式產物。
- 初始調查：圖文面板水平 RunLength 上限 540 DIP 導致換排；目前磁鐵矩形僅四角且圓形未含中心。需追查起點在後續事件是否被原始座標覆寫。
- 使用 imagegen 內建工具產生透明板擦；圖檔為外觀，擦除幾何另依矩形與座標轉換實作。

## 驗證狀態
尚未執行本批建置／測試／封裝。
## 進行中排解
- 第一次 x64 Release build 退出 1（25.32 秒，1 warning / 94 errors）。根因為兩處誤用 Windows.UI.Text.FontWeights，WinUI 使用 Microsoft.UI.Text.FontWeights；後續 Ui.Text/Ui.ToolTip 是無 assembly 引發的連鎖 XAML 診斷。已改命名空間，待重建。
- 查找時 PowerShell 將含萬用字元檔名原樣送給 rg，以及猜測 ScreenAnnotationWindow 位於根目錄，造成 os123／找不到檔案；改 rg 目錄 -g 與實際 ScreenAnnotation 子目錄。
- 確認圓／菱形／五角形／星形原本以外框角作起點，不在圖形參考點上；兩宿主改共同中心起點建構，既有文件形狀不變。起點仍在 pointer-down 吸附，新增 hover 綠圈；矩形九點、多邊形頂點／邊中點、圓與圓弧中心／四向點均由同一索引提供。
- 第二次 x64 Release build 退出 0（23.37 秒，0 warning / 0 errors）。隔離示範資料啟動成功；實際視窗觀察繪圖單排、窄視窗分組、板擦顯示、自訂卡片正常。截圖仍發現 CheckBox 透過 SDK 靜態別名帶入系統紫色，查本機官方 generic.xaml 後直接補控制項語意 brush，不依賴只改 AccentFillColorDefaultBrush。
- 尚未以 UI 執行擦除使用者資料；本批不新增或執行自動化測試，既有 2334 項數字屬前批證據，不沿用作本批通過。
## 實作與素材
- 主要來源：Core MagnetSnapIndex／ShapeConstruction／RectangularEraser／EditorSession／ToolbarPreferences；主窗DrawingWorkflow／BoardEraser／Rendering／Input／Saving／DocumentImport；screen chrome／docking／magnet；共用ToolbarUi／ToolbarFlowPanel／PinIcon／App.xaml；十語catalog／手冊及產生器。具體清單以本批Git diff為準。
- 矩形九點、三角六點、多邊形頂點及邊中點、線段端點及中點、圓／圓弧中心與四向點（弧另加起訖點）。起點不再只吸附外框角；新建中心式圖形先點中心。既有作品不遷移。
- 板擦僅新增一般畫布；screen既有橡皮擦仍為圓形。物件與局部筆跡模式，圖片／文字保護及鎖定語意沿用原規則。局部不是編輯點陣圖；沒有宣稱任意形狀或圖片的像素擦除。
- 素材：內建 imagegen、透明背景，輸出複製至 HeiBan.Windows/Assets/BoardEraser.png（2,532,061 bytes），不是臨時路徑依賴。無額外runtime／NuGet依賴。
- 最終生成提示：Use case: product-mockup. Asset type: transparent PNG for a draggable rectangular blackboard eraser in the HeiBan Windows whiteboard app. A single beautifully crafted physical classroom chalkboard eraser, horizontal rounded rectangular natural light walnut wood handle, dark forest green felt pad visible along the lower edge. Clean restrained realistic product illustration, straight-on top view with very subtle front edge depth, long edges perfectly horizontal, about 2.4:1 object ratio. Soft studio light, elegant tactile wood and felt, recognizably a board eraser at 120 pixels wide. Centered isolated object filling canvas with small padding, genuine transparent background, no scene, no surface, no cast shadow outside object, no lettering, no logo, no hands, no other objects.

## 實際命令與目前結果
- git status --short：開工無輸出。git fetch origin／rev-list HEAD...origin/main：公開與私人均0/0，remote正確；gh repo view私人庫isPrivate=true。
- dotnet build HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 --no-restore：r1失敗1warning94errors（兩處CS0234根因）；r2 23.37秒及r3 24.07秒成功0warning0error。最後垂直容量／文件變更仍須以Portable publish結果為準。
- python Build-LocalizationCatalogs.py：十語各624keys，missing0。python Build-UserGuides.py：十語25章62段。四張前批實機圖保留，caption明示工具列排列差異，未偽造本批截圖。
- computer-use：r2隔離示範資料視窗觀察單排、板擦、自訂卡片成功；r3窗口捕捉回傳的影像不符目標，未保存／未當手冊圖片，也未對背景視窗輸入。隔離預覽程序清理不涉及使用者App或作品。
- 本批自動化測試、擦除／Undo實機驗收、觸控筆、4K／混合DPI、左右停靠、RTL／母語、MSIX／ARM64／WACK：未執行。前批成功數字僅屬歷史。應由使用者試用後決定後續細節及正式進版。

## 封裝與交接
準備以獨立 canvas-ui-2026-10-15-r1 label封裝，不覆寫舊試用；成品及資料保全證據於成功後追加。

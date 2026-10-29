# 固定教學工具／右下布局／雷射色盤／圖層命令 — 2026-10-29

## 開工

使用者要求三固定工具選取／雷射／藤條不可關閉、每頁常駐相鄰；更多不重複藤條工具，保留顯示藤條。板擦與藤條同45°、圖示底端對齊及相近大小。雷射支援常用色及增刪管理。物件右鍵補移至頂端／上移／下移／移至底端。僅Windows，兩畫布共用相關邏輯；起點9f7efe5，已讀索引與平台狀態／架構／問題／規則並記git status。保留既有三文件6／8／4行及三YouTube檔；1.0.17不進版、不改Store、不清理。沒有本批App／自動測試授權，編譯／封裝及靜態核對後交付試用。

## 調查／設計中

固定工具須同時更新Normalize／HideTool／重設／主與螢幕自訂UI／Arrange，不只把按鈕畫出；自訂排序亦不能把固定三工具拆開。板擦圖像與擦除接觸輪廓需一起旋轉，底端依實際可見輪廓與藤條圖而非未旋轉容器定位，避免看得到的位置與擦除範圍不一致。雷射重用既有ProfilePalette／PaletteEditor，不新增第二套色盤。右鍵圖層操作需保留多選相對次序、頁面／鎖定界線，使用一筆Undo，不以遞增ZIndex累積到溢位。

## 實作進行中

三固定工具的偏好／HideTool／移動／重設及兩host自訂UI統一使用FixedTools；常用也強制保留，不能取消或拆開排序。Arrange將三按鈕直接作為同層siblings，拿掉藤條額外wrapper與管理／更多重複工具入口；保留顯示藤條只控制右下快捷。

右下布局按可見輪廓的底邊與最大邊長對齊，不按透明圖框。Cane.png alpha>=128的32點convex hull只讀取校正，圖片byte未改；板擦既有輪廓加25°旋轉到45°，等比例fit／置中以免透明pointer host外有無法抓取區域。完整6項affine同時供XAML、GPU拖動預覽、CanGrab／ContactAt／背景擦除用，不能只轉Image。Cane按板擦可見最大邊匹配大小，兩者可見底緣同距底40 DIP、間距18 DIP。

首次build36.30秒失敗：WinUI Matrix的平移欄位是OffsetX／OffsetY，誤用System.Numerics的M31／M32，兩筆CS0117造成連鎖XAML解析錯誤。已修正欄位映射，保留build.log，接續重編譯。

雷射兩host直接接現有PaletteEditor/ProfilePalette（增、刪、管理、還原、選取），不新增色盤檔或訂閱指標事件；screen補原缺少的ColorPicker，關閉設定時保存owner教學偏好。顏色共用但不改目前畫筆筆色。

新增共用LayerReorder.MoveSelection：目前頁面（包含共享頁物件）的未鎖定多選保留相對次序，上／下各跨一個未選鄰居，頂／底整塊移動。只替換當頁在全域排序的slots，其他頁物件相對順序保留；只在實際順序改變時一筆Undo，重整有限ZIndex避免max+1累加溢位。右鍵四命令有document epoch／active page／selection防陳舊回呼；全鎖選取禁用。既有拖曳圖層入口保留。

## 編譯與來源整理

第二次同參數build30.60秒、0warning0error；log build-r2.log。之後補藤條快捷透明padding以容納旋轉後的尖端／握柄，讓可見像素仍在可點擊host內；最終來源依Portable重新publish。沒有新增或執行實作／核心測試，沒有啟動App。

Build-LocalizationCatalogs.py：十語647key、650authoring rows、missing=0；Build-UserGuides.py：十語25節64段。同步固定工具規則、更多只顯示快捷選項、雷射共用色盤、右下45°及底緣匹配、右鍵四圖層命令。既有使用者編輯指南不覆寫。

移除前已查cane額外slot／更多手動工具入口及ChangeScreenLayer舊bool方法引用，所有正式呼叫改用固定工具／LayerMove；既有LayerReorder.Move拖曳入口與歷史文件保留。變更Core ToolbarPreferences／BoardEraserGeometry／CanePose／ToolArtBounds／LayerReorder；Views ToolbarUi.Presentation；MainWindow Chrome／Cane／BoardEraser／Input／DrawingWorkflow／Teaching／TeachingPreferences；ScreenAnnotation Chrome／Docking／Objects／Window；renderer ToolArt；九語手冊來源與十語catalog／指南、平台紀錄。沒有改PNG／WAV／作品schema／其他平台、版號或Store。

待實機：三固定工具在各頁／各停靠／圖示模式與自訂／重設／舊偏好遷移；右下兩物件底緣／大小、板擦抓取／拖動擦除與GPU預覽一致；雷射常用色增刪／跨畫布同步／重開保存且不改筆色；右鍵多選／鎖定／共享頁／非當頁／相同ZIndex／極端ZIndex、上下邊界與undo／redo；DPI／小視窗與性能。沒有聲稱這些已驗收。只編譯及封裝靜態核對，沿用1.0.17、獨立試用Data、不清理或Store作業。

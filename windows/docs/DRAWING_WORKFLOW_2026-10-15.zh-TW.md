# Windows 繪圖操作與文件交換開發日誌（2026-10-15）

## 開工

- 使用者本批需求：PDF／PPTX匯入及PDF匯出相容確認、磁鐵吸附、建立物件不自動開詳細調整、連續繪圖、圖示／圖文分頁工具列與常駐選取、三點三角形直線預覽、自訂全選／預設、圓規圖示、附實機畫面的十語手冊。
- 平台限Windows。開工HEAD `38634bb9f3ed0a51a6143c568541a11117b9af13`，`git status --short`無變更。沿用1.0.14開發候選，使用獨立試用標籤，不進正式版。
- 已讀根／Windows AGENTS、開發索引、平台狀態／架構／問題／決策。先調查現有輸入、工具列、文件交換與手冊產生器，進行中追加發現及命令結果。

## 調查中

- PDF／PPTX須分開確認Windows原生PDF rasterizer與PowerPoint相容轉換來源；匯入頁面採可註記頁面，不能把PPTX內容解析當成PowerPoint完整渲染。
- 尚未執行本批編譯、測試、封裝或UI驗收。

## 進行中發現與證據

- 已有WebView2 PDF匯出，首頁原只接受JSON／heiban，PDF原只輸出目前頁。新增Windows.Data.Pdf圖片頁面匯入；PPT/PPTX透過本機PowerPoint COM STA唯讀轉PDF，強制停用巨集，關閉自開文件並保留既有Office文件。沒有綑綁Office／轉換器或新增NuGet依賴。
- 直線／形狀提交後主畫布明寫`_tool="select"`，已取消；圓規建立圓弧後也保留工具。詳細快速列以明確雙擊選取ID控制，建立／單擊只顯示變形把手。
- 三角形預覽有兩層問題：輸入用了CurvePreview，繪製又用了會做cubic smoothing的RenderLiveStroke。現以獨立不平滑的RenderPolyline繪多邊形暫態，永久polygon與curve各沿原契約。
- 磁鐵共用Core空間格索引，一次手勢建一次，查詢只訪近格；距離以一般畫布縮放／screen DPI轉換。不在pointer move掃全部物件或改既有筆跡。toolbar.json新增DisplayMode／MagnetEnabled及未知欄位保留；選取不可隱藏，兩宿主使用共同分頁factory但控制項／session獨立。
- Core首次新增檢查曾因`rotatedHit`與既有測試名稱衝突而編譯失敗，改唯一變數名後2334項檢查通過。數輪x64 Release build皆0 warning／0 error；原生隔離驗證兩頁PDF匯入、作品編解碼、兩頁PDF匯出、兩張PPTX經PowerPoint轉PDF成功，結果在`.build/workflow-20261015/workflow-result.json`。Poppler將匯出PDF兩頁轉PNG後已檢視，內容／頁序正常。
- computer-use使用隔離示範作品：單擊矩形只見控制點；雙擊見Inspector與快速列；以drag連畫兩個矩形皆保留圖形工具、沒有自動調整列。初次隱藏啟動造成遮擋畫面與即時狀態延遲，改可見隔離視窗並重新觀察後操作成功；沒有把其他視窗內容保存到手冊。
- 十語UI新增24列翻譯，產生616key／語，missing=0；九份手冊來源（zh-CN派生）補匯入限制、整份PDF、分頁、磁鐵、連續與雙擊。實際示範視窗截圖接續製作。

## 原生UI重建排解

- 示範啟動發生WinUI fail-fast（Windows事件Application Error 1000，0xc000027b）；先改用FrameworkElement.Parent，但仍有同症狀。只在隔離資料根啟用未處理UI例外記錄後，取得0x800F1000及堆疊，定位`DrawingArea_SizeChanged → SetDock → ArrangeMainToolbar → 重掛Select`。這不是缺少Office元件；訊息「並未偵測出安裝元件」是此次XAML集合錯誤的表面症狀。
- 主畫布加呈現快取／重入守護：只有按鈕／模式／方向改變才重掛控制項，SizeChanged僅調RunLength及量測。尺寸事件亦不再反覆保存工具列偏好，真實Dock變更才保存；偏好原子寫入序列化，避免兩宿主／停靠命令同時replace同一檔。
- 修正後重新啟動三角形／PDF示範成功，三角形圖可見兩條直線預覽；已保存四張真正Windows視窗JPEG共231,547 bytes至Assets/Guides/images。十語各25章60段、四圖引用與manifest SHA靜態核對通過。
- 增加screen四邊圖文排版／三點三角形／連續矩形／磁鐵原生檢查後，又捕獲screen重掛子頁按鈕的同類錯誤（不是主視窗再次崩潰）；修正為拆掉舊根之前先明確從子面板移除按鈕，並補screen工具的Tag來源，避免分頁把所有無Tag工具當成palette。此失敗、堆疊及後續重跑結果保留，不使用舊workflow-result.json冒充當次通過。

## 最終來源驗證（封裝前）

- Core Release：2334checks通過；最終x64 build21.57秒，0warning／0error。原生最終執行資料根`native-final-data-r2`，2026-10-15本機結果更新至15:47:55（台灣），success=true且screen的threePointTriangle／continuousShapes／magnet／labeledFourSideLayout皆true。前輪workflow-error.txt仍是歷史失敗，不因保留而當成最終失敗或改寫。
- 未驗收：使用者真實PPT/PPTX（字型、圖表、外部連結、加密、舊版.ppt）、原生PDF密碼輸入、手寫筆／觸控、DPI／多螢幕、RTL母語與完整回歸。UI頁面範圍／取消及自訂全選／預設持久化仍需實際操作回報。WACK／MSIX候選／Store／GitHub Release未執行。
- 使用者可用獨立標籤免安裝包實測；維持1.0.14.0候選。變更不含新增NuGet相依，手冊四圖增加約232KB原始載荷。實際ZIP大小／SHA與來源commit在封裝成功後接續。

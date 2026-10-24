# 2026-10-24 Windows 畫布空白修復（實測通過，封裝中）

## 使用者回報與範圍

eraser-laser-2026-10-24-r1 開作品後沒有畫布，輸入仍有筆跡寫入首頁縮圖，重新進入依然空白。此為阻擋使用的顯示退化，不可沿用上批「編譯成功」視為驗收。保留所有作品與舊產物，只修Windows，仍1.0.16／1.0.16.0，不重做Store。

開工git status為原三份平台文件6／8／4行差異及三份YouTube新文件，全部保留。已讀根開發索引、Windows目前狀態／架構／問題／決策。scratch保存dirty baseline與36份Store SHA；目前未見HeiBan程序。

## 初步定位

- 上批把可選板擦PNG的LoadToolArtAsync加入CreateResources的Task.WhenAll，主畫布_ready須等待它完成。載圖使用ms-appx URI，在免安裝／未封裝桌面程式不是可靠路徑。
- 工具圖僅捕捉IO／COM例外；其他例外會令資源Task失敗。ImmediateCanvas.InitializeSurfaceAsync只捕捉COM，呼叫又以丟棄Task方式啟動，存在初始化失敗後永久_ready=false、既無Draw亦無錯誤畫面的明確缺口。縮圖使用獨立renderer，與輸入照常而主畫面空白的回報一致。
- 這是程式路徑確認，不等於已取得使用者現場例外堆疊；待重現／驗證。資產實際存在於前批payload，不應用重建作品或清除資料解決。

## 預計修正

可選圖改安裝目錄絕對路徑／唯讀stream，與必要畫布初始化分離；工具圖失敗保留XAML板擦，不得卡住畫布。主畫布初始化失敗須處理、可見錯誤與相容回退，避免靜默空白。測試依當次明確授權，已詢問使用者；獨立測試資料不碰現有作品。

## 進行中：使用者授權實機驗證

使用者明確回覆「請實際驗證，再交付」。已以HEIBAN_WINDOWS_DATA_DIRECTORY獨立資料啟動舊eraser-laser包，Computer Use開啟內建指南；工具列與板擦可見但所有指南物件／畫布均空白，已重現回報。測試資料與使用者Data隔離，不更動現有作品。

第一批修正：板擦資源改BaseDirectory唯讀stream並與必要載圖脫鉤；全部非OOM例外捕捉並記錄型別／HRESULT。主host初始化與Draw補非COM失敗回退；fallback載圖失敗有重載入口，沒有首幀時禁止指標新增隱形筆跡。錯誤文字新增十語。診斷只存一份型別／代碼／階段，不存例外訊息／stack或作品內容。

首輪編譯26.37秒失敗：renderer已有Path方法，新增Path.Combine被解析成該方法，改System.IO.Path.Combine；94error／1warning包含93個XAML連鎖錯誤，未改無關XAML。

## 已執行的建置與實機流程

- `python windows/scripts/Build-LocalizationCatalogs.py`：10語、626來源、629authoring rows、0 missing；只新增兩條恢復文字。
- cwd windows：`.build/tools/dotnet/dotnet.exe build HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 -p:WindowsPackageType=None --artifacts-path .build/canvas-recovery-20261024-r1 --nologo -v:minimal`。首輪失敗如上；修正後29.18秒0 warning／0 error。完整log留ignored scratch。
- Computer Use舊包＋old-isolated-data：內建指南120物件不可見；選鋼筆drag、Ctrl+S，磁碟121物件，畫面仍空白，正常退出。只含合成測試資料。
- 修正版build EXE＋new-isolated-data：首頁指南打開即可見文字／圖形／白底，BoardEraser圖可見。Ctrl+N建立Canvas recovery verification筆記（A4直向／橫線條），鋼筆drag由(210,310)至(575,445)，綠線立即可見，無完成選框。首頁等待保存動畫後縮圖可見該線；雙擊重開線仍可見；正常退出。
- 故障注入：僅將ignored build輸出Assets/BoardEraser.png暫移.test-disabled，HEIBAN_RENDER_PATH=xaml＋同獨立資料重新啟動。舊線與橫線背景可見，再drag第二筆可見；主畫布未被可選圖失敗阻擋。取得last-canvas-error.json：stage optional-eraser-art、System.IO.FileNotFoundException、0x80070002。不是舊包URI的實測例外，不混淆。正常退出後已恢復PNG。
- UI自動隱藏header800ms使兩次HomeButton索引過期；重新觀察並於展開區hover後成功回首頁，沒有修改產品header邏輯。一次state未要求include_text而讀null、兩次PowerShell glob／skill相對路徑讀取失敗，均改明確檔案／正確路徑。

## 變更清單與限制

`Engine/Direct2DCanvasRenderer.ToolArt.cs`、`MainWindow.Input.cs`、`MainWindow.BoardEraser.cs`、`Views/ImmediateCanvas.cs`、新增`Diagnostics/CanvasSurfaceDiagnostics.cs`；Localization Sources／authoring／10 catalogs、README排錯說明及平台狀態／架構／決策／問題／日誌。只有Windows，無文件格式或指南原稿遷移；不替換既有作品中的指南。

主host首幀與可選圖隔離已透過UI驗證；錯誤overlay重試與GPU裝置遺失恢復尚未故障注入，OOM、ARM64、混合DPI／多螢幕、長時大量筆跡與擦除延遲、WACK／Store重包或送審未執行。沒有新性能採樣，不宣稱50ms或所有延遲已解決。接續封裝及來源／SHA紀錄另補，使用者作品不進ZIP或Git。

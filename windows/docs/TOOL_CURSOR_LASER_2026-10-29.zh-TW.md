# 工具游標與按住雷射 — 2026-10-29

## 開工

使用者GO：畫布游標對應工具、只有選取保留箭頭；雷射按住左鍵才顯示、未按不顯示，雷射模式不能選取。Windows一般／螢幕畫布一起處理，沿用1.0.17／1.0.17.0作下一系列開發，不自行進版或Store提交。起點e55614a9489e9ff3696b04abd50ce35d051f6f54。先讀索引／AGENTS／平台狀態、架構與問題；保留三文件6／8／4行及三YouTube原新檔，scratch保存status與既有Store SHA。

本批授權實作與建置／試用封裝；尚未取得本批新增實作測試或實機操作授權，因此不執行測試。前批授權僅用於當時筆刷／畫布修復，不能挪作本批新驗收。

## 調查中

正在核對MainWindow與NativeOverlay兩種游標擁有者、雷射hover與選取事件的先後次序。第一次rg使用PowerShell未展開的MainWindow.Input*路徑報os error123，改用目錄加-g，不修改檔案。

## 可確認原因與實作

一般PointerMoved無條件在laser加入sample；screen在right／double物件Hit後才判斷laser，且把所有非up事件都Add，故hover會發光、雙擊／右鍵會改成選取。Main的DoubleTapped與ShowContext也不排除laser。已把雷射改成捕捉左鍵手勢獨立路由，Press／MovePressed／Release共用暫態engine；hover不新增，release／cancel／離開主畫布／停用或切工具清空尾跡。原生screen補LeftDown與第二次按下double的capture；模式切換／隱藏取消capture。進雷射清除選取，右鍵／雙擊不進物件hit test。按住不動保留最後光點，舊尾跡仍按既有時間fade；不新增永久物件或Undo。

主游標原只在select時更新，非選取重設成系統arrow；screen預設32515十字。ToolCursor共用ToolIcons原向量，在工具／DPI尺寸首次需要時以獨立Win2D software surface產生白邊黑線native cursor，十字熱點與右下工具badge，工具／size快取。沒有新增PNG或第二套工具圖示表；可選圖生成失敗按size快取cross fallback，不能影響畫布初始化。ShapeCursor仍優先resize／rotate／grabbing，CursorCanvasHost維持WinUI ProtectedCursor擁有者，NativeOverlay以WM_SETCURSOR套用同一native圖；退出釋放自己的HCURSOR、借用系統游標不Destroy。

API核對使用Microsoft Win2D官方CanvasSvgDocument.LoadFromXml／DrawSvg與CanvasDevice forceSoftwareRenderer文件；資源只需產生一次的建議已以快取採用：https://microsoft.github.io/Win2D/WinUI3/html/M_Microsoft_Graphics_Canvas_Svg_CanvasSvgDocument_LoadFromXml.htm 、https://github.com/microsoft/Win2D/blob/winappsdk/main/winrt/lib/drawing/CanvasDevice.abi.idl 。未依第三方範例改寫引擎。舊screen performance helper的hover示範輸入同步為down／move(LeftDown)／up，沒有新增測試斷言或執行它。

一處猜測ScreenAnnotationWindow.BoardEraser.cs不存在（實際入口在Panels），僅查找失敗，未刪改檔案。建置與交付結果待後續追加。

## 建置與補查

dotnet build windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 -p:WindowsPackageType=None --artifacts-path windows/.build/tool-cursor-laser-20261029-r1 --nologo -v:minimal：成功62.65秒，0warning0error。其後補兩host的圖層選取防線、長時間按住後移動不連接已消退舊位置，最終以封裝重新build來源為準。Build-UserGuides.py重建十語25節64段，說明按住／放開、靜止光點、laser選取限制與游標熱點；既有使用者指南不覆寫。

目前觀察到使用者Store版1.0.17.0程序正在執行。本批不關閉或操作它、不複製其即時作品資料；新Portable使用獨立Data。未根據已安裝程序推論Store最新認證狀態。未執行本批App／測試／性能／WACK，游標實際外觀、混合DPI與操作手感待使用者試用。

變更檔案：Core LaserPointerEngine；Views ToolIcons／ToolCursor／ShapeCursor；MainWindow.Input／Chrome／xaml／xaml.cs；ScreenAnnotation NativeOverlayWindow／ScreenAnnotationWindow與Chrome／Objects／Panels／原Performance合成呼叫；共用renderer Laser；九語手冊來源及十語生成資產、平台狀態／日誌／架構／決策。沒有其他平台／文件契約修改。原生滑鼠cursor的軟體surface生成失敗只提供十字回退，不宣稱已驗收特殊顯卡／資源壓力情況。

## 封裝及交付結果

x64免安裝`tool-cursor-laser-2026-10-29-r1`已完成，來源`152c9e0c573997870da69de82473945c69c5bf6c`；ZIP 132918771bytes／SHA256 `d2640965a2ccfae543ed409f38607ff9852fb1140d0b4c87e016feb3f327ad20`。586 payload／196 source SHA及588 archive entries CRC核同，兩EXE x64，ZIP與交付Data使用者檔=0；本批使用獨立作品庫，沒有複製目前執行中的Store資料。51份Store檔SHA不變。App／實機／核心及實作測試／性能採樣未執行；待使用者試用，無Store重包／進版／上傳。 [產物紀錄](TOOL_CURSOR_LASER_ARTIFACT_2026-10-29.json)。

Package-PortableTrial.ps1 -Runtime win-x64 -Label tool-cursor-laser-2026-10-29-r1成功，來源152c9e0c573997870da69de82473945c69c5bf6c；最終publish紀錄windows/.build/portable-trial-f87579f204744cf0bb569b588647a58b。inspect_delivery.py核對ZIP CRC／payload與來源SHA、x64PE、空Data與全部51Store檔SHA成功。只執行封裝完整性核對，沒有App／測試或性能驗收。

同步時發現遠端main已增加Mac提交到670a7003a1bd1bab0783c3deaf8912c03f22d036。git fetch後核對檔案範圍：Mac與共用文件，無Windows檔；以git merge --no-edit origin/main整合，無衝突，保留152c9e0封裝來源commit與所有遠端歷史，不rebase／force。新開發索引已讀，沒有本批編寫Mac程式。Windows封裝來源byte不受merge影響。

未驗收：游標圖示實際視覺、混合DPI／多螢幕、快速按放與切工具、失焦／取消、物件／圖釘／圖層在laser下不能選取、長按靜止與放開即清除、ARM64、WACK／Store安裝升級及新性能數字。版本1.0.17／1.0.17.0沿用，沒有新正式Release或商店作業；沒有刪任何作品、SDK、舊試用或已上傳商店套件。原未提交6／8／4行及三YouTube檔保留。公開原碼／記錄與私人壓縮交接分開推送。

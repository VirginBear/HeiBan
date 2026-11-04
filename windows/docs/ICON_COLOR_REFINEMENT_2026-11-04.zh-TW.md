# Windows 1.1.2 圖示細描邊與筆色回饋 — 2026-11-04

使用者要求A圖示描邊變細、鋼筆／螢光筆本體隨目前筆色、直線／箭頭改形狀紫色，以及原風格選取改用帶框線的語彙。只改Windows，沿用1.1.2，不覆寫已交付試用／Store包。開工保留三份既有dirty清理文件與三份YouTube未追蹤文件，git狀態／patch存`.build/icon-color-refinement-20261104`；已讀索引與平台目前狀態、架構、問題與規則。

初查A使用1.7～1.8描邊、部分generic還有3.5底線；筆身是固定藍／黃，現有SetToolColor只畫底下色線。規劃圖示的可變色brush狀態與實際筆跡分離：顏色設定時更新UI現有畫刷，輪盤只在顏色改變時替換對應SVG，不能把顏色快取無上限累積或在畫線Move重新載入資源。底下色線仍只給目前工具。

## 進行中實作與排解

A主要描邊降到1.1／generic1.25（26px viewBox單位），移除generic雙重粗線；直線／箭頭使用其他圖形相同紫色。原select path加入虛線框短節與同A鼠標輪廓，系統選取游標仍由ShapeCursor的select分支保留箭頭，不改使用者作品與命中邏輯。

筆身三個語意色角色定義於ToolIcons.BrushColor，生成器共用同一常數；Toolbar的XAML幾何只建立一次，之後僅改SolidColorBrush顏色，底線仍只顯示於目前工具。輪盤共用SVG、每個既有圖示key保存目前色，換色先建新資源成功才dispose舊資源並原位取代，不以RGB建立無限新key。設定窗樣本／輪盤設定與更多隱藏工具亦接目前色，兩host各自提供顏色避免混用。尚未改任何永久文件、Undo或筆劃預覽路徑。

首次patch工具拒絕同一patch內重複target，拆成單一target後成功，未涉及產品執行失敗。首QA build因WinUI Viewbox是sealed，不能作為動態元件基類（CS0509與後續XAML連帶錯誤）；改Grid持有Viewbox。第二build0警告0錯誤；補輪盤設定即時色更新後第三build作為原生驗證來源。原先字符串連續替換色票有值碰撞可能，已在驗證前改逐XML屬性單次替換，保留alpha與金屬筆尖中性色。測試含色票常數本身作為使用者顏色，避免替換兩次。

十語指南在既有workspace段落追加本批行為，仍26節80段；UI沒有新增文字key。Core純幾何／資料測試本批未重跑，前批3445不算本輪結果。待原生動態顏色與GPU繪製、正常封裝核對後追加交付結果。


第三build0警告0錯誤26.34秒。首隔離原生QA結果：15項screen斷言、36項動態色／幾何identity檢查、132份SVG GPU繪製通過；六種色含黃色、藍色、兩個角色token自身、半透明與全透明，不重建XAML幾何。一般工具列兩個筆身黃色確認；GPU預覽直線／箭頭為紫色、原風格選取帶框線。目視另發現A螢光筆圖稿自帶一條色痕，會和「只有目前工具底下有色線」混淆，移除圖稿色痕，保留原ColorIcon唯一底線，準備以同binary＋更新SVG重跑。XML132、紫色及無額外色痕的靜態斷言已通過；首次追加記錄因Python預設cp950解碼失敗，改明確UTF-8，未改產品資料。

實際用computer-use點螢光筆並重新擷取，確認工具由鋼筆切成螢光筆且兩個筆身仍是黃色、底線隨目前工具移動。一次視窗bounds變更使索引點擊被拒絕，重新觀察後僅重試一次成功。最後只更新highlighter.svg到第三QA build內容目錄，再以全新qa-data-r2重跑，不宣稱重編C#或重跑Core。


## 最終原生結果與封裝前界線

qa-data-r2同樣15 screen斷言、36動態色／幾何檢查與132 SVG真實GPU繪製通過；最後SVG不含多餘螢光筆色痕，A細描邊與紫色形狀、classic框線select目視通過。原生驗證使用新隔離資料根，不讀寫原作品。沒有新UI key，十語guide仍26節80段。Core／硬體延遲／ARM64實機／WACK本輪未執行。

命令：`python windows/scripts/Generate-MenuIcons.py`（66）；`python windows/scripts/Generate-DuotoneIcons.py`（66）；`python windows/scripts/Build-UserGuides.py`（10語26節80段）；`dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/icon-color-refinement-20261104/qa-build`（第二29.39秒、第三26.34秒，皆0警告0錯誤）；獨立`--icon-style-validation-output=...`與HEIBAN_WINDOWS_DATA_DIRECTORY測試根。最後只換一份highlighter.svg到第三build內容目錄重跑，不混稱重編C#。

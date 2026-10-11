# Windows十語使用說明 — 2026-10-12

## 階段1：開工

使用者要求使用說明新增多國語言，完成後由使用者提交本次更新。沿用已確認十語：zh-TW預設、zh-CN、en、ja、ko、es、fr、de、pt-BR、ar。開工公開HEAD87c6ae2，status僅原.vscode/；讀開發索引、Windows AGENTS／目前狀態／架構／問題。先建立日誌，遵守整批驗證後由使用者決定正式進版，metadata暫沿用1.0.14，試用用新Label，不自行提高版號或提交Store。

初查：現有Assets/HeiBanUserGuide.html為正體中文單檔；作品入口用LaunchFile，首頁另用LaunchUri硬編碼路徑；來源目錄會由csproj的Assets通配項複製。舊手冊螢幕toolbar仍描述固定尺寸與捲動，與新實作矛盾，需更新。主張離線十語、共用模板／章節契約、各語完整操作說明與ar RTL；不使用線上翻譯服務、不記使用者作品。母語／4K／Store實機驗收需區分。

首次輸出過多因HTML單行，工具截斷；Python -c包class字串遇PowerShell引號拆解SyntaxError退出1，未改檔，改保存腳本讀取。發現與實際結果接續記錄。

## 階段2：實作與來源

9份UTF-8人工編寫txt（zh-TW及8語）有相同25章55段；zh-CN以Windows NLS與地區用語表生成。Build-UserGuides.py退出0，輸出10個独立HTML、manifest SHA及zh-TW相容入口，不呼叫網路／翻譯API。重新編排原手冊重複段落，涵蓋同一現行功能範圍；修正開始章「一律自動保存」、舊screen固定尺寸／捲動與物件屬性混用等過時說明，保留強制終了資料風險、Updater／Store邊界、可選圖釘色Mac舊版相容限制及未交付功能。

共用HTML產生器提供內嵌CSS／JS、響應式章節導覽、離線搜尋、手冊語言選單與章節anchor沿用；手冊選語只切文件，不寫App偏好。ar為RTL並以bdi隔離快捷鍵／路徑／數值。首頁與作品入口共用OpenUserGuideAsync，開啟時讀Strings.Language，缺頁退zh-TW相容入口，以LaunchFile開本機StorageFile。首頁label及作品項目都改現有T("使用說明")，不增加新UI key，既有592key字典不改。

舊圖譜query退出0、BFS depth2／165nodes，含OpenUserGuideAsync與RefreshLanguage，用於導航；圖譜未重建，精確改動以本次C#源碼為準。未掃私人作品或執行語意API。

Package-PortableTrial將authoring txt／生成器／manifest加入source SHA。Package-Store新增DevelopmentLabel隔離dist/store/candidates/<label>，不覆寫原同版套件／原根latest report、也不為防覆寫而加版本；report標formalVersionApproved=false與label。Read-StorePackage逐byte匹配十HTML及manifest，另保留25legal與guide／README核對。兩平台座標、作品JSON、renderer、Undo與版本metadata未改。

本批修改C#兩入口、XAML一label、兩packaging script、生成器、9份來源與來源README、11個Guides assets及舊相容HTML，並更新平台狀態／架構／決策／問題／日誌。HTML字串均escape，不把來源當可執行markup；manual只描述目前候選，不冒称正式驗收完成。翻譯未母語校閱，檢查及封裝接續。

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

## 階段3：當次編譯、靜態檢視、資料接續

- source實作 `84583637706e172e0ed64c0e8431122311f17309`，35檔1113新增11刪除；Windows .gitattributes後續提交 `1ab7018b24e4fc06f354ac8d968207de8d0c7770`，固定Guides HTML／來源txt LF，避免另一台電腦autocrlf使每頁SHA manifest失效。兩次間App／HTML內容不變。
- `Package-PortableTrial.ps1 -Runtime win-x64 -Label guides-2026-10-12`退出0，App/helper publish無warning/error；證據`.build/portable-trial-ede12fb563574818a430e822f7005f24/`與`.build/portable-guides-2026-10-12.log`。ZIP `dist/trials/HeiBan-Windows-Portable-1.0.14-guides-2026-10-12-win-x64.zip`，131,753,592bytes，SHA256 `2022630e14aa2b1313ab0319659c266a9d9046e69617ced060dd761a1ef27e8b`。
- `Package-Store.ps1 -DotnetPath windows/.build/tools/dotnet/dotnet.exe -DevelopmentLabel guides-2026-10-12`退出0；x64 51.93秒／ARM64 52.96秒，各0warning／0error。證據`.build/store-2aeb6eb481cc4e9a943ca3e44987f020/`與`.build/store-guides-2026-10-12.log`。bundle `dist/store/candidates/guides-2026-10-12/HeiBan-Store-1.0.14.0-x64-arm64.msixbundle`，193,675,520bytes，SHA256 `8dc919c47c69585a114cc9c8d1ddf20c1126e08b5524ca73009c8e85b396d666`。版本仍1.0.14.0，formalVersionApproved=false、storeSubmitted=false；原root三個Storebundle及reports不覆寫。
- `.build/inspect-guides.py`及`--packages`各退出0：10語×25章×55段、完整anchor／切語相對路徑、ar dir=rtl、無外部資源、manifest每頁SHA一致；portable147source／568inventory／570archive、12guide documents（10語＋manifest＋相容頁）、空Data、逐payload SHA；Store198source／兩MSIX各12guide逐byte、無Data／Updater／pdb、bundle套件byte／identity／兩架構已由packaging核對。原Store12／13／14SHA核同。這是靜態產物檢視，不是App／browser tests。來源SHA一致是檢視當時，後續README／docs是交付紀錄。
- `Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.14-guides-2026-10-12-win-x64`退出0；先確認無HeiBan程序並核GitHub已發布assets，清除舊save-mode未發布runtime／ZIP／sidecar452,723,319bytes。這次舊Data已有20檔898,085bytes（不是上一批的9檔），全保留至`dist/trial-data-backups/20261011-212517-bd8345c8/`；不讀／記作品名稱內容，前備份保留。
- `.build/handoff-guides.ps1`退出0；從核同備份複製到新解壓版空Data（允許空子目錄但拒絕已有檔／reparse point），20／20 SHA相符，備份保留。ZIP仍空Data；root Store12／13／14及新ZIPSHA再次核同。原始portable inspection的dataFiles=0是接續前，而現在解壓版20檔；不同時点分開記。

交付：[十語內容檢視](GUIDES_CONTENT_INSPECTION_2026-10-12.json)、[試用產物](GUIDES_PORTABLE_ARTIFACT_2026-10-12.json)、[試用檢視](GUIDES_PORTABLE_INSPECTION_2026-10-12.json)、[商店產物](GUIDES_STORE_ARTIFACT_2026-10-12.json)、[商店檢視](GUIDES_STORE_INSPECTION_2026-10-12.json)、[清理](GUIDES_TRIAL_CLEANUP_2026-10-12.json)、[資料接續](GUIDES_DATA_HANDOFF_2026-10-12.json)、[使用者试用清單](GUIDES_TRIAL_REVIEW_2026-10-12.zh-TW.md)、[商店候選素材](STORE_UPDATE_GUIDES_2026-10-12.zh-TW.md)。本批已完成手冊與封裝準備，正式版本決策仍待使用者依整批驗證作出。

未執行：App、browser互動、tests、WACK、Store安裝／提交／發布、母語校閱、4K／DPI／RTL实機、畫布／保存／Undo回歸、效能量測。手冊行為／操作一致性與語文品質需試用確認；不因包完成將正式進版核准改true。Mac／Web、資料格式與原發行歷史未改。

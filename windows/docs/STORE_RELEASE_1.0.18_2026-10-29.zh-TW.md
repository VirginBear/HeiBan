# Microsoft Store 1.0.18.0 更新 — 2026-10-29

## 開工與核准

使用者對teaching-tools試用回覆「很棒 打包吧」，再明確確認「採用1.0.18／1.0.18.0」。依windows/AGENTS本批核准正式進版與製作Store包；不推論已上傳／送審／發布，也不把「很棒」換成未執行的自動測試數字。只Windows，起點64538b6，已讀平台索引／狀態／架構／問題／規則與前版Store紀錄。git status已保存，既有三文件6／8／4行及YouTube三檔保留。

先快照全部既有Store檔（除可更新的STORE_ARTIFACTS.json最新指標），同步csproj／StoreIdentity／manifest及十語指南到1.0.18。以既有Package-Store.ps1正式入口製作x64＋ARM64 bundle。保留Store身份、免費策略、runFullTrust與舊套件byte，不操作使用者Data／目前程式、不清理。編譯及套件靜態核對，沒有新的App／自動測試／安裝升級／WACK／性能採樣授權。

## 本次累積範圍

- 共用工具游標，雷射僅按住左鍵顯示；放開清除，不在雷射／藤條模式選取物件。
- 藤條持續跟隨、右下握點、45°休止／75°揮動與彈性回彈；使用者指定參考中單次0.26s揮擊聲。來源／notice保留，非原創合成聲，不納入完整MP3。
- 選取／雷射／藤條固定相鄰跨分頁，自訂不可取消；更多顯示藤條只控制右下快捷。板擦／藤條45°、依可見底邊及大小匹配，板擦圖與抓取／擦除共用affine。
- 雷射常用色與筆刷共用，可管理增刪／還原並保存；兩種畫布支援。
- 物件右鍵四層級操作，支援未鎖多選相對次序、一筆Undo／頁面與陳舊回呼界線；十語手冊／新指南更新，不覆寫使用者練習文件。

## 進行中

版本／十語送審說明與封裝準備中。實際命令、失敗、來源commit、build與包SHA、未驗收項待進行中追加，不先寫成成功。

### 開工命令失敗與排解

版本diff的Python console以cp950輸出，遇©字元而UnicodeEncodeError，該命令尚未stage／commit。其後封裝入口已啟動，原始碼檔案本身在啟動前已凍結；立即改UTF-8輸出並補齊來源commit，再核對包內sourceGitHead及全部sourceSnapshot。沒有在編譯中修改產品來源。新版指南含30工具，靜態核對不可沿用前版29工具常數。

### 封裝與靜態核對進度

既有Package-Store.ps1以Release／指定本機SDK／FormalVersionApproved完成；x64 81.61秒、ARM64 68.91秒，均0warning／0error。實際build batch為`.build/store-bbd8499a5f0b4ba6bf55a37a389c870c`。首次獨立靜態核對以錯誤來源路徑HeiBan.Windows/Licenses找notice，FileNotFoundError；包內notice已存在，來源應為windows/Licenses，修正本批scratch檢查程式重跑；沒有改產品／重包。

### 內嵌版本來源不一致，保留候選後重包

第一次內容／306來源SHA／50舊Store檔／PRI等核對通過，但額外以FileVersionInfo靜態讀PE發現：x64的ProductVersion=1.0.18+64538b6，ARM64=1.0.18+a1d5bd6。原因是前述console命令失敗後，編譯先於來源commit啟動；兩者來源檔byte一致但embedded git標記不同。本批不把它當最終包。僅將本次新產出的1.0.18候選／SHA／reports移入`.build/store-1.0.18-20261029/first-attempt`保留（初版bundle197254386bytes／SHA93fba1a54aa37bf74460af488a9f64f1c858f84823ea9f414879fe0e955001bd）；恢復既有latest指標後，以已存在的a1d5bd6重新封裝。沒有覆寫／刪除舊版本或修改程式來源，最終額外核對兩arch EXE／DLL的FileVersion與ProductVersion完整commit。

## 最終結果與證據

- 來源`a1d5bd6309f9bbcecd907a2547b663382b89869e`；正式版1.0.18／1.0.18.0已獲使用者核准。最終build batch`.build/store-f99d87ae8ca4481ab6a4ff845110681a`。
- 最終Release x64 **55.82秒**、ARM64 **78.61秒**，各0warning／0error。兩架構EXE及DLL四份FileVersion均1.0.18.0，ProductVersion均1.0.18+完整a1d5bd6來源commit。
- bundle **197254394bytes**（約188.12MiB），SHA256 `ef2d7cd7a9af894486764fb704b298ce012def7df269515269fcd09acb111070`。每arch MSIX／bundle三檔及SHA sidecar均核同；bundle內兩包與獨立檔逐byte核同、identity／version／arch正確。
- 306來源SHA／所有ZIP CRC核同；x64 636entries、ARM64 632entries，各26法律文件及21指南檔核同。兩個PE架構、10內嵌catalog、10manifest語言、10無邊界指南25章／30工具、51Store PNG、42targetsize variants／14 ICO幀及PRI unplated／lightunplated確認。
- 板擦／藤條PNG、取樣WAV、來源metadata／notice對照來源一致；完整參考MP3不隨包。僅runFullTrust，無Data／standalone updater／PDB／本機自簽章。
- 50份既有Store檔（21包）SHA不變，含1.0.17 bundle仍`f4caf4d9611ab901f236ec2640e0e0de2242d62f0b628ad48bbc7ec0f076ad78`。僅最新指標更新；未清理舊包、未修改使用者作品。

[產物來源與SHA](STORE_ARTIFACTS_1.0.18.0_2026-10-29.json)／[靜態核對](STORE_INSPECTION_1.0.18.0_2026-10-29.json)／[十語更新文案](STORE_WHATS_NEW_1.0.18_2026-10-29.md)／[提交資料及精簡runFullTrust理由](STORE_UPLOAD_GUIDE_1.0.18_2026-10-29.zh-TW.md)。

## 實際命令

1. `git status --short`、平台index／CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY／AGENTS及私人交接資料讀取；既有工作樹內容快照。
2. Python inline更新三版號來源／九份指南作者檔；`python windows/scripts/Build-UserGuides.py`：十語／25節／64段。
3. `git add -- <本批選定來源及新文件>`、`git diff --cached --check`、`git commit -m "chore(windows): prepare approved Store version 1.0.18"`：a1d5bd6。前一次console失敗與執行順序修正如上。
4. 兩次實際封裝皆用`& './windows/HeiBan.Windows/Packaging/Package-Store.ps1' -Configuration Release -DotnetPath 'D:\Game\HaiBan x64\windows\.build\tools\dotnet\dotnet.exe' -FormalVersionApproved`。第一輪候選保留，最終以已建立的a1d5bd6重包，不覆寫歷史包。
5. `python windows/.build/store-1.0.18-20261029/inspect-store.py`：先來源notice路徑失敗；修正後第一輪通過，再因PE來源不一致加嚴；最終版連同`check-pe-versions.ps1`靜態核對通過。MakePRI只dump資源，FileVersionInfo只讀PE，不啟動App。
6. 公開／私人紀錄分開提交推送與遠端SHA核對：以交付追加紀錄為準。scratch命令證據在本機，其他電腦不可假定.build／dist存在。

## 未執行與交付邊界

未執行App／實機／音效試聽／自動測試／安裝升級／WACK／性能採樣；使用者「很棒」是試用回饋，不換算測試數字或延遲承諾。未代上傳／送審／發布，未建立GitHub二進位Release，未製作新免安裝／搬移Data。既有1.0.17送審狀態以使用者先前回報為止，未查後台，不假定目前認證結果。後續開發累積在1.0.18，下一正式進版仍需使用者確認。

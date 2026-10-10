# Windows 目前開發狀態

## 2026-10-10 — GitHub Windows 1.0.12-preview.5（已公開）

x64／ARM64各提供Installer ZIP及Portable ZIP，[新版下載](https://github.com/VirginBear/HeiBan/releases/tag/windows-v1.0.12-preview.5)。相應source fddf85e已推main且tag一致，77build-source blob保持相等；公開Portable原entry／Installer原EXE逐byte相同，7assets遠端size／digest與本機相符，7個未登入下載HEAD均200。

GitHub舊Windows四ZIP及舊HTML已清除，保留歷史Release／tag、原說明及2個manifest文本；本機只留p5原4包及公開4ZIP。Mac來源／公開Release與所有作品／備份保留。沒有為本次上傳重跑程式測試，沿用已核SHA不變的700Core／ARM64原生／PDF成果，x64實機及完整Installer升級仍未驗收。下方「本機交付，未發布」為之前工作的歷史邊界。[公開紀錄](PUBLIC_RELEASE_2026-10-10.zh-TW.md)、[遠端雜湊](GITHUB_ASSETS_1.0.12-preview.5_2026-10-10.json)、[遠端清理](GITHUB_CLEANUP_2026-10-10.json)。


## 2026-10-10 — 1.0.12-preview.5 右鍵物件操作（完成本機交付）

最新Windows為1.0.12-preview.5／FileVersion1.0.12.5。依最新指示取消螢幕右鍵自動穿透：右鍵物件開調整／複製／個別刪除選單，命中已多選物件保留整組；空白右鍵取消暫態但維持作畫，選取不新增Undo。穿透由模式按鈕或Ctrl+Alt+D切換。下方preview.4及更早條目保留歷史偏好，不代表最新操作。

700Core Release及本輪ARM64原生result／screen-result同輪success，實際右鍵選單／空白不切模式／文字多選、副本刪除Undo通過；樣式、截圖、36preview幀byte等價回歸及PDF strict通過。77來源雙鏡像SHA一致，兩架構四包退出0／兩次Successful compile，包內版本／當前手冊／README／授權／空Data與SHA核對通過。

模擬機Current唯一程序11412、捷徑及549payload逐SHA通過；56Data檔SHA保全vm/c7、2目前作品＋9垃圾桶共11份，歷史c12至c6作品全部涵蓋。已清p4舊包／payload與建置鏡像1,965,162,051bytes，QA備份r5a；SDK／Inno／所有作品與歷史備份保留。未改Mac，未commit／push／發布。CUA右鍵／工具列點擊未產生可靠回應，未算硬體驗收；完整硬體／IME／多螢幕／混合DPI／手寫／x64實機與Installer升級未執行。

[右鍵修正紀錄](WINDOWS_RIGHT_CLICK_REVIEW_2026-10-10.zh-TW.md)、[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.5.json)、[清理紀錄](CLEANUP_1.0.12-preview.5_2026-10-10.json)。

## 2026-10-10 — 1.0.12-preview.4 螢幕物件與多選（完成本機交付）

本輪只改Windows。色圓／線條／填滿在選取工具下直接改已完成物件，支援未鎖定多選及滑桿合併Undo；截圖成為螢幕session原位置圖片，尺寸／旋轉／Undo／Redo，沒有寫主作品。Shift限直線／箭頭水平或垂直，包含A/B端點；首頁單擊選取／雙擊開啟、Ctrl／Shift或明確多選，批次垃圾桶／還原。右鍵直接穿透，物件命令在更多 → 選取物件。

Core Release700項通過，最終原生r3 result／screen-result皆success及PDF strict成功；77來源與native／package鏡像SHA一致。新36預覽／收筆幀逐byte一致，傳輸705245184→6114048bytes，中位24.7323→1.824ms（同步render，非硬體輸入延遲）；idle換工具不render。兩架構四包封裝退出0，兩次Successful compile、無compiler warning／error；SHA、架構、PRI／runtime／品牌／當前手冊／README及25份授權逐byte通過，ZIP空Data／無QA作品。

CUA可讀模擬機，但切換隔離QA click回noWindowsAvailable -10005；未算硬體點擊驗收。完整中文IME、手寫、混合DPI、多螢幕、x64實機及Installer升級未執行。前期r1／r2失敗與修正保留，見[本輪稽核](WINDOWS_SCREEN_OBJECTS_REVIEW_2026-10-10.zh-TW.md)。Mac未改，未commit／push／發布。


最終Current為1.0.12.4，唯一程序7720／捷徑及549payload逐SHA通過。正常關閉前後SHA備份vm/c6，56Data檔完整保留、2目前作品／9垃圾桶共11份，歷史c12／c2／c3／c4／c5作品全部仍在。舊Current全部bytes可由舊封裝與保全Data解釋，未知bytes0；更新前亦檢查未知payload檔案。只留最新四包／Current，已清舊p3包／payload及建置鏡像共1,967,680,113bytes；QA先SHA備份e4a～c，SDK／Inno／所有作品保留。見[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.4.json)及[清理紀錄](CLEANUP_1.0.12-preview.4_2026-10-10.json)。

## 2026-10-10 — 1.0.12-preview.3 操作修正（完成本機交付）

最新 Windows 為1.0.12-preview.3／FileVersion1.0.12.3，Mac基準1.0.12／20261010.4。圖釘圖示／原位改名、游標位置滾輪縮放、CAD雙向框選、第一／第二點曲線預覽、顏色／線條跨工具保留、目前線條樣本、直列不擠壓、截圖灰霧已修；切工具關浮窗、暫態預覽不重建永久scene、模式切換正確重建輸入alpha。詳見[本輪稽核](WINDOWS_INTERACTION_REVIEW_2026-10-10.zh-TW.md)。

Core680項通過，最終ARM64原生r7 result／screen-result皆success，包含Win2D四線像素、兩階段曲線、GDI遮罩、圖釘Undo、20按鈕尺寸、暫態快取及模式alpha0／1；PDF strict通過。76個native／封裝來源SHA一致，兩架構四包SHA、架構、PRI／runtime、當前手冊／README及25授權逐byte通過，ZIP空Data／無QA作品。

模擬機Current已更新、唯一新版程序與桌面「黑板 Windows 最新版」，549payload檔逐SHA通過。正常關閉前後備份vm/c5，51Data檔保留、2目前作品／8垃圾桶，歷史c12／c2／c3／c4作品全部仍在；移除舊Current前其全部bytes可由舊payload與保全Data解釋，未刪未知資料。最新四包見[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.3.json)。

Mac鎖定使最後實體點擊未驗收；完整手寫、中文IME、混合DPI、多螢幕、x64實機與Installer升級未執行。Mac來源未改，未commit／push／發布。舊包／鏡像清理及所有資料保全見[清理紀錄](CLEANUP_1.0.12-preview.3_2026-10-10.json)。

本輪舊包／payload／鏡像合計移除3,612,977,725bytes（檔案大小總和），只留最新四包；QA資料先逐SHA備份i3a～g，SDK／Inno及使用者資料保留。

## 2026-10-10 — 1.0.12-preview.2 流暢度修正

此輪只改Windows，Mac基準仍1.0.12／20261010.4。修普通畫布scene／文字排版快取、Selected O(N²)掃描、長筆跡JSON快照／移動、隱藏圖層重建與保存交錯；縮圖／偏好／搜尋改空檔或合併背景工作。螢幕選取拖動局部讀回、手勢中延後保存；維持單排／四邊配置、右鍵物件選單、Ctrl+Alt+K清空／復原與截圖回貼。

Core Release568項通過；原生ARM64 result／screen-result皆success，9普通畫面＋22螢幕幀逐byte等價。最終300物件重繪中位31.3325→1.5991ms，螢幕30.331→4.4957ms，非硬體延遲。第一輪仍有快取P95尖峰；完整硬體／IME／混合DPI／x64實機與Installer升級未完成。[稽核報告](WINDOWS_PERFORMANCE_REVIEW_2026-10-10.zh-TW.md)與[量測數據](PERFORMANCE_1.0.12-preview.2_2026-10-10.json)。

交付完成：兩架構四包SHA／架構／PRI／runtime／品牌／當前手冊／README及25份授權逐byte核對通過、ZIP空Data／無QA作品。ARM64 Portable88.44MiB／Installer61.00MiB；x64 Portable91.02MiB／Installer63.50MiB，精確大小與SHA見本版manifest。

模擬機Current更新至FileVersion1.0.12.2，唯一程序與桌面「黑板 Windows 最新版」，549檔與ZIP逐SHA一致；CUA已查看最終新單排工具列及雷射顯示。正常關閉舊程式前後備份vm/c3、37個Data檔完整保留，現行1份作品／6份垃圾桶；先前c12的6個作品ID均仍存在於此次Data，c12亦保留。資料位置不因封裝改動。

舊p1四包／sidecar、舊Current payload及建置／QA鏡像移除，本批初次交付與曲線補正重封合計3,606,237,162 bytes（約3.61GB），QA資料先逐SHA備份；SDK／Inno／原AppData／Documents及所有作品備份不刪。歷史SHA與文字日誌保留。[封裝清單](ARTIFACTS_2026-10-10_1.0.12-preview.2.json)／[清理紀錄](CLEANUP_1.0.12-preview.2_2026-10-10.json)。


## 2026-10-10 — 最新本機版本 1.0.12-preview.1

Windows **1.0.12-preview.1**（FileVersion1.0.12.1）以Mac **1.0.12／20261010.4**為基準。螢幕工具列改單排820×60 DIP、直式64×688 DIP純圖示，色圓開獨立280 DIP色彩／粗細／透明度面板（3×2色票、垂直滑桿）；短畫面只捲中段，模式及清空／結束可達，去掉固定文字／狀態列與多餘空白。作品庫側欄／卡片及左下視角膠囊延用Mac配置。

補T螢幕文字、Enter換行／Ctrl+Enter完成／Esc取消、雙擊重編輯；普通畫布／螢幕／草稿共用文字右鍵設定，字級8～144、顏色、字型、對齊、透明度及粗斜底線。Shift／框選可多選，批次只改指定欄位、保留混合值與未知富文字欄位、限當頁未鎖定文字／便簽、一筆Undo。僅選取不增加Undo。保留右鍵物件操作／空白穿透、一鍵全清除與Ctrl+Alt+K，以及截圖直接回貼。

本輪Core／手冊**543項**通過；ARM64原生中文草稿、取消／雙擊／換工具、多選右鍵及樣式復原、四邊尺寸、透明層與控制列次序、原作品未污染、Win2D／向量PDF通過。200%DPI實測橫列1640×120px、直列128×1376px，66個來源逐SHA一致。完整對照及限制見[功能表](MAC_1_0_12_PARITY_2026-10-10.zh-TW.md)。

四包已封裝，見[產物與SHA](ARTIFACTS_2026-10-10_1.0.12-preview.1.json)。模擬機已更新C:\HeiBanPreview\Current，桌面「黑板 Windows 最新版」，唯一新版本程序及549個payload逐SHA一致。現有34個Data檔案（含4目前作品）先備份再遷移核對，其他作品／AppData／Documents保留。Mac來源未改；未commit／push／發布。

Mac鎖定使本輪CUA畫面確認未執行；原生合成驗證不等於真實指標／中文IME／多螢幕／混合DPI／觸控筆驗收，x64實機與Installer安裝升級未執行。

本批清理合計1,964,671,701 bytes（約1.96GB），只留最新四包／Current，作品及文字歷史均保留。見[清理摘要](CLEANUP_1.0.12_2026-10-10.json)。

## 1.0.9 交付紀錄（歷史）

## 2026-10-10 — 最新本機版本 1.0.9-preview.1

最新來源及試用封裝改為 Windows **1.0.9-preview.1**（FileVersion 1.0.9.1），對齊 Mac 1.0.9／20261010.1 可操作功能。新增Mac配置作品庫側欄／收藏／篩選／排序／卡片／多選、左下視角膠囊，及四邊停靠／左右直排／可收合的透明螢幕畫布、中文／可改名圖層、多選／套索、膠帶／雷射、富文字與便簽風格、裁切／射線、浮動工具與自訂倒數、頁面／視角管理、多格式匯出。螢幕物件右鍵可複製／副本／刪除／鎖定／層級；主列垃圾桶及Ctrl+Alt+K一鍵全清除，可復原。完整對照見 [功能表](MAC_1_0_9_PARITY_2026-10-10.zh-TW.md)。

螢幕繪圖已改已完成筆跡快取、局部像素讀回／上傳及16ms排程，未落筆懸停不重繪。同一VM原生80樣本舊策略中位66.38ms→5.15ms，18組畫筆／螢光筆／收筆像素比對與雷射清除無殘影通過；這不是實體輸入延遲測量，見 [效能紀錄](SCREEN_CANVAS_PERFORMANCE_2026-10-10.json)。

本輪實際 Core／手冊527項通過，ARM64原生建置與真實 Win2D／PDF／screen API 管線通過；中文 PDF 能以 strict parser 開啟並保留向量及可編輯原稿。透明控制列已查看，未宣稱完整指標／多螢幕／觸控筆／x64 實機或安裝升級通過。

最新四包位於 windows/dist；模擬機部署固定 C:\HeiBanPreview\Current，桌面「黑板 Windows 最新版」。Portable Data 由舊試用版保全後遷移；其他舊作品保存在 windows/recovered-user-data/2026-10-10，AppData／Documents 原作品不刪除。本機舊 preview 包／建置暫存清理約7.83GB，文字紀錄保留；GitHub舊公開版不變，未commit／push／發布。本輪建置／產物／清理的實際結果見 [BUILD_STATUS](BUILD_STATUS.zh-TW.md)及產物清單。

## 先前紀錄（歷史）


更新：2026-10-09。

## GitHub 公開預覽整理

原始碼已公開；本次只整理文件與下載包，不修改 Windows 功能、不重建／不執行測試套件。原創採 GPL-3.0-only 加 [限定 Windows SDK 例外](../LICENSE-WINDOWS-EXCEPTION.txt)，使用者已同意。公開 Installer ZIP 包裝原 EXE，Portable 保持 payload 並加入原始授權；ARM64／x64 各兩包，另附最新版來源 HTML。新公開雜湊見 [下載清單](../../docs/releases/windows-0.1.0-preview.5.assets.json)，原 dist manifest 保留。7個 assets已公開為prerelease，遠端digest／大小及4個主要下載HEAD已核對；來源tag指向991835a。發佈期間後續程式變更未收入該tag，保留本機供後續開發。實際發佈證據見 [公開稽核](../../docs/PUBLIC_RELEASE_2026-10-09.zh-TW.md)。

## 原 preview.5 開發批次與驗收（歷史）

**最新可試用封裝：0.1.0-preview.5**。Codex已整合Antigravity第0／1批來源、修復Windows原生編譯、截圖與圓規／arc邊界，完成ARM64／x64自包含Portable ZIP與安裝檔；不是第2～5批全部功能完成。見 [建置與驗收範圍](BUILD_STATUS.zh-TW.md)、[產物清單](ARTIFACTS_2026-10-09_preview5.json)。

- Windows 11 ARM64模擬機內已查看首頁、隔離空白文件畫布與最終Portable畫布。新版在 `C:\HeiBanPreview\preview5`，Windows桌面捷徑「HeiBan preview.5」，模擬機保留running供使用者試用。Portable作品保存在該資料夾的Data，不覆蓋舊作品。
- Core／手冊 **475項檢查通過**；原生截圖harness確認100×50 BMP裁切與兩次框選取消／清理。四包SHA-256、ZIP必要PRI／執行庫／品牌／手冊、PE架構與空Data檢查通過。
- 第0批：截圖採App自有區域框選，完成直接置入圖片物件，不另存截圖資料夾。請求綁定文件／頁面／視野，取消與逾時處理保留；快速操作列、樣式、工具排序沿用前批修正。
- 第1批：右上浮動導覽／收合、計算機括號與鍵盤／插入、圓規畫布預覽與掃弧、arc起訖控制點與等比縮放、背景計時器、圖片基礎與離線繁體中文手冊已有來源並收入本版。
- 本輪追加：半徑把手改65%位置，鎖定後不攔截筆尖；arc端點優先命中、跨0°連續、邊把手可縮小。修正Count()、命名空間、VirtualKey、尺框呼叫及PS5.1中文腳本編碼。
- **仍待驗收／開發**：完整滑鼠拖曳／色輪／A-B端點／圖片旋轉／尺支點／截圖置入操作、完整浮窗及自訂計時設定、x64實機、安裝升級／解除安裝、手寫硬體與性能。CUA在Parallels內的點擊未觸發新增視窗，不能據此宣稱UI回歸全部通過。
- W-S01入口位置已定：右上導覽列閱讀模式旁的螢幕圖示、首頁完整名稱按鈕，工具列更多備援；功能本體與可操作入口尚未實作，詳見主計劃第6節。來源手冊第18節已更正為規劃狀態；既有preview.5包內舊手冊文字待下次封裝更新。
- 第2～5批仍未完成：雷射／遮題／透明螢幕畫布、結構化筆記、媒體與管理、隱私與線上。下一輪按 [開發計劃](WINDOWS_DEVELOPMENT_PLAN_2026-10-09.zh-TW.md) 推進。

本版沿用preview.4的直線／箭頭A-B、圖片把手、選取顏色、作品列收合與尺邊支點來源。歷史複核見 [Antigravity進度紀錄](ANTIGRAVITY_PROGRESS_REVIEW_2026-10-09.zh-TW.md)，歷史完成聲明不等於全部互動已驗收。

維護：[開發日誌](DEVELOPMENT_LOG.zh-TW.md)、[問題紀錄](ISSUE_HISTORY.zh-TW.md)、[決策](DECISIONS.zh-TW.md)、[架構](ARCHITECTURE.zh-TW.md)。

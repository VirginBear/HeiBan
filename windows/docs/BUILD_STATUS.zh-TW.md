# Windows 建置與發行記錄

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

本輪Core Release680項退出0；ARM64最終Release publish成功，原生隔離r7 result／screen-result皆success，PDF strict1頁／4原稿通過。76個client／Core／資源／封裝檔與native及package鏡像逐SHA一致；最終兩架構Portable／Installer四包退出0，兩次Successful compile及PARITY_PACKAGING_COMPLETE，無compiler warning／error。先前浮窗失敗與中間重封日誌保留，詳見[互動稽核](WINDOWS_INTERACTION_REVIEW_2026-10-10.zh-TW.md)。

四包SHA sidecar、PE ARM64／x64、必要PRI／runtime／品牌、當前手冊／README與25份授權逐byte通過；ZIP無使用者Data或QA作品。ARM64 Portable88.46MiB／Installer61.00MiB，x64 Portable91.04MiB／Installer63.52MiB；精確大小與SHA見[產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.3.json)。

Current為FileVersion1.0.12.3，唯一程序及桌面捷徑、549payload檔逐SHA通過。51Data檔先備份vm/c5再遷移，2目前作品／8垃圾桶與歷史作品保全；僅清已核對舊payload／鏡像，QA資料逐SHA備份。未公開發布、未commit／push、未改Mac。Mac鎖定，最終硬體點擊、完整IME／混合DPI／多螢幕／手寫、x64實機及安裝升級未執行。

[本輪清理紀錄](CLEANUP_1.0.12-preview.3_2026-10-10.json)。

本輪舊包／payload／鏡像合計移除3,612,977,725bytes（檔案大小總和），只留最新四包；QA資料先逐SHA備份i3a～g，SDK／Inno及使用者資料保留。

## 2026-10-10 — 1.0.12-preview.2 性能修正

Windows FileVersion1.0.12.2，Mac基準1.0.12／20261010.4；Core Release568項退出0，原生ARM64 Release publish退出0。最終隔離qa-perf12p2-final的result及screen-result同輪success；300物件scene31.3325→1.5991ms／P9550.7451→4.9077ms；螢幕80樣本30.331→4.4957ms／P9556.8714→9.9080ms；像素9＋18筆跡／3旋轉拖曳幀等價。PDF strict1頁、2BT／382cubic／75line及4物件有效原稿stream通過；原作品未污染。

71個client／Core最終來源與current-source逐SHA一致。Package-Portable／Installer兩架構四包退出0，兩次Successful compile／completion marker，無CS／MSB／NU／WMC warning或error。README在封裝啟動後更新導致ARM64 ZIP首輪仍p1；新增包內README assert抓出、停止部署，使用相同已驗證來源重封ARM64，不略過檢查。

交付完成：兩架構四包SHA／架構／PRI／runtime／品牌／當前手冊／README及25份授權逐byte核對通過、ZIP空Data／無QA作品。ARM64 Portable88.44MiB／Installer61.00MiB；x64 Portable91.02MiB／Installer63.50MiB，精確大小與SHA見本版manifest。

模擬機Current更新至FileVersion1.0.12.2，唯一程序與桌面「黑板 Windows 最新版」，549檔與ZIP逐SHA一致；CUA已查看最終新單排工具列及雷射顯示。正常關閉舊程式前後備份vm/c3、37個Data檔完整保留，現行1份作品／6份垃圾桶；先前c12的6個作品ID均仍存在於此次Data，c12亦保留。資料位置不因封裝改動。

舊p1四包／sidecar、舊Current payload及建置／QA鏡像移除，本批初次交付與曲線補正重封合計3,606,237,162 bytes（約3.61GB），QA資料先逐SHA備份；SDK／Inno／原AppData／Documents及所有作品備份不刪。歷史SHA與文字日誌保留。[封裝清單](ARTIFACTS_2026-10-10_1.0.12-preview.2.json)／[清理紀錄](CLEANUP_1.0.12-preview.2_2026-10-10.json)。

Mac已解鎖，CUA看見新版首頁與單排工具列，但QA卡片及最大化點擊均無畫面變化，不宣稱硬體互動驗收。完整實體滑鼠／手寫／IME／混合DPI／多螢幕、跨App剪貼簿、x64實機與安裝升級未完成。首輪CS0103命名空間缺失及衍生XAML錯誤有紀錄；未commit／push／發布。詳細性能原因／數據與界線見本輪稽核。


## 2026-10-10 — 1.0.12-preview.1 本機交付

基準Mac1.0.12／20261010.4；Windows FileVersion1.0.12.1。只改Windows，未公開發布。Core Release543項通過；Windows11 ARM64原生Release publish退出0；Package-Portable.ps1／Package-Installer.ps1依win-arm64、win-x64完成四包，.NET10.0.401／Inno6.7.3；最後packaging完整日誌退出0、兩次Successful compile與完成marker，未有CS／MSB／NU／WMC warning或error。

四包SHA及sidecar一致。Portable主程式PE分別ARM64 0xAA64／x64 0x8664，必要PRI／runtime／Win2D／品牌／當前手冊逐byte／25份授權、空Data及無QA作品檢查通過。ARM64 Portable88.41MiB、Installer60.97MiB；x64 Portable90.99MiB、Installer63.50MiB。精確大小與SHA見[清單](ARTIFACTS_2026-10-10_1.0.12-preview.1.json)。封裝mirror與host66個來源逐SHA一致。

原生隔離qa-parity12-final：中文多行、草稿未提前提交、取消／雙擊／換工具提交、Shift文字多選／右鍵保留多選、選取無Undo、批次樣式Undo通過；普通畫布共用右鍵與草稿通過。工具列200%DPI橫1640×120、直128×1376px，單排／純圖示／固定清空結束、280DIP色彩面板及Flyout不受root限制通過；四方向重排保留handlers。原文件4物件未污染。PDF strict解析1頁、2BT／382cubic／75line及4物件原稿增量stream通過。

沿用局部讀回性能策略；最終原生同步80樣本中位28.4176ms→0.7467ms／P9544.799→1.3027ms，18組逐byte像素等價與雷射清除無殘影通過，非硬體端到端延遲。見[本輪效能](SCREEN_CANVAS_PERFORMANCE_1.0.12_2026-10-10.json)。

部署Current前正常存檔退出、備份到recovered-user-data/2026-10-10/vm/c12並逐SHA核對；34個Data檔含4目前作品保留，原AppData／Documents不刪。Current FileVersion1.0.12.1、桌面捷徑及唯一新程序、549檔與ZIP逐SHA一致。舊1.0.9四包及其sidecar清理，SHA文本封存archive-before-1.0.12。mirror與QA資料先保全再清理，精確根及bytes見本輪清理紀錄。

本輪Mac鎖定，CUA無法查看最新畫面。完整實體滑鼠／觸控筆／中文IME／混合DPI／多螢幕、剪貼簿跨App往返、Intel／AMD x64實機及Installer安裝升級未執行。驗證首段要求初始橫列，重用已有左側停靠偏好的QA根曾失敗；另建乾淨QA資料根後完整成功，失敗文字紀錄保留。

本批清理合計1,964,671,701 bytes（約1.96GB），只留最新四包／Current，作品及文字歷史均保留。見[清理摘要](CLEANUP_1.0.12_2026-10-10.json)。

## 1.0.9 建置紀錄（歷史）

## 2026-10-10 — 1.0.9-preview.1 本機交付

基準：Mac 1.0.9／20261010.1現行可操作功能，Windows FileVersion 1.0.9.1。只修改Windows，未commit／push／公開發行。對照及未交付原型見 [功能表](MAC_1_0_9_PARITY_2026-10-10.zh-TW.md)。

實際驗證：本輪Core／手冊Release **527項通過**；Windows 11 ARM64、.NET SDK10.0.401原生Release publish成功。隔離合成文件的真實Win2D PNG、WebView2向量／中文PDF、Win32透明screen session／恢復檔通過。PDF以pypdf strict開啟，保留2個BT文字段／382個cubic／75個line及可編輯4物件JSON，Poppler視覺檢查中文字與底線。layer原生結果為中文名稱，不顯示UUID。

螢幕控制列：原1080×210 DIP改680×80，收合680×48。200%DPI實測1360×160／1360×96px，展開占用面積少約75%；淺色半透明、兩排小圖示／六色票／綠色滑桿、更多及收合。真實VM畫面已查看。模式切換後HWND順序保持控制列高於透明輸入層；設定Flyout可超出root，不受80 DIP限制。

介面追加：作品庫採Mac側欄、收藏、格式／排序、190 DIP卡片與多選；視角及頁面移到左下浮動膠囊。螢幕控制列可四邊停靠，左右154×740 DIP直排、收合154×48；清除／收合／結束固定底部。物件右鍵選單保持作畫，可複製／副本／刪除／鎖定／排序；空白右鍵才穿透。垃圾桶及Ctrl+Alt+K單次清空，全清除可單步復原。原生檢查四方向尺寸／收合、值及handlers保留、右鍵與副本／刪除／清空Undo通過；實際拖曳、剪貼簿跨App往返未執行。

螢幕作畫：原全屏讀回每幀22,038,912 bytes、33ms排程且hover也重繪。改committed GPU快取、live／收筆／雷射dirty bounds，Win2D局部GetPixelBytes＋DIB逐列複製＋UpdateLayeredWindowIndirect，16ms排程且普通hover不重繪。80個同程序同步合成樣本，舊策略中位66.3760ms／P95 129.1576ms，新策略5.1510ms／P95 17.1063ms；讀回1,763,112,960→1,111,704 bytes，減少99.94%。18組畫筆／螢光筆／收筆逐byte相等，雷射兩幀32,600 bytes且清除無殘影。數字只描述此VM渲染測量，不能視為實體輸入端到端延遲／fps，詳見 [效能紀錄](SCREEN_CANVAS_PERFORMANCE_2026-10-10.json)。

封裝：Package-Portable.ps1／Package-Installer.ps1依win-arm64及win-x64執行，Inno6.7.3安裝檔與自包含ZIP共四包；SHA sidecar、必要PRI／runtime／Win2D／品牌／當前手冊／完整授權、ARM64 0xAA64／x64 0x8664及空Data檢查。實際清單見 [產物與SHA](ARTIFACTS_2026-10-10_1.0.9-preview.1.json)，dist只保留目前四包及SHA文本。

部署：最終ARM64 ZIP更新C:\HeiBanPreview\Current，Windows桌面「黑板 Windows 最新版」供試用。更新前備份舊Current Data、正常存檔關閉，再逐檔SHA複製到新版；32個Data檔案逐SHA保留（4個目前作品檔，含垃圾桶／偏好）；549個部署檔案與ZIP逐SHA一致、唯一新版本程序及捷徑通過。舊Portable／安裝AppData／Documents資料保全於windows/recovered-user-data/2026-10-10，原AppData／Documents不刪除。

清理：舊封裝、已不用VM建置／publish／QA鏡像移除，文字日誌／SHA／錯誤記錄保留；開發SDK及Inno保留，作品不列為廢棄暫存。精確移除bytes／roots與Data驗證存本機build-logs。本版取代1.0.8-preview.1／.2；累計移除7,832,766,940 bytes（約7.83GB），見 [清理摘要](CLEANUP_2026-10-10.json)。GitHub舊公開release未變。

驗收界線：**完整實體滑鼠／觸控筆／多螢幕／跨App操作、Intel／AMD x64實機、Installer安裝升級與性能硬體量測未執行**。CUA只有Parallels外層AX，先前點擊未觸發按鈕；native合成樣本不等於全部UI互動通過。失敗／修正記錄見ISSUE_HISTORY與DEVELOPMENT_LOG；完整packaging compiler輸出本機保存，不收錄作品正文。


## preview.5 歷史建置紀錄

2026-10-09：完成Windows 11 ARM64原生Release publish及ARM64／x64的Portable ZIP、Inno Setup安裝檔；整輪封裝退出碼0。四包SHA-256與sidecar一致，ZIP必要PRI／執行庫／圖示／品牌／離線手冊非空，主程式PE為ARM64 `0xAA64`／x64 `0x8664`，ZIP沒有預載作品。大小與雜湊見 [preview.5產物清單](ARTIFACTS_2026-10-09_preview5.json)。

修復：自有區域截圖直接置入、請求取消隔離、圓規筆尖／半徑把手重疊、arc邊縮小與跨0°端點、前批UI編譯錯誤及PowerShell中文腳本編碼。計算機／計時器／導航／手冊已收入封裝。475項Core／手冊檢查退出碼0；原生截圖harness的100×50頂向32bit BMP裁切（20054 bytes）及兩次取消／清理通過。

實際查看ARM64首頁、隔離空白文件畫布及最終免安裝版畫布。最終ARM64 ZIP已解壓至VM `C:\HeiBanPreview\preview5`，桌面建立「HeiBan preview.5」捷徑，VM保留running供試用。沒有匯入舊作品到新Data、未強制結束其他舊版程序。

驗收界線：完整滑鼠／色輪／截圖成功置入、計算機／計時器所有互動、x64實機、安裝／升級及性能尚未驗收。CUA點擊新增沒有開啟對話框，改用命令列開啟新建空白文件確認畫布顯示；不能把核心檢查／BMP裁切當作完整UI驗收。第2～5批功能仍未完成。首次編譯與封裝編碼失敗記錄保存在 `build-logs/preview5-arm64-attempt1.log`、`preview5-packaging-attempt1.log`；成功ARM64編譯／封裝主流程見 `preview5-arm64.log`、`preview5-packaging.log`。PowerShell5.1 Transcript只保存主流程訊息，未完整保存原生compiler stdout。

## preview.4 歷史建置紀錄

2026-10-08 修正 A／B 端點、圖片變形、選取形狀色彩、作品列自動收合與尺邊支點；Windows ARM64 Release 編譯及 216 項純 C# 幾何檢查通過。完整滑鼠／色輪互動仍待驗收，詳見 [本輪紀錄](INTERACTION_FIXES_preview4.zh-TW.md)。

ARM64／x64 自包含 Portable ZIP 與 Inno Setup 安裝檔已全部完成，最終封裝退出碼 0；四個檔案 SHA-256 與 sidecar 一致，ZIP 必要 PRI／執行庫及 PE 架構檢查通過。最終建置紀錄未出現 CS／MSB／NU／WMC warning 或 error。詳見 [preview.4 產物清單](ARTIFACTS_2026-10-08_preview4.json)。

## preview.3 歷史建置紀錄

2026-10-08 對照目前 Mac 介面重整 Windows 工具列、原生圓形色輪、即時屬性及尺規；ARM64 Release 編譯成功，新版工作區已在 Windows 11 ARM64 顯示。兩端旋轉／色輪／停靠等完整互動與效能仍待驗收。詳細變更見 [介面修正](UI_PARITY_preview3.zh-TW.md)。

ARM64／x64 各完成 self-contained publish、Portable ZIP 與 Inno Setup 安裝檔，整輪退出碼 0。四個產物的 SHA-256 與 sidecar 相符；Portable 的主程式 PE machine 為 ARM64 `0xAA64`／x64 `0x8664`，均包含非空 `HeiBan.pri`、執行庫、品牌資源與 preview.3 README。詳見 [產物清單](ARTIFACTS_2026-10-08_preview3.json)。preview.2 的 EXE／ZIP／hash 封存在 `windows/dist/archive/0.1.0-preview.2/`，不移動使用者已解壓的作品目錄。

隔離預覽在 `C:\HeiBanBuild\ui-preview3`，採用原作品副本；預覽期間出現已儲存作品，已另存可開啟的 `.heiban` 到 Windows 使用者 `Documents\HeiBan\Preview-2026-10-08`。沒有強制結束仍在使用的程序。這次查看了真實工作區；完整互動、x64 實機、安裝升級與效能仍待驗收，未執行自動測試。

## preview.2 啟動修復

2026-10-08 修復發行包漏掉應用程式 `HeiBan.pri` 的啟動失敗，重新產出 ARM64／x64 安裝版與免安裝版。Windows 11 ARM64 的兩種新版均已實際查看首頁。詳見 [啟動修復紀錄](STARTUP_FIX_preview2.zh-TW.md) 與 [新版雜湊清單](ARTIFACTS_2026-10-08_preview2.json)。舊包已移至 `windows/dist/archive/0.1.0-preview.1/`，不可再用作可啟動的發行版。

## preview.1 歷史建置紀錄

以下保留原始建置與當時的驗收界線；本次使用者回報證實舊包的主視窗啟動失敗。

日期：2026-10-08（Asia/Taipei）。版本 **0.1.0-preview.1**。

## 完成的工程步驟

- 閱讀原 Windows 骨架／架構／路線與共用 JSON 契約；發現空按鈕、未使用 InkPresenter 與未量測的性能承諾，已修正實作及文件狀態。
- 在本機 Parallels Windows 11 ARM64 VM 安裝獨立開發工具 `.NET SDK 10.0.401` 與官方簽署的 Inno Setup 6.7.3。SDK ZIP 依官方 release metadata 的 SHA-512 驗證；未改系統 PowerShell execution policy、未信任開發憑證。
- 原生 ARM64 Release `dotnet build` 成功，最後明確建置報告為 **0 warnings / 0 errors**。
- x64、ARM64 各完成 self-contained publish、Portable ZIP 及 Inno Setup 安裝檔；最後整輪退出碼 0，compiler log 未出現 CS／NU／WMC／MSB warning 或 error。
- Portable ZIP 含 `.NET coreclr.dll`、`Microsoft.ui.xaml.dll`、Win2D、品牌資源、`portable.dat` 與 Data 目錄。PE machine 分別為 ARM64 `0xAA64`、x64 `0x8664`；ICO PNG 為 256×256。這些是產物結構檢查，不能代替啟動／功能驗收。
- 四個包的 SHA-256 與同名 sidecar 一致，精確大小／hash／架構清單保存於 [ARTIFACTS_2026-10-08.json](ARTIFACTS_2026-10-08.json)。
- ARM64 ZIP 解壓到 Windows 使用者暫存目錄、指定獨立資料目錄後啟動自己的 HeiBan 預覽程序；後續程序仍存在，最近 Application error log 無該 HeiBan 錯誤。這只確認程序啟動，沒有證明首頁或繪圖互動正常。
- 已結束自己的隔離預覽程序，確認預覽 Boards 為空後清除暫存 App／資料；保留編譯工具與建置快取供後續開發。
- 原始碼 `git diff --check` 通過。未修改本輪 Mac 程式或作品、沒有 Windows 預載示範作品。

## 產物

位於 `windows/dist/`，不放到 `macos/dist/` 或 Web `dist/`。

| 檔案 | 大小 |
| --- | --- |
| `HeiBan-Setup-0.1.0-preview.1-arm64.exe` | 60.5 MiB |
| `HeiBan-Setup-0.1.0-preview.1-x64.exe` | 63.0 MiB |
| `HeiBan-Windows-Portable-0.1.0-preview.1-win-arm64.zip` | 87.5 MiB |
| `HeiBan-Windows-Portable-0.1.0-preview.1-win-x64.zip` | 90.1 MiB |

## 尚未確認的範圍

- CUA 介面工具回報 Mac 鎖定且無法自動解鎖；已請使用者解鎖，因此本輪沒有查看 Windows 畫面、操作驗收、安裝／解除安裝驗收或效能量測。
- 未新增／執行自動測試，未執行跨平台 fixture 往返。
- x64 binary 在 ARM Windows 上成功建置，但尚未在 Intel／AMD 實體 Windows 執行；Surface／Wacom 等手寫硬體未驗收。
- 產物未 Authenticode 簽章、未 MSIX；GitHub workflow 只寫入本機，未推送或在雲端執行。
- PDF／SVG／完整便簽／富文本／Google OAuth／筆壓輪廓等移植仍在 [工作清單](WORKLIST.zh-TW.md)。這是可供後續驗收的開發預覽，不能宣稱與 Mac 全功能相同或達到「8ms／144 FPS」。

## 開發環境隔離

Windows SDK／編譯器放在 VM 的 `C:\HeiBanBuildTools`，本地編譯副本／快取放在 `C:\HeiBanBuild\source`；專案完整原始碼與可搬移發行包在本機 `windows/`。開發 VM 在本輪起始為 suspended，建置結束後恢復 suspended，避免長時間占用 Mac 資源。

## 公開文件中的日誌邊界

上述 build-logs 檔保留本機，避免上傳含機器環境的原始輸出；公開 Git 只有建置摘要、錯誤原因／修正與驗收界線。公開下載清單另見 docs/releases 的 preview.5 assets manifest，與原內部 dist 的 SHA 不同。

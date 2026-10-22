# Microsoft Store 1.0.16.0更新準備 — 2026-10-22

## 開工及授權
- 起點c08a362dd9738c040bdb056acc72f7e407d3b0a0；保留CURRENT_STATUS／DEVELOPMENT_LOG／ISSUE_HISTORY既有YouTube未提交內容及三份YouTube新文件，只處理Windows。
- 使用者指示「OK 那我們打包好 我準備更新上架」，並明確回覆「採用1.0.16／1.0.16.0」。本批可以進版與製作正式Store提交包；不等於助手可以自行上傳／提交或宣稱Microsoft通過認證。
- 已讀開發入口、Windows目前狀態／架構／問題／決策與AGENTS。既有1.0.15.0及歷史Store套件保留byte，不覆寫。
- 不新增或執行App／實作測試／WACK；使用既有Store封裝流程的建置與套件／資源完整性核對。使用者本次表示準備更新，不補寫未曾提供的完整實機驗收結果。

## 本次累積內容
- 工具預設全開、圖示與文字，筆刷／線條樣式／清除本頁納入常用；保留其他自訂偏好。
- 十語完整操作說明與單頁無邊界可編輯練習，保留使用者既有指南作品。
- 完成自由筆不自動出現選取框；改善筆跡快取與輸入處理。磁鐵只作用幾何建構與圓規定位，不扭曲自由筆交叉軌跡。
- 兩畫布圖形選單共用描邊九宮格；圓形橡皮擦與板擦使用順序背景批次／隔離preview，放開一筆Undo及保存邊界等待；板擦長度調整。
- Windows多尺寸ICO與Store深／淺色unplated圖示資源，修正Shell底板資源缺漏。實際Shell／多DPI驗收依後續使用者結果，不宣稱完整通過。

## 實際交付
商店上傳包`dist/store/HeiBan-Store-1.0.16.0-x64-arm64.msixbundle`已完成，196597450bytes／SHA256 `57080fb301f2557bae8977f863877c7b91a40bae4eabed96f6f4813c9040e0be`，來源fa2582325c90483185e09f5d1583e48dc6106e16。x64／ARM64建置耗時00:01:55.58／00:01:47.10，各0warning0error；281來源SHA、ZIP CRC、套件身分／架構／內含包SHA、十語手冊／指南與42個targetsize圖示核同，兩架構實際resources.pri識別深／淺色unplated。原12份舊Store套件及28份歷史檔SHA均不變。未執行App／實作測試／WACK或Store安裝升級；助手未上傳／送審／發布。

## 命令與結果
- `store-1.0.16-prepare.py`先建立28份舊Store檔SHA快照、私人受保護欄位快照；GUIDE status九個來源語言改1.0.16、Build-UserGuides.py生成10語25章64段與練習。
- `Package-Store.ps1 -Configuration Release -DotnetPath windows/.build/tools/dotnet/dotnet.exe -FormalVersionApproved`完成兩架構SDK build／manifest validation及MakeAppx bundle；獨立artifacts樹避免混入Portable輸出。未呼叫App／WACK／安裝或測試入口。
- `inspect-store-1.0.16.py`讀來源／新MSIX／bundle及舊產物，核對SHA／CRC／PE架構、runFullTrust唯一功能、10語嵌入catalog與guide byte、練習單頁infinite25章29工具、ICO14尺寸及Store51 PNG。對兩個實際包的resources.pri以固定SDK10.0.26100.8249 MakePRI dump，確認UNPLATED／LIGHTUNPLATED與14個TargetSize；不是僅檢查來源檔名。
- 本批沒有刪除作品、試用資料、歷史Store包或GitHub已發布資產；原YouTube18行未提交內容及三份YouTube新文件保留。版本變更依使用者明確回覆，無同版覆寫。

## 使用者接續提交
1. Partner Center開啟HeiBan既有產品的更新提交，套件頁上傳`HeiBan-Store-1.0.16.0-x64-arm64.msixbundle`一個檔案即可，同包包含x64與ARM64。
2. 套件處理完成後確認顯示1.0.16.0。十語「此版本新增功能」可用同目錄STORE_WHATS_NEW_1.0.16_2026-10-22.md；既有產品說明、免費售價與隱私文字沿用。
3. 若後台要求再次說明runFullTrust，可沿用STORE_RUN_FULL_TRUST_2026-10-12.zh-TW.md短版；本次未增加新受限功能。
4. 完成後由使用者按提交認證。此檔是未自行簽章的Store提交包，正式Store簽章／認證／發布依Microsoft結果。

## 未驗收與限制
- 使用者核准進版／準備更新有明確對話證據；未收到本批完整測試清單，不回填全部通過。App／自動或實作測試／WACK／Store安裝升級卸載／GPU與新性能採樣未執行。歷史實機與未驗收事項仍依各批日誌。
- 螢幕畫布CPU回讀、大scene重建、背景快照／Undo成本仍是已知限制，未承諾效能上限。商店MSIX與Portable資料位置不同，使用者既有作品不隨套件上傳或自動跨通道搬移。
- 安裝包已準備完成不表示已上傳／認證／上架；私人microsoft_store實際後台狀態保持原紀錄，新增1.0.16準備紀錄分開交接。

# 板擦更多入口與鏡像 — 2026-10-15

## 開工
- 基準bcf1022。開工已有CURRENT_STATUS／DEVELOPMENT_LOG／ISSUE_HISTORY三份未提交紀錄與三份YouTube新文件，保留並排除本批提交。
- 使用者要求工具列「更多」可開啟板擦；保留現有原創圖，鏡像成左高右低。只改Windows，1.0.14開發候選不進版。
- 先追蹤主畫布更多選單及板擦顯隱設定來源，確認入口與既有偏好保存共用；鏡像必須同時作用於圖片、抓取、提示及擦除，不增加第二套擦除演算法。
- 本批測試未執行。開始時沒有graphify圖譜，針對既有功能直接查原始碼，不建立整庫圖譜。

## 實作進度
- 原PNG不重畫、不修改；Image以中心ScaleX=-1鏡像，保留已接受的材質與比例。起初打算imagegen處理，確認只是既有App的顯示方向後採原生transform，避免再次生成改變外觀。BoardEraserGeometry以x→1-x共用12點輪廓，未transform指標宿主，抓取偏移不變。
- ShowMoreToolsMenu新增已翻譯的「顯示板擦」勾選入口，與右鍵隱藏共用SetBoardEraserVisibleAsync；保存失敗還原偏好並顯示錯誤。首頁批次設定沿用同一BoardEraserVisible欄位。九份手冊來源新增更多入口與鏡像說明，zh-CN由產生器轉換。
- 查找時PowerShell萬用路徑及不存在Controls／Toolbar.cs造成讀取錯誤；改以rg限定MainWindow*.cs後定位Chrome.cs，無資料變更。

## 執行中限制
- Win32_Process確認上一版topdown-eraser-r1仍在使用。未終止程序、未讀搬作品、未清舊版；已請使用者正常保存關閉後再接續，否則新版保持空白Data，舊版完整保留。

## 交付結果
本機試用`dist/trials/HeiBan-Windows-Portable-1.0.14-eraser-entry-2026-10-15-r1-win-x64.zip`，132586851bytes／SHA256 `2cf8988e499f0c404ceda37445c2607e5866c55d0c6f445155408a65fe29785a`，來源`b2f9c3d7abe7a0726971a7ed53ca187893f3d51b`。App／Updater publish退出0，ZIP CRC／573payload／162source SHA、兩EXE x64及十語核同。使用者已正常保存關閉，確認無HeiBan程序後接續27個Data檔／24345830bytes，逐SHA相同；ZIP空Data。舊試用已備份到`dist/trial-data-backups/20261015-145134-a33251e2`後清理455068005bytes；Store1.0.12 SHA保持。最終EXE及實作測試未執行，待使用者實機驗收。
實際執行：git status／fetch（公開前進1落後0、私人0/0）、Build-UserGuides.py（十語25章62段）、git commit、Package-PortableTrial.ps1 -Runtime win-x64 -Label eraser-entry-2026-10-15-r1、只讀ZIP完整性腳本、Data逐SHA接續、Clear-ObsoleteTrials.ps1 -KeepTrial新試用名，均完成；JSON證據以前綴ERASER_ENTRY_MIRROR保存。
使用者回覆「已儲存並關閉，接續作品」後再核程序，才執行接續與舊包清理；沒有終止其程序。原PNG SHA未改，只有顯示與共用幾何鏡像。十語既有「顯示板擦」字串重用，不增加catalog key。
App／實作測試／ARM64封裝／Store／Release未執行。鏡像後觸點、更多顯隱持久化、Undo／取消及DPI仍待使用者實測。既有YouTube未提交內容保留。

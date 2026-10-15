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

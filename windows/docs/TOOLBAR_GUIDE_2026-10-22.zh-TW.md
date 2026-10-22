# 常用工具與完整無邊界操作說明 — 2026-10-22

## 開工
- 基準ca70369；保留原有三份平台文件未提交的YouTube段落及三份未追蹤YouTube文件。
- 使用者要求：預設常用含筆刷／線條樣式、圖示與文字；說明作品改無邊界並涵蓋全部工具。Windows限定，同系列1.0.15 metadata，不自動進版。
- 已讀入口／Windows規則、狀態、架構、問題與決策。既有指南範例實際為notebook三頁，需改infinite單頁；指南有與範例相矛盾的舊文字，需同步修正。
- 未執行實作測試，先記錄實作理由與封裝結果；不套用前批數字。

## 進行中
- 預設CommonTools集中為八項（含brush／dash），新建及reset圖文模式；舊常用完全相同才補入兩項，原顯隱順序全預設且icons才升級labels。新增DefaultPresentationRevision=1並在兩畫布設定交接保留。自訂常用／排序／顯隱不強制重設。
- 操作指南v2為單頁infinite，25章64段完整手冊，29項catalog工具全部分章列名；25章節圖釘可定位，筆跡與幾何保留可編輯。無尺寸邊界。不覆寫v1、不重建已刪v2。
- `python windows/scripts/Build-UserGuides.py`成功，十語25章64段；沒有擷取新App畫面或讀作品內容。既有預設檢查一處改期待labels，未新增或執行測試。
- 調查輔助輸出首次cp950無法印阿拉伯文，明確PYTHONIOENCODING=utf-8後完成；一次rg字面萬用路徑error123改以目錄與-g過濾。

- 第一輪portable封裝成功；靜態座標檢視發現章節圖釘放正文中，改放章節前留白，避免遮字，重新產生資源並以r2重新封裝。前一輪不交付。零內容文件換行修正只處理本批新增CRLF，原YouTube未提交18行保留。

## 最終封裝與資料接續
- `Package-PortableTrial.ps1 -Runtime win-x64 -Label toolbar-guide-2026-10-22-r1`成功；調整圖釘留白後以`-Label toolbar-guide-2026-10-22-r2`重新publish與封裝成功。最終來源cdd54758eb281bd71db4cb2b99152a913b5843c5；沿用1.0.15，沒有Store／Release或正式進版。
- 最終ZIP 132760672bytes／SHA256 82aefc4b7410ff39127f36093a7a598879d09313f9f180061d116bc97f841334；靜態CRC、583payload與173source SHA、x64 PE、十語指南SHA符合。每語單頁infinite、25個章節圖釘、29項工具映射；ZIP使用者Data=0，詳TOOLBAR_GUIDE_PORTABLE_ARTIFACT／INSPECTION_2026-10-22.json。
- `toolbar-guide-handoff.ps1`首次偵測舊版正在執行，正常停止，沒有複製或清理。使用者回覆「已儲存並關閉，接續作品」後重新確認程序未執行，接續38檔24479726bytes，全部SHA符合。v1範例及使用者修改原樣接續；v2由新版本首次啟動加入，不覆寫舊作品。
- `Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.15-toolbar-guide-2026-10-22-r2-win-x64`完成；清理兩份舊試用runtime／ZIP，釋放911697865bytes、保留資料24479726bytes，備份位置與GitHub公開資產核對見TOOLBAR_GUIDE_TRIAL_CLEANUP_2026-10-22.json。原Store1.0.15.0 bundle SHA仍a889482ff3aa171569ce415fc285340b26742528af4306a3e0a0e3d6fa07eb96，沒有刪商店／公開發行。
- 實際未執行：App／UI／實作測試／硬體與DPI驗收／新截圖／性能benchmark／Store上傳與發布。本批只生成資源、編譯封裝與檔案完整性核對；不聲稱指南排版或操作已完成實機驗收。待確認：新舊偏好遷移、自訂保留、兩畫布常用與圖文模式、v2首次出現與刪後不重建、無邊界全文閱讀／圖釘定位／練習物件。

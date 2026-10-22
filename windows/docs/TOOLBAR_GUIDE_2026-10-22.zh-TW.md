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

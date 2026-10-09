# Windows 目前開發狀態

更新：2026-10-09。

## GitHub 公開預覽整理

原始碼已公開；本次只整理文件與下載包，不修改 Windows 功能、不重建／不執行測試套件。原創採 GPL-3.0-only 加 [限定 Windows SDK 例外](../LICENSE-WINDOWS-EXCEPTION.txt)，使用者已同意。公開 Installer ZIP 包裝原 EXE，Portable 保持 payload 並加入原始授權；ARM64／x64 各兩包，另附最新版來源 HTML。新公開雜湊見 [下載清單](../../docs/releases/windows-0.1.0-preview.5.assets.json)，原 dist manifest 保留。實際發佈進度見 [公開稽核](../../docs/PUBLIC_RELEASE_2026-10-09.zh-TW.md)。

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

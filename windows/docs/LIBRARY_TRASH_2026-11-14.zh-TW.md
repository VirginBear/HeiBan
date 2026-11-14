# Windows 作品垃圾桶保留與清理

依使用者回饋，補上手動永久刪除及 30 天保留政策。開工 git status 已核對，現有三份已修改及三份未追蹤 Windows 文件須保留。程式、手冊及驗證規劃限 Windows。

實作採新版 invariant UTC 時間戳及同一資料根的垃圾桶鎖。舊資料首次啟用保留政策後有完整 30 天，可還原；清理只處理垃圾桶中的已知作品檔、備份、縮圖與索引。讀取失敗或辨識不出的作品留存供救援。新版首頁右鍵／⋯ 顯示永久刪除，取消為確認視窗預設按鈕。手冊與字串已重新生成十語，未重建使用者既有操作指南作品。

已執行 Core.Tests Release，6,883 項通過，含 14 項隔離垃圾桶斷言。初次 Windows x64 Release 建置 0 警告、0 錯誤；最終試用封裝會重新編譯後續安全修整。檢查命令的首次路徑查詢使用了 PowerShell 不支援的 shell 展開，改用明確路徑後完成。未用實際使用者作品執行刪除或操作測試。

x64 免安裝封裝成功。執行 Package-PortableTrial.ps1 -Runtime win-x64 -Label trash-retention-2026-11-14-r1，來源 8a300ea。重新計算 ZIP CRC、724 份 payload SHA-256 與 ZIP SHA，封裝清單記錄 424 份來源。ZIP 為 100,528,866 bytes，SHA-256 45e9d0cb5ad8f051d6a971879647d946a2ea254c8dd3d5e20837262cae090a40，資料根沒有既有作品。檔案在 windows/dist/trials/HeiBan-Windows-Portable-1.1.4-trash-retention-2026-11-14-r1-win-x64.zip。維持 1.1.4 開發試用標籤，未執行 GUI 互動、商店封裝、發布及舊包清理。

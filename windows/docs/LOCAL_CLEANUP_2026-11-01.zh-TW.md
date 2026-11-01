# Windows本機清理與1.1.0送審紀錄 — 2026-11-01

使用者回報「已經送驗證了」，並要求清理不需要的軟體與雜物。將1.1.0送審狀態記為使用者提供，未查Partner Center、未宣稱已通過。範圍僅Windows本機可重建產物／舊未發布試用執行檔；保留原始碼、歷史文件、使用者資料、參考軟體、SDK工具與已發布／送審正式套件。每項刪除先盤點引用、路徑、資料與雜湊，結果待追加。

開工git status只有三份既有YouTube未追蹤文件，保留；未偵測到執行中的HeiBan。不可對整個.build或trials盲目遞迴刪除，因為可能含有作品及證據。

## 盤點與保護

試用29份、約10.94GiB；建置暫存多份每個約1.2GiB，Store約4.16GiB全部保留。GitHub API實際列出發布資產，清理器仍會再次核對。舊試用ZIP預檢皆無Data／未知檔案，三份失敗試用缺少inventory；清理器新增明確PreserveTrials參數跳過這三份，保留未知內容，其他舊試用先保存Data／未知／變更檔並驗SHA再移除程式。保留最新1.1.0試用及ZIP。

.build工具鏈與參考資料保留；Data／ScreenAnnotations及gui-data等資料根先取SHA，其他資料也以文件／資料目錄護欄保守保留。所有Store檔案、最新試用及三份YouTube文件先取SHA；不清整個.build、不動macOS／Web或系統已安裝程式。

## 實際清理與限制

1. 執行現有`Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.1.0-review-1.1.0-2026-11-01-r1-win-x64 -PreserveTrials <三份缺inventory的名稱>`，完成25份未發布舊試用程式／ZIP清理。工具本身核對SHA後保存655份Data檔及6份未知檔，0份修改檔；共180,914,551bytes，位置`dist/trial-data-backups/20261101-072608-2c7b31e8`。這三份缺inventory的目錄另確認均完全空白，經絕對路徑／reparse邊界檢查後以非遞迴Directory.Delete(path,false)移除；若出現新檔案會失敗，不刪子項。Preserved-Brush-Trial-Data目錄保持原樣。
2. 自製批次刪除建置輸出的命令遭自動審核拒絕（blocked by policy，無詳細理由），未建立或執行該刪除腳本。改以官方`dotnet clean`：先讀取FileListAbsolute，確認輸出全在對應Windows artifact根內，排除Data／工具與執行中程式，再循artifact根分組執行；288組隔離artifact及10組預設專案清理全部exit0，保留完整CLI日誌。不修改清理清單來擴張MSBuild刪除範圍。
3. 另唯讀確認72份中間MSIX／bundle與dist/store留存包SHA完全相同，合計5172729420bytes（約4.82GiB）；嘗試限縮為只移除這些完全相同的檔案仍遭自動審核拒絕（同樣只回報blocked by policy），命令未執行，72份仍在。未改用其他刪除通道繞過拒絕。其餘未能安全辨識的輸出、原始探針／結果／參考檔維持。

## 核對結果

同一組Windows輸出目錄，清理前合計76158958399bytes，清理後32824843587bytes，邏輯檔案大小淨減少43334114812bytes，約40.36GiB。未先記錄磁碟區可用容量，這是檔案邏輯大小差，不冒充實體配置區塊／磁碟可用空間量測。

1,779個預先保護檔案（含所有Store文件／套件、最新試用、既有Data與SDK data、三份YouTube文件）逐一SHA核對一致，0遺失／0不符；其中520個原路徑移至保留資料夾的檔案亦定位後核同。舊試用工具另逐檔保存並核對所有655份Data及6份未知檔。最新1.1.0試用EXE／ZIP及1.1.0.0商城bundle保留；Store SHA不變。未更改App原始碼或版號，未執行App／功能測試／WACK；本批是維護清理，不套用舊測試數字。

證據在`windows/.build/cleanup-20261101/`的inventory、trial-preflight、protected-before、verification、standard-clean-result及default-clean-result；含使用者檔案路徑的清單不提交公開Git。舊試用工具證據在`.build/trial-cleanup-20261101-072608-2c7b31e8/cleanup.json`。Git ls-files確認dist及.build未被追蹤，清理沒有刪除GitHub已發布資產／Git歷史，也不宣稱因此減少遠端Git儲存量。

使用者回報本次更新已送驗證；僅按回報記錄，未登入Partner Center查證階段或通過／發布結果。

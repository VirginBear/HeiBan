# Windows 流暢度工作清單編製紀錄（2026-10-10）

## 開工

使用者要求列出值得修改的項目，將交由 Antigravity 執行。已讀開發索引、Windows 狀態／架構／問題與私人規則；兩庫 git status --short 乾淨，私人 visibility PRIVATE。先建立本日誌，再核程式位置與撰寫交接清單。只編製文件，不執行清單中的實作或測試。

## 初步發現與界線

Windows 已使用 WinUI 3／Win2D，已有固定場景快取、中間輸入點、64 段筆跡快取、螢幕 dirty region 與背景保存基礎。清單應以這些現況為起點，不能重新宣稱它們未實作。可確認 RenderObjects 排序與遍歷、主畫面 viewport 變化令快取重建、螢幕 GetPixelBytes／native Present 路徑；是否為實際瓶頸仍待新一輪量測。

本批 rg 一度引用不存在的 MainWindow.Persistence.cs，回檔案不存在；後續用 rg --files／符號搜尋定位實際保存檔案，不以錯誤路徑作交接證據。

## 待完成

補齊實際符號／風險、優先順序／依賴、量測與驗收定義、MSIX 送審版本保全與測試授權界線。同步公開工作清單與平台狀態；私人只保存交接入口。下一版功能／版號不在本次自行決定。

## 清單完成與調查結果

已編製九項、三階段工作：新基準、配置／UI／排程、順序快取、空間索引、viewport 快取、overlay 傳輸／GPU 原型、長筆跡／低延遲輸入、保存記憶體、硬體／DPI／生命週期驗收。現況與提案分開；未將歷史 VM／合成數字當本輪成果。工作入口／平台狀態／私人交接已更新。沒有新架構實作或新程式問題，架構／決策／問題歷史不改；提出的替代方案待實際設計與驗收後才作決策。

实际執行 Get-Content、rg --files／rg -n、git status 與 gh repo view。路徑查找失敗包括 MainWindow.Persistence.cs、HitTesting.cs 及 MainWindow*.cs 的 literal path；後續用 -g 搜索真实檔案，保存位於 MainWindow.xaml.cs::SaveAsync，縮圖為 SaveThumbnail／QueueThumbnail，命中在 Core/Engine/EditorSession.cs::Hit。不存在路徑未放入工作清單；本批沒有程式建置／運行失敗。

未執行：清單中的實作與所有測試／效能量測、硬體操作／WACK／MSIX 安裝、建置／封裝、Store／Release／排程及 macOS／Web 修改。原始码、送審 bundle／SHA／素材与作品保留。

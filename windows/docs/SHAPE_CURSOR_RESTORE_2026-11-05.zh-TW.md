# Windows圖形游標恢復 — 2026-11-05

使用者回報圖形工具游標也被筆尖改動影響，要求回原樣。只Windows、維持1.1.2，不改Store包。先讀索引／Windows規則／狀態／架構／問題。開工dirty三份清理文件／YouTube三草稿保留，status及diff存`.build/shape-cursor-20261105`。

確認變更源：ToolCursor所有非藤條工具都走alpha圖案置中＋ToolCursorGeometry.Anchor，前批把直線／箭頭／矩形／三角也改圖形頂點hotspot，超出使用者原先針對畫筆／橡皮擦的要求。此次只讓curve、line、arrow、rect、circle、triangle、quadrilateral、diamond、pentagon、star十種幾何工具回到舊版32×32十字(4,4)＋translate(8,8) scale(.85)黑白圖示；保留目前alpha native資源管理／64筆cache／DPI，落點回round(size/8)。兩host共用ShapeCursor→ToolCursor，無輸入座標／筆畫／永久文件變化；畫筆、橡皮擦、雷射與物件縮放／旋轉游標保持。

實際修改／命令／驗證進行中追加，未使用前批測試數字當本批結果。

## 實際驗證

- `dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release`：6028 PASS，涵蓋15工具／兩style／六size；幾何預期回crosshair，畫筆anchor與laser中心維持。
- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/shape-cursor-20261105/qa-build`：0warning／0error。
- 獨立qa-data＋`--cursor-cane-validation-output=<native>`：515原生hotspot／bitmap／cache／sound、26 palette／drag、16 screen PASS。已目視native-cursor-hotspots.png：所有幾何皆十字與旁圖，兩style相同；筆尖／eraser／laser保持。
- `python windows/scripts/Build-UserGuides.py`：10語26章80段，指南說明釐清工具差異。首德文片段輸出遇cp950編碼錯誤，只影響terminal列印，已在UTF8腳本中處理，未改產品。

無實體滑鼠跟手／ARM64硬體／Store安裝／WACK驗收；本批未重跑OptimizationChecks（幾何游標改動無資料層變化），不套前批數字。新免安裝／SHA結果待追加。原作品與已送商店版本保持。

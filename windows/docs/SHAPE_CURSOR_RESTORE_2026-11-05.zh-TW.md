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

## 交付

`Package-PortableTrial.ps1 -Runtime win-x64 -Label shape-cursor-2026-11-05-r1`正常Release成功，來源1c795b96793c425d1e721570c0d4f6bb4d5058d3；`.build/shape-cursor-20261105/Verify-Portable-r1.py`：729 payload、413來源、132SVG、10語指南逐SHA／ZIP CRC／正常版排除QA／三音效frames peak與SHA／獨立空Data全通過。ZIP133745779bytes，SHAde6c4800bba6b2b87e3a0e9e3dba2e8be497c486240cf2a0ea0cb08c7f23c1b9。

成品：`windows/dist/trials/HeiBan-Windows-Portable-1.1.2-shape-cursor-2026-11-05-r1-win-x64/HeiBan.exe`與同路徑`.zip`。agent未啟動正常trial，原生QA獨立資料庫正常關閉；未搬移或刪原作品。正式1.1.2.0 x64／ARM64／bundle三SHA保持。原dirty三文件及三YouTube草稿保留；只Windows。

試用標準：一般／螢幕畫布各用直線、箭頭、矩形、圓、多邊形與曲線，十字中心就是建構點、工具圖示旁掛；兩圖示風格皆如此。畫筆／螢光筆／油漆筆／橡皮擦仍筆尖定位、雷射仍小光點中心，選取／縮放／旋轉不變。主觀實機手感待使用者。

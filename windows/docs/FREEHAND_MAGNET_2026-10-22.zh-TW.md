# 自由筆跨越舊筆跡凸凹 — 2026-10-22

## 開工與範圍
- 起點54048777974f2507444fb53bfad5e548552feed1；git status保留三份平台文件既有YouTube未提交內容及三份YouTube新文件。只修改Windows，沿用1.0.15，不自行進版或商店提交。
- 使用者完成上一候選手動採樣，回報響應改善，但自由筆跨舊筆跡像被吸引／排斥而凸凹。本批先讀入口及平台狀態、架構、問題、決策，開始紀錄後實作。
- 不新增或執行測試；只讀使用者已產生的數值採樣、靜態路徑分析、編譯封裝及檔案完整性檢查。實際軌跡仍待使用者驗收。

## 已確認原因與處理方向
- 本機toolbar設定magnetEnabled=true；一般畫布在PointerPressed設定WindowsInkCoordinator.PointTransform=SnapDrawingPoint，Append對每個自由筆取樣點吸附。MagnetSnapIndex把舊筆跡參考點加入索引，半徑內新點會改位置，跨越時進出半徑產生凸凹。這是可確認的輸入座標修改，不能歸因於硬體不足或只用性能數字解釋。
- 螢幕畫布OnPointer也在自由筆每次down／move／up之前做同樣吸附。修正兩個入口：自由畫筆／螢光筆／油漆筆保留輸入軌跡，磁鐵限幾何建構與圓規定位，保留形狀第一點吸附。尺規的明確投影與停筆一秒直線辨識分開維持。
- 新採樣schema2共112.4804秒：GC0/1/2=78/63/47，GC pause累計451.108ms，managed allocated=400923048bytes，PointerMove P95=0.1189ms、CanvasDraw P95=0.4479ms、ToolSwitch max2.0095ms。兩次工作負載不同，不能當作受控前後速度提升比例；CPU scopes不是端到端或GPU延遲。

## 實作與交付進行中
- MagnetSnapIndex加入SupportsConstructionTool供兩畫布共用；主畫布的首點／hover／move／提示圈只供幾何建構與明確圓規中心移動。WindowsInkCoordinator刪除僅供磁鐵使用的PointTransform與所有呼叫／重設，保留Projection（尺規）、壓力與傾角。自由筆不建／查索引，幾何工具稍後依原generation／epoch／page／zoom建立；螢幕畫布同樣清除自由筆舊索引，不影響幾何第一點。
- 修改既有screen驗證入口的磁鐵對象由pen改line及端點檢查，避免保留已取消的行為預期；該入口未執行，也未新增測試。既有其他驗證入口可能有舊選取預期，本批未宣稱整套驗證通過。
- 十語指南shapes章說明自由筆不吸附，重新生成HTML與單頁無邊界練習資源；v2既有可編輯指南作品不覆寫，只有內建說明及未建立的範例採用新文字。未知欄位／筆畫格式／使用者磁鐵設定不改，不把已存的凸凹線條自動重寫。
- `rg`查所有PointTransform引用後刪除；初次查Core路徑誤寫HeiBan.Core、查Toolbar誤用不存在檔名／shell glob，皆只讀失敗，已以rg實際目錄修正。`python windows/scripts/Build-UserGuides.py`完成10語、25章、64段／語；這是資源產生，非App實機驗收。
- 正在執行x64 Release build；封裝、接續資料與使用者驗收結果待補。

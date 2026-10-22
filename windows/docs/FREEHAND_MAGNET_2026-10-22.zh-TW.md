# 自由筆跨越舊筆跡凸凹 — 2026-10-22

## 開工與範圍
- 起點54048777974f2507444fb53bfad5e548552feed1；git status保留三份平台文件既有YouTube未提交內容及三份YouTube新文件。只修改Windows，沿用1.0.15，不自行進版或商店提交。
- 使用者完成上一候選手動採樣，回報響應改善，但自由筆跨舊筆跡像被吸引／排斥而凸凹。本批先讀入口及平台狀態、架構、問題、決策，開始紀錄後實作。
- 不新增或執行測試；只讀使用者已產生的數值採樣、靜態路徑分析、編譯封裝及檔案完整性檢查。實際軌跡仍待使用者驗收。

## 已確認原因與處理方向
- 本機toolbar設定magnetEnabled=true；一般畫布在PointerPressed設定WindowsInkCoordinator.PointTransform=SnapDrawingPoint，Append對每個自由筆取樣點吸附。MagnetSnapIndex把舊筆跡參考點加入索引，半徑內新點會改位置，跨越時進出半徑產生凸凹。這是可確認的輸入座標修改，不能歸因於硬體不足或只用性能數字解釋。
- 螢幕畫布OnPointer也在自由筆每次down／move／up之前做同樣吸附。修正兩個入口：自由畫筆／螢光筆／油漆筆保留輸入軌跡，磁鐵限幾何建構與圓規定位，保留形狀第一點吸附。尺規的明確投影與停筆一秒直線辨識分開維持。
- 新採樣schema2共112.4804秒：GC0/1/2=78/63/47，GC pause累計451.108ms，managed allocated=400923048bytes，PointerMove P95=0.1189ms、CanvasDraw P95=0.4479ms、ToolSwitch max2.0095ms。兩次工作負載不同，不能當作受控前後速度提升比例；CPU scopes不是端到端或GPU延遲。

## 實作與交付
- MagnetSnapIndex加入SupportsConstructionTool供兩畫布共用；主畫布的首點／hover／move／提示圈只供幾何建構與明確圓規中心移動。WindowsInkCoordinator刪除僅供磁鐵使用的PointTransform與所有呼叫／重設，保留Projection（尺規）、壓力與傾角。自由筆不建／查索引，幾何工具稍後依原generation／epoch／page／zoom建立；螢幕畫布同樣清除自由筆舊索引，不影響幾何第一點。
- 修改既有screen驗證入口的磁鐵對象由pen改line及端點檢查，避免保留已取消的行為預期；該入口未執行，也未新增測試。既有其他驗證入口可能有舊選取預期，本批未宣稱整套驗證通過。
- 十語指南shapes章說明自由筆不吸附，重新生成HTML與單頁無邊界練習資源；v2既有可編輯指南作品不覆寫，只有內建說明及未建立的範例採用新文字。未知欄位／筆畫格式／使用者磁鐵設定不改，不把已存的凸凹線條自動重寫。
- `rg`查所有PointTransform引用後刪除；初次查Core路徑誤寫HeiBan.Core、查Toolbar誤用不存在檔名／shell glob，皆只讀失敗，已以rg實際目錄修正。`python windows/scripts/Build-UserGuides.py`完成10語、25章、64段／語；這是資源產生，非App實機驗收。
- `dotnet build ... -c Release -r win-x64 -p:Platform=x64 --no-restore`完成48.62秒，0warning／0error。`Package-PortableTrial.ps1 -Runtime win-x64 -Label freehand-magnet-2026-10-22-r1`再publish並封裝成功；不把編譯當實機測試。

## 最終交付與未驗收
- 來源f239b52d992253b49c29042fd29a588c8fe7aab1；ZIP132782470bytes／SHA256 `df7cb73e56ad7bdaf32753f488245555e437eacfee3e52d11f3008c7b582287a`。`python windows/.build/freehand-magnet-inspect.py`核對CRC、585payload與179source SHA、x64 PE、10語HTML／無邊界練習25章29工具、採樣launcher BOM，ZIP沒有使用者Data。
- `freehand-magnet-handoff.ps1`先確認新舊App未執行，複製52檔／24767478bytes，全部SHA符合。`Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.15-freehand-magnet-2026-10-22-r1-win-x64`備份作品及未知檔後清舊未發布runtime／ZIP，釋放456357664bytes、保留24771674bytes，備份dist/trial-data-backups/20261022-125548-77a21a95。舊數值採樣另以原始byte存PRIVATE repo，SHA256 b9ffa9b4e0c9bf437b37ed3a21d3d1f7c042fc231578e39af8e1c7e320dabd9e，Git -text保留。
- Store1.0.15.0的SHA256仍為a889482ff3aa171569ce415fc285340b26742528af4306a3e0a0e3d6fa07eb96；已發布歷史與商店產物保留。產品／正式套件版本不變，無Store／Release發布。
- 本批未執行App、自動／實作測試、新性能採樣、GPU trace、DPI／Undo／圓規回歸驗收。新手感由使用者確認；最新基準心跳P95=50.548ms、max205.9376ms，仍不能說所有排程停頓已排除。
- 建議手動驗收：磁鐵開啟畫筆／螢光筆／油漆筆反覆跨舊線，交叉附近不跳點／不出綠圈；直線與矩形首點仍吸附，圓規中心／尺規／停筆一秒直線功能及逐筆Undo維持。一般與螢幕畫布各確認；既有已變形線條不會被自動修復。

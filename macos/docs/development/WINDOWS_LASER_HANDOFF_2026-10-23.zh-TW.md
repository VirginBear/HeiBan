# Windows 雷射尾跡交接 · 2026-10-23

狀態：待 Windows 原機開發與驗收。本批只修改 Mac，沒有修改 Windows 程式、資源或產物；本機來源未 fetch，不代表最新遠端狀態。

## 使用者問題與來源證據

使用者指出兩個平台的雷射都呈現一段一段，質感差。Mac 原因可確認為 24 組透明度 path 各自 round cap 疊加；本批改連續輪廓。現有本機 Windows `windows/HeiBan.Windows/Engine/Direct2DCanvasRenderer.cs` 的 RenderLaser（約387行）逐相鄰取樣呼叫 DrawLine，以每段 timestamp 決定透明度，再畫白芯；頭部是三層實色 FillCircle。這是可確認的分段渲染方式，尚未在 Windows 實機證明它是所有視覺／流暢問題的唯一原因。

## 開發工作

- [ ] 先核對 Windows 最新 Git 狀態，保留原機新修改；不直接搬 Swift／SwiftUI。
- [ ] 以 StartsTrail 分組，保留手勢斷點；不要跨暫停、離開畫布或顯示器連線。
- [ ] 螢幕座標建立二次曲線平滑中心線及連續漸細輪廓，以整條幾何一次填色／柔光／白芯；避免逐段透明度或逐點端帽。
- [ ] 光點改徑向柔和過渡，保留 PointDiameter 與 trail Width 分開控制、DPI density 換算及 WhiteCore 開關。
- [ ] 維持 500 取樣上限及暫態邊界，不能加入作品、Undo 或自動保存；停止後釋放計時／圖形資源。
- [ ] 以 Win2D/Direct2D 原生資源實作，避免每 frame 建立全螢幕 CPU bitmap；量測後決定平滑網格快取與 GPU effect 範圍。

## 驗收目標（尚未執行）

慢速／高速／急轉彎／迴圈／停留／移出再進、point/shortTrail/line、白芯開關、不同粗細／點徑／淡出、100–200% DPI及多螢幕。比較連續性、CPU/GPU、frame time與輸入延遲，不因Mac可編譯而宣稱Windows已改善。

Mac參考：`macos/Sources/HeiBanMac/Views/Canvas/LaserTrailGeometry.swift`、`LaserOverlayView.swift`；限借用幾何與生命週期思路。Windows Store封裝與版本由Windows工作平台另行處理。

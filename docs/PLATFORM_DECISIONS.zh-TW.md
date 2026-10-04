# HeiBan 黑板 - 跨平台架構決策與行為一致性記錄 (ADR)

> 依據工作清單 **W29** 與驗收案例 **A23**、**A31**，記錄 macOS、Web、Windows 跨平台架構技術選型、輸入事件分派、字型度量容差與資料契約互通規範。

---

## 1. 跨平台架構選型 (Architecture Decision Matrix)

各平台依據「原生極致性能」與「平台慣用語」獨立選擇實現方案，**絕不採用低效跨端過度抽象（如純套 WebView 封裝）**，全平台核心共享 **HeiBan Document Schema v1.0.0** 與標準化測試 Fixture 套件。

| 維度 | macOS 原生平台 | Web 網頁平台 | Windows 平台規劃 |
|---|---|---|---|
| **技術堆疊** | SwiftUI + AppKit + Metal | React 19 + TypeScript + Vite | WinUI 3 + C# (.NET 9) / Windows App SDK |
| **渲染引擎** | 原生 Direct Metal / CoreGraphics (120Hz ProMotion) | HTML5 Canvas 2D / OffscreenCanvas + WebGL | Direct2D + DirectWrite (硬體加速渲染) |
| **手寫筆與壓感** | Apple Pencil / Wacom Tablet (NSEvent 壓感 0.0~1.0) | W3C PointerEvents (Coalesced Events 壓感) | Windows Ink API + PointerPoint 高精度壓感 |
| **文字排版引擎** | CoreText + NSTextView (IME 候選字隔離) | HTML5 Canvas measureText + DOM Overlay | DirectWrite + XAML RichEditBox |
| **本地持久化** | Atomic Swap + `~/Library/Application Support/com.bear.HeiBan` | IndexedDB + File System Access API | `Windows.Storage.ApplicationData` + 原子寫入 |
| **多端同步** | CloudSyncCoordinator (WebSocket / Firestore) | Firestore SDK / WebSocket | C# CloudSyncClient (WebSocket / REST) |
| **協作演算法** | LWW (Last-Write-Wins) + 修訂號收斂 (ConvergenceEngine) | LWW + 修訂號收斂 (與 Swift 完全等價) | LWW + 修訂號收斂 (與 Swift 完全等價) |

---

## 2. 跨平台文件契約 (Schema Contract v1.0.0)

所有平台必須 100% 遵守並通過以下幾何與資料契約：

1. **幾何座標容差**：
   - 跨端往返序列化之 X、Y、寬度、高度容差必須 $\le 10^{-6}$。
2. **字型度量容差**：
   - 因 CoreText、DirectWrite 與瀏覽器字型排版度量微小差異，跨平台多行富文本換行與尺寸容差定義為 $\le 2.0\text{ pt}$。
3. **15 種標準幾何物件支援**：
   - 筆跡（stroke）、螢光筆（highlighter）、油漆筆（paint）、矩形（rect）、圓形（circle）、三角形（triangle）、菱形（diamond）、星星（star）、反向雙向延伸線段（line）、單向反向延伸箭頭（arrow）、富文本片段（text）、和紙便簽（sticky）、貓咪便簽（sticky）、裁切圖片（image）、畫布圖釘（pin）。
4. **群組識別碼（groupId）保留**：
   - 跨平台讀寫必須完整保留 `groupId`，解散或重組操作依平台行為案例標準化。

---

## 3. 輸入事件與快捷鍵對應表

| 操作功能 | macOS 鍵位 | Web 網頁鍵位 | Windows 鍵位 |
|---|---|---|---|
| **選取工具** | `V` | `V` | `V` |
| **鋼筆工具** | `P` | `P` | `P` |
| **螢光筆** | `H` | `H` | `H` |
| **橡皮擦** | `E` | `E` | `E` |
| **新建檔案** | `Cmd + N` | `Ctrl + N` (或 UI 按鈕) | `Ctrl + N` |
| **儲存檔案** | `Cmd + S` | `Ctrl + S` (自訂攔截) | `Ctrl + S` |
| **復原／重做** | `Cmd + Z` / `Cmd + Shift + Z` | `Ctrl + Z` / `Ctrl + Y` | `Ctrl + Z` / `Ctrl + Y` |
| **全選** | `Cmd + A` | `Ctrl + A` | `Ctrl + A` |
| **複製／貼上** | `Cmd + C` / `Cmd + V` | `Ctrl + C` / `Ctrl + V` | `Ctrl + C` / `Ctrl + V` |
| **畫布平移** | `Space + 拖曳` / 雙指滑動 | `Space + 拖曳` / 滾輪 | `Space + 拖曳` / 滾輪 |

---

## 4. 平台完成與互通性驗收清單

- [x] **文件契約往返無損**：Fixture F04 通過 Web (`tests/contract.test.ts`) 與 macOS (`HeiBanTestRunner`) 雙向檢驗。
- [x] **十人協作並發收斂**：macOS 與 Web 收斂演算完全等價（LWW + ID 排序破歧義），無任何資料遺失。
- [x] **發行產物分離與冷安裝保全**：macOS 產物已固定版本（1.0.0）、產物 SHA-256 雜湊與 Application Support 資料隔離。
- [x] **Windows 規格落地**：架構決策與 Direct2D/WinUI3 介面合約已底定，共享全部測試 Fixture (F01–F05)。

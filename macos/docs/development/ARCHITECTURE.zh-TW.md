# Mac 實際架構與維護邊界

更新：2026-10-09。這份文件描述現況，未建立不存在的 Storage／Metal 模組。

## 套件與職責

```text
HeiBanMac：SwiftUI / AppKit / ScreenCaptureKit / WebKit
  App、命令選單與退出生命週期
  Views：工作區、浮動面板、原生文字與滑鼠輸入
  Adapters：檔案面板、剪貼簿、影像解碼、截圖與權限
  ScreenAnnotation：多顯示器透明視窗、控制列、恢復檔、快捷鍵
  Guide：離線手冊視窗
             ↓ 命令／文件快照
HeiBanCore：文件模型、幾何、編輯狀態與本機資料
  BoardEngine：狀態擁有者與指標路由
  BoardEngine+*：各職責的命令，不建立第二份作品資料
  Algorithms：命中、路徑、識別、座標與工具尺寸
  LocalBoardLibrary：檔案、修訂、備份、縮圖與垃圾桶
  BoardExporter / HeiBanDocumentCodec：匯出／原稿編解碼
HeiBanTestRunner：既有檢查執行檔與 Fixtures，不是產品工具
```

Core 目前仍依賴 CoreGraphics、SwiftUI Path、ImageIO、Security 與部分 Apple API，並非完全可直接移植的純 Foundation 套件。跨平台相容邊界是文件契約；本輪沒有重新設計 Windows。

## BoardEngine 檔案地圖

| 檔案 | 責任 |
|---|---|
| `BoardEngine.swift` | 共用狀態、工具切換、指標手勢、形狀預覽、歷史套用、工具列與尺規配置 |
| `StrokePreviewStore.swift` | 獨立高頻筆畫預覽與路徑段 |
| `BoardInteractionTypes.swift` | 操作相關值型別與工具樣式契約 |
| `BoardEngine+Persistence` / `BoardPersistenceState` | 保存排程、文件 header、串行寫入、退出等待 |
| `BoardEngine+Library` | 建立／啟用作品、命名、複本、恢復與垃圾桶 |
| `BoardEngine+Notebook` | 頁面、當前頁過濾與增刪 |
| `BoardEngine+Drawing` | 落筆、尺邊約束、識別、橡皮擦、游標與快照 |
| `BoardEngine+TextEditing` | 草稿、原地輸入、富文本、提交／取消 |
| `BoardEngine+SelectionStyle` | 混合值、批次樣式交易、便簽高度估算 |
| `BoardEngine+Layers` | 圖層、群組、選取、剪貼簿、幾何變換 |
| `BoardEngine+Images` | 圖片置入、裁切、截圖結果與來源管理 |
| `BoardEngine+FileIO` | 原稿開啟、另存、共用格式匯出面板 |
| `BoardEngine+CanvasConfiguration` | 主題、尺寸、背景與世界座標圖釘 |
| `BoardEngine+Navigation` | 閱讀、視角鎖定與適合內容 |
| `BoardEngine+StructuredNotes` | 尚未完整接入介面的導圖／表格／公式／簡報基礎 |

延伸檔不是服務層，也不是不同引擎；全部修改同一份 board／objects。需要共用的暫態狀態使用模組內 internal，UI 仍不能直接存取這些狀態；其餘 helper 維持 private。未宣稱僅拆檔就完成效能優化。

## 關鍵不變條件

1. 永久物件在世界座標；滑鼠與游標範圍在螢幕座標。縮放只能透過 viewport 換算，筆寬與橡皮擦範圍單位不可混用。
2. 高頻取樣只改預覽／工具狀態。手勢結束產生一次命令；雷射、圓規輔助線、游標不加入物件或匯出。
3. 多選樣式修改跳過鎖定物件；批次發布 objects，保留原物件順序，一筆歷史交易。
4. 普通作品先在主執行緒取得值型別快照，串行 queue 寫入。generation 只拒絕過期 UI 回報，**不是**磁碟寫入取消機制。
5. 切換文件統一 `activate`，同時保留版本／未知欄位並清掉舊互動與歷史。對外 `load` 先保存目前作品。
6. 螢幕註記、未整合的 DocumentSession 使用 `persistenceEnabled: false`；由各自保存擁有者處理，不能回寫 current 或普通作品庫。
7. 退出保存由 AppDelegate 處理，失敗拒絕退出；View 不再另寫一份退出快照。
8. 多文件、雲端、協作、更新模型的存在，不代表正式 UI 已啟用。移除前要查檢查程式與既定產品需求。

## 螢幕畫布邊界

Controller 管開始、穿透、焦點、截圖、停止；Session 管每顯示器的 engine／透明 NSPanel／恢復檔；AnnotationInputView 擁有原生輸入與整個螢幕的命中區域；Canvas 僅組合既有渲染層（GeometryReader 與原生輸入同尺寸）；AnnotationWindowPolicy 統一跨程式層級／Space 行為；Controls 只呼叫命令；HotKeys 只登記三組快捷鍵。先保存才關閉；恢復檔損壞先保留原檔，避免空白覆寫。

## 開發時注意

- 目前 UI 命令假設主執行緒；尚未完整以 `@MainActor` 約束所有 Core API，不能把可變 engine 傳給背景工作。
- 大圖片仍內嵌 JSON。未經 v2 遷移不能直接換 ZIP 或拆外部資產。
- `.partial` 橡皮擦是舊文件相容值，不能當死 enum 刪除。
- SwiftUI `@State` 有同名 Core 狀態型別干擾，現有視圖使用 `@ViewState` 別名；不要為格式統一隨意改回。
- 廣域錄製權限／一次性系統選取器是不同授權路徑，詳見截圖問題紀錄。

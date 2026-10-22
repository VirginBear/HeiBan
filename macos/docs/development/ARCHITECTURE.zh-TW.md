# Mac 實際架構與維護邊界

更新：2026-10-17。這份文件描述現況，未建立不存在的 Storage／Metal 模組。

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
4. 普通作品先在主執行緒取得值型別快照，串行 queue 寫入。自動保存頻率由 AppSettings 控制；關閉自動保存不會關閉 persistence owner，手動／離開仍須落盤。generation 只拒絕過期 UI 回報，**不是**磁碟寫入取消機制。
5. 切換文件統一 `activate`，同時保留版本／未知欄位並清掉舊互動與歷史。對外 `load` 先保存目前作品。
6. 螢幕註記、未整合的 DocumentSession 使用 `persistenceEnabled: false`；由各自保存擁有者處理，不能回寫 current 或普通作品庫。
7. 退出保存由 AppDelegate 以 `terminateLater` 等待非同步寫入回報，成功才允許結束，失敗拒絕退出；View 不另寫退出快照。螢幕恢復檔由 ScreenAnnotationController 先提交文字並保存，失敗時保留透明畫布。
8. 多文件、雲端、協作、更新模型的存在，不代表正式 UI 已啟用。移除前要查檢查程式與既定產品需求。

## 螢幕畫布邊界

Controller 管開始、穿透、焦點、截圖、停止；Session 管每顯示器的 engine／透明 NSPanel／恢復檔；AnnotationInputView 保有1%透明底層與文字編輯host；ScreenAnnotationCanvas共用普通畫布的NativePointerSurface和工具疊層。PointerView只有一份事件監聽，位於尺／圓規等互動視圖下方。AnnotationWindowPolicy 統一跨程式層級／Space 行為；Grip只傳原生手勢，Controller拖曳時只移origin，放開才更新方向／尺寸／本機偏好；HotKeys只登記三組快捷鍵。先保存才關閉；恢復檔損壞先保留，避免空白覆寫。

ToolbarPreferences定義兩種畫布共用的工具與排序；ToolbarContentPolicy排除螢幕pins/viewLock，把Undo/Redo拆同尺寸格，固定clearAll由螢幕尾端提供。ToolbarToolsView／ToolbarBrushSettings共用圖示、More、自訂和樣式交易；偏好低頻通知同步現有engine，重新出現時回讀UserDefaults。螢幕模式覆寫截圖PNG、圖片對話框的高位階視窗遮讓、選取工具啟動作畫、四邊停靠及全螢幕清空。AnnotationToolbarLayout依實際itemCount限制在visibleFrame內，32pt工具格／4pt間距，空間不足換列／欄；清空與退出不被中段擠出。舊17/16格數只供舊幾何呼叫相容，不作正式工具定義。

文字editor為AnnotationInputView獨立可互動NSHostingView子視圖；其frame優先命中，其餘交共用renderer，空白處由NativePointerSurface接收。只訂閱文字編輯開關／錨點來增刪／定位，非每個指標樣本重排。InlineTextEditorPanel共用NSTextView草稿，完成才提交；Controller暫停／保存／換工具／停止時共用commitTextDrafts。Esc編輯時不被穿透切換攔截。

TextStyleContextMenu 由 PointerView 與 NSTextView 各自持有，包含預設命令及自訂值 NSPopover；草稿只修改編輯狀態、已提交物件走 setSelectedTextStyle。批次命令共用 modifySelectedObjects，限定本頁未鎖定 text／sticky，一次發布／undo；色彩與字形同步 rich spans，不改填色、圖片或圖形。自訂面板套用前核對選取／草稿對象，僅傳修改欄位；樣式調整不增加文件格式。

## 開發時注意

- 目前 UI 命令假設主執行緒；尚未完整以 `@MainActor` 約束所有 Core API，不能把可變 engine 傳給背景工作。
- 大圖片仍內嵌 JSON。未經 v2 遷移不能直接換 ZIP 或拆外部資產。
- `.partial` 橡皮擦是舊文件相容值，不能當死 enum 刪除。
- SwiftUI `@State` 有同名 Core 狀態型別干擾，現有視圖使用 `@ViewState` 別名；不要為格式統一隨意改回。
- 廣域錄製權限／一次性系統選取器是不同授權路徑，詳見截圖問題紀錄。

螢幕畫布清空不屬於退出／modal生命週期：取消暫態時保留工具與模式，clearAll產生可復原歷史，雷射不進歷史；空白恢復檔立即寫入。普通作品庫不受影響。工具列設定不寫進.heiban／undo，尺寸按visibleFrame與實際工具格數限制、空間不足換列／換欄。

## 1.0.13 導覽與圖層拖曳

WorkspaceHeaderView 在工作區上疊放 TopNav／ReadingNavigation，不改 Canvas 尺寸。原生 NSTrackingArea 偵測膠囊附近游標，hitTest 回 nil；只有顯示中的膠囊與收起箭頭接受點擊。隱藏使用 opacity／allowsHitTesting，不重建 popover 錨點；700ms 可取消延時避免游標進選單時消失。固定顯示是本機 AppStorage 偏好，未加入作品格式或復原。

LayerPanelView 持有當前拖曳 ID、作品／頁 ID 及目標上下側；LayerDragHandle 的 NSDraggingSession 產生 Finder 式圖示／名稱預覽，來源結束回呼（含取消）清理 UI。DropDelegate 只接受本 panel 的私有型別與 session，drop 前再核對作品／頁／鎖定狀態；moveLayer 依 stable zIndex 排序替換當頁槽位，提交一次既有 reorderObjects 交易。相同位置不產生歷史，其他頁相對順序／物件內容／未知欄位保留。build_app.sh 只宣告內部 drag UTType，不為它設定文件開啟副檔名。


## 開發快取與公開包

macos/.build是可重新產生的SDK模組／中間檔／建置產品，沒有作品或不可替代來源；最新macos/dist/HeiBan.app包含自身執行檔與Resources，不依賴這份快取。沒有編譯工作執行時才清理；清理後先保留已簽章成品，避免單純公開封裝就重新編譯產生大量快取。scripts/package_public_release.py的Mac分支只讀已建App、授權與手冊，產DMG／ZIP及雜湊，不修改Windows包或作品庫。發行tag連結來源commit，開發日誌區分前批編譯／局部操作與此次發布，不把發布視為全功能驗收。

## 1.0.15 Windows同步的新增邊界（2026-10-16）

- DrawingReferenceGeometry.swift／DrawingAssistState／MagnetSnapIndex：共同形狀參考，按revision／頁／zoom快取的空間格查詢；不移動被吸附的原物件。
- BoardEraser.swift／DrawingAssistOverlays.swift：Core凸輪廓切段＋單手勢快照／replaceObjects，Mac原生抓取及同一鏡像素材。保存快照排除尚未提交擦除，放開後一次落盤／Undo；取消不增加歷史。
- MacDocumentExchange：Mac平台PDFKit／Keynote／ImageRenderer，通過BoardEngine.documentImportHandler／pdfExportHandler接既有入口。Core不持有NSPanel／PDFKit／AppleScript；Keynote只操作自己的臨時簡報，無COM或Office依賴。
- PDFEditableAttachment：符合PDF交叉索引的增量stream，沿舊Mac／Windows可發現的base64原稿標記；不更改.heiban契約。多頁PDF及原稿皆在本機產生，完整原稿分享限制見隱私文字。
- 工具列icons／labels及Common偏好由ToolbarPreferences／ToolbarContentPolicy共用；labels單排／單列，四頁及組頁只為暫態UI。螢幕尺寸按labels與icons分流，clear／close在中段之外。
- 手冊單一正體中文21章來源保持generate_user_guide.py，其餘語言的Mac原生操作總覽由Documentation/Guides＋generate_localized_guides.py生成，Guide視窗依L10n載入資源，頁內語言選擇不改App偏好。


## 1.0.15 同版修整（2026-10-17）

板擦高頻快照已從 engine.objects 移到 BoardEraserState.previewObjects，由 BoardEraserObjectsLayer 獨立訂閱並以目前頁過濾後交共用renderer。document永遠只讀永久objects，無須在每次取得快照時猜測是否正擦除。開始記錄作品／頁與drawingGeometryRevision；放開前再核對，外部命令若已修改永久物件則丟棄過時預覽。取消不回寫原陣列，避免覆蓋新操作。isBoardEraserActive只在開始／結束發布，供保存回饋及導航鎖定；原生視窗失焦或拆除清理手勢。

普通保存的generation在每次已提交編輯推進，先標記尚未保存，才決定是否排自動寫入；關閉自動保存不會保留過期的「已儲存」。排程執行及完成回報都核對generation，但已開始的串行磁碟寫入仍可能完成。同步／非同步離開作品均提交文字與板擦後取值型別快照；不是保存所有未完成筆畫的通用交易機制。

圖文工具列以shownPageIDs作實際渲染清單；More補齊目前未渲染工具，螢幕Undo／Redo同樣展開為共用元件。設定請求依renderedIDs決定是否先開More，不再誤用包含其他頁工具的visibleIDs。中段ScrollView有明確可用尺寸，常駐入口在捲動區之外；沒有新增第二套命令catalog或作品設定。

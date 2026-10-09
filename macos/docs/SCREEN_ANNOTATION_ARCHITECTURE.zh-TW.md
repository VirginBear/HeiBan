# 螢幕畫布與工具互動架構

日期：2026-10-09 · 範圍：macOS

## 透明疊層

每個 NSScreen 對應一個透明、非啟動 NSPanel 與獨立 BoardEngine。使用 AnnotationInputView 繼承 NativePointerSurface.PointerView，直接作為 NSPanel.contentView；SwiftUI 僅渲染筆畫暫態預覽、物件、選取、橡皮擦與雷射，不建立第二套筆畫文件模型。

- 原生輸入視圖明確鋪滿每個 NSScreen.frame.size；本地座標以左上為起點，viewport 恆為 identity。SwiftUI GeometryReader 固定同尺寸，無需從已有註記推算可命中區域。
- 空白區域使用 0.01 alpha 中性 backing，避免零 alpha 視窗像素被當成可穿透；這是約 1% 遮罩，不是底層螢幕截圖。首點接受 mouseDown，背景點擊不得拖動整個 panel。
- 作畫時接收滑鼠；操作時 `ignoresMouseEvents = true`，底層 App 可收到原本滑鼠操作，透明層仍保留。
- 普通繪製不擷取螢幕、不讀取影片、不暫停底層 App。背景是實際仍在運作的桌面。
- AnnotationWindowPolicy 統一 canvas = statusBar + 1、controls = canvas + 1。低於系統 popup menu，避免選單／popover 被蓋住；canJoinAllApplications 加入他 App 的全螢幕集合，stationary／ignoresCycle 避免被當成普通文件視窗。Space／其他 App 啟動時重新排序，不強制啟動主 App。
- 暫態清理會將 currentTool 重設為 select，所以作畫／操作切換必須由 Session 捕捉並恢復工具／樣式。跨顯示器同步不得重複調用同工具 toggle。文件恢復完成後才設定初始畫筆、無邊界畫布與 viewport。
- 原生保存／確認對話框期間隱藏 canvas／controls；截圖生命週期完成前不提前恢復控制列。
- 控制列獨立於畫布，位階比畫布高一層；可切換作畫／操作、復原、顏色、筆寬、透明度、保存、結束。
- 每個螢幕獨立文件與歷史；滑鼠進入時切換該螢幕的操作對象。
- 全域 Carbon EventHotKey 登錄 `⌘⌥⇧D`、`⌘⌥⇧S`、`⌘⌥⇧X`，不建立全鍵盤監聽 EventTap，不要求輔助使用／輸入監控權限。若登錄衝突，保留選單與控制列。
- 結束與 App 退出先保存；保存失敗時保留畫布資料，避免直接關閉造成遺失。
- 顯示器配置改變先結束並保存，重新開啟時重建座標。

## 一次性截圖

重用 MacScreenCaptureService。隱藏控制列，保留註記視窗，暫時讓滑鼠穿透。有效廣域授權使用 ScreenCaptureKit 單張截圖；沒有有效授權走 SCContentSharingPicker 與一次 SCStream 完整畫面。PNG 包含螢幕當下內容及註記，保存完回到先前操作狀態。

SCStream 僅為獲得一張圖片啟動，第一個完整影格後立即停止。取消／失敗也清理串流與選取器。截圖過程可透過結束快捷鍵取消。DRM 影片與系統安全畫面不承諾擷取。

## 持久化界線

螢幕引擎 `restoreSession: false, persistenceEnabled: false`，不回寫一般作品庫與 current.blackboard.json。控制器另外合併物件變更，保存至 `ScreenAnnotations/display-<ID>.heiban`，附 `purpose: screenAnnotation`。文件只保存註記，底層畫面另以 PNG 記錄。

版本欄位和未知文件欄位由 BoardEngine 保留，儲存採原子替換。不可解析的恢復檔保留為 preserved 檔案，保留失敗時不覆寫。

## 圓規狀態

`prepare` → `isArmed` → `isDrawingArc` → 可編輯 arc 物件。

- 準備：移動中心、半徑、筆尖起點均不生成物件。
- 點中心切換鎖定：中心橘色，禁止中心／半徑移動。
- 畫弧：保留準備起點，累計相鄰滑鼠取樣角差，跨 0° 連續，限制 ±360°。
- 放開只提交有足夠角度的弧，回選取；無位移不得自動生成整圓。「整圓」是明確獨立操作。

## 雷射與渲染

滑鼠移動與拖曳都採樣；樣本不每筆發布以避免整個 SwiftUI 版面高頻重算。TimelineView 每幀將時間送入 Canvas 值，確保靜態閉包不被重用而漏掉新的樣本。尾跡依 24 個透明度桶合併繪製。樣本數上限 500，過期清理定時器在停止後取消。

點徑以螢幕 pt 計算；工具按鈕第二次點開設定，光點模式沒有尾跡，短尾跡／線條模式有。模式、色彩、大小、粗細、消退時間、白芯儲存於本機偏好。

## 四邊屬性面板

共用色彩、線條、物件三組控制元件。側邊使用垂直捲動；上下使用並列三欄，各欄獨立垂直捲動，窄視窗支援水平捲動。高度上限 264 pt，寬度依工作區可用大小計算。停靠狀態屬於偏好，不污染物件 undo 歷史。

## 交付與後續

- macOS 1.0.8 App、離線搜尋手冊、`.heiban` UTI 已整合。
- 不新增 Windows / web 依賴，不同步修改 Windows。
- 多螢幕與專用獨佔全螢幕仍需在真實配置驗收；畫面分享必須確認分享的是整個顯示器而非單一 App 視窗。
- 全域快捷鍵目前是固定預設；可自訂快捷鍵設定列為後續工作。

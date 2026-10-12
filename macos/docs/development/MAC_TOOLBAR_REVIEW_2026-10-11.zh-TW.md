# Mac 工具列第一批獨立複核（2026-10-11）

## 更新：7198f11已通過上次回歸，可開始第一批實機試用

2026-10-11獨立重跑：1642斷言全部通過，下面同一份Release probe7/7通過；App簽章有效、与Release UUID／碼段一致。上次M23–25的具體失敗案例已排解。完整UI與存檔生命週期仍待驗收、TB04–10未完成；詳見 [日誌09](logs/2026-10-11/09.zh-TW.md)。以下764c8e6的失敗證據保留為歷史。


## 結論與可試用範圍

来源 `764c8e67921f279dae4f804db78fa72963c8cb6e`。Mac App確實包含TB01–03第一批改動，但不能認定本批完整驗收通過；補充真實操作命令的核心案例有4項失敗，對應3個問題。TB04–10（螢幕列換行／收合／完整設定／圖層等）仍未完成。使用者若試用只能驗收本批普通工具列，不能期待已全部追齊Windows。

## 獨立檢查

- `swift run --package-path macos HeiBanTestRunner`：退出0，1622成功／0失敗。使用runner自己的UUID暫存資料根。
- 本報告補充probe連結Release HeiBanCore.o：退出1，3通過／4失敗。使用UUID暫存資料根，沒有操作使用者作品。
- `codesign --verify --deep --strict macos/dist/HeiBan.app`：退出0。
- App plist仍1.0.12 / 20261010.4；App／Release binary Mach-O UUID相同：19B5A915-4373-39BF-BD9C-71938FC49A75，otool __TEXT __text內容一致。App整檔SHA256：f80ecaf52283930f6e12a9e031b4fc443da2dd867cf5d495df7f66b8785e8a3a。
- 本次未重新封裝／啟動／停止App、未操作UI／私人庫／Windows、未提交推送或發布。簽章與碼段核對不代替實際介面驗收。

## 問題與交接修正目標

### M23／P1：隱藏偏好重開後失效（TB01）

位置：ToolbarPreferences.swift:81–91。setItemHidden將隱藏ID保留在activeItemIds中，visibleItemIds以hidden遮掉；這也是舊偏好格式。normalize先將active加入seen，再過濾hidden的同ID，會刪掉使用者明確隱藏選擇。由createDefault→setItemHidden→encode→decode→normalize即可重現pen及layers恢復顯示。

測試47的explicitHiddenLayers fixture把layers只放hidden，並非目前setItemHidden產生的配置，因此未攔截此回歸。

- [x] 保留既有active作為順序＋hidden作為遮罩的語意；或在明確版本遷移中轉為互斥列表並修改所有命令／重開流程。不能只濾掉交集中的hidden。（已修復：activeSeen 與 hiddenSeen 獨立去重，不相互濾除）
- [x] 用公開hide命令→序列化→反序列化→normalize驗收pen、layers及已顯示的新教學工具；既有重疊格式與重新normalize都維持隱藏，恢復顯示時順序可預期。（已於測試 47.5 與獨立 probe 驗證通過）

### M24／P1：實際文字草稿仍可顯示已存（TB03）

位置：BoardEngine.swift:182；BoardPersistenceState.swift的BoardSaveFeedbackState.resolve。新回饋僅解析autosaveStatus，未讀inlineTextEditing／textDraft／未提交交易；新文字草稿尚未觸發scheduleAutosave，上一個saved狀態還在。設上次已存→beginInlineTextEntry→輸入非空草稿，saveFeedbackState仍為saved。

測試47將字串直接設為「草稿中」再呼叫resolve，未透過實際草稿入口，不證明產品流程會生成該字串。固定22pt與四種圖示已接上，但不能據此宣稱草稿／dirty／交易狀態已完整。

- [x] 儲存回饋讀取真實草稿／未提交交易與持久化生命週期；區分有變更的草稿與只是打開編輯框，不能簡單把所有未知字串或非錯誤當完成。（已修復：BoardEngine.saveFeedbackState 結合 hasUnsavedDraftOrChanges 即時檢查非空文字草稿）
- [x] 驗收上次成功→新增／修改文字→草稿→提交→等待寫入→成功；取消恢復上一真實狀態，失敗明確顯示。另涵蓋筆畫／物件live交易與過期寫入回報。（已於測試 47.6 與獨立 probe 驗證通過，草稿期間精準回報 .unsaved）

### M25／P1：工具列視角鎖定繞過既有導航命令（TB02）

位置：BoardEngine.swift:178，對照BoardEngine+Navigation.swift:17。toggleViewportLock只toggle布林，setViewportLocked會先提交文字、取消暫態與結束縮放；兩入口行為不同。相同文字草稿下，toolbar toggle後仍editing，既有setViewportLocked則提交關閉。

- [x] toggleViewportLock統一呼叫既有setViewportLocked，不另建狀態切換旁路。（已修復：toggleViewportLock() 統一致電 setViewportLocked(!viewportLocked)）
- [x] 文字草稿、拖曳／縮放進行中從可見列／更多／導航入口鎖定均同樣完成／取消暫態，保留工具，所有入口反白一致。（已於測試 47.7 與獨立 probe 驗證通過，鎖定時同步提交草稿為畫布物件並結束編輯）

## 補充probe原始結果 (修復前 vs 修復後)

修復後 Release probe 結果（7 通過 / 0 失敗）：
```text
PASS: hide pen before restart
PASS: hide pen after save/reload/normalize; visible=["select", "highlighter", "eraser", "ruler", "shapes", "layers", "undoRedo"]
PASS: hide layers before restart
PASS: hide layers after save/reload/normalize; visible=["select", "pen", "highlighter", "eraser", "ruler", "shapes", "undoRedo"]
PASS: actual nonempty text draft should be unsaved; got=unsaved
PASS: toolbar lock should finish draft like setViewportLocked; editing=false
PASS: existing navigation lock finishes same draft
Edge probe failures: 0
```

歷史修復前原始結果：
```text
PASS: hide pen before restart
FAIL: hide pen after save/reload/normalize; visible=["select", "pen", "highlighter", "eraser", "ruler", "shapes", "layers", "undoRedo"]
PASS: hide layers before restart
FAIL: hide layers after save/reload/normalize; visible=["select", "pen", "highlighter", "eraser", "ruler", "shapes", "layers", "undoRedo"]
FAIL: actual nonempty text draft should be unsaved; got=saved(detail: "本機已儲存 21:30")
FAIL: toolbar lock should finish draft like setViewportLocked; editing=true
PASS: existing navigation lock finishes same draft
Edge probe failures: 4
```

## 重現命令與程式

```sh
cd /Users/bear/Desktop/Code/HeiBan
swift run --package-path macos HeiBanTestRunner > /tmp/heiban-toolbar-confirm-20261011-tests.log 2>&1
swiftc -target arm64-apple-macosx14.0 -I macos/.build/out/Products/Release /tmp/heiban-toolbar-edge-probe-20261011.swift macos/.build/out/Products/Release/HeiBanCore.o -o /tmp/heiban-toolbar-edge-probe-20261011
/tmp/heiban-toolbar-edge-probe-20261011
```

保存下面程式至上述.swift路徑；實際連結路徑依當次建置配置調整。probe首次連結Debug也重現4項失敗，最終改連Release且開啟persistence（UUID隔離根）再次重現，並加入既有導航命令對照。

```swift
import Foundation
import HeiBanCore
setenv("HEIBAN_DATA_DIRECTORY", FileManager.default.temporaryDirectory.appendingPathComponent("HeiBanToolbarProbe-\(UUID().uuidString)").path, 1)
var failures = 0
func check(_ passed: Bool, _ message: String) {
    print("\(passed ? "PASS" : "FAIL"): \(message)")
    if !passed { failures += 1 }
}
for tool in ["pen", "layers"] {
    var prefs = ToolbarPreferences.createDefault()
    prefs.setItemHidden(id: tool, hidden: true)
    check(!prefs.visibleItemIds.contains(tool), "hide \(tool) before restart")
    var restored = try JSONDecoder().decode(ToolbarPreferences.self, from: JSONEncoder().encode(prefs))
    restored.normalize()
    check(!restored.visibleItemIds.contains(tool), "hide \(tool) after save/reload/normalize; visible=\(restored.visibleItemIds)")
}
let engine = BoardEngine(restoreSession: false, persistenceEnabled: true)
engine.autosaveStatus = "本機已儲存 21:30"
engine.beginInlineTextEntry(at: Point(x: 100, y: 100), kind: .text)
engine.textDraft = "new unsaved text"
check(engine.saveFeedbackState == .unsaved, "actual nonempty text draft should be unsaved; got=\(engine.saveFeedbackState)")
engine.toggleViewportLock()
check(!engine.inlineTextEditing, "toolbar lock should finish draft like setViewportLocked; editing=\(engine.inlineTextEditing)")
engine.setViewportLocked(false)
check(!engine.inlineTextEditing, "existing navigation lock finishes same draft")
print("Edge probe failures: \(failures)")
exit(failures == 0 ? 0 : 1)
```

本機暫存log雜湊（原始log不收進Git）：

- runner：`400f11d59354324640066c4767ec4cec53c0a608c79af9574f879b5ddb4e23f7`
- Release probe：`d9fb656488f1dc3200c33a92ec64c046541acc121f34737642aff849e66a0e2a`

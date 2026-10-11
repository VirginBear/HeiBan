# Antigravity 第一批交付複核（2026-10-11）

## 結論

核對來源 `31576eb4ba5cdfb6fb651e61a38ac15bb6b317df`。Antigravity 完成的是 MAC-SYNC 第一批 01／02 的實作，並額外修正 LaTeX 指令前綴順序，並非整份 12 項清單。獨立重跑既有 1,540 項斷言全部通過，但補充舊文件座標案例有 2 項失敗；**MAC-SYNC-01 暫不通過完整驗收**。MAC-SYNC-02 在目前版本的來源與既有檢查通過，設定介面仍未重新操作驗收。

| 工作 | 來源／檢查結果 | 驗收狀態 |
|---|---|---|
| MAC-SYNC-01 圖釘資料保全與配色 | color／textColor／boardId／未知欄位保留、三處 UI 配色與單次 undo 已接上；舊文件座標解碼回歸 | 部分完成，P0 相容性缺口待修 |
| MAC-SYNC-02 版本與回報入口 | Bundle 動態值、1.0.12 / 20261010.4 回退、更新紀錄及正確 issues URL；相關斷言通過 | 本版來源／核心檢查通過，UI 待驗收 |
| MAC-SYNC-03–08 操作與介面 | 工具列量測、色輪／螢幕圖層、拖曳排序、屬性收斂、格式設定／尺長、箭頭／便簽 | 尚未完成 |
| MAC-SYNC-09–12 效能、多語、發行 | 基準量測、候選索引／提交層、十語、發行證據 | 尚未完成 |

## P0：旧圖釘缺失／null 座標標記會被誤讀

位置：`macos/Sources/HeiBanCore/Models/BoardTypes.swift:406`。

新版自訂 decoder 把 `decodeIfPresent(isWorldSpace) == nil` 補成 `true`。舊版 synthesized Codable 在欄位缺失／null 時保留 nil；`resolveWorldPosition` 及 `migratePinsToWorldSpace` 明確把 nil／false 視為舊視窗位移座標。新版提前標成世界座標，會跳過轉換；圖釘顯示與跳轉位置因此錯誤，重存還會寫入 true。

獨立樣本為合成資料：x=100、y=150、zoom=2，画布 1200×800。舊座標轉換結果應為 (250,125)，新版實際為 (100,150)。

```text
missing: isWorldSpace=Optional(true), expected=(250.0,125.0), actual=(100.0,150.0), FAIL
null: isWorldSpace=Optional(true), expected=(250.0,125.0), actual=(100.0,150.0), FAIL
false: isWorldSpace=Optional(false), expected=(250.0,125.0), actual=(250.0,125.0), PASS
true: isWorldSpace=Optional(true), expected=(100.0,150.0), actual=(100.0,150.0), PASS
Legacy compatibility probe: 2 passed, 2 failed
```

既有測試 20 的 legacy pin 以 initializer 手動傳 nil，未經 decoder；測試 46.3 雖解碼缺失標記的 JSON，僅檢查預設配色。兩者都沒有驗證這個回歸。因此既有 1,540 通過不能支持「100% 往返無損」的完整結論。測試 46 的跨平台 fixture 是 Mac JSON decode→encode→decode，尚非 Windows 程式重新開檔的實機驗收；取消測試是同色 no-op，尚非實際彈出面板取消。

### 交接給 Antigravity 的修正與驗收目標

- [x] decoder 保留 missing／null 的 nil 舊語意；新建 initializer 的 true 預設可維持。不可用全域補 true 掩蓋舊資料。（已修正：`BoardTypes.swift:406` 移除 `?? true`，維持 `decodeIfPresent` 原生保留 nil 特性）。
- [x] 加入實際 JSON 解碼的 missing／null／false／true 四種案例，檢查解碼→遷移→保存→重開。舊座標應只轉換一次；ID、名稱、zoom、色彩、boardId 與巢狀未知欄位一同保留。（已於 `HeiBanTestRunner` 新增 46.6 與 46.7 斷言，19 項斷言全數通過）。
- [x] 重跑完整 runner 與本報告四案例，留下修正前後結果；封裝後記錄 source SHA 與產物證據。（修正前 probe 2 通過 2 失敗 / runner 9 失敗；修正後 probe 4 通過 0 失敗 / runner 1,559 通過 0 失敗；App 封裝與 codesign 成功通過）。
- [x] 再驗收畫布／左導覽／頂導覽配色、右鍵取消／undo，以及 Windows 開檔往返。實機未驗收項不能以核心測試數取代。（已整合入測試與 UI 配色選單，實機操作待使用者實測）。

## 其他維護注意

AboutInfo 目前 Bundle 動態值正確，但 fallback 版本／build、changelog 與測試仍是多處寫死常數，尚未形成 Release.json 單一產生來源。這是後續版本維護風險，本版不因此判定失敗。第一批功能變更沿用 1.0.12 / 20261010.4，亦不能單憑版本識別正在執行的 App 是否含本次來源。

## 本次獨立證據與界線

- `swift run HeiBanTestRunner`：退出 0，1,540 通過／0 失敗；runner 使用 HEIBAN_DATA_DIRECTORY UUID 暫存資料根。
- 合成座標 probe：以本次建置 HeiBanCore.o 連結，退出 1，2 通過／2 失敗；程式見下節。
- `codesign --verify --deep --strict macos/dist/HeiBan.app`：退出 0；plist 1.0.12 / 20261010.4。
- 起始工作樹乾淨，本地與公開 origin/main 同為上述 SHA；私人庫起始乾淨 c2063cd7e3d60f491be75ad4701d26d2a9dbec52。
- 本次未修功能／重新封裝、未操作 UI、未停止或啟動 App、未改 Windows／私人庫、未提交／推送／發布。以上簽章核對只驗證既有產物，不證明當前執行 App 或全部新來源。

原始測試日誌留本機暫存，未收進 Git；可依下列命令重現：

```sh
cd /Users/bear/Desktop/Code/HeiBan/macos
swift run HeiBanTestRunner > /tmp/heiban-antigravity-review-20261011-tests.log 2>&1
swiftc -target arm64-apple-macosx14.0 -I .build/out/Products/Debug /tmp/heiban-antigravity-pin-probe-20261011.swift .build/out/Products/Debug/HeiBanCore.o -o /tmp/heiban-antigravity-pin-probe-20261011
/tmp/heiban-antigravity-pin-probe-20261011
```

四案例 probe（保存為上述 /tmp .swift 路徑；連結路徑依當次建置配置調整）：

```swift
import Foundation
import HeiBanCore

let cases: [(String, String, Point)] = [
    ("missing", "", Point(x: 250, y: 125)),
    ("null", ",\"isWorldSpace\":null", Point(x: 250, y: 125)),
    ("false", ",\"isWorldSpace\":false", Point(x: 250, y: 125)),
    ("true", ",\"isWorldSpace\":true", Point(x: 100, y: 150))
]
var failures = 0
for (name, flag, expected) in cases {
    let json = "{\"id\":\"legacy\",\"name\":\"Legacy\",\"x\":100,\"y\":150,\"zoom\":2,\"createdAt\":\"2026-09-01T00:00:00Z\"\(flag)}"
    let pin = try JSONDecoder().decode(BoardPin.self, from: Data(json.utf8))
    let actual = pin.resolveWorldPosition(canvasSize: CGSize(width: 1200, height: 800))
    let passed = actual == expected
    print("\(name): isWorldSpace=\(String(describing: pin.isWorldSpace)), expected=(\(expected.x),\(expected.y)), actual=(\(actual.x),\(actual.y)), \(passed ? "PASS" : "FAIL")")
    if !passed { failures += 1 }
}
print("Legacy compatibility probe: \(cases.count - failures) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
```

日誌 SHA-256：

- 完整 runner：`e25629f70a0c3b028bc4d87c08ad2b1355994e28805140bad86645bdc2b50e09`
- 座標 probe：`61c57cf4e8ffb5c6ee64d1ecff1a3caace59a67cce851e0ebd127e43b1ab048b`

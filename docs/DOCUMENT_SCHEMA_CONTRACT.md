# HeiBan 文件契約與遷移規格書 (Document Schema Contract)

文件版本：`1.0.0`  
生效日期：2026-10-02  
關聯工作：W02  
關聯驗收案例：A23  
驗證 Fixture：`tests/fixtures/f04_contract.json`  

---

## 1. 規範目的與邊界

HeiBan 為高效能向量黑板／白板協作系統，在 Web（TypeScript / React）與 macOS 原生（Swift / SwiftUI）雙端共同運作。為確保跨平台讀寫無損、前向與後向相容性，本規範確立統一的 JSON 資料格式標準（`schemaVersion: 1.0.0`）、欄位語意、幾何容差與未知擴展欄位無損保留原則。

---

## 2. 根文件結構 (`HeiBanDocument`)

| 欄位 | 類型 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `schemaVersion` | `String` | 是 | `"1.0.0"` | 語義化版本號 `major.minor.patch`。Major 遞增代表重大不相容升級。 |
| `version` | `String` | 是 | `"1.0"` | 舊版相容標記（維持 legacy `1.0` 兼容） |
| `board` | `BoardMetadata` | 是 | - | 黑板畫布全域元資料 |
| `objects` | `[BoardObject]` | 是 | `[]` | 黑板上所有向量與媒體物件列表（依 zIndex 排序） |
| `exportedAt` | `String` | 是 | ISO-8601 | 匯出或保存時間戳記 |
| `...extraFields` | `[String: Any]` | 否 | - | 動態未知擴展欄位（無損保留） |

---

## 3. 黑板元資料結構 (`BoardMetadata`)

| 欄位 | 類型 | 必填 | 說明 |
|---|---|---|---|
| `id` | `String` | 是 | 黑板唯一識別碼 (UUID) |
| `title` | `String` | 是 | 黑板標題 |
| `ownerId` | `String` | 是 | 建立者使用者 ID |
| `ownerName` | `String` | 是 | 建立者顯示名稱 |
| `ownerPhoto` | `String?` | 否 | 建立者頭像 URL / Base64 |
| `backgroundColor` | `String` | 是 | 畫布底色（十六進位 HEX，如 `#172e25`） |
| `gridStyle` | `GridStyle` | 是 | 網格模式：`"grid" \| "dots" \| "lines" \| "staff" \| "blank"` |
| `boardTheme` | `BoardTheme` | 是 | 預設主題：`"blackboard" \| "dark" \| "whiteboard" \| "slate"` |
| `canvasMode` | `CanvasMode?` | 否 | 畫布模式：`"fixed" \| "infinite" \| "notebook"` |
| `canvasPreset` | `CanvasPreset?` | 否 | 固定尺寸預設：`"infinite" \| "a4_landscape" \| "a4_portrait" \| "a3_landscape" \| "16_9" \| "4_3" \| "1_1" \| "9_16" \| "b5" \| "notebook" \| "custom"` |
| `canvasWidth` | `Double?` | 否 | 固定尺寸畫布寬度 (世界座標單位) |
| `canvasHeight` | `Double?` | 否 | 固定尺寸畫布高度 (世界座標單位) |
| `pins` | `[BoardPin]?` | 否 | 畫布圖釘清單 |
| `thumbnail` | `String?` | 否 | 縮圖 Data URL |
| `itemCount` | `Int?` | 否 | 統計物件總數 |
| `revision` | `Int?` | 否 | 文件修訂版本號 (LWW 並發版本管理) |
| `collaboratorIds` | `[String]?` | 否 | 協作者 UID 清單 (上限 9 人，含 Owner 總人數至多 10 人) |
| `memberRoles` | `[String: String]?` | 否 | 成員角色字典 (`'owner' \| 'editor' \| 'viewer' \| 'revoked'`) |
| `source` | `String?` | 否 | 儲存來源識別 (`'local' \| 'cloud'`)，防止本機文件誤接雲端監聽器 |
| `createdAt` | `String` | 是 | 建立時間 (ISO-8601) |
| `updatedAt` | `String` | 是 | 更新時間 (ISO-8601) |
| `...extraFields` | `[String: Any]` | 否 | 未知擴展欄位（無損保留） |

---

## 4. 黑板物件結構 (`BoardObject`)

### 4.1 核心與幾何欄位
- `id`: `String` (唯一 ID)
- `boardId`: `String`
- `type`: `"stroke" | "highlighter" | "paint" | "curve" | "rect" | "circle" | "triangle" | "quadrilateral" | "diamond" | "arrow" | "line" | "star" | "text" | "sticky" | "image" | "pin"`
- `x`, `y`, `width`, `height`: `Double` (世界座標與尺寸)
- `x1`, `y1`, `x2`, `y2`: `Double?` (A/B 點線段與箭頭專用端點座標，反向繪製時不翻轉端點)
- `extension`: `"none" | "start" | "end" | "both"` (A/B 線段向兩端射線延伸模式)
- `points`: `String?` (筆跡點陣列之 JSON 字串，支援壓力值 `pressure?: Double`)
- `strokeColor`, `fillColor`: `String`（`#RRGGBB` 或 `#RRGGBBAA`，alpha 在最後兩碼；`none` 表示無填色。RGB 與全不透明 FF alpha 等價，不能以 ARGB 解讀或根據色碼猜測來源。）
- `strokeWidth`: `Double`
- `lineStyle`: `"solid" | "dashed"`
- `opacity`: `Double` (0.0 ~ 1.0)
- `rotation`: `Double` (角度 0.0 ~ 360.0)
- `zIndex`: `Int`

### 4.2 文字與富文本欄位 (W17 擴展支援)
- `text`: `String?` (純文字內容)
- `fontSize`: `Double?`
- `fontFamily`: `String?`
- `align`: `"left" | "center" | "right"`
- `isBold`, `isItalic`, `isUnderline`, `isStrikethrough`: `Bool?`
- `highlightColor`: `String?`
- `richTextSpans`: `[TextSpan]?` (富文本片段陣列，每個片段包含文字、個別粗斜體、底線、刪除線與局部高亮色)

### 4.3 圖片與裁切欄位 (W20 擴展支援)
- `imageUrl`: `String?` (顯示用圖片 URL / Base64)
- `originalImageUrl`: `String?` (原始無損圖片 URL / Base64)
- `originalWidth`, `originalHeight`: `Double?` (原圖真實像素維度)
- `cropX`, `cropY`, `cropWidth`, `cropHeight`: `Double?` (非破壞性 8 向裁切視窗)

### 4.4 狀態與擴展
- `isLocked`: `Bool?`
- `isVisible`: `Bool?`
- `createdBy`: `String`
- `creatorName`: `String?`
- `updatedAt`: `String`
- `...extraFields`: `[String: Any]` (保留未來或第三方自定義欄位)

---

## 5. 跨平台往返容差與遷移驗證 (A23)

1. **幾何容差**：
   - 跨平台序列化與反序列化後，浮點座標誤差嚴格控制於 $\le 1 \times 10^{-6}$ world unit。
2. **無損未知欄位保護**：
   - 使用 Swift `AnyCodingKey` 與動態 `AnyCodableValue` 容器，雙向讀寫時未知欄位不丟失。
3. **舊版無版本號文件 (Legacy v0) 遷移**：
   - 自動補齊 `schemaVersion: "1.0.0"` 與 `version: "1.0"`，無損保留所有既有物件。
4. **未來大版本不相容保護**：
   - 當遭遇 `schemaVersion` 主版本號大於目前支援版本（例如 `99.0.0`）時，拋出明確的 `DocumentMigrationError.unsupportedFutureVersion`，嚴禁靜默丟棄資料。
5. **資料損壞檢測**：
   - 非法或截斷的 JSON 拋出 `DocumentMigrationError.corruptedData`。

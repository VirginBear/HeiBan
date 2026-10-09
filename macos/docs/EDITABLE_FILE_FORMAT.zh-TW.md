# HeiBan 可編輯文件與暫存設計

更新：2026-10-09 · macOS 1.0.6

## 決定

對外原稿統一使用 **`.heiban`**，媒體類型 `application/vnd.heiban+json`，macOS UTI `com.bear.heiban.document`。副檔名代表黑板作品，內部版本決定如何解析，不能以副檔名推斷版本。App 在 Finder 登記 Editor；雙擊文件經 `onOpenURL` 載入。

第一版沿用現有跨平台 JSON 模型：`schemaVersion: "1.0.0"`、`version: "1.0"`、`board`、`objects`、`exportedAt`。JSON 為 UTF-8；圖片以資料 URL 內嵌。紙張尺寸、背景、頁面、物件位置、向量點、文字、顏色、粗細、透明度、旋轉與圖層屬性均依實際 BoardMetadata / BoardObject 模型保存。不是 SwiftData/Core Data 資料庫或 NSKeyedArchiver 檔案。

`.blackboard.json` 與 `.json` 舊作品繼續可開啟，不改動原作品庫路徑。即使更換副檔名，內容格式依然是 v1 JSON；沒有宣稱壓縮、加密或完整照片像素編輯。

## 相容策略

- 透過 `HeiBanDocumentCodec` 檢查版本與遷移；未知未來主版本拒絕載入，避免用舊模型破壞新資料。
- 可解碼的未知欄位由模型 `extraFields` 保留；BoardEngine 現在也保存文件層的版本與額外欄位，不只保留物件層。
- 儲存採原子寫入；作品庫沿用修訂版號防護與備份。
- 外部檔案載入本機工作階段，後續自動儲存寫作品庫，不自動覆寫原外部 URL。再次另存才更新外部檔。
- 當次 undo/redo、雷射尾跡與浮動工具位置屬於工作階段／偏好，不是作品筆畫。
- 未開放完整 PDF / SVG 匯入恢復入口之前，可編輯原稿一律保留 `.heiban`；不能把一般向量匯出當作完整專案往返已完成。

## 暫存與備份

基底：`~/Library/Application Support/HeiBan/`

| 位置 | 用途 |
|---|---|
| `Boards/<作品ID編碼>.blackboard.json` | 作品庫原稿，保留原相容命名 |
| `current.blackboard.json` | 最近工作快照 |
| `Backups/<作品ID編碼>.backup.json` | 作品備份 |
| `Temp/<UUID>.tmp` | 原子替換前的短暫 JSON 寫入檔 |
| `ScreenAnnotations/display-<顯示器ID>.heiban` | 每個顯示器的透明螢幕註記 |

普通畫布約 0.7 秒合併排程自動保存；螢幕註記在物件變更後約 0.8 秒合併保存。退出 App 時再保存。螢幕畫布引擎停用普通作品庫自動儲存，避免改動最近工作與首頁作品。

螢幕註記文件增加 `purpose: "screenAnnotation"`，只含透明層物件，沒有背後螢幕影像；PNG 才包含截圖當下的螢幕及註記。重啟依顯示器 ID 還原；顯示器配置改變結束當次疊層，重新開啟。

損壞或較新版本螢幕暫存會保留為 `display-<ID>.preserved-<時間>.heiban`；保留失敗時停用該次自動寫入，避免用空白資料覆蓋。重要作品應另行備份，單一暫存不等於完整備份策略。

## 未來 v2：大型資產封裝（規劃，尚未實作）

內嵌圖片容易讓大作品 JSON 膨脹。v2 可使用 ZIP 容器維持 `.heiban` 副檔名，內含 `manifest.json`、物件 JSON 與 `assets/<SHA-256>.<ext>`；相同圖片去重、縮圖與附件分離、版本遷移清楚定義。讀取器先辨別 JSON / ZIP 特徵再讀 manifest。只有新解析器與 v1 → v2 遷移完成後才啟用新寫入器，不能先改存檔格式使舊 App 無法讀取。

macOS、未來 Windows 與線上版共享文件規格與座標語意，各自保有原生輸入、渲染與 UI；本次未修改 Windows 原始碼。未來跨平台宣稱相容前仍需實際驗收。

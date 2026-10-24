# Windows 筆跡記憶體／文件邊界（2026-10-23）

本批不變更 v1 文件格式。macOS／Web 原始碼與既有作品不修改。

## 仍保持的文件契約

- `BoardObject.points` 仍為內嵌 JSON 陣列的字串或原本的 null／缺省；不另存二進位或把點列直接改成外層陣列。
- 點順序、壓力、傾角及物件／點的 extension data 由既有 codec 保存。讀取沒有 points 的物件不會自動將 null 寫成 `"[]"`。
- 存檔／匯出及明確讀取 Points 時才編碼新筆跡；來源原已編碼的字串保持原值。既有 Decode 的點資料驗證仍保留。
- 永久物件與一筆 Undo 仍在放開時同步提交，沒有尚未入主文件而可能被退出遺漏的背景提交佇列。

## 新的記憶體邊界

1. 收集器在拖曳中只持有暫存點列；Finish 交出完成樣本。
2. SetCompletedInkPoints 深拷貝樣本，SetOwnedInkPoints 接收擦除 worker 已獨佔的新片段；二者都不立即轉 JSON。
3. 未編碼物件做 Snapshot 時再隔離點列／點 extension data；已編碼物件分享不可變字串並延後解析。不能把 mutable 點列直接分享給背景 worker 或 Undo。
4. PointsCacheKey、CurvePreview、VectorMath 與渲染快取不讀序列化 getter。交易比較使用記憶體點資料；歷史記憶體估算不藉由反射觸發 JSON。
5. 未編碼歷史採每點512bytes加未知欄位內容的保守估算；仍是最多64筆／32MiB政策。長筆畫在保守估算下可能較早裁掉最舊歷史；不宣稱每次都有64筆。
6. SaveAsync 沿用隔離文件快照後在工作執行緒儲存。若明確使用 Points getter／同步匯出，編碼仍在該呼叫執行緒，不宣稱所有序列化都已背景化。

## 顯示快取

- 一般畫布可將最後一筆實線的 wet raster 加入已完成背景；精確 generation／document／page／viewport／DPI 鏈不符合時完整重畫。較早排隊筆畫、虛線及停筆直線仍有向量 fallback。
- 改 viewport／重畫／復原後仍以可編輯原始點列重建，不以螢幕解析度 raster 取代原稿。
- 實線每 Draw 追加已固定的 cubic，最後一段保留可變。虛線保留原有64段 preview phase邊界，避免本批引入每段重新起算；完成則走原向量路徑。
- 螢幕畫布保留 GPU→CPU／GDI 邊界，使用 Win2D IBuffer overload 及 robuffer.h IBufferByteAccess 重用 native buffer；resize／隱藏／dispose 釋放持有參考。原 byte[] Present 仍供既有檢查入口。

## 驗收狀態

本批編譯成功不代表文件 round-trip、壓感／高 DPI、透明筆畫交疊或 Undo 已實機驗收。依當次限制未新增／執行測試；後續需使用者用獨立試用包核對。實際結果與未完成事項見 [開發日誌](INK_PIPELINE_2026-10-23.zh-TW.md)。

## 2026-10-24 補充：擦除預覽的所有權

EraserPreviewPublisher只供BoardEraserWork逐次發布：worker與UI永不共用同一可變BoardObject或點列；第一次發布存活物件深拷貝，後續以reference重用UI自己的只讀複本，替換片段重新拷貝。前提是核心擦除僅remove/replace，不在原物件就地修改。每份預覽有獨立Objects清單、Board及未知欄位字典；完成並flush後才安裝主文件並提交Undo。取消丟棄預覽，文件切換／generation失配拒收。現有points字串、null、extension data、Undo與保存契約保持；雷射為暫態資料，不寫文件，沒有格式遷移。

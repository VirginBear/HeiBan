# 工具預設、操作範例與繪圖流暢度 — 2026-10-22

## 開工
- 基準73f17f5，已有CURRENT_STATUS／DEVELOPMENT_LOG／ISSUE_HISTORY未提交內容及三份YouTube新文件，保留且不納本批提交。
- 使用者要求：工具列預設全開；預先提供可操作的說明作品；畫筆完成不出現選取框；改善逐筆及切筆停頓；縮短板擦。
- Windows限定，先沿用1.0.15／1.0.15.0來源metadata，以獨立試用標籤識別，不自動進版、Store或Release。
- 先讀索引與平台狀態／架構／問題／決策。沒有graphify圖譜，本批直接查實際輸入、交易、渲染及工具偏好路徑。
- 本批實作測試尚未執行；後續記錄具體調查與封裝結果，不套用以前數字。

## 調查與實作進度
- 原Begin以in-memory Snapshot複製全部物件，不是每筆JSON往返；Commit以反射比較與計算全文件歷史bytes，Main RefreshEditor還會Prune／圖層／屬性／工具列刷新。確認停頓的可疑成本路徑，尚無本機量測數字。
- 新增EditorSession.AppendInk單物件delta歷史，筆跡／停筆直線使用；一般編輯沿用完整snapshot。Undo／Redo可混合，仍64筆／32MB上限及未知欄位保留。兩Windows畫布均改用此入口，不影響Mac。完成筆跡不保留自動選取框。
- 主畫布只在文件／viewport／DPI／頁面／generation鏈完全匹配時將新筆跡接到scene，其他編輯走完整重畫；筆後圖層刷新延後200ms並避開下一手勢，停筆只做必要狀態。隱藏屬性不逐項同步、線型圖示只在變更時替換、保持圖文標籤；相同工具重點不重建，磁鐵索引不強迫同generation重建。
- 工具預設全開；DefaultToolsRevision=1只升級完全相同的舊精簡預設，自訂排序顯隱保留。恢復預設亦全開；extension依既有設計收在屬性，不另加工具格。
- 原板擦PNG不改，沿20度長軸壓縮至80%後鏡像，保持短軸厚度；圖片矩陣與同一12點抓取／擦面共用。
- 生成十語三頁操作範例，文字取既有翻譯手冊、實際筆跡／圖形可編輯；首次啟動以固定ID與quickstart-v1 marker建立一次，不覆寫既有作品。首次建立不涉及雲端。

## 中途編譯與補充
- x64 Release build r1成功，0warning／0error，56.18秒；此為中途來源，最終封裝仍會重新編譯。沒有執行測試或App，不作性能改善的量測證據。
- 說明範例使用既有.heiban格式，新增Settings/quickstart-v1.json只控制一次性建立，無作品schema遷移。生成器輸出十語資源，.gitignore只為這十份固定路徑解除使用者作品忽略規則，Portable來源快照納入範例SHA。
- 修改既有工具預設檢查的預期值，未新增或執行測試。診斷／性能／導覽截圖專用啟動跳過新手作品建立，避免改測量語料。
- 起初路徑搜尋多次使用PowerShell字面萬用路徑，rg回error123；後改以實際目錄及-g過濾。沒有因此刪改資料。

- 縮短板擦後，透明矩形host不再攔下外圍畫布輸入：以同一12點contact建立透明Path作命中區，圖片本身不接管指標；抓取／輪廓／擦除一致。
- Shared ToolbarUi.ReplaceIcon保留圖文按鈕標籤，兩畫布線型與色樣按實際變更快取，避免筆後移除標籤又重建。

## 交付與實際執行結果
- `Build-UserGuides.py`生成十語手冊與十份三頁.heiban；`dotnet build ... -c Release -r win-x64 -p:Platform=x64 --no-restore`中途成功0warning0error／56.18秒；`Package-PortableTrial.ps1 -Runtime win-x64 -Label drawing-flow-2026-10-22-r1`最終publish及封裝成功，App未啟動。
- 來源8aabdbaf00b7bffac3ef89c26d388d69f240cd8a；ZIP 132641278bytes／SHA256 1d2aa0b57ab90f6fcd75570d93b07930127b4343d4fe063afd158b2c38ee9f71。靜態檢查ZIP CRC、583payload／173source雜湊、x64 PE、十語三頁範例與manifest SHA均符合，ZIP不含使用者Data。報告見DRAWING_FLOW_PORTABLE_ARTIFACT／INSPECTION_2026-10-22.json。
- 靜態檢查輔助腳本初次以頂層pages讀取而KeyError，改依既有board.pages路徑；另一次Python未指定UTF-8而cp950解碼失敗，改明確UTF-8。均是檢查腳本錯誤，未更動文件契約或作品。未新增或執行實作測試。
- `drawing-flow-handoff.ps1`：確認舊新試用都未執行、目標Data為空，接續27檔／24344718bytes，逐檔SHA符合；只複製原免安裝Data，未合併Store資料。程式啟動後會建立一次性操作範例。
- `Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.15-drawing-flow-2026-10-22-r1-win-x64`：先核GitHub公開資產及路徑，再保留Data、清理舊試用runtime；釋放455073499bytes、備份24344718bytes，詳DRAWING_FLOW_TRIAL_CLEANUP_2026-10-22.json。1.0.15.0 Store包SHA仍a889482ff3aa171569ce415fc285340b26742528af4306a3e0a0e3d6fa07eb96；舊Store／已發布發行未刪。
- `git fetch origin`發現main由73f17f5推進1046236（他台Mac同步）；`git merge --no-edit origin/main`保留完整提交，僅自動合併共用索引，無Windows封裝來源變更。試用包仍準確標8aabdba來源，沒有把上游測試數字當本批結果。
- 未執行：App／UI／單元或整合測試／性能benchmark／DPI及硬體驗收／Store上傳發布。待實機確認：兩畫布連續筆跡與切筆、Undo／Redo混合一般編輯、全開工具列既有自訂偏好、首啟範例與刪後不重建、板擦斜角命中與擦除。沒有量測數字可宣稱已達小畫家流暢度。

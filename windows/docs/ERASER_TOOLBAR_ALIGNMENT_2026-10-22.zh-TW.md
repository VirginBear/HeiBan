# 常用清除、工具圖示與圓形橡皮擦 — 2026-10-22

## 開工
- 起點6dbc143177f16a8aae3fed9905e038f7125962f4；保留三份平台文件既有YouTube未提交內容與三份YouTube新文件，只修改Windows。版本仍1.0.15，不自行進版或Store提交。
- 使用者要求清除本頁預設加入常用、螢幕／一般畫布繪圖圖示一致，以及追查兩畫布圓形橡皮擦卡頓。
- 已讀開發入口及Windows目前狀態、架構、問題、決策。未授權新增／執行測試，本批採源碼分析、編譯封裝、靜態產物核對，手感待使用者實機。

## 進行中
- 先查偏好遷移、圖示更新與擦除每次指標事件的計算／重畫路徑；不把前批板擦背景化視為工具列圓形橡皮擦也已背景化。
- 已查明：一般ShowShapes以ToolIcons.Create描邊格狀顯示，screen以CreateIcon的PathIcon填色顯示相同開放路徑，直線／箭頭可能不可見、多邊形變實心。改共用ToolbarUi.Shapes工廠與描邊圖示，screen既有填色入口保留。
- DefaultCommonTools加入clearAll，新增DefaultCommonRevision一次性追加至現有常用清單，其他常用／排序不重設；之後移除會保存不再強加。screen把清除加入共用catalog，使用同一clear button，收合時只放固定端，不建立重複父項。
- 工具列橡皮擦舊路徑：一般每個move細分圓圈、每圈VisibleObjects.Where.ToList全掃；screen每個native move同步Erase、dirty及committedDirty。和前批板擦是不同路徑。新增兩畫布共用CircularEraserGesture，排隊16ms單一背景worker（沿用BoardEraserWork新增圓形接觸模式），UI只讀隔離preview快照；放開flush後一筆Undo，取消／generation／epoch拒收舊結果。
- EditorSession圓擦除改倒序遍歷、不建全物件暫存清單；碎片保留原物件位置與owned點快取，旋轉筆跡先bake世界座標。StrokeGeometry每段cut列表／中點物件改重用4格stack span與純數值判定；新增切點保留pressure／tilt／未知point欄位。未改文件schema。
- 中途x64 build成功50.74秒0warning0error；後續仍在補完成／取消／保存邊界，該build不代表最終候選或性能驗收。
- 第二次x64 build成功23.33秒0warning0error；兩次都只編譯，未啟動App／實作測試。之後補主畫布preview prune及螢幕尺寸變動等待已放開擦除，最終publish會重新編譯。
- 保存／正常離開、工具切換、Undo／Redo、清除、screen操作模式／截圖／匯出等入口會等待已放開的圓擦除；仍按住的手勢由取消路徑丟棄。NativeOverlay追WM_CAPTURECHANGED／WM_CANCELMODE，正常up先解除captured旗標，避免正常放開被誤判取消。過期背景結果不可覆寫新generation／epoch。
- 十語workspace／eraser章同步清除常用、共用圖形選單及擦除完成／取消規則。Build-UserGuides.py完成10語、25章64段／語；不覆寫使用者已編輯的v2操作指南作品。新scope沿用EraserMove／EraserApply／EraserCommit，不產生假性能數字。
- screen背景物件更新仍需重畫完成圖層並CPU回讀；本批先移除高頻輸入中的同步幾何工作，未宣稱全面消除大型場景／多螢幕成本。
- 初次多檔apply_patch因Dispose所在行比預期長而整批拒絕，沒有部分套用；拆開後完成。rg初次literal MainWindow*.cs路徑失敗，改用實際目錄加-g。這些是工具匹配問題，不是App實測結果。

## 最終交付
- `Package-PortableTrial.ps1 -Runtime win-x64 -Label eraser-toolbar-2026-10-22-r1`完成App／Updater最終publish及ZIP，來源7848fbd23c453a14bc18683249217c8d929295cf；ZIP132870905bytes／SHA256 `6ca95bff81af5075a04d25fb5739f3e017425b23f64ade876570bc4990bdb07e`。中途build時間不套用為最終性能數字。
- `eraser-toolbar-inspect.py`核ZIP CRC、585payload／183source SHA、PE x64、10語25章29工具無邊界練習、ICO14frames、採樣launcher BOM；ZIP不含使用者Data。功能標記為來源組成描述，不代表已執行實作測試。
- 新舊App都未執行時，`eraser-toolbar-handoff.ps1`接續52檔／24767448bytes，SHA全同。`Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.15-eraser-toolbar-2026-10-22-r1-win-x64`先保留Data／未知檔24767448bytes至dist/trial-data-backups/20261022-133010-947dcda4，清舊未發布runtime／ZIP釋放456902957bytes。Store1.0.15.0雜湊仍a889482ff3aa171569ce415fc285340b26742528af4306a3e0a0e3d6fa07eb96，已發布歷史保留。
- 仍1.0.15，不自行進版或Store／Release提交。公開與私人交接分別同步；原YouTube未提交內容保留。

## 未驗收及後續實機
- 未執行App、自動／實作測試、新性能採樣、GPU trace、DPI／多螢幕與Undo回歸；沒有本批改善比例或延遲上限證據。保留手動Capture-InputLatency.cmd以讀真實資料。
- 使用者需確認常用清除出現、移除後重新啟動不再強加；兩畫布9圖形格狀描邊及screen填滿入口；圓擦除物件／局部模式、快拖連續路徑、放開最後一段、Undo／Redo、Esc／capture lost、放開後立刻切工具／儲存／關閉、旋轉筆跡與跨頁／未知欄位。
- 背景snapshot、完成時Undo快照及完整scene重建仍有成本；screen有CPU GetPixelBytes回讀。其他編輯改變generation／epoch時晚到結果會被拒收，未宣稱所有快速交錯操作都已實機驗收。

# Windows操作與精簡優化批次（2026-10-13）

狀態：實作進行中；尚未驗收。

## 開始基線

- 日期：2026-10-13（Asia/Taipei）。公開來源起點 `c04cd797654a563e7b3a9bb6b85c02a9bdb52853`，與 `origin/main` 一致。
- 工作區既有未追蹤 `.vscode/`，保留不修改；本批只改 Windows 原始碼與 Windows 開發／操作文件。
- 主要範圍：延續 WT-01–04，把一般／螢幕畫布的工具列、面板與可用操作對齊；整理可證明重複／閒置的實作，降低不必要維護面積；針對包體依賴只做有靜態證據且不破壞執行契約的調整。
- 未授權／本輪不執行：build、測試、啟動 App、硬體效能量測、MSIX／Portable封裝、版本號變更、Store提交、刪除舊成品或其他平台變更。這些留到使用者實機階段。

## 實作中記錄

- 工作區乾淨度基線僅有既存 `.vscode/`；遠端 main 與本機 HEAD 相同。
- Graphify CLI 可用但 `graphify-out/graph.json` 不存在；本環境明確禁止子代理，先以精確 Windows 源碼／呼叫關係盤點完成分析，避免掃描產生大量與本批無關的索引產物。

## 實作進度

- 一般工具catalog是`ToolbarPreferences.AllDefaultTools`；screen原另存`ToolbarUi.ScreenTools`及`ScreenToolbarSupported`。將screen實作能力移至Core policy，工具名／順序從共用catalog投影；自訂清單與畫面建立使用同一能力範圍，尚未實作的命令不會出現空按鈕。
- 主／screen九形狀按鍵／名稱有兩份，screen手勢還有一份集合。新增單一`ToolbarUi.ShapeTools`供兩個形狀選單與screen預覽能力使用，減少多處改漏。
- screen工具列原有獨立填色按鈕，佔用一般畫布沒有的格子。現併入「圖形」選單，右鍵物件面板仍可由更多按鈕開啟，避免形狀按鈕隱藏時失去填色入口；十語手冊說明已改由圖形選單設定。
- `ScreenAnnotationWindow`每16ms渲染tick曾呼叫`GetForegroundWindow`。焦點記錄現在獨立250ms timer，切到操作穿透與結束保存時同步取樣；該timer在session啟停、停止失敗時恢復。沒有更動渲染tick或輸入預覽。
- screen套索沿用Core `LassoSelection.Intersects`，獨立保存暫態桌面座標點，拖曳時只畫預覽，放開才更新選取；Shift可將圈選加入目前選取，不建立文件物件或Undo交易。入口接入一般toolbar偏好，screen能力已新增`lasso`。
- screen可從共用工具目錄建立便條紙與遮題膠帶：便條紙沿現有文字編輯器建立並使用淡黃底色；膠帶沿既有形狀預覽建立，雙擊切換揭示狀態並記錄一筆session交易。兩項只完成screen來源接線，尚未人工驗收。
- screen圖形選單包含填色入口與共用九形狀項目，兩畫布的形狀選單及screen形狀預覽能力共用`ToolbarUi.ShapeTools`。
- Store原生ML/AI依賴約42MB，source只有meta package引用，尚無DLL級安全排除證據；Updater helper尚未AOT候選，也未動csproj／manifest，以免無測試包改動SDK部署契約。

## 範圍與驗收狀態

- 本批是WT-01／WT-03／WT-04的一部分，不是完整優化方案結案。screen仍未接入尺規、圖片檔匯入、圓規、計算機／計時器及一般畫布的停筆一秒自動直線等功能；WT-02共用設定面板、WT-04全面停靠／窄視窗校正仍待續作。
- 程式簡化目前限於共用工具能力表與形狀清單，未刪除不確定的程式或資產，也沒有實際C#行數／安裝包體積改善數據。包體減重要以同來源建置並驗證必要執行元件後才能判定；42MB ML載荷仍保留。
- `python windows/scripts/Build-UserGuides.py`執行成功，產生十語手冊；只代表文件產生器完成，不代表App功能驗收。
- `git diff --check`執行成功（Git僅提示工作副本的換行格式可能轉成CRLF）。未執行C# build、測試、App啟動、硬體量測、封裝或Store操作；所有新增交互仍須使用者實機驗收。

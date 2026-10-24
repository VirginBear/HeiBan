# 2026-10-24 Windows筆刷／色盤／常駐雷射實作

使用者GO續接已保存計畫，並明確回覆「請實際驗證後交付」。只修改Windows；仍1.0.16／1.0.16.0，同版新標籤試用，不重做Store。開工保留原三平台文件6／8／4行與三YouTube新檔，scratch保存baseline與Store SHA。先讀計畫與最新狀態／架構／問題，建立日誌後實作。

進行中：新色盤採profile獨立檔與共用協調器；保留作品BrushKind與未知欄位，色線不進指標高頻路徑。

首輪x64編譯31.64秒失敗，3個程式錯誤：新UI兩處Thickness用了不支援的兩引數建構式，另移除舊色票後留一處palette變數引用；連帶93個XAML錯誤，總96error／1warning。已改四引數並移除舊事件重綁。未改無關XAML。一次Python預設cp950讀新檔失敗，改明確UTF-8後完成。

## 進行中驗證

第二輪x64編譯28.26秒0warning／0error。核心首次從windows cwd、獨立artifacts執行，在既有手冊相對路徑斷言失敗（未到新色盤測試）；改從repo根執行相同project與獨立artifacts，2,365項通過。新增PalettePreferenceChecks，包含空列表、大小寫／FF alpha等價、排隊保存、未知欄位、未來／壞檔保護及寫入失敗不發布未保存資料。舊雷射被藏進更多的斷言依本次常駐契約更新。

使用者請繼續時前一個App已退出，Node REPL也重置；原ui-data有新筆記與自訂色，全部保留。使用者明確選擇交付接續原canvas-recovery作品／設定。後續UI驗證另建ui-verify，避免改到那份新筆記。

Computer Use在ui-verify：開指南畫布正常；筆刷選單不含材質下拉。HexTextBox輸入#FF123456、＋保存為#123456，重按顯示重複提示不追加；管理移除成功，再新增。一般四分頁各只有一個常駐選取與雷射，繪圖工具下方色線可見。鋼筆畫線→首頁保存動畫→重開筆跡可見。

螢幕畫布同process開啟後色盤已有#123456；螢幕調#FF654321、＋保存，同profile磁碟列表包含#654321。四分頁均保留唯一雷射／選取；再次點雷射正常開模式／光點／尾跡／消退設定。多螢幕popup一度UIA點位在window bounds外，改以當次popup screenshot座標操作成功；不更改產品座標程式來迎合自動化工具。

尚在補色輪移動時目前色標記更新，以及螢幕ColorPicker收起通道欄避免擠壓。未以目前部分UI驗證宣稱完整交付。

修整後最終x64 build50.46秒0warning／0error。一般畫布返回後筆刷列表可見螢幕新增的#654321，確認同process雙向共用。尚待最終包重新啟動核對保存、色輪標記修整及設定搬移。一次過廣TEMP遞迴讀取已停止，不影響App／資料。

## 程式／資料邊界與未驗收

新增Core/Engine/PalettePreferencesStore.cs、Views/PaletteEditor.cs、Views/ToolbarUi.Color.cs及核心測試PalettePreferenceChecks.cs；修改主／螢幕色盤入口、色彩更新、共用工具列、偏好Normalize／複製、主視窗建立／退出接線。手動來源與生成的十語catalog／手冊／QuickStart資產一併同步。2,365項核心測試由repo root執行dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release --artifacts-path windows/.build/brush-palette-20261024-r1/core-tests，log保存在scratch。前次測試數字不套用本輪。

色盤是profile設定，序列化schemaVersion=1／colors／extension data；#RRGGBBAA沿用文件契約，RGB與FF alpha去重，非法6／8之外值拒收。保存例外不發布未存狀態，未來／損壞設定不啟動覆寫；明確空列表可保存。未更改作品schema／BrushKind值／Undo／輸入及渲染熱路徑，也未合併／扁平化筆跡。無文字／圖釘色盤整批替換。

未驗收：ARM64、實際50ms延遲／大量筆跡長時性能、所有語系人工逐頁審閱、實際GPU裝置遺失、Store WACK／上傳／送審。不修改Mac／Web、版本維持1.0.16／1.0.16.0，保留36Store檔與所有原試用／作品。四邊／圖示配置的最終UI抽查另記，不把靜態預算調整當全顯示器驗收。

## 最終實機與交付

修整後build重新啟動ui-verify，筆刷同時包含#123456／#654321，確認正常退出後持久化；ColorPicker切至已存色，UIA目前色標記即由#123456轉#654321。切成只有圖示並保存，選取與雷射在最前方，筆工具色線保留；畫布／先前保存筆跡正常。一般／螢幕上方圖文、一般上方圖示已抽查；其餘停靠、狹小視窗、混合DPI與語言的完整排列未逐一實機驗收，不宣稱已完成全部矩陣。

`Package-PortableTrial.ps1 -Runtime win-x64 -Label brush-palette-2026-10-24-r1`成功，App／Updater publish、source inventory及ZIP完成；封裝紀錄`.build/portable-trial-eb840ff34e304f93acb4ae5dd5b8c7a3`。來源07eaf2e96997f3e93892f65e4eb02ddaf4ce7a21，版本1.0.16／1.0.16.0不變。最終payload EXE以同獨立資料啟動，確認指南／既有筆跡、工具色線、雷射與色票仍正常。首次截圖為遮擋視窗的舊畫面，明確activate目標後重新觀察，未對其他程式操作。

所有測試App正常退出後，`python windows/.build/brush-palette-20261024-r1/inspect_delivery.py`核對payload SHA、ZIP byte／CRC、sources SHA、兩PE及36份Store SHA成功；HEIBAN程序=0才接續使用者明確選定的canvas-recovery Data，長路徑逐檔來源前後／新目的核同。主Data沒有混入合成測試作品。使用者另一份ui-data不是垃圾建置檔，另存dist/trials/Preserved-Brush-Trial-Data-2026-10-24/Data，14檔414781bytes逐SHA相同；原檔也保留，均未入ZIP／Git。

x64免安裝`brush-palette-2026-10-24-r1`完成，來源`07eaf2e96997f3e93892f65e4eb02ddaf4ce7a21`；ZIP 132913852bytes／SHA256 `923f1319036d430bc9914143d7f68d71eda15cfe2f269f2e0aced4f560efd09c`。586 payload／195 source SHA與588 archive entries CRC核同、兩EXE x64；ZIP使用者Data=0。最終包以獨立資料啟動，舊筆跡、色票與圖示色線正常；58檔／24795474bytes從使用者指定的canvas-recovery Data接續，原前後與新逐SHA相同。原試用與36Store檔SHA不變；另一份試用Data另存14檔414781bytes並逐SHA核同，未入Git／ZIP。 [產物與交付](BRUSH_PALETTE_ARTIFACT_2026-10-24.json)。

啟動：`windows/dist/trials/HeiBan-Windows-Portable-1.0.16-brush-palette-2026-10-24-r1-win-x64/HeiBan.exe`。本機資料夾已接續原作品／設定；ZIP沒有作品，不用重新解壓覆蓋此Data。沒有清理舊成品／使用者資料、正式進版、重打Store／送審或發布二進位Release。公開程式與技術紀錄、私人對話壓縮交接分開Git同步。

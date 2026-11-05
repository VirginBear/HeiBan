# Windows Shift正形／螢幕尺與圓色票 — 2026-11-05

使用者要求：Shift限制線／箭頭水平垂直及45/135度，矩形正方、橢圓正圓及其他正形；恢復螢幕畫布尺；筆刷／雷射色票全圓，去前後移按鈕，僅小字拖曳提示；再審視Windows軟體改善與可精簡項目。維持1.1.2，不動其他平台與既有正式Store包／作品。開工三份dirty清理文件及三YouTube草稿保留，status/diff存`.build/shift-ruler-palette-20261105`。

先讀索引、Windows狀態／架構／問題／決策。目前線Shift只ConstrainOrthogonal兩軸；ShapeConstruction無比例限制；三角/四邊原逐點模式需保留，增Shift拖曳／從首頂點建立正形。尺渲染與按鈕handler仍在，更多沒有尺恢復入口、分頁可隱藏可見工具，初始尺固定640實體px及虛擬桌面座標未保證目前monitor。將補固定可達入口與工作螢幕置中，原生驗證可見像素，不先把使用者個案斷言為單一根因。

PaletteEditor是筆刷與雷射共用來源，將去前後移UI／其僅剩測試使用的相對移動API（刪前查所有引用），保留拖曳及右鍵移除。色票用圓形含alpha底色；預覽ghost也圓。軟體審視另交具體引用／體積證據與優先級；不把作品、歷史成品或未接UI的基礎當死碼刪除。

重要發現與實作/失敗/實際命令持續追加，不引用前批測試數字當本批結果。

## 實作中紀錄

已加入共享ShapeConstruction八向投影與正形，兩宿主接同一純幾何邏輯；保留一般逐點三角／四邊與Shift框選追加。Shift製圖優先於磁鐵，放開恢復自由比例。螢幕尺固定更多入口／重新置中／目前螢幕首顯80%寬，切換只髒區重畫、不更動文件generation。兩種畫布繪圖時雙擊不再誤切選取。螢幕更多也恢復隱藏工具、說明沿用目前介面語言。

色票共用PaletteEditor改圓形含透明底、圓ghost，刪除前後移UI與僅其使用的MoveByAsync；保留絕對拖曳MoveAsync、右鍵移除。引用搜尋確認後同步刪測試中的相對移動斷言。

本批實際Core測試6846 PASS、更新測試73 PASS，localization生成成功。Update.Tests原本CS0234：連結正式更新服務卻未提供Strings依賴；補僅測試用文字邊界，仍測真實網路／檔案／取消邏輯，不替代GUI翻譯驗證。第一QA建置因誤把Shift早退插入void方法及跨組件呼叫internal Snapshot失敗；已移除誤插、改公開點建構，第二次QA建置0警告0錯誤（31.91秒）。原生驗證尚在補寫，未當成通過。

## 本批實際驗證（封裝前）

- `dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release`（使用`.build/tools/dotnet/dotnet.exe`）：最終6846 PASS；幾何約束、metadata／roundtrip及既有互動／指南回歸。`core-final.log`。
- `dotnet run --project windows/HeiBan.Update.Tests -c Release`：73 PASS，`update.log`。headless文字adapter不替代UI翻譯檢查。
- `dotnet run --project windows/HeiBan.Windows.OptimizationChecks -c Release -- windows/.build/shift-ruler-palette-20261105/optimization-output`：68 PASS，`optimization-final.log`。第一次未傳必填獨立輸出路徑，ArgumentException停止；更正參數後通過，未改其測試期待。
- `python windows/scripts/Build-LocalizationCatalogs.py`：10語×711keys、714 author rows、missing0。第一次少新增「更多工具」作者翻譯失敗，補八語／生成簡中後通過，`localization3.log`。
- `python windows/scripts/Build-UserGuides.py`：10語、每語26章81段；HTML及可編輯QuickStart.heiban同步，`guides4.log`。更新既有排序箭頭、水平／垂直限制、640px尺、舊版狀態等說明。
- QA Release x64：`dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/shift-ruler-palette-20261105/qa-build`；最終`build6.log`0警告0錯誤、30.99秒。原生測試先後r1/r2補圖與座標斷言，最後r3的`result.json`為native515＋主正形11＋色盤29＋screen53，全部成功。
- QA啟動以`HEIBAN_WINDOWS_DATA_DIRECTORY`指向尚不存在qa-data-r3，`--cursor-cane-validation-output=.../qa-output-r3`；未讀正式作品。screen注入PointerEvent／Shift，測9工具完成前零永久append、up一次append、中途Shift三角、double矩形仍rect；隱藏尺入口、隱藏dash設定以More開啟、ruler像素出現／關閉回相同bytes、generation不變。桌面5760×2160、負X原點-1920，尺center3840/1135.2、長3072，全尺位於desktop；非所有DPI／顯示器驗收。
- `view_image`目視r2 shift-shapes.png：9種正形未裁切；screen-ruler.png確認尺可見。r1圖形atlas測試布局偏移造成裁切，修的是驗證圖X/Y排列而非產品座標，再跑r2/r3。
- 使用computer-use skill在獨立QA視窗實際開筆刷面板：圓色票、圓形透明底、只有拖曳小字提示與右鍵移除，無前後排序按鈕。首次input報coordinate geometry unavailable，重新activate／observe後成功；沒有猜坐標／操作使用者其他程式。
- 非原生Windows鍵鼠持續Shift拖曳測試：未執行；adapter-level modifier注入不冒充物理鍵手感。ARM64實機／WACK／Store安裝與升級／新延遲benchmark：未執行。未刪作品、舊試用、正式包與歷史資源。

## 手動試用：成功條件

1. 一般與螢幕畫布各試線／箭頭：Shift拖曳只落水平、垂直、45°／135°；矩形正方、橢圓正圓，菱形／五角／星形等比例。
2. 三角／四邊按Shift從第一點拖，放開即正三角／正方；不按仍逐點建立。拖曳中按下／放開Shift能切換。選取的Shift追加仍正常，手繪筆不受限制；畫完一筆Undo可復原。
3. 螢幕更多→螢幕尺→顯示／重新顯示，尺回目前螢幕中央；移動／旋轉／側邊伸縮可用，隱藏後無殘影。工具列即使把尺隱藏，更多仍可恢復。
4. 筆刷及雷射常用色全部圓形；管理後拖末色到首位，前六快捷色同步、重開同序，右鍵仍可刪；無前後排序鈕。

Windows整體審視與具體後續優先級見[報告](WINDOWS_REVIEW_2026-11-05.zh-TW.md)。本批只交本機試用，不代表新商店發布。

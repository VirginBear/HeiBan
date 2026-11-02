# Windows畫布範圍截圖與框選順暢度 — 2026-11-02

使用者要求有邊界畫布整頁、無邊界手動框選後直接複製圖片，並檢查一般框選頓挫是否有無效傳送／重算。僅Windows，同系列1.1.0開發標籤，不進版、不動已送審包。先讀目前狀態及架構／問題；開始即建立紀錄。

git status原有CURRENT_STATUS、DEVELOPMENT_LOG、MARQUEE_AND_MANUAL_CLEANUP三份未提交清理紀錄，以及三份YouTube未追蹤文件；先存差異快照於.build/canvas-capture-20261102，保留既有內容，不能當成本批親自完成的清理。後續只提交本批變更。實作／測量結果待追加。

## 實作中發現

確認框選移動沒有DocumentCodec／保存；但按下末尾因select而InvalidateCanvas(true)，放開RefreshEditor又Prune並強制重建scene，5千物件時雖只是改選取也重畫全部。此外move進低priority隊列、重複游標處理。改成框選專用O(1)預覽＋PresentInteraction，按下／放開僅選取狀態不破壞committed scene；物件比對與屬性同步只在放開執行。尚不宣稱實際延遲數字。

新增Core截圖範圍／像素上限plan；Win2D離屏渲染直接提供Bitmap剪貼簿並Flush，含紙張背景／格線與可見當頁物件，無工具列／游標／選取框。PNG匯出與新截圖共用RenderCanvasImageAsync，避免兩套繪製。GPU最大維度與40M像素約束；拖曳不建立bitmap或clone文件。新工具管理分頁可自訂常用；螢幕host不支援此文件畫布命令，子集合偏好保留。

首輪Core測試編譯因將RadialToolProfile誤寫為檔名RadialToolbox而失敗，已改用實際類名，重跑結果待記。

一個輔助編輯步驟未指定UTF-8而遇cp950解碼錯誤，停在Optimization測試檔；改用明確utf-8-sig補完，先前指南／plan編輯已成功且沒有冒稱該步完整執行。

首輪原生PNG已寫入Clipboard，但測試觀察器讀自訂格式token時得到WinRT.IInspectable而非string，於解碼前拋InvalidCastException；不是冒稱剪貼簿解碼已過。改只在診斷組態使用型別明確的Properties.Title驗證來源，正常包僅標準Bitmap、不加token格式，重新建立獨立資料根／結果r2重驗。

第二輪驗證發現Flush後Title亦未保留，來源保護故意中止而未讀取未知剪貼簿。改用僅診斷組態的GetClipboardSequenceNumber，在Flush後記錄並於讀取前／取得view後再次確認序號，正常包仍只有標準Bitmap。未以取消來源保護方式取得使用者剪貼簿。

## 本批驗證結果（封裝前）

- `windows/.build/tools/dotnet/dotnet.exe run --project windows/HeiBan.Windows.Core.Tests -c Release`（獨立artifacts）：2383 PASS，證據 `.build/canvas-capture-20261102/corechecks-r3.log`。
- `dotnet run --project windows/HeiBan.Windows.OptimizationChecks -c Release -- <獨立空目錄>`：68 targeted checks PASS，`optimization.log`與`optimization-output`保留。
- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true -p:ArtifactsPath=<qa-build>`：最新r4 0警告0錯誤。正常Portable稍後另建，不能混同診斷包。
- `python windows/scripts/Build-LocalizationCatalogs.py`／`Build-UserGuides.py`／`Generate-MenuIcons.py`：十語699 keys無缺漏、每語26節73段與64 SVG；首次指南生成因未登錄新工具coverage拒絕，補映射後成功。
- 診斷程序以`HEIBAN_WINDOWS_DATA_DIRECTORY`指定尚不存在的`qa-data-r3`，以`--canvas-capture-validation-output`啟動，未讀原作品。r3 `result.json`：整頁200×160、負座標160×120、當頁／隱藏篩選、背景、視野外與zoom獨立、stream處置後標準Bitmap解碼、過期epoch拒絕全部true。
- Sky真實Pointer拖曳三例（5003物件）：左到右a,b；右到左touch a,b；左到右部分覆蓋none。均保留preview至放開、選取正確，sceneRebuilds=0／generationChanges=0。`qa-results-r3/input/gestures.json`。
- 點「管理→畫布範圍截圖」實際拖曳：讀回自己新寫入的Bitmap550×230，`mouse-region.json` success；檢視PNG只有背景與兩矩形，不含工具列／板擦／藤條／游標。再次進入後Esc，畫面顯示已取消截圖；Alt+F4正常關閉測試程序（PID11028已結束）。
- 尚未執行：硬體端到端延遲／FPS量測、多DPI／所有修飾鍵、實際貼到第三方對話軟體、ARM64執行與Store送審；不能把零scene重建當成零延遲。所有程序與測試資料均在獨立.build。
- 不改版號1.1.0；本輪無刪除檔案、不複製原使用者作品，保留既有清理紀錄與已送審bundle。再次點同截圖命令亦顯示取消訊息（最終Normal Release編譯涵蓋此文字分支）。

## 免安裝交付

- 程式來源凍結 `d87c8a2c55972d53a3235e97b5a5125ddd279a59`；正常Release x64 Portable（非診斷組態），產品1.1.0、EXE／DLL FileVersion1.1.0.0，ProductVersion帶來源SHA。
- 實際封裝命令：將`windows/.build/tools/dotnet`加入本程序PATH，再執行`windows/HeiBan.Windows/Packaging/Package-PortableTrial.ps1 -Runtime win-x64 -Label canvas-capture-2026-11-02-r1`。成功，App與Updater均完成publish，證據`.build/portable-trial-1785d23bbbe34aae9f4aee92773660ef/publish.log`。
- EXE：`windows/dist/trials/HeiBan-Windows-Portable-1.1.0-canvas-capture-2026-11-02-r1-win-x64/HeiBan.exe`。
- ZIP同名加`.zip`，133316109 bytes，SHA256 `17e14338e7e29cf727709eb6d41e52617ddc15f844d6b1f99b91ac9d1abcf202`，相鄰`.sha256`檔一致。
- 實際執行`python windows/.build/canvas-capture-20261102/Verify-Portable.py`：654 payload SHA及ZIP內byte核同、233來源raw-byte SHA核同、ZIP CRC通過；64個SVG與十語HTML／QuickStart／manifest核同。Normal HeiBan.dll不含三個診斷觀察器方法。
- 全新獨立空白Data，未自動搬移／覆寫原作品。正常試用程式尚未啟動，UI驗證使用前述獨立診斷build；請使用者實機試用。ZIP／dist不入Git，跨電腦需另取得本包或依來源重建。
- 已送審1.1.0.0 bundle SHA仍`a7799085a7ccb5f7f0a23b37d0b12425a9def99ff366d8fa13686ee01eaade66`；本批不製作／上傳新Store包，不進版。

## 使用者驗收

1. 開有邊界／A4作品，放大只看局部，按「管理→畫布範圍截圖」，在其他支援圖片的軟體Ctrl+V。成功：整個當頁邊界內內容皆在，含背景；沒有工具列／選取框。若要常用入口，可從自訂工具列加入常用。
2. 開無邊界筆記，點同命令後拖出範圍並放開，再Ctrl+V。成功：只含框內文件區域；反向拖曳亦同；Esc／右鍵可取消。極大範圍為限制記憶體會降低解析度，不改截圖邊界。
3. 在有多個物件的作品，以選取工具從空白處拖曳。成功：框持續跟隨，放開才產生選取；左到右全包選取、右到左交叉選取維持。觀察是否仍有頓挫，若有請回報物件量、縮放與發生在按下／拖動／放開哪段；本輪未宣稱達到任何ms／FPS目標。

公開與私人紀錄的後續docs commit另由Git歷史定位；已保存本批開工的既有未提交清理與YouTube文件，不將他批紀錄混入本批提交。

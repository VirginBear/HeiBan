# Windows 1.0.12-preview.3 操作修正

本輪依使用者試用回報修正 Windows；Mac 基準維持 1.0.12／20261010.4，不改 Mac、文件格式或未知 JSON 欄位。版本為 1.0.12-preview.3，FileVersion／AssemblyVersion 1.0.12.3。現有未提交內容保留，未 commit／push／公開發布。

| 回報 | 已實作行為與原因 |
| --- | --- |
| 圖釘像星星、名稱不能直接改、稱作導航 | 工具列改真正圖釘輪廓，入口稱「圖釘」。雙擊畫布圖釘或名稱，原位 TextBox 改名；Enter／離開保存，Esc 取消，單步復原。右鍵亦可改名；圖釘清單改名離開清單後使用同一編輯器，避免巢狀 ContentDialog。 |
| 滾輪只平移 | 一般垂直滾輪直接用 ViewportTransform.ZoomAt，縮放後鼠標下的世界座標不變，倍率 .05–8。水平滾輪保留平移；中鍵／空白鍵拖曳平移。 |
| CAD 框選失敗 | 普通畫布原來缺少選取矩形分支，螢幕則固定用套索的碰觸判定。改共用 WindowSelection：左往右完全包含，右往左碰觸；藍色實線／綠色虛線區分，Ctrl／Shift 可追加。只處理當頁可見物件，選取不新增 Undo。 |
| 選框誤抓空白 | 線／箭頭／延伸線／旋轉圖片／多邊形／圓弧使用實際輪廓；平滑筆跡依同一 Catmull-Rom 控制點細分，弱引用快取以 Points 字串失效。空心圓／矩形內部不再攔截空白框選，曲線點選按實際彎曲路徑。 |
| 曲線點完才可見 | 第一點後跟隨鼠標預覽，第二點後預覽三點曲線，第三點提交一筆 Undo。普通畫布修 hover 的 invalidate；螢幕新增曲線工具與暫態錨點。普通畫布第三點完成即結束捕捉，避免誤拖已完成曲線。 |
| 線條按鈕固定虛線 | 工具列、屬性選項、物件快捷列顯示目前實線／虛線／點線／點劃線。選單樣本改閉合填滿 geometry，因 PathIcon 不描繪 open path；live 筆跡亦使用所選樣式，dash端點明確Round，點線呈現圓點。 |
| 先選色再換筆失效 | 原每工具重新載入配色／線條，蓋掉使用者剛選的值。現在明確修改的顏色／線條成為後續繪圖預設，跨工具保留；選取物件時仍修改所選物件，工具特有筆刷／粗細／透明度保留。 |
| 物件快捷列顯示舊樣式 | 原 signature 只有 ID／type／lock；改色、改線條未更新。現在原地同步色票／數值／線條，不移除浮窗錨點；Cancel 還原新的 model 引用時重綁，避免 handler 寫到舊 model。 |
| 直式螢幕圖示擠壓 | 模式 PathIcon 明確 18×18 DIP；所有按鈕32×32、色票22×22。中段頂端對齊、禁水平捲動、可垂直捲動；固定色圓／線條／清空／更多／結束。維持64×688 DIP，收合直列300 DIP。 |
| 截圖框不清楚 | 原只畫白邊框。現在快取灰霧桌面，選區拷回原快照，藍色邊框；截圖編碼仍取未遮罩原快照。遮罩只合成一次，原生窗口／GDI 在專屬工作執行緒。 |
| 切工具需多次點擊／頓挫 | 設定浮窗 OverlayInputPassThroughElement 指向工具列，切換主動關舊浮窗；已作畫時換螢幕工具不再重做模式／輸入層；取消無交易預覽不失效永久 scene，一般換工具只重畫暫態層；螢幕矩形／框選 preview 不再每次 move 重畫既有物件。這些減少可確認的重複工作，未宣稱硬體輸入延遲完全消失。 |

## 已執行驗證

- `/opt/homebrew/opt/dotnet/libexec/dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj -c Release`：本輪680項通過（新增112項），包括25組游標／倍率錨點、包含／碰觸／相切／旋轉／空心圖形／箭頭／射線／曲線與未知欄位回歸。
- Windows 11 ARM64／.NET10.0.401 原生 Release publish 成功。最終隔離 `qa-interaction12p3-r7` 的 `result.json`、`screen-result.json` 都 success；普通畫布預選樣式、圖釘編輯／取消／Undo、雙向框選、兩階段實際 Win2D 預覽、快捷列即時樣式與 Cancel 重綁；螢幕實際 OnPointer 框選／曲線／單筆 Undo／樣式、右鍵操作／清空 Undo、中文草稿等通過。
- 200% DPI 橫列1640×120px；20個直列按鈕全32×32 DIP，內容18×18或22×22。中段寬43DIP、高412.5DIP，內容高500DIP，以捲動容納而非壓縮。CUA 已看到直列外觀。
- 實際原生渲染計數：圖形／框選多次move維持committed scene，圖形提交只重建一次；作畫／操作切換重建alpha背景，實際像素分別為1／0，確保快取不阻斷輸入。
- 四種線條實際Win2D像素通過：實線816／虛線624／點線416／點劃線560個非透明像素，四張合成線段PNG留存，不僅檢查Icon非null。
- GDI 合成24×24純色測試：選區像素等於原圖，框外符合灰霧混合；不擷取使用者內容作測試素材。
- 本輪向量PDF strict解析成功：1頁、2文字／382 cubic／75 line操作，xref有效stream內4物件原稿仍可讀。PNG／SVG／HTML 與螢幕獨立保存亦通過。
- 兩次前期色圓浮窗檢查失敗（closed）；補 Activate 單獨無效。測試連續關閉文字窗口後先讓 WinUI 處理焦點再開浮窗，r3／r4通過；保留失敗結果，不把第一次嘗試寫成成功。首輪封裝後又修 PathIcon／快捷列，須用最終76來源重封，前輪不部署。

證據：`docs/build-logs/interaction12p3-r7-native/`；原生驗證使用隔離資料與合成作品，不能等同所有實體輸入流程。完整手寫筆、IME、混合 DPI、多螢幕、x64 實機及 Installer 升級未執行。本輪 CUA 開隔離QA時同時仍有舊Current，一次色圓點擊無可靠浮窗，不算硬體點擊驗收；後續Mac鎖定，未能進行最終物理點擊。

## 封裝／資料保全

兩架構 Portable ZIP／Installer EXE、來源SHA、包內檔案／手冊／README／完整授權與Data隔離檢查，詳見 [產物清單](ARTIFACTS_2026-10-10_1.0.12-preview.3.json)。模擬機更新前後逐SHA保存Data，保留所有舊備份／垃圾桶；正常關閉才更新，桌面「黑板 Windows 最新版」指向 `C:\HeiBanPreview\Current`。舊成品清理限已確認的 Windows payload／建置鏡像，QA資料先備份；詳見本版部署／清理紀錄。

最終本機交付：四包SHA／架構／當前手冊與README／25授權通過；76 native與封裝來源SHA一致。Current549檔逐SHA、唯一程序及捷徑通過。vm/c5完整保全51Data檔，2目前作品／8垃圾桶；c12／c2／c3／c4作品皆被涵蓋。清理摘要見[CLEANUP](CLEANUP_1.0.12-preview.3_2026-10-10.json)，所有作品與SDK／Inno保留。

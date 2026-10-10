# Windows 螢幕右鍵操作修正（1.0.12-preview.5）

2026-10-10，Mac基準仍1.0.12／20261010.4。使用者最新要求取代preview.4的右鍵自動穿透偏好；本輪只改Windows。

## 操作契約

- 作畫狀態右鍵命中物件：切到選取工具，開啟顏色／粗細／透明度、線條、填滿、複製、副本、貼上、個別刪除、鎖定及層級選單。文字另有文字樣式。
- 命中已多選物件保留整組選取；命中未選物件改選該物件。選取本身不建立Undo。
- 空白右鍵取消尚未完成的繪圖手勢，保留選取與作畫狀態，不會變「操作」。
- 穿透模式由工具列「作畫／操作」或Ctrl+Alt+D切換，移除物件選單中的穿透項目。
- 右鍵命中／damage採既有原生輸入座標，選單位置由實體桌面轉工具列DIP；不為開物件選單重建整屏scene。

## 來源及驗證

Objects.cs恢復命中選取與實際MenuFlyout，Text.cs驗證右鍵多選文字，ScreenAnnotationWindow.cs更新狀態提示；csproj、README與內建手冊同步版本／行為。既有複製相容格式、Undo、鎖定保護與螢幕獨立保存不變。

700 Core Release退出0；ARM64原生right12p5-native/result.json及screen-result.json皆success，實際右鍵物件選單、空白不切模式、無新增Undo及文字多選保持通過；副本／刪除／Undo、物件樣式／截圖／36預覽幀byte等價回歸通過。PDF strict1頁／4原稿通過。兩架構四包與Data保全／部署已完成，結果見下方。複製驗證使用相容payload，不覆寫使用者剪貼簿。硬體滑鼠／完整IME／觸控筆／混合DPI／多螢幕、x64實機與Installer升級未執行。

CUA可讀模擬機；隔離QA與舊Current同時有控制列，兩次右鍵讀回未可靠顯示選單，因此不計為硬體驗收。保留原生路由驗證與實體互動的區別，未改使用者物件或剪貼簿。


完成本機交付：兩架構四包封裝退出0、兩次Successful compile／completion marker，無compiler warning或error；SHA／PE架構／PRI／runtime／品牌／當前手冊與README／25份授權逐byte通過，ZIP空Data／無QA作品。77來源與native／package雙鏡像SHA一致；Current FileVersion1.0.12.5，唯一程序11412／桌面「黑板 Windows 最新版」，549payload逐SHA通過。

正常關閉前後逐SHA備份vm/c7、56Data檔完整遷移，2目前作品／9垃圾桶共11份；c12／c2／c3／c4／c5／c6所有作品ID仍涵蓋。舊Current全部bytes可由p4ZIP及保全Data解釋，未知bytes0；清舊p4四包／sidecar及舊Current／VM建置鏡像共1,965,162,051bytes，QA先逐SHA備份r5a。SDK／Inno及所有作品／歷史備份保留；Mac未改，未commit／push／公開發布。

CUA可讀新版單排工具列；右鍵物件與工具列點擊未產生可靠回應，故不計為實體驗收。完整硬體滑鼠／IME／觸控筆／混合DPI／多螢幕、x64實機及Installer升級未執行。原生路由驗證不代表硬體端到端測試。

實際命令與證據：Core `dotnet run --project HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj -c Release`（right12p5-core.log／700）；VM build-visual.ps1、validate-perf.ps1（right12p5-native/result.json與screen-result.json）；PDF strict解析（同資料夾pdf-validation.json）；package-current.ps1（1.0.12-preview.5-packaging.log）；verify-final-source.ps1（final12p5-source-verification.json）；update-current.ps1、verify-current.ps1、cleanup-final-mirrors.ps1；部署／Data／清理記錄於build-logs並彙整至本版ARTIFACTS及CLEANUP JSON。

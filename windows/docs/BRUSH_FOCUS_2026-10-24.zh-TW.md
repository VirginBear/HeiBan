# 2026-10-24 Windows筆刷單層捲動與目前工具色線

使用者回饋續修同批筆刷：確認不是透明度滑桿，而是面板右側內外兩個捲軸；只要當前選用筆／形狀工具有筆色色線。沿用同批「請實際驗證後交付」授權，只Windows、1.0.16／1.0.16.0不進版。開工保留既有三份平台文件6／8／4行與三YouTube新檔，scratch保存baseline與36Store SHA。尚未更改作品或產物。

正在查FlyoutPresenter的內建捲動與顯式ScrollViewer重疊，先不誤刪顏色／粗細／透明度控制項。工具色線將共用活動工具判斷，隱藏時保留圖示尺寸避免切換跳動。

## 原因與實作

已讀本機SDK WinUI 2.3.9 generic.xaml的DefaultFlyoutPresenterStyle（27581行附近）：ControlTemplate內建ScrollViewer並綁定VerticalScrollBarVisibility／VerticalScrollMode。原筆刷Content又包ScrollViewer，長內容在可用高度不足時產生巢狀兩條捲軸。一般筆刷、螢幕筆刷／獨立調色盤只給panel，由FlyoutPresenter統一限高與捲動；沒有移除顏色亮度／粗細／透明度滑桿。

SetToolColor增加活動工具key，筆／螢光／曲線／油漆依key匹配，九種幾何透過共用ShapeTools映射到shapes鍵；選取／橡皮擦／雷射時不亮其他筆色線。線以Opacity=0保留圖示量測空間，避免切換時文字跳動；非活動工具不建立新的色chip，活動色不變也不重建。仍只在工具／顏色狀態改變更新，不新增指標／Draw工作。

查找時一處猜測ToolbarUi.Shapes.cs不存在，改rg定位實際ToolbarUi.cs；一次Python -c引號截斷未讀取SDK檔，改明確Get-Content範圍讀取。未修改無關平台或作品。

## 進行中驗證

x64 build --artifacts-path windows/.build/brush-focus-20261024-r1成功50.18秒，0warning／0error。從repo root執行本機dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release --artifacts-path windows/.build/brush-focus-20261024-r1/core-tests，本次2,365項PASS。Build-UserGuides.py重建十語手冊／新指南，每語25節64段，補只當前工具有色線與單一捲動區。

Computer Use以獨立ui-verify啟動build：一般筆刷UIA只一個VerticalScrollBar，scroll後Value422，粗細與透明度及底部預覽可達；HEX改#FF123456，鋼筆單色線、切螢光筆只剩其色線、選取時無筆色線。第一次觀察啟動尚未建立視窗，程序仍啟動中，後續list_windows取得正常；一次切螢光筆refresh回no monitor found for window，重新列視窗並activate後恢復且確認切換已生效。尚在補螢幕與最終包驗證。

一般繪圖分頁選矩形後，只有圖形鍵有色線。螢幕畫布筆刷只一個VerticalScrollBar（工具有時把同一index68在快顯樹重複列出，非兩個控制項）；拖動該捲軸後，底部粗細、透明度與狀態文字都可見。螢幕鋼筆／螢光筆單色線切換可見。工具的popup UIA座標曾超出螢幕（y6104）及refresh多次no monitor found，未照無效座標輸入，改採當次快顯screenshot-2區域拖動並重取畫面確認；不把refresh延遲當App卡頓。尚未驗證獨立螢幕調色盤、完整四邊／混合DPI及ARM64；不聲稱本批有新性能採樣。

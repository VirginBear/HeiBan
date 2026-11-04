# Windows 1.1.2 圖示風格與操作／作畫圖示 — 2026-11-04

使用者確認上一批操作右鍵輪盤成功，選定A彩色雙色描邊；要求藤條參照現有直藤條、保留原圖示並在工具列設定可切換。操作／作畫需同一螢幕窗框、差別為鼠標／畫筆。明確指定本次及後續本系列先用1.1.2；本批只改Windows，未要求新Store送審。

開工保留原三份dirty清理文件與三份YouTube未追蹤文件，狀態與patch另存`.build/icon-style-20261104`。先讀開發索引與Windows規則、狀態／架構／決策／問題。A生成板已目視檢查：有粗深色描邊與功能雙色填面，藤條誤為拐杖。本批落實可縮放向量，不裁切生成圖當小圖示，不修改游標與實際藤條動畫素材。

目前進行中：查共用ToolIcons、兩畫布自訂設定與輪盤快取，規劃共用風格偏好與預載向量。實作、失敗與驗證結果逐步追加，不把前批測試數字套用。

## 進行中實作與排解

工具圖譜沿icon／toolbar／preferences詞彙找到ToolIcons與ToolbarPreferences五個節點、29關聯；舊圖schema為links，首次誤用edges後改讀links，現行設定／輪盤仍查source。新增ToolbarPreferences.IconStyle（classic預設／duotone），舊偏好保留原樣與未知欄位；兩畫布自訂視窗可看兩套樣本、保存後共用，取消不改目前風格。預設回原風格。向量132份（原64內容保留、新mode pair2、A66），A手繪主要工具雙色填面；藤條重用現有直桿／節點path。模式共用ModeWindow常數，只換ModePointer／ModePen；未改實際藤條圖片／動畫與游標。

輪盤沿用原renderer，只依Style切換SVG及清除舊GPU圖示；A的XML在啟動／明確設定時預載，不在繪畫frame讀檔；SvgImageSource快取可共享，UIElement仍各視窗各自建立。螢幕原有按鈕只替換圖示、保留色線／標籤與事件。產品／FileVersion／AssemblyVersion及Store manifest／identity source同步1.1.2／1.1.2.0；不動已封裝1.1.1.0。

Localization首輪忘了Sources顯式key而guard拒絕，補三個key後708keys／10語missing0；指南26節80段完成。Core本批3445 PASS。QA首build因factory回傳UIElement，設定清單直接讀Width／Height／VerticalAlignment造成CS1061與後續XAML連帶錯誤；明確轉FrameworkElement後重建中。SVG原檔比對首次把Git LF blob與工作樹CRLF混比而失敗，改以正規化內容確認64份原向量不變，132份XML皆可解析；原64產物byte將以封裝時實際SHA另核對，不混稱Git blob byte。

QA第二build因StackPanel沒有IsEnabled而CS1061，改為明確停用header中的ComboBox／Button，避免儲存期間仍修改捕獲值；第三build0警告0錯誤。首原生QA在隔離資料根qa-data-r1完成13項screen斷言、132份SVG真實GPU解析繪製，duotone→classic→duotone切換正常，模式不修改註記。computer-use實際開風格下拉，清單可見原本描邊／A雙色；改選原風格預覽後按取消，工具列仍是A，磁碟toolbar.json仍為duotone。

目視GPU預覽發現檔案SVG根width/height=26使Win2D viewport不放大圖示，會影響輪盤hover放大；預載XML移除固定width/height、保留viewBox，SvgImageSource檔案維持原尺寸契約。加入新QA flag的QuickStart skip，避免測試資料根自動建立指南。第四build0警告0錯誤、22.90秒，重跑隔離原生QA中；原userData與舊試用未使用／未覆蓋。使用者對前批操作輪盤的「成功了、很喜歡」屬本機人工接受回饋，並非新增混合DPI／高權限驗收證據。


## 修正後驗證

第四build後以qa-data-r2重新啟動原生QA：13項screen斷言／132份SVG GPU解析繪製通過，A→原本→A的輪盤快取切換及相同窗框／不同badge正確。目視style-a-preview.png確認A圖示依viewport正確縮放；SVG範例不再固定26px。第二輪沒有建立預設指南。正常包來源紀錄新增兩個圖示生成腳本與兩套SVG，供跨機器還原及逐檔SHA驗證；沒有新增執行時相依套件。


computer-use第二輪實際在自訂工具列選原本描邊→儲存，磁碟iconStyle=classic、完成非同步保存後工具列亦回原版；正常退出後同qa-data-r2不帶QA flag冷啟動，另做保留風格觀察。一次無screenshot的UI索引點擊因coordinate input geometry unavailable失敗，重新擷取畫面後僅重試一次成功；不是產品錯誤。完整手動驗收仍請看實際4K／多DPI外觀，ARM64實機與新Store／WACK未執行。

本批實際命令：`dotnet run --project windows/HeiBan.Windows.Core.Tests -c Release`（3445）；`python windows/scripts/Generate-MenuIcons.py`（66）；`python windows/scripts/Generate-DuotoneIcons.py`（66）；`python windows/scripts/Build-LocalizationCatalogs.py`（708keys／missing0）；`python windows/scripts/Build-UserGuides.py`（10語／26節80段）；`dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/icon-style-20261104/qa-build`（第三／四成功，各失敗log保留）。原生helper旗標`--icon-style-validation-output=...`僅驗證組態，資料根必須尚不存在，兩輪r1／r2獨立。

原生QA模式按預期不建立指南；去掉QA flag以同隔離資料根冷啟動後正常建立指南。實際開啟新指南，確認啟動載入已儲存的classic風格，不因進作品／建立指南而被A覆寫。沒有讀取原作品庫。


## 藤條對照實際素材補修

r1正常試用封裝與核對已成功（來源e01e225、133397353bytes，SHA5efab7855d39aa213e96cfb4c46072e9a0668afc268aa32c1799e992c3050971，722 payload／390來源／132SVG及CRC通過），保留原byte但不作最終交付。再次目視實際Assets/Cane.png，除了直桿外還有米白纏繞握柄及綠色收邊；初稿沿舊小圖示path會顯得節點凸出，故A藤條改為貼近實際素材的平順直桿、細節環及米白／綠握柄。原classic path、Cane.png與動畫均不變；不是覆蓋原始生成提案PNG。

只有SVG與生成器更新，QA使用同第四build binary、將一份cane.svg複製到QA內容目錄，另起qa-data-r3重新GPU解析／繪製與host檢查；不得稱重編C#。正常最終包採新標籤r2與來源commit，不覆寫r1，也不提高1.1.2版號。


## 最終交付與驗收

r3素材重測同樣13 screen斷言／132 SVG GPU繪製通過，目視確認直桿、纏繞握柄與綠邊，與Cane.png語彙一致。所有自建QA程序正常關閉。最終正常x64 Portable以`Package-PortableTrial.ps1 -Runtime win-x64 -Label icon-style-2026-11-04-r2`完成，來源`1bbf3bc7870d04d783d1ab59fe13693b4aa8bce6`；ProductVersion1.1.2+該SHA／FileVersion1.1.2.0。封裝紀錄`.build/portable-trial-06b4f3152c9a48bf8aea4f8291e77e06`。

- 直接執行`windows/dist/trials/HeiBan-Windows-Portable-1.1.2-icon-style-2026-11-04-r2-win-x64/HeiBan.exe`；ZIP同名加.zip。
- ZIP133395278bytes，SHA256 `b6bad04fe3768728cb34d893ae201f359bf1ee3170b6f88de87fd05be1dc1b35`。
- `Verify-Portable-r2.py`核對722 payload／390來源（含兩個圖示生成器及兩套SVG）、132 SVG／10語指南、ZIP SHA／CRC全通過。RunIconStyleValidationAsync／ValidateIconStyleAsync等診斷方法不在正常assembly，Data空白獨立；正常trial未由agent啟動，QA使用獨立測試組態。
- 既有Store1.1.1.0保持197514657bytes及SHA `85c1400ae94430309fd4c440881238e8d71127e0c0cd6e38616470af6491e968`；未作新Store包／送審／發布，未跑WACK／ARM64實機與硬體延遲。

手動成功條件：更多→自訂工具列→圖示風格選A並儲存，工具列／形狀選單／輪盤均換A；切螢幕畫布後相同；操作鈕為螢幕＋鼠標、作畫鈕為同一螢幕＋筆，輪盤顯示可切換的目標模式。改選原本描邊但按取消，原風格不變；儲存才切換且重開保留。選原本描邊可回舊圖示，預設亦回classic。兩風格藤條都沒有彎鉤；A帶原素材米白握柄。4K／混合DPI完整外觀仍待使用者實際審視，不把GPU解析當所有螢幕驗收。

公共程式與私人壓縮交接分庫提交，私人另存實作GPU預覽與三個代表SVG；原五套概念PNG不覆蓋。原有三份dirty文件、三份YouTube未追蹤文件及作品、舊產物完整保留。

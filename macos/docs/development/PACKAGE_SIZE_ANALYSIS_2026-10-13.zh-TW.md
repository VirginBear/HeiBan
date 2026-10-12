# Mac／Windows 發行體積分析（2026-10-13）

狀態：分析完成，尚未實作減重。範圍：讀取兩平台封裝與來源，僅新增 Mac 開發文件，不改 Windows／Mac 程式、套件設定或成品。

## 比較基準

MB 採 1,000,000 bytes。解壓大小是檔案內容總和，不含檔案系統配置區塊、作品及快取。

| 成品 | 下載大小 | 解壓後程式內容 |
| --- | ---: | ---: |
| Mac 1.0.13 ARM64 ZIP | 4.15 MB | App 13.52 MB |
| Mac 1.0.13 ARM64 DMG | 4.72 MB | 同一 App |
| Windows 1.0.14 ARM64 本機試用 ZIP（10/12） | 123.82 MB | 346.95 MB |

兩包版本／功能批次不同，這是目前可量測成品的封裝比較，不宣稱同一功能快照。Windows試用 ZIP 的 SHA-256 為 eed7341e766c423e0c6b9a7ce239974c64175c3533e58431e0f862105e4fe5e1，與既有部署紀錄相符。Mac檔案內容比較 Windows約25.7倍；ZIP下載約29.8倍。ZIP另有少量安裝／法律文件，因此Mac App大小與ZIP全部檔案內容並非完全同一範圍。

本機仍有 Windows已公開1.0.12-preview.5：ARM64 ZIP92.77 MB、安裝EXE63.98 MB；兩者使用不同壓縮方式，不能把較小的EXE解讀為較小的安裝內容。Inno採lzma2＋SolidCompression。

Windows1.0.14.0 Store紀錄：ARM64 MSIX95.45 MB、x64 MSIX98.02 MB、雙架構bundle193.48 MB。此處為追蹤的JSON紀錄，不是本機重新量測；本Mac checkout沒有這三個二進位。bundle包含兩架構，不能直接拿整個bundle當單架構App大小。

## Windows ARM64 試用 ZIP 拆分（互斥分類）

| 項目 | 檔案內容 | ZIP內壓縮資料 |
| --- | ---: | ---: |
| 主程式 .NET 執行環境 | 90.35 MB | 34.15 MB |
| 自包含更新程式與附檔 | 82.83 MB | 30.71 MB |
| 機器學習依賴＋Tensors | 42.23 MB | 16.78 MB |
| Windows SDK .NET API投影 | 26.87 MB | 6.69 MB |
| HeiBan主程式、Core、apphost與PRI | 3.95 MB | 1.13 MB |
| App圖片／各語手冊 | 1.33 MB | 1.03 MB |
| 法律文件 | 0.94 MB | 0.15 MB |
| 主程式除錯符號 | 0.27 MB | 0.14 MB |
| 其他框架與封裝資料 | 98.18 MB | 32.96 MB |

「其他」是剩餘分類，包含WinUI原生庫／框架PRI等，不能宣稱全部精確歸屬某個NuGet包；ZIP壓縮資料不含ZIP標頭。Updater內符號算在Updater類別，避免重複加總。按HeiBan.deps.json的runtime/native清單識別.NET、API投影與ML；ZIP路徑先將反斜線轉正斜線。原始數據見[JSON](PACKAGE_SIZE_AUDIT_2026-10-13.json)。

## 原因與證據

1. **Mac共享OS框架。** Package.swift無外部套件依賴；otool -L確認AppKit、SwiftUI、CoreGraphics、ScreenCaptureKit、WebKit與Swift runtime從/System/Library及/usr/lib載入，App沒有複製整套框架。App共18檔，主執行檔11.47 MB，其餘約2.05 MB。這些能力的體積由macOS本身提供，不是不存在。
2. **Windows同時自包含.NET及Windows App SDK。** HeiBan.Windows.csproj設SelfContained=true、WindowsAppSDKSelfContained=true；Publish-Common.ps1亦明確指定。免安裝／安裝包攜帶所需框架，以減少預先安裝要求；Windows內建API仍有使用，不能概括成Windows不提供系統框架。C#程式以.NET執行，Mac Swift是原生機器碼。這是框架／部署選擇的差異，不能只歸咎語言。
3. **獨立更新程式再帶一份.NET。** Updater為net10.0、SelfContained=true、PublishSingleFile=true；執行檔82.75 MB，壓縮約30.67 MB。單檔把內容集合起來，不代表減少依賴。隔離helper可在主App退出後替換檔案，不能未考慮檔案鎖定／更新生命週期就移除。Store打包腳本排除Updater，改由商店更新，但仍自包含主框架。
4. **總套件引入ML等相依元件。** deps明列Microsoft.WindowsAppSDK.AI／ML／Search／Widgets與Microsoft.Windows.AI.MachineLearning。onnxruntime.dll21.85 MB＋DirectML.dll18.62 MB；ML整組含Tensors42.23 MB。Windows App與Core的C#/XAML/csproj未搜到onnx／DirectML／AiFabric／SemanticIndex直接呼叫，屬可疑精簡候選；這個有限字串搜尋不能證明原生框架沒有間接相依。沒有把任何DLL當作已確認可刪除。
5. **目前未開啟主App trimming/AOT。** PublishAot=false；PublishTrimmed只在Release且AOT=true才設定，因此這些包未依該條件裁剪。不能逕開AOT／裁剪期待自動成功；XAML、WinRT、反射及JSON相容需要在Windows實機驗收。只有0.27 MB主程式PDB，移除符號不會解決百MB差距。

## 補充：以 Microsoft Store 版比較兩個減重候選

使用者後續澄清以Windows Store要求為主。本節覆蓋先前通用建議的Store優先順序，不修改任何Windows程式或封裝設定。

### Store基準與確定的更正

最新十語手冊候選（GUIDES_STORE_ARTIFACT／INSPECTION_2026-10-12.json，source1ab7018）：ARM64 MSIX95,552,946bytes、x64 MSIX98,120,539bytes、雙架構bundle193,675,520bytes。這些是既有原機封裝紀錄，本Mac沒有MSIX可重新拆解；候選formalVersionApproved=false、storeSubmitted=false，不當成已上架精確版本。

Package-Store.ps1第54行拒絕任何Updater／Data／portable.dat／update-files.json／PDB，payloadChecks兩架構均noUserDataOrStandaloneUpdater=true。GitHubUpdateService.cs在packaged模式停用自行更新，交Store管理。因此Updater82.83MB從來不在這份MSIX內，優化Updater對Store現有成品新增節省為0MB。先前可觀Updater減重只適用官網／免安裝。

| 候選 | Store適用性 | 可節省量的證據 | 可行性／風險 | 優先度 |
| --- | --- | --- | --- | --- |
| Updater Native AOT／裁剪 | Store已排除helper | Store新增節省0MB；免安裝helper現有82.83MB（ZIP30.71MB）不是保證節省 | 獨立helper較容易隔離，但仍需驗證JSON、更新等待、rollback；對Store無收益 | Store不做；官網另議 |
| 減少ML／AI等SDK相依 | 與Store主App相關 | 同SDK ARM64試用ML含Tensors42.23MB、ZIP內16.78MB；不是MSIX減少量保證 | 中等可行性，須確認MSBuild／原生Runtime是否重新帶入、XAML／Win2D／PDF依賴與版本一致 | 兩案中優先 |

### 套件鏈的直接核對

透過官方NuGet v3 flatcontainer讀取目前精確版本nuspec，無還原／執行套件：

- Microsoft.WindowsAppSDK2.5.1總套件直接依賴AI2.5.5、ML2.1.94、Search2.5.5、Widgets2.0.5、WinUI2.3.9及Runtime2.5.1等。
- WinUI2.3.9的依賴僅WebView2、Base、Foundation及InteractiveExperiences，不直接依賴ML；ML2.1.94另引MachineLearning2.1.74。
- 因此必要元件引用有實際路徑可評估。WinUI／Win2D不可删；MainWindow.Export.cs確實使用WebView2輸出PDF，這不是候選可刪項。
- HTTP Range只讀Runtime2.5.1 nupkg中央目錄及少量XML（169,661,368bytes為遠端完整包大小，沒有整包下載／保存）。ComponentReference.targets對framework-dependent的component版本有一致性檢查；AppXReference.props宣告Microsoft.WindowsAppRuntime.2框架包。不能只把WinUI包版本號設成2.5.1或只關一個SelfContained設定。
- Microsoft官方SDK說明支援按元件引用。官方repo#5969中維護者於2025-11-18建議自包含、未封裝App只引用WinUI元件並移除Runtime引用，以避免ML DLL被帶入；WebView2仍為WinUI依賴。這支持精簡有實際路徑，但案例是SDK1.8／unpackaged，不能直接當成目前2.5.1／Store MSIX已成功驗證。#5438亦是版本不同的封裝線索，須核對Runtime引用是否重新帶入不需要的原生庫。

### Store要求與更值得另評估的方案

Microsoft的MSIX規格目前每package／bundle上限25GB，現有約95.55MB單架構遠低於此大小上限；不能從大小判斷全部認證是否通過。官方亦支持framework-dependent packaged部署，Store可自動配置Windows App SDK依賴；bundle只配送相應架構，193.68MB不代表每位用戶要下載兩架構。

若目標是商店主包明顯變小，可另比較「Windows App SDK使用共享框架、.NET仍自包含」作為較保守混合方案。這是把SDK移至Microsoft管理的共享框架，不是消除首次缺框架時的總下載量。它與ML手動裁剪效果不可直接相加。Windows App SDK與.NET是兩條依賴，Store可安裝前者並不代表一定會配置目前.NET10；不要一併關SelfContained=true。需另建候選核對實際Manifest、PRI、框架版本與乾淨x64／ARM64安裝，原包保留。沒有實作、重建、WACK、測試或提交Store。

### Store方案的後續驗收標準（本批未執行）

- 相同source／版號／架構比較原包與元件精簡候選，記錄MSIX／內容大小及payload差異，不以NuGet下載大小推估App減重。
- 缺.NET／SDK的乾淨Windows環境可從Store流程完整安裝、首次啟動及更新；單架構原生架構正確。
- 畫布／Win2D、透明螢幕畫布、尺／圓規、貼圖、文字、多語手冊及WebView2 PDF不因精簡回歸。
- WACK／套件驗證與所需合法文件保留；全部通過後再由使用者決定正式進版／送審。

來源：[SDK2.5.1依賴](https://www.nuget.org/packages/Microsoft.WindowsAppSDK/2.5.1)、[WinUI2.3.9依賴](https://www.nuget.org/packages/Microsoft.WindowsAppSDK.WinUI/2.3.9)、[官方模組化說明](https://learn.microsoft.com/windows/apps/windows-app-sdk/system-requirements)、[打包部署與架構配送](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/deploy-overview)、[Store框架依賴配置](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/deploy-packaged-apps)、[MSIX需求](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/app-package-requirements?pivots=store-installer-msix)、[原始問題5969](https://github.com/microsoft/WindowsAppSDK/issues/5969)。

## 建議順序（分析建議，沒有變更架構決策）

- 官網安裝／免安裝版優先評估獨立Updater的Native AOT／裁剪，保留替換／回滾／程序等待契約；82.83 MB是目前載荷，不是保證可省的數字。
- 盤點Windows App SDK總套件是否能改為必要元件引用，確認ML／Search／Widgets的間接依賴與封裝註冊後才減少相依；優先來源設定，避免封裝後手刪DLL。
- Store／安裝版評估framework-dependent部署，讓相容runtime由安裝流程配置或共享；真正離線免安裝版仍需保留必要相依。執行環境體積會移到共享安裝位置，並非從系統消失。
- 最後才评估主App trimming／Native AOT。現有C#＋WinUI＋Win2D架構不因包較大就必須重寫C++。本次沒有量測啟動、RAM、GPU或FPS；磁碟體積無法代表繪圖流暢度。

## 核對來源與限制

- 本機：macos/Package.swift、macos/scripts/build_app.sh、windows/HeiBan.Windows/HeiBan.Windows.csproj、windows/HeiBan.Updater/HeiBan.Updater.csproj、Packaging/Publish-Common.ps1、Package-Store.ps1、inno_setup.iss，以及兩平台成品／紀錄。
- [Microsoft：.NET發佈模式](https://learn.microsoft.com/en-us/dotnet/core/deploying/)確認自包含模式攜帶runtime，共享框架模式需相容runtime。
- [Microsoft：Windows App SDK自包含部署](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps)確認框架複製進成品；MSIX自包含同样內含框架。
- [Microsoft：單檔部署](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview)及[裁剪](https://learn.microsoft.com/en-us/dotnet/core/deploying/trimming/trim-self-contained)說明單檔／自包含與裁剪的不同及相容性限制。
- 沒有重建、測試套件、啟動App、修改包、刪除DLL、發布／推送；沒有建立編譯快取。文檔保存本機以供後續跨平台調教。

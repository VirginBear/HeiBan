# Windows版本減重分析計劃報告書

日期：2026-10-13。狀態：分析與開發計劃完成，減重實作／新候選／驗收尚未進行。

2026-10-13後續本機優化批次只整理screen toolbar catalog與降低焦點輪詢頻率，沒有修改SDK／ML／Updater依賴或產生新封裝；不改變下列size基線與WR候選狀態。詳[本機優化日誌](WINDOWS_OPTIMIZATION_BATCH_2026-10-13.zh-TW.md)。

Windows原機補充：已取回Mac最新交接並只讀拆解既有Store MSIX，確認ML載荷存在，詳[工具共用／體積本機分析](TOOLBAR_AND_SIZE_REVIEW_2026-10-13.zh-TW.md)及下方Store補充。WT-01–04工具對齊另列，不把共用UI當成減重／性能驗收。

主要對象：Microsoft Store MSIX版；官網安裝版及離線免安裝版另列。使用者將在Windows電腦評估、開發與測試。本報告不構成正式進版或Store提交授權。

## 1. 結論與推薦

**Store版先評估SDK必要元件引用，再比較Windows App SDK共享框架；獨立Updater減重留給官網／免安裝版。**

Store打包早已排除Updater，對現有商店包再優化Updater的節省為0MB。機器學習元件有可觀載荷，但是否能完整排除，要以同來源／同架構的實際MSIX及運行結果決定。維持C#／WinUI／Win2D，不因磁碟大小直接重寫繪圖引擎。

## 2. 範圍與版本邊界

- Windows來源metadata目前1.0.14／Store1.0.14.0，是尚未核准正式進版的開發候選；遵守[進版政策](RELEASE_POLICY_2026-10-12.zh-TW.md)與[平台規則](../AGENTS.md)。
- 同版候選用DevelopmentLabel和獨立dist/store/candidates目錄，不覆寫原送審包／已發布包／來源與SHA。
- Mac來源／成品維持獨立。本批僅編寫報告、補紀錄與同步Git，不修改任何平台程式或套件設定。
- 官方Store商品先前已由使用者後台截圖確認上架；本報告未登入Partner Center，沒有確認現在線上精確版本。不要把下列候選當成目前用戶下載版本。

## 3. 證據基準

### 3.1 最新Store候選：原Windows端紀錄

來源commit：1ab7018b24e4fc06f354ac8d968207de8d0c7770；DevelopmentLabel：guides-2026-10-12；版本1.0.14.0，formalVersionApproved=false、storeSubmitted=false。

| 檔案 | bytes | MB |
| --- | ---: | ---: |
| ARM64 MSIX | 95,552,946 | 95.55 |
| x64 MSIX | 98,120,539 | 98.12 |
| x64＋ARM64 bundle | 193,675,520 | 193.68 |

[原封裝與雜湊](GUIDES_STORE_ARTIFACT_2026-10-12.json)、[原靜態檢視](GUIDES_STORE_INSPECTION_2026-10-12.json)。本Mac沒有這三份MSIX二進位，大小與排除檢查來自已追蹤的Windows紀錄，尚未重新拆解商店包。

Store與App Installer只選對應CPU架構；bundle大小不代表每位用戶下載兩份。官方MSIX／bundle大小上限25GB，現有包遠低於該項限制；大小合規不代表全部認證通過。見[官方需求](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/app-package-requirements?pivots=store-installer-msix)與[架構配送](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/deploy-overview)。

### 3.1a Windows原機Store靜態量測補充（2026-10-13）

本機讀既有guides bundle，bundle及兩MSIX SHA核同原紀錄。ML／Tensors依各HeiBan.deps.json runtime/native資產定位，兩架構各6檔；x64解壓41,995,768bytes／壓縮entry17,537,365bytes，ARM64解壓42,225,720bytes／壓縮entry17,119,480bytes。兩包無獨立Updater／Data／PDB。[完整JSON](STORE_PAYLOAD_REVIEW_2026-10-13.json)。這是補充原Store靜態量測，未建新BASE／A／B，未證明ML可移除，未執行App／功能驗收。下方仍保留Mac端Portable原始參考，壓縮數字不可混用。

### 3.2 實際量測：ARM64免安裝開發試用包

檔名：HeiBan-Windows-Portable-1.0.14-parallels-arm64-2026-10-12-win-arm64.zip。來源148d427a47e03a09bf21431d248fe00e3e9b6d9a，ZIP123,816,578bytes／payload346,950,805bytes，571個檔案；SHA-256與[部署紀錄](PARALLELS_TRIAL_DEPLOYMENT_2026-10-12.json)一致。

| 互斥分類 | 解壓內容MB | ZIP內壓縮資料MB |
| --- | ---: | ---: |
| 主程式.NET runtime | 90.35 | 34.15 |
| 自包含Updater及附檔 | 82.83 | 30.71 |
| ML相依＋Tensors | 42.23 | 16.78 |
| Windows SDK .NET API投影 | 26.87 | 6.69 |
| HeiBan主程式／Core／apphost／PRI | 3.95 | 1.13 |
| 其他框架與封裝資料 | 98.18 | 32.96 |
| 圖片／手冊／法律／主程式符號 | 2.54 | 1.33 |

方法：只讀ZIP central directory的file_size／compress_size，正規化反斜線，再用HeiBan.deps.json的runtime/native資產清單分類。其他框架是剩餘項，不冒充完整NuGet歸屬；壓縮項不含ZIP標頭。MB為十進位，不含檔案系統配置區塊。

[Windows交接基準JSON](PACKAGE_SIZE_BASELINE_2026-10-13.json)提供原始整數、分組、SHA及限制；[跨平台原始量測](../../macos/docs/development/PACKAGE_SIZE_AUDIT_2026-10-13.json)與[調查過程](../../macos/docs/development/logs/2026-10-13/02.zh-TW.md)保留。

**42.23MB／16.78MB是參考載荷，不是已確認的MSIX節省。** 兩來源批次不同、壓縮方式不同，不能直接以95.55−16.78宣告新商店大小。

## 4. 兩個候選的適用性比較

| 項目 | 獨立Updater AOT／裁剪 | SDK／ML相依精簡 |
| --- | --- | --- |
| Store包是否包含目標 | 不包含 | 主App使用SDK，相依值得盤點 |
| Store新增減重 | 0MB | 未量測；ML載荷有可觀空間 |
| 開發可行性 | helper相對獨立，但Store沒有收益 | 中等，有官方元件套件及明確依賴鏈 |
| 核心風險 | JSON／反射、等待程序、檔案替換、rollback | 原生Runtime重新帶入、PRI／XAML、間接依賴 |
| 對功能的預期影響 | 不改繪圖，但須完整更新回歸 | 目標不改功能，實際需完整操作回歸 |
| 推薦管道 | 官網Installer／Portable | Store優先，成功後另驗官網版 |

Store封裝Package-Store.ps1拒絕Updater／Data／portable.dat／update-files.json／PDB，既有兩架構payloadChecks均noUserDataOrStandaloneUpdater=true。GitHubUpdateService在packaged模式交Store管理更新；這是本專案設計，不宣稱所有Store發行類型都有相同更新規則。

## 5. SDK依賴與精簡路徑

目前HeiBan.Windows.csproj：.NET10、UseWinUI=true、SelfContained=true、WindowsAppSDKSelfContained=true、PublishAot=false；PublishTrimmed僅在Release且AOT=true時設定。不要誤認主App已經裁剪。

從目前精確版本的官方NuGet nuspec核對：

- Microsoft.WindowsAppSDK2.5.1總套件直接引用WinUI2.3.9、Foundation2.3.12、InteractiveExperiences2.1.9、AI2.5.5、ML2.1.94、Search2.5.5、Widgets2.0.5、Runtime2.5.1等。
- WinUI2.3.9直接依賴WebView2／Base／Foundation／InteractiveExperiences，不直接依賴ML。
- ML2.1.94引入Microsoft.Windows.AI.MachineLearning2.1.74；包內onnxruntime.dll約21.85MB、DirectML.dll約18.62MB。
- 有限來源搜尋未見ML／AI直接呼叫，不等於證明原生框架沒有間接使用。
- PDF匯出MainWindow.Export.cs實際使用WebView2；繪圖使用Win2D，這兩者保留。主程式一般文字搜尋不是Windows App SDK Search API使用證據。

[SDK總套件](https://www.nuget.org/packages/Microsoft.WindowsAppSDK/2.5.1)、[WinUI套件](https://www.nuget.org/packages/Microsoft.WindowsAppSDK.WinUI/2.3.9)、[官方模組化說明](https://learn.microsoft.com/windows/apps/windows-app-sdk/system-requirements)。

官方repo[#5969](https://github.com/microsoft/WindowsAppSDK/issues/5969)的維護者曾建議自包含、未封裝App移除完整Runtime引用、只保留WinUI元件，避免ML重新被帶入；那是SDK1.8的unpackaged案例，並非目前2.5.1 MSIX已驗證結果。需要查當前MSBuild native資產／框架抽取，不能只移除一條PackageReference就宣布成功。

Runtime2.5.1的ComponentReference.targets對共享框架的元件版本一致性有檢查：拆分套件須保留相容的Foundation／InteractiveExperiences等版本，不能把每個元件都寫成2.5.1或任意升／降版。分析時只用HTTP Range讀其XML／目錄，沒有還原或執行套件。

## 6. 實驗方案：同來源對照，不同方案分開

| 候選 | 變更範圍 | .NET | Windows App SDK | 目的 |
| --- | --- | --- | --- | --- |
| BASE | 原設定重建 | 自包含 | 自包含、總套件 | 原機可重現基準 |
| A | 必要元件引用 | 保持自包含 | 保持自包含，確認是否能去除完整Runtime抽取 | 真正移除未使用相依 |
| B | 官方框架依賴部署 | 保持自包含 | 共享框架 | 降低主包、共享Microsoft元件 |
| C | A＋B | 保持自包含 | 精簡元件＋共享框架 | A、B各自成功後再評估 |
| U（另管道） | Updater Native AOT／裁剪 | helper另議 | 不影響Store | 官網更新程式減重 |

B是Microsoft支持的packaged部署模式，manifest必須正確宣告PackageDependency，並處理初始化／版本需求；[官方指南](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/deploy-packaged-apps)。SDK共享與.NET共享是兩回事，不能順手把SelfContained也關掉，或假設Store會自動安裝.NET10。

B／C可能顯著縮小黑板主包，但首次使用者缺框架仍要下載相依；另記首次總下載／增量更新／安裝佔用。A／B收益可能重疊，不直接相加。沒有預定最終MB數字。

## 7. Windows端工作清單

### WR-01：建立可重現基準

- [ ] 核對git status／遠端，保留本機Windows未提交成果；在完整專案根目錄同步後只改Windows。
- [ ] 記錄source commit、實際dotnet --info、Windows build、SDK／NuGet版本、架構、MSIX版本及label。global.json10.0.100允許latestFeature；不能只記最低版本而漏實際SDK。
- [ ] 同來源以BASE重建兩架構，盤點MSIX內容及SHA；確認沒有Updater／作品／PDB並與原包區分。
- [ ] 輸出每檔bytes／壓縮bytes／來源包，尤其ML是否真的存在於Store MSIX；若沒有，撤回該分項節省假設。

### WR-02：A方案必要元件

- [ ] 核對UI／Win2D／PDF／截圖／螢幕畫布真正使用API，保留必需相依。
- [ ] 在獨立變更中替換總套件引用；明確核對Runtime引用及原生資產抽取，避免DLL再被另一條鏈帶入。
- [ ] 固定相容版本，查NuGet還原結果／MSBuild展開設定與PRI內容，法律文件依新精確版本更新。
- [ ] 產雙架構候選；比較移除／新增清單，確認不是只把payload移到另一個自己攜帶的容器。

### WR-03：B方案共享SDK

- [ ] 從BASE另一份候選開始，.NET仍自包含；只調SDK部署與必要初始化。
- [ ] 檢查生成manifest的Microsoft framework身分／版本與兩CPU架構；既有驗包腳本的必要DLL清單須按部署模式分開，不關掉驗證來放行缺檔。
- [ ] 從Store相同依賴配置機制安裝／更新；本機側載需合法測試簽章及依賴準備，不能拿unsigned送審包直接當一般用戶安裝包。
- [ ] 記錄已有framework與完全缺framework兩種環境的主包、首次總下載與磁碟差額。

### WR-04：回歸與Store候選決策

- [ ] 依第8節執行功能／安裝／資料驗收並保存證據。
- [ ] A、B單獨通過後才製C，保留BASE與各方案rollback資料。
- [ ] 綜合減重、維護成本與失敗率選方案；若省量低或有未解啟動／資料問題，維持原部署。
- [ ] 整批通過後由使用者決定正式進版與Store提交。候選完成不等於授權發行。

### WR-05：官網Updater後續

- [ ] 排在Store工作之外，獨立評估helper AOT／裁剪及JSON source generation需求。
- [ ] 驗下載驗證、正常退出等待、多視窗、權限／檔案鎖定、失敗回滾、中斷恢復、保留Data與未知檔；不強制kill用戶App。
- [ ] 維持Portable真正離線所需依賴，不用共享.NET的前提破壞免安裝承諾。

## 8. 驗收目標與拒絕條件（待Windows端執行）

| 面向 | 驗收要求 |
| --- | --- |
| 大小 | 同commit、同版號、同架構、同Release配置；MSIX及payload逐檔記錄；A目標移除已確認非必要相依，B分別記主包與首次總成本 |
| 安裝／更新 | x64、ARM64原生；最低支援Windows10 build19041與Windows11；乾淨／已有依賴環境；測試簽章側載不能冒充Store端驗證 |
| 資料 | 原作品開啟／保存／重新開啟、備份／垃圾桶／未知欄位、正常退出與失敗保留；不得為通過測試清空使用者作品 |
| 繪圖 | 筆畫／圖形／AB端點／粗細／填色／透明度／線型／箭頭／Undo、圖片貼上及PNG／SVG／PDF匯出 |
| 螢幕畫布 | 跨App／多螢幕／混合DPI、穿透切換／快捷鍵、文字、四邊工具列／清空／退出 |
| UI | 十語介面及手冊、RTL、色彩選擇、圖層拖曳回饋、尺／圓規／計算機／計時器 |
| Store封裝 | 身分／manifest／PRI／capabilities、授權文件、依賴配置與更新路徑、WACK；原Store包與公開歷史保留 |
| 效能 | 相同測量條件比較啟動時間、繪圖延遲／掉幀、RAM；體積改善不能代替性能證據 |

建議以主包下降10%以上作優先採用門檻，這是計劃目標不是預測。若小於門檻但維護／安全收益有實證，可另由使用者評估。任何啟動、作品損壞、遺失功能或更新失敗均阻止採用；先回退候選，不改已發布包。

## 9. 候選建立與結果記錄方式

在Windows的windows目錄、相關方案設定實作完成後，使用既有腳本，例如：

```powershell
powershell -File HeiBan.Windows/Packaging/Package-Store.ps1 -DevelopmentLabel weight-base-2026-10-13
powershell -File HeiBan.Windows/Packaging/Package-Store.ps1 -DevelopmentLabel weight-a-2026-10-13
powershell -File HeiBan.Windows/Packaging/Package-Store.ps1 -DevelopmentLabel weight-b-2026-10-13
```

日期依實際開發日替換。腳本本身不會自動選A／B；相應來源與設定必須先實作並記commit。B若使用共享SDK，現有self-contained DLL必要清單須先調整為正確模式契約。不要繞過重複label／防覆寫檢查。

每方案保存：SOURCE_COMMIT、dirty來源清單／hash、環境、完整設定差異、build log、兩架構asset bytes／SHA、payload diff、WACK、安裝／更新／功能案例結果、失敗與回退方式、正式進版批准狀態。二進位／Data／PFX／私人作品留原機，不進Git；分享精簡JSON、文字報告及必要去識別截圖。

| 候選 | x64 MSIX | ARM64 MSIX | 主包差額 | 首次依賴成本 | 功能／WACK | 決策 |
| --- | --- | --- | --- | --- | --- | --- |
| BASE | 待新量測 | 待新量測 | — | 待量測 | 未執行 | 基準 |
| A | 未產生 | 未產生 | 未量測 | 待量測 | 未執行 | 待評估 |
| B | 未產生 | 未產生 | 未量測 | 待量測 | 未執行 | 待評估 |
| C | 未產生 | 未產生 | 未量測 | 待量測 | 未執行 | 待評估 |

## 10. 本次交付與限制

已完成來源／封裝紀錄審視、免安裝ZIP拆分、官方NuGet／部署說明核對及本報告／基準JSON。沒有修改csproj／MSBuild／原生程式、沒有重建／測試／WACK／Store安裝／提交，也沒有進版。Store確切減重仍由Windows端實作及測量。

開發進度見[CURRENT_STATUS](CURRENT_STATUS.zh-TW.md)，本次同步日誌見[交接紀錄](SIZE_PLAN_HANDOFF_2026-10-13.zh-TW.md)。相關授權維持GPL-3.0與限定Windows元件例外，移除／改版相依時更新精確第三方文件，不能刪法律文件來湊減重數字。

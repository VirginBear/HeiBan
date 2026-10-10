# Windows 架構決策（2026-10-08）

## 2026-10-10 — 順序快取與局部像素複製

Core ObjectOrderCache保存整份文件的穩定升／降Z視圖。文檔／list參考、數量與逐項object參考／Z改變時重建；每次取得視圖先O(n)無配置掃描，避免Generation尚未提交就漏掉圖層修改。相同Z保持原list次序（降序不是reverse升序）；枚舉時即時過濾頁面與可見性，locked語意延續。這是UI thread資源，不寫入JSON；呼叫端在每次繪製／命中重新取得，不能跨永久修改保留舊view當索引。每頁空間索引仍未實作。

Renderer只有明確Ascending的OrderedBoardObjects可略過排序，其他enumerable保留OrderBy fallback；單物件RenderPreview共用原culling／transform helper。快照匯出仍可用原稳定sort，不引用UI session view跨async操作。Hit對零rotation保持唯讀樣點參考；空心rect四邊短路及polygon局部生成去除全函式捕捉closure。

Overlay committed／target皆同device／BGRA／96DPI，以CopyPixelsFromBitmap整數pixel region恢復舊新damage，再畫暫態與局部readback／Present；不經DrawImage取樣copy。沒有新GPU backend／緩衝重用／排程或schema遷移。診斷入口--performance-output在storage初始化前要求全新資料根，結果標明合成／GPU同步範圍，正常App不寫逐點效能log。

## 2026-10-10 — 發行管理紀錄的讀取入口

Windows README／CURRENT_STATUS 連到獨立 PRIVATE HeiBan-private。私人庫的產品 JSON／交接狀態只供具權限開發者讀取，不是 runtime 相依、不參與公開 SDK 封裝、不是 submodule。MSIX 所需公開 manifest 仍在 Windows 源碼；跨電腦先 clone／讀私人管理紀錄再核最新平台文件。本機工具／產物／作品不藉此庫同步。

## 2026-10-10 — 正式 MSIX 管道

HeiBanStoreBuild 為顯式 MSBuild 分支，啟用 WindowsPackageType=MSIX／AppxPackage、Store manifest、PRI 與 self-contained SDK 封裝。既有 None 與手動 PRI publish target 保持各自條件。Store 編譯使用獨立 artifacts 路徑，App 啟動仍用官方 self-contained 初始化，禁止 bootstrap／DeploymentManager 額外下載安裝。SDK 自行處理 native activation；package identity 分支停用 GitHub updater，不帶外部 helper。

Packaging/Store 是產品公開身分／套件版本／品牌縮放圖與商店手冊；Package-Store.ps1 負責雙架構 SDK build、必要 payload／授權／身分核對、MakeAppx bundle 與來源／產物 SHA。純授權文件只從 SDK 生成的 PRI resfile 過濾，不改 Content payload／原檔名／內容。此層只宣告 runFullTrust，沒有 unvirtualizedResources；現有作品根在 MSIX 下的重新導向與解除安裝生命週期待實際驗收。

## 2026-10-10 — preview.6 更新邊界

Core/Updating/UpdatePolicy 負責嚴格版本解析、Release repo／包名／架構／URL／digest 契約；UpdateFiles 負責 PE Machine、ZIP 路徑／ADS／連結／重複／大小上限、inventory hash 與 Portable 備份／rollback；UpdateInstallation 是每安裝 cache key、短期更新 mutex 與程序租約。均不讀寫作品模型。

Windows/Updating/GitHubUpdateService 以 async HttpClient 背景查詢／下載，metadata 與 package 分開限制大小，下載驗證後原子寫 pending。UI 僅從 Changed 經 DispatcherQueue 更新獨立設定面板，手勢／繪圖永久狀態不受更新影響。Closing 保存完成後取消下載、核對最新偏好及 pending 架構，再複製自包含 helper 到 cache、寫 job 並啟動；重入 Closing 由 preparingClose 保護。

HeiBan.Updater 等原程序與資料保存退出，取得安裝 gate 後檢查其他視窗／原二進位版本及架構、重新核下載 SHA。Inno 原安裝註冊、Portable 宣告程式檔替換，最後核版本／架構與 result；不 kill 使用者 App。GitHub 更新只信任指定 GitHub Release／TLS 及其 digest，不具獨立發行簽章。MSIX 分支停用，交商店處理。Packaging 同時發布 helper、生成 inventory，測試腳本使用獨立 fixture／AppId。

## 2026-10-10 — preview.5 右鍵契約

ScreenRightClick取消暫態後Hit；空白直接返回，維持作畫及原選取。物件命中先damage舊選取，已包含ID保留多選，否則只選命中ID；切select後damage新把手，開MenuFlyout。只更新選取疊層，不改永久scene或模式。選單坐標由overlay實體桌面轉成chrome DIP，沿用ShowChromeFlyout焦點與style commit。自動右鍵及物件選單均不再切穿透；工具列模式及Ctrl+Alt+D為明確入口。


## 2026-10-10 — preview.4 螢幕樣式與區域更新

ScreenAnnotationWindow.Style集中所選物件樣式／填滿與300ms交易，工具預設和選取對象依select分開。CommitScreenStyle在手勢／模式／保存之前完成，Undo／Redo保留仍存在ID並重新載入內嵌圖像。CapturedRegion傳實體桌面選區，screen轉成overlay local，捕捉以DocumentEpoch防過期。

暫態DamagePreview合併舊新圖形範圍；select的down先加入舊選取框damage，避免清選取後殘影。沒有暫態／交易的Cancel不刷新，換工具只有改選取框可見性時局部更新；mode alpha仍全幅重建。MainLibrary Extended／Multiple框架選取，DoubleTapped開作品；批次操作在確認後移到可還原Trash。


## 2026-10-10 — 1.0.12-preview.3 互動契約

WindowSelection處理世界座標的方向框選，與LassoSelection分開；左往右包含全部占用輪廓，右往左碰觸。Main／Screen都在release才設定選取，不把矩形預覽加入文件。CurvePreview沿用renderer Catmull-Rom控制點，弱引用快取依不可變Points字串失效；命中／框選使用平滑路徑，預覽錨點獨立於文件。ViewportTransform.ZoomAt保存游標世界錨點。

Pin的TextBox位於TextOverlay，按pin ID／DocumentEpoch核對後提交，一筆Undo；失焦／Enter保存、Esc取消。明確顏色／線條修改成為後續繪圖預設，工具特有粗細／透明度保留；物件樣式仍走既有交易及多選套用。快捷列以model引用判定handler重綁，顯示原地更新避免浮窗錨點被替換。

Flyout的OverlayInputPassThroughElement僅指定工具列；Screen已作畫的換工具不重設native模式。無交易取消只失效overlay，保留永久scene快取；形狀／框選move只更新暫態preview，僅物件移動／擦除／提交失效永久scene。截圖先合成灰霧快照，WM_PAINT複製灰霧再揭示原選區，編碼只讀原圖；GDI資源與message loop在worker清理。

## 2026-10-10 — 1.0.12-preview.2 流暢度

DocumentSnapshot／各模型Snapshot以MemberwiseClone保留標量，明確深複製mutable lists／dicts；圖片／Points／文字字串與不可變JsonElement共享。Same只比較持久欄位、忽略JsonIgnore，交易中完成保存同步revision到before。EditorSession的DocumentEpoch只在Open增加，跨await保存核對epoch；Undo仍保留磁碟revision。preview point offset不持久化，收筆才翻譯點，renderer／命中／vertex把手共用位移契約。

MainWindow.Rendering分離committed GPU bitmap與transient overlays，以文件／generation／page／viewport／size／DPI key及明確dirty失效。裝置重建與關閉釋放。TextCache逐欄核對layout／rich spans，圖片非同步用epoch防過期回寫。縮圖待idle、writer gate序列與revision防回寫舊縮圖；搜尋／偏好合併。Screen選取拖動合併前後旋轉物件範圍，依damaged區域傳輸，保存timer避開未完成交易。


## 2026-10-10 — Mac 1.0.12 對齊

Core `TextStyleChange` 以 nullable 欄位表達本次變更，保留混合值及富文字未知欄位；`TextStyles.ApplySelection` 限當頁未鎖定文字／便簽，一次交易。Views `TextStyleMenu` 共用普通畫布／螢幕／草稿右鍵UI，進階面板只提交實際改動欄位，延遲操作先核對文件與選取ID。`TextDraftEditor` 使用原生RichEditBox，草稿獨立於文件，完成才加入／替換；取消不寫入。螢幕座標／文字尺寸為實體像素，樣式與UI以DPI換算邏輯pt。

螢幕工具列固定820×60／64×688 DIP，色圓開280 DIP面板、3×2色票；僅中段捲動，模式／清空／結束可達。WinUI設定最小寬度仍受無標題視窗追蹤限制，`NativeOverlayWindow.ResizeCompactWindow` 用SetWindowPos與SWP_NOSENDCHANGING保持WM_SIZE並避免被caption寬度撐開，原生200%DPI尺寸檢查驗證128px。文字使用獨立可取得鍵盤焦點的WinUI視窗，高於NOACTIVATE透明輸入層。

## 1.0.9 介面架構（歷史）

2026-10-10 UI以Mac 1.0.9／20261010.1為基準：MainWindow.Home.cs管理作品庫側欄／收藏／篩選／排序／多選／垃圾桶還原，library-ui.json獨立保存偏好且保留未知欄位；卡片190pt，支援160／250。主工具32pt、標題32pt，左下導覽膠囊集中倍率／視角鎖定／閱讀與頁碼；根視窗按DPI選初始大小，窄視窗自動收側欄。ScreenAnnotationWindow.Objects.cs共享物件格式與session交易；右鍵先命中物件再決定開選單或穿透。Docking.cs重排同一組controls、四邊停靠，左右154×740 DIP直排；清空／收合／結束固定底部，拖曳原生抓手移動完成後依最近螢幕邊停靠，screen-ui.json保存方向／位置比例／收合。


螢幕註記採680×80 DIP兩排WinUI控制列，可收合680×48；Chrome.cs分離色票／滑桿／更多。小控制列的Flyout允許超出root。NativeOverlayWindow持久DIB＋UpdateLayeredWindowIndirect；ScreenAnnotationWindow快取committed CanvasRenderTarget，live曲線以最新控制點凸包及padding追蹤damage，收筆使用整段範圍，雷射合併前後範圍。只讀回damage像素並逐列寫DIB，繪圖／穿透切換、取消、復原、物件操作及尺寸變更保守整屏刷新。沒有落筆的正常hover不重繪；16ms排程不能等同達到固定fps。Performance.cs只在隔離資料根原生驗證模式執行，紀錄渲染耗時／傳輸量及逐byte像素等價，不擷取使用者硬體輸入。


## 2026-10-10 — 教學工具與透明螢幕畫布

Core 仍不引用 Windows UI：EditorSession 用 stable ID 集合管理多選，LayerPresentation 只產生展示文字；LassoSelection、SelectionStyle、LaserPointerEngine、BoardExporter 與 PdfDocumentAttachment 為獨立引擎。雷射樣本不進持久文件與 Undo。

MainWindow.Teaching／TeachingPreferences／RichText／Pages／FloatingTools／Export 分開管理工具 UI、偏好、原生格式編輯器、頁面、浮動工具與輸出。普通文字保留原生 IME，富文字以 RichEditBox 編輯、CanvasTextLayout 渲染。

ScreenAnnotation.NativeOverlayWindow 用 Win32 per-pixel WS_EX_LAYERED 覆蓋虛擬桌面，Win2D 畫入 premultiplied BGRA，UpdateLayeredWindow 提交；NOACTIVATE 保留下方焦點，TRANSPARENT 切滑鼠穿透。控制列是獨立 WinUI 視窗，寬／筆寬依 DPI 換算；註記使用虛擬桌面實體像素坐標與來源原點，獨立恢復檔及跨程序 FileShare.None lease。合成截圖回貼原 board/page，不改來源直到明確截圖。

SVG／HTML 在 Core 輸出；PNG 共用 renderer；PDF 才使用隱藏 WebView2 與期限受控的列印工作，保留中文／向量，將 Mac 相同 marker/base64 原稿放在合法 incremental PDF stream。未知 JSON 欄位繼續保留，不新增破壞性 schema migration。

## 先前紀錄（歷史）


## 決策

**C#／.NET 10 LTS + WinUI 3（Windows App SDK 2.5.1）+ Win2D 1.4.0。** 套件以明確版本固定；原生 x64／ARM64 各自建置。UI、輸入、GPU 快取與文件核心各自負責一層。

| 選項 | 適合之處 | 本案的取捨 |
| --- | --- | --- |
| WinUI 3 + C# + Win2D | Windows 原生控制項、IME、可及性、Direct2D；強型別文件核心 | 採用，能沿用既有 Windows 骨架；XAML 需 Windows 建置 |
| C++ + Win32/Direct2D | 精確控制原生輸入、配置與生命週期 | 保留未來輸入／渲染熱區擴充，不先增加 COM 與手刻 UI 維護成本 |
| Rust + Windows API | 幾何與背景工作的記憶體安全 | UI 與 IME 整合需額外橋接；目前不引入第二個原生核心 |
| WebView2 / Electron | 沿用 Web 功能速度較快 | 本案希望獨立 Windows 原生畫布與控制項，因此不採用；不以沒有量測的效能數字排除它 |

.NET 10 為 LTS；原有 .NET 9 計畫接近支援結束，不沿用新專案的基線。[Microsoft .NET 生命週期](https://learn.microsoft.com/en-us/dotnet/core/releases-and-support)。原有 Windows App SDK 1.6 已結束支援，改用查證存在的穩定版本 2.5.1。[SDK 版本](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/release-channels)。

## 模組與檔案隔離

```text
windows/
  HeiBan.Windows.Core/     # net10.0：JSON、幾何、文件交易、磁碟路由，不依賴 UI
  HeiBan.Windows/          # WinUI 3：生命週期、首頁、編輯器、Win2D、指標採樣
    Assets/               # Windows 獨立品牌與 ICO
    Engine/               # GPU 快取與 Windows 輸入收集器
    Views/                # 共用圖釘元件
    Packaging/            # publish、Portable ZIP、Inno Setup
  docs/                   # Windows 決策、工作清單、建置記錄
  dist/                   # 只有 Windows ZIP / Setup.exe / SHA-256
  .staging/               # 每次打包獨立目錄
```

沒有任何 csproj 連結到 `macos/` 或 Swift 檔案；輸出不寫根目錄 `dist/`。平台間共享文件規格，沒有在 Windows 安裝過程讀取／搬動 Mac 作品庫。Windows CI 必須位於 GitHub 指定的 `.github/workflows/windows-build.yml`，但其路徑觸發與產物僅針對 Windows。

## 執行分工與效能設計

1. **UI 執行緒**只維持目前工具、即時手勢、選取與文件交易。每個手勢完成才記錄 Undo，不在 PointerMoved 序列化全文件。Undo 上限 64 個交易及約 32 MB 字串記錄；大型圖片的交易還需要差異式歷史以降記憶體。
2. **指標收集**使用 WinUI 的中間點，依時間戳排序並去重，避免回頭連線產生折痕。滑鼠採固定粗細，Surface 筆壓及傾角保留到資料。觸控暫不畫墨水，以避免手掌把筆劃當成另一條輸入；不宣稱已做系統級 Palm Rejection。
3. **Win2D**保存已提交世界座標幾何，平移／縮放只改矩陣。即時筆跡每 64 個穩定曲線段建立快取，尾段獨立重建。縮圖與 PNG 共用渲染器；GPU 資源在換板／裝置重建／視窗結束釋放。
4. **可見範圍**使用含旋轉與線寬 padding 的保守 AABB 排除畫面外物件。目前仍逐物件遍歷；空間索引、分區快取與延遲量測是後續性能工作，沒有宣稱百萬點滿幀。
5. **保存**在 UI 取得快照後背景寫檔，使用唯一 tmp、Flush(true)、File.Replace 與備份。成功後才更新 UI 保存世代；保存期間新編輯不被標成已保存。使用 semaphore／跨程序 file lock，磁碟 revision 較新時拒絕覆寫。
6. **首頁**正常讀小型 metadata／縮圖，缺少索引時從文件補回。錯誤有明確對話框，不靜默把未來版本或損毀文件變空白。
7. **文字輸入**使用原生 TextBox，避免手刻 IME；只在畫布 PointerWheel 接收縮放，編輯文字期間停止畫布滾輪操作。

Win2D 支援 GPU 加速，但不保證硬體／驅動條件下永遠使用 GPU。[官方 Win2D 指南](https://learn.microsoft.com/en-us/windows/apps/develop/win2d/quick-start)。

## Ink 與 AOT 的界線

原骨架名稱 `WindowsInkCoordinator` 實際是 `PointerPressed/Moved` 收集器，沒有 InkPresenter。穩定 WinUI 的 InkCanvas 仍不受支援，官方提出 Win2D＋pointer input 等替代方案。[官方支援表](https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/what-is-supported)。本階段採穩定 API；獨立輸入／預測需另外建 InkDesktopHost／原生橋接原型並量測。

**暫不啟用 Native AOT、trimming 或 single-file 發佈。** JSON extension data、XAML、WinRT 投影與 Win2D 先以穩定自包含部署落地；待功能與映射驗收後再比較 AOT 啟動和大小。AOT 不等於沒有執行期，更不能由編譯選項推導固定 80ms／50 MB。[官方自包含部署](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps)。

## 發行與資料

兩種包使用同一個 self-contained publish，避免功能分岔：安裝版包入 Inno Setup，免安裝版注入 `portable.dat` 和空 `Data/` 後壓縮。免安裝版不因偶然出現 Data 資料夾而切換模式、不在無法寫入時偷用 AppData；失敗會顯示說明。

Windows Shell 依最後副檔名判定；`.blackboard.json` 不能作為複合副檔名關聯而覆蓋全域 `.json`。安裝版另提供可選 `.heiban` OpenWithProgids；內容仍符合同一 JSON 契約。解除安裝只移除程式與自身關聯，保留作品。

Portable 是資料路由策略，並不表示作業系統不留 MRU／執行歷史。正式簽章、MSIX、自動更新與 Store 發行尚未完成，不能把安裝包稱作沙盒。

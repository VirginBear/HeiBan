# Windows 流暢度稽核 — 2026-10-10

Windows 1.0.12-preview.2／FileVersion1.0.12.2，保留Mac1.0.12／20261010.4功能與介面基準。此次只修改Windows，保留同工作區既有未提交內容與所有作品。

使用者回報畫面仍卡，來源確有可移除的高頻成本：普通畫布每次hover重畫整份scene；中文字每幀重新排版；選取getter在遍歷物件時又讀SelectedId，造成O(N²)掃描；筆跡移動每個事件逐點JSON Clone再Serialize；交易快照完整JSON往返，圖片payload也反覆複製。背景保存完成可能與切文件／拖曳交錯。此次改程式並重新封裝，不只提出建議。

## 檢視範圍與處理

| 範圍 | 發現與修正 | 保護與實際證據 |
| --- | --- | --- |
| MainWindow Input／Rendering／Chrome／Ruler／Teaching／Pages／RichText／FloatingTools | 分開永久scene與暫態畫筆、游標、尺規、套索、雷射；快取scene，隱藏圖層不重建；雷射16ms排程；移除重複selection bar刷新 | key含文件身份、generation、page、viewport、尺寸、DPI；模型修改明確標dirty，裝置重建／關閉釋放GPU資源；9種原生畫面逐byte一致 |
| Direct2D renderer | 快取文字CanvasTextLayout、標記區域及CanvasStrokeStyle；筆跡GPU路徑沿用；圖片載入epoch防舊await回寫、修重複bitmap釋放與無引用圖片裁剪 | 字串／字型／大小／尺寸／格式／透明度及每個rich span逐欄核對；穩定scene只建一次、懸停零文字排版重建 |
| EditorSession／DocumentCodec／Models／ObjectHandles／VectorMath | Selected改單次scan；typed snapshot替代已知模型JSON clone；拖動僅改bounds與preview位移，收筆一次翻譯Points | mutable collections獨立複製，immutable字串及JsonElement共享；未知欄位、壓力、傾角保留；parsed cache不共享；單筆Undo、Cancel、page／lock／rotation命中通過 |
| Main保存／Import／Library／Home／偏好 | 保存編碼／磁碟與匯入解析放背景；autosave不排重複工作；縮圖待空檔、寫入序列及舊revision跳過；搜尋150ms合併、工具偏好400ms合併／背景落盤；垃圾桶去除第二次Decode與同步讀取 | DocumentEpoch隔開切文件的await；snapshot對應自己board／objects；transaction revision跟隨完成的保存，避免假Undo；原子寫入／衝突檢查與history64筆／32MB上限保留 |
| ScreenAnnotation Input／Render／Objects／Text／Docking、NativeOverlayWindow | 長筆跡位移預覽；選取拖動前後旋轉bounds合併damage，局部pixel readback及DIB寫入；保存避開手勢／文字草稿；重複座標事件略過 | ray／eraser等保守全幅；18筆跡／收筆幀＋3旋轉選取幀＋1大幅彎曲邊界幀逐byte一致、雷射消退無殘影；右鍵／清空／文字／四邊配置原生檢查通過 |
| Screenshot／Exports／startup／recovery | 檢視cancel／epoch與原稿／輸出邊界，保留App區域截圖直接置入與恢復檔lease；不全面重寫未量測模組 | 真實PNG／SVG／HTML／PDF與原稿有效stream檢查；原始4物件未污染 |

## 最終量測

同一Windows11 ARM64 VM、200% DPI，原生Release，合成資料，重現原演算法與新演算法。並非拿兩個歷史EXE比較。GPU測量包含同步讀回；CPU配置量只計管理堆。時間會受VM／主機負載影響；最終邊界追加驗證時VM亦在封裝建置。

| 情境 | 原策略 | 本版 | 樣本 |
| --- | --- | --- | --- |
| 普通畫布穩定scene重繪中位／P95 | 31.3325／50.7451ms | 1.5991／4.9077ms | 300物件、140文字、19,200筆點；40幀 |
| 普通畫布管理配置量 | 8,601,832 bytes | 20,952 bytes | 上述40幀 |
| 文件快照8次 | 225.7151ms／77,457,968 bytes | 1.9684ms／2,960,360 bytes | 600物件＋2MiB圖片字串 |
| 選取getter100次 | 525.1017ms | 0.6437ms | 600物件 |
| 筆跡移動40事件 | 128.1457ms／46,126,320 bytes | 0.0156ms／21,480 bytes | 2,000筆點；收筆另0.6754ms |
| 螢幕畫筆渲染中位／P95 | 30.3310／56.8714ms | 4.4957／9.9080ms | 80幀，3024×1822實體像素 |
| 螢幕畫筆像素傳輸量 | 1,763,112,960 bytes | 1,111,704 bytes | 上述80幀 |
| 旋轉已選筆跡拖曳傳輸 | 全幅3幀為66,116,736 bytes | 4,142,128 bytes | 3幀，逐byte等價 |

第一輪同機普通快取P95仍27.0384ms，最後重跑較低，不據此承諾完全無卡頓或固定fps。普通畫布平移／縮放／物件變更仍需重建scene；大型圖片decode、長筆跡resize／橡皮擦、更多物件及多螢幕仍會增加工作量。快取以額外GPU bitmap記憶體換取重繪成本，尺寸／DPI改變會重建。

## 實際驗證與限制

- `/opt/homebrew/opt/dotnet/libexec/dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj -c Release`：568項通過，退出0。
- 原生ARM64 Release publish退出0；隔離qa-perf12p2-final的result／screen-result皆success。22組螢幕像素與9組普通畫面等價；原生中文草稿、取消、雙擊、Shift多選／右鍵、樣式Undo與四邊尺寸通過。
- pypdf strict確認1頁、2 BT、382 cubic、75 line；有效xref stream含4物件原稿。不是標準FileSpec附件，使用既有Mac相容marker契約。
- 本輪首編譯Performance.cs缺Engine命名空間，CS0103與衍生WMC1509／9999；補using後重建成功，失敗日誌保留。
- Mac已解鎖，CUA查看新版首頁、最終緊湊列及雷射畫面；對隔離作品的座標點擊未開啟畫布，QA視窗最大化點擊也無變化，不把操作嘗試算硬體驗收。實體滑鼠／手寫端到端延遲、中文IME、多螢幕／混合DPI、跨App剪貼簿、x64實機及安裝升級未完成。

最終封裝／部署／資料與清理證據記於BUILD_STATUS、CURRENT_STATUS及本版manifest。未commit／push／發布。精確性能數據見PERFORMANCE_1.0.12-preview.2_2026-10-10.json，原始結果在docs/build-logs/perf12p2-curve-native。

收尾追加：物件bounds不足以包含Catmull-Rom外凸；screen damage加入筆跡對角線／3保守padding，1000×600曲線拖動與全幅逐byte等價。一般旋轉拖動仍局部傳輸；大筆跡範圍較大以正確清除舊像素。

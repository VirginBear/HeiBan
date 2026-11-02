# Windows框選問題與手動清理清單 — 2026-11-02

使用者回報滑鼠選取框選異常，並要求待刪資料集中或提供清單自行刪除。先詢問發生畫布與具體症狀，同時讀取現行框選流程；不猜測已重現或修復。清理部分沿用昨日72份與留存Store包完全相同的暫存副本，重新唯讀驗SHA後提供TXT／CSV，使用者自行刪除；不再次執行先前被審核拒絕的刪除或移動。

開工git status只有三份既有YouTube未追蹤文件，全部保留。範圍僅Windows；不動已送審1.1.0、最新試用作品或其他平台。維持版本1.1.0，調查／清單結果待追加。

## 已確認原因與實作

使用者補充螢幕畫布正常、一般畫布異常。現行PointerMoved第274行誤呼叫CompleteWindowSelection，第一次移動便清除_marquee與_preview，後方正確Update分支永遠無法繼續；PointerReleased原本已有正確Complete。移除移動處的誤呼叫四行，沿用原更新及放開完成，不改左右框選語義或螢幕畫布。

舊ValidateInteractionsAsync只依序直接呼叫Begin/Update/Complete，測不到實際事件誤接。因此新增僅HeiBanValidationBuild可編入的routed pointer觀察器，觀察真正按下／移動／放開後的_marquee、preview與選取集合；正常Store禁止診斷符號。使用獨立新資料根、合成矩形驗證；另複製Windows來源於忽略的.build，將Input還原HEAD原碼作相同觀察器的前後對照。未預填通過。

既有10/12關聯圖以main/window/interaction/pointer/selection/canvas/session詞彙查詢，BFS244節點；圖僅定位，實際根因來自目前原始碼，沒有宣稱過期圖已完整涵蓋新程式。

## 本輪驗證結果

- 兩個`dotnet build ... -c Release -r win-x64 --artifacts-path <baseline-build/fixed-build> -p:Platform=x64 -p:WindowsPackageType=None -p:AppxPackageSigningEnabled=false -p:HeiBanValidationBuild=true`：皆0警告0錯誤。基準Input檔取自開工HEAD，其他測試觀察器相同。
- 用computer-use的sky在兩個獨立資料根／合成文件做實際滑鼠拖曳。首次工具偵測到使用者輸入，沒有執行；重新觀察後才重試，未繞過控制保護。修正前LTR移動1樣本，previewHeld=false且previews空；本次終點恰巧選到a,b，不假稱每次都完全選不到。一般人工連續移動會於第一樣本提早決定選取。
- 修正後LTR包含a,b、RTL僅碰觸a,b、LTR僅碰觸a而不完整包含→空集合，三個實際事件手勢通過。move樣本數1／2／1，皆於每個樣本維持_marquee與preview，放開後選取集合符合幾何規則且preview清除。不是硬體延遲／多指標壓力測試。
- `dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj -c Release`：本輪2365 PASS。
- 原始碼事件路由檢查：PointerMoved只Update，不Complete；PointerReleased保留Complete。既有手冊語義恢復，沒有變更框選方向、快捷鍵或文件格式，不重寫十語內容。
- 原生證據：`.build/marquee-20261102/baseline-results-r1/gestures.json`及`fixed-results-r1/gestures.json`；合成資料與測試來源／日誌均留忽略的.build，沒有讀寫真實作品。正常交付包不編入PrepareMarqueeValidationAsync；Store與Validation同時建置仍由既有guard拒絕。

## 手動清理清單

唯讀重新核對72份暫存MSIX／bundle與留存原件SHA完全相同，共5,172,729,420bytes（4.82GiB），沒有遺失／變更項。清單位於`windows/dist/manual-cleanup-2026-11-02/`，提供UTF-8 BOM CSV與每行一個絕對路徑TXT；CSV亦列出不可刪的原件及SHA，README提示僅刪列出的檔案，不刪父目錄。此次未移動／刪除任何副本，使用者手動處理；不再嘗試先前被審核拒絕的刪除。

正式已送審1.1.0.0套件原byte保留。此修正維持1.1.0開發批次，以新的試用Label區別，未自行進版／重新送審。普通免安裝試用結果於下方追加。

## 修正試用交付

`Package-PortableTrial.ps1 -Runtime win-x64 -Label marquee-fix-2026-11-02-r1`完成。來源22d2b6c5ef2ccfd6f84c63dcb0aeaea47f3af368，產品1.1.0不增加；PE FileVersion1.1.0.0／ProductVersion1.1.0+來源。正常Release包不是含觀察器的QA執行檔。

- EXE：`windows/dist/trials/HeiBan-Windows-Portable-1.1.0-marquee-fix-2026-11-02-r1-win-x64/HeiBan.exe`。
- ZIP：同目錄名稱追加.zip，133303121bytes，SHA `f5b83ac3a2800acea120e885a0e26d2b6b112f74f355dbef04f3a08f0227b8bb`。
- 653 payload SHA／229來源SHA／ZIP CRC一致；PrepareMarqueeValidationAsync未編入、Data空白獨立，未搬移作品。已送審bundle SHA仍為a7799085a7ccb5f7f0a23b37d0b12425a9def99ff366d8fa13686ee01eaade66。
- 封裝紀錄`.build/portable-trial-ad4b0b8541aa4d30b73bfb4aafff2f47`，核對`.build/marquee-20261102/trial-verification.json`。無新Store包／送審／進版。

本機手動清理資料夾另附「本次測試建置資料夾_可重建.txt」：只列baseline-build與fixed-build兩個編譯輸出，檢查不含Data／ScreenAnnotations等資料根、測試程式已正常關閉，供使用者自行清理；來源、結果與合成資料在同層其他資料夾，不列為刪除目標。此次沒有自動刪除或移動72份副本。

# Windows操作模式右鍵輪盤與五套圖示提案 — 2026-11-04

使用者先詢問操作模式能否右鍵長按輪盤，另要求生成五套不同工具圖示供挑選（先不實裝）。確認後使用者明確回覆第1項「直接實作並測試」；僅操作輪盤程式實作，圖示只提案。只改Windows，同1.1.1開發標籤，不修改既有Store提交包、作品與其他平台。

開工已讀DEVELOPMENT_INDEX、Windows CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY／AGENTS與git status；原有三份未提交清理文件及三份YouTube文件保留，差異存.build/operate-radial-20261104。現有graphify導向NativeOverlayWindow，但10/12圖已舊，現行Radial以實際source為準。

## 調查與設計中

NativeOverlayWindow操作模式使用WS_EX_TRANSPARENT／HTTRANSPARENT且OnPointerCore在!_drawing時返回，所以原輪盤收不到外部軟體的右鍵事件。需新增限定螢幕會話及操作模式啟用的WH_MOUSE_LL橋接，hook執行緒只做短小狀態機與轉送，不繪圖／等待UI。右鍵短按暫存後補送，長按保留給輪盤；標記自己補送的事件避免迴圈，未處理事件CallNextHookEx。CAD等外部軟體的右鍵拖動與長按存在本質衝突，要能關閉，不能宣稱所有軟體零差異。

參考Microsoft LowLevelMouseProc、SetWindowsHookEx、SendInput原始文件；UIPI與較高權限目標／安全桌面不能假設可重播。五套imagegen概念板各16工具，同順序與功能配色；A雙色描邊、B實心、C教具擬物、D深色高對比、E粉筆。圖片未接入Assets、ToolIcons或打包清單。

實作、生成結果、失敗與本輪驗證待逐步追加。

## 進行中驗證與修正

五套原創imagegen概念板A～E完成並已顯示；合計約8.2MB的原始PNG與SHA清單存於私人repo designs/windows-tool-icons-2026-11-04，未接入公開程式Assets或打包內容。每套16工具與小尺寸／輪盤示意；屬風格草圖，選定後仍須逐工具細修（例如生成藤條帶彎鉤，實際藤條素材會保留原直藤條語彙）。

Core3440 PASS（新增1017含1000個合成短按配對，不是1000次真實OS事件）。首輪QA build成功但驗證targetPID尚未接線產生2警告，之後已加入native helper。第二輪因probe MenuFlyout.ShowAt的new()被推論成Point而非FlyoutShowOptions，造成CS0117及連帶XAML解析錯誤；改為明確FlyoutShowOptions，再建第三輪。補送失敗保留最初Win32 error，處理部分配對及延後卸載；普通操作時不開輪詢timer，只有右鍵手勢中才啟用。

## 交互邊界補強

輪盤只在長按後顯示，快速右拖在門檻前補回down並交還原生up；修飾鍵／其他滑鼠鍵組合、同程序工具窗與較高／無法查驗權限目標皆直接放行。右鍵pending/wheel才開12ms timer，閒置沒有timer；move只保留最新一份UI資料、起訖事件有序，不排1000Hz UI佇列。取消／關閉時保留必要release drain，自己補送事件以ExtraInfo標記防迴圈；跨程序重播失敗顯示錯誤並停用本次hook。

操作輪盤固定格顯示既有筆圖示與「作畫」，返回目前繪圖工具；不是套用五套新圖示。選繪圖工具／作畫後才嘗試恢復工具窗鍵盤焦點，顯示輪盤本身不搶外部視窗焦點。DPI只在gesture起點鎖定，使用實體桌面座標扣overlay原點一次，渲染與命中用同一scale。

## 本輪實際驗證

- `windows/.build/tools/dotnet/dotnet.exe run --project windows/HeiBan.Windows.Core.Tests -c Release`：3440 PASS，新增1017項（含1000合成短按配對）；不是1000次OS右鍵或硬體延遲量測。
- `dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:HeiBanValidationBuild=true --artifacts-path windows/.build/operate-radial-20261104/qa-build`：第三輪0警告0錯誤；補焦點恢復後第四輪0警告0錯誤，35.20秒。完整log在同scratch目錄。
- 驗證組態啟動兩個獨立程序，資料根分別probe-data-r1、qa-data-r1，沒有讀寫原作品庫。QA hook只允許自建probe PID，未攔截使用者其他軟體。
- 原生WinUI／Win32 hook實際安裝成功，11項host斷言通過：操作模式、輪盤顯示、座標與hover、作畫格／工具切換、hook卸載、取消、偏好持久化及500個move只保留最新份。這些輪盤動作由合成Signal驅動，沒有宣稱真實長按已測。
- 使用computer-use的`sky.click(mouse_button:"right")`在獨立probe空白區實際短按兩次：probe down=2、up=2、原生右鍵選單=2；hook intercepted=2、replayed=2、started=0。畫面確實出現QA right-click menu。普通左鍵按鈕通過，left=1，操作模式／輪盤狀態不變。Esc關選單與正常退出螢幕會話返回空白首頁成功。
- `qa-results-r1/result.json`、`live.json`及`probe-results-r1/input.json`保存上述機器可讀證據。正常包需另外檢查不含這些驗證入口。

目前computer-use API只有click／左鍵drag，沒有右鍵持續按住與移動，因此**實體長按→拖向格子→放開、外部右拖、混合DPI／多螢幕與高權限目標均未實機驗收**；不能把合成狀態檢查當作這些情境已通過。交付需使用者依下列步驟確認。

## 手動驗收與成功條件

1. 開螢幕畫布，切操作；其他軟體空白處短按右鍵。成功：原軟體選單出現一次，沒有輪盤或多餘點擊。
2. 原地按住右鍵約0.22秒，輪盤出現後再拖向工具，放開。成功：選中格發亮、輪盤消失、進入作畫並使用該工具，外部軟體不跳右鍵選單。
3. 選「作畫」格。成功：恢復目前工具；作畫時輪盤同一格顯示「操作」並可切回。選中央空白或Esc取消，成功：仍維持操作模式、不改註記。
4. 連續短按、操作後再次長按、正常退出再重開；成功：無卡住右鍵、輪盤殘影或遺失其他按鍵操作。
5. 更多→操作模式右鍵輪盤關閉，退出重開。成功：設定保留，操作模式右鍵完全交由外部軟體；作畫模式原輪盤不受影響。CAD等需右鍵長按的軟體建議關此設定。

## 修改範圍與相容

新增Core OperateRightGesture／檢查、Windows OperateRadialHook、screen adapter與共用偏好選單；修改螢幕生命週期、輪盤渲染及偏好複製。新增僅驗證組態的App probe及screen host helper；正常封裝排除。十語新增3 key至705 keys、指南26節79段同步。沒有改.heiban作品格式；toolbar.json新增OperateRadialEnabled，既有未知欄位維持保留。五套圖片只在私人庫設計目錄，不是App圖示。

## 官方參考

- [LowLevelMouseProc](https://learn.microsoft.com/en-us/windows/win32/winmsg/lowlevelmouseproc)：hook執行緒與回呼時限。
- [SendInput](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput)：實際插入數量及UIPI邊界。
- [MSLLHOOKSTRUCT](https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-msllhookstruct)：螢幕座標與額外事件標記。

正常試用包、雜湊及Git同步結果待後續追加；不覆寫1.1.1.0 Store套件，不代表送審／商店驗收完成。

封裝前另跑OptimizationChecks，首次少傳必要的獨立輸出目錄而按guard失敗（optimization.log）；補上`-- windows/.build/operate-radial-20261104/optimization-results-r2`後68 targeted data checks通過。Localization最後重生十語705keys、missing=0。清除新增翻譯行尾空白；不影響事件邏輯。QA與probe兩個自建程序均正常關閉，原作品庫未接續／未覆蓋。

## 正常x64免安裝試用交付

來源凍結`7868acaaa854bfbf7da21867f7238b064c067406`，產品維持1.1.1／FileVersion1.1.1.0。執行`Package-PortableTrial.ps1 -Runtime win-x64 -Label operate-wheel-2026-11-04-r1`成功；封裝紀錄`.build/portable-trial-a74f79b7010e41de896838ef65afc71b`。正常App與Updater publish完成，無測試旗標；正常成品未由agent啟動，QA測試使用獨立驗證build。

- 直接執行：`windows/dist/trials/HeiBan-Windows-Portable-1.1.1-operate-wheel-2026-11-04-r1-win-x64/HeiBan.exe`。
- ZIP同名加`.zip`：133352310 bytes，SHA256 `541ba676b1044f89ca0371e03b48e9e1ab1c2547d5f81fb6063f59d05f6e0b92`。
- `Verify-Portable-r1.py`核對654 payload、251來源、64原SVG與10語指南、ZIP SHA／CRC全通過；ShowOperateInputProbe／ValidateOperateRadialAsync等診斷入口不在正常assembly，Data獨立空白。生成提案PNG未進payload。
- 已提交1.1.1.0 Store bundle仍為197514657 bytes，SHA256 `85c1400ae94430309fd4c440881238e8d71127e0c0cd6e38616470af6491e968`，保持不變。未製作新Store／ARM64包、未代上傳／發布、未跑WACK。

所有試用資料根與既有作品保留，未清理舊產物。原有三份dirty清理文件與三份YouTube未追蹤文件未納入本批提交。私人圖示五套原檔／SHA、壓縮交接與產品紀錄將分庫保存，不把私人管理資料加入公開repo。

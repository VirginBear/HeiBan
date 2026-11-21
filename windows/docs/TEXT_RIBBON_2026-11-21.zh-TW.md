# Windows 1.1.6 文字編輯重整

## 開工與需求

2026-11-21 接續使用者實測回報：文字列擁擠、螢幕畫布所有項目塞入窄工具列而不可用。要求字型／字級／字色、對齊、橫直文字方向，能分別調整選取文字與整個方塊，區分文字色、方塊背景與選取字元螢光底色，並檢查流暢度。

沿用 1.1.6，只修改 Windows 與相應資料契約。開工 git status 原有三份文件修改及三份未追蹤 YouTube 文件保留。先核對既有文字編輯、工具列尺寸與原生文字呈現邊界。開始時尚未執行本批測試，未宣稱前批通過等於本批可用。

## 進行中發現與實作邊界

- 舊 CreateFormatPage 是無分組單排／單欄，超出視窗只有隱藏捲動；一般畫布側欄還硬限寬96 DIP。改為三分頁、可換行控制組與可見垂直捲動，頁寬依工作區上限560 DIP。螢幕左右停靠編輯時也展開完整分頁寬度，保留握把與結束鈕，分頁尺寸改變會重新量測自有視窗。
- 文字格式範圍明確選反白文字或整個方塊；一般游標位置影響後續輸入。原生格式修改使用一組 display batch 與 undo group，工具列 SelectionChanged 合併至一次待處理更新。
- 舊 ReadDraft 每個 grapheme 讀取十多項跨原生格式屬性。改用 TextRangeUnit.CharacterFormat 區段，於未知欄位與未改文字邊界分段，保留原擴充資料。先前預覽診斷實際20000字只讀1個格式區段；最終證據待本輪驗證。
- 直排以 Win2D 真正的 TopToBottomThenRightToLeft 呈現，不插入換行或改寫內容。原生 RichEditBox 的公開接口沒有提供同等直排編輯設定，本批原生輸入維持橫排，排版分頁用共用 renderer 即時預覽直排／垂直對齊，頁面提交後按該方向呈現。這是已知操作限制，介面、手冊與交付均必須說明。
- 排版預覽只有分頁可見時才以80ms合併更新，不在每次按鍵儲存文件，也不掃描整份畫布。字體色、選字螢光底色與方塊背景色是不同資料。
- 初次編譯的 CS0165 是局部事件函式捕捉尚未初始化控制項；產生的多個 XAML Ui.Text 型別錯誤是後續連鎖錯誤。先初始化被捕捉的參考後，build-r3零警告零錯誤。中間Python預設cp950讀UTF8失敗，未寫檔，修正明確UTF8；失敗log保留。
- 螢幕預覽曾因外部滑鼠操作點到疊加畫布而正常提交文字。診斷 preview 才設 overlay 穿透，避免佔用使用者其他軟體操作；產品正常作畫邏輯未改。

- 實際右側工具列核對確認文字頁的按鈕和範圍下拉都可見；切排版時卻沿用舊高度，預覽被縮成細線。改為各頁明確高度與分頁回呼，螢幕宿主在切頁時重算視窗。預覽CanvasControl改成首次進排版頁才建立。
- verification-r1／r2 的既有 native-editor 檢查未過：初次150ms固定等待時，編輯器尚未完成Loaded後格式恢復；增加可觀察 ReadyForInput 並以有上限的等待驗證。r1是提交前仍在等待恢復，r2為重開格式核對時機。驗證程序另將疊加層設成穿透，以免真實桌面點擊污染合成手勢；正式產品不套用此診斷政策。最終以r3實際結果決定，保留前兩次失敗證據。

- verification-r3 九步通過，Core6918、Optimization68，文字範圍／底色／20000字單格式讀取與直排幾何、上／下對齊、快取重用驗證通過。但實際排版頁又抓到預覽host預設左對齊而量到零寬，已改內容Stretch並新增自動點入排版頁核對至少200×100的檢查；最終執行verification-r4。

- verification-r4新增預覽尺寸檢查確實攔下零寬問題；Stretch仍不足，CanvasControl本身無自然寬度。改給初始520DIP、宿主SizeChanged再配合實際寬度；build-r5加相同原生尺寸檢查通過。預覽卸載時RemoveFromVisualTree並釋放renderer，避免Win2D事件循環保留GPU資源。最終九步入口改執行verification-r5。
- @oai/sky實際切排版、點直排後，完整預覽呈現中文沿欄向下、換欄由右至左，英文依原生混合直排方向處理。畫面底下有其他軟體，未把桌面截圖存到公開或私人repo。

- verification-r5原生長圖／舊編輯通過，新文字頁測試仍看到host回到文字頁高度（557×253，preview為0×0）。追到舊AppWindow.Changed仍會啟動150ms dockTimer，FinishChromeDrag再RebuildChromeLayout；程式自行Resize／Position也可能走同一路徑，與新PointerReleased停靠重複。移除該fallback與其所有計時器引用，僅保留握把放開的停靠交易，避免程式調整視窗後重建正在使用的文字頁。最終改驗verification-r6，並將排版停留檢查延長至500ms。

- verification-r6九步通過，移除舊dockTimer後排版停留500ms仍有可用預覽。最後補齊直排的實體座標對齊：DirectWrite的段落對齊沿書寫軸，直排時交換兩軸映射，讓「靠下」真的向下、「靠右」真的向右；新增字元區域位移斷言，最終為verification-r7。

## 最終命令與驗證結果

執行 `python windows/scripts/Build-LocalizationCatalogs.py`（10語、772個source key）、`python windows/scripts/Build-UserGuides.py`（10語、每份26節），以及 `./windows/scripts/Verify-Development.ps1 -OutputDirectory windows/.build/text-ribbon-20261121/verification-r8 -IncludeNative`。九步全通過，513份來源資源於驗證期間雜湊一致。Core6918、Optimization68、Roslyn199檔零違規／28政策檢查；x64 WinUI零警告零錯誤。

原生驗證確認選取範圍的黃色螢光底色不波及其他字、整框斜體涵蓋全文、局部字型色彩字級重開保留、20000字純文字只讀1個格式區段。Win2D字元區域確認中文直排沿同欄向下，上／下對齊位置不同，未變內容沿用快取。螢幕工具列實際呼叫排版頁按鈕後預覽至少200×100可用，再回文字頁；兩種畫布的貼上、撤銷及舊圖片／工具原生回歸通過。

這些結果不等於整個App已達特定毫秒延遲。硬體IME、跨混合DPI、ARM64執行與Store認證未執行。使用者重點試用：切三分頁、選字與整框兩種範圍、分別改字色／螢光底色／背景、橫直排與上中下排版預覽、提交再重開，以及長文字輸入與離開的手感。

- verification-r7九步通過，直排靠下／靠右的實體位移斷言也通過。最後實際拖右側握把，發現雖有移動卻在放開時回到接近原位。根因是舊FinishChromeDrag用「滑鼠位置／整個螢幕」當停靠位置，但PositionChrome使用「視窗左上／可移動距離」，兩者不是相同座標。改為依放開時的AppWindow.Position與工作區扣視窗尺寸後的行程正規化；DockChrome共用該轉換，新增右側75%位置不回彈的原生斷言。最終驗證verification-r8，之後再用真實握把確認。

- 最終verification-r8九步全通過，來源與資源雜湊一致；沒有沿用前輪測試數字當成這輪結果。右側75%位置不回彈的原生斷言、直排實體軸對齊、排版尺寸500ms停留、20000字區段讀取及舊編輯／圖片檢查均通過。前述行尾空白清理已包含於r8最終來源。

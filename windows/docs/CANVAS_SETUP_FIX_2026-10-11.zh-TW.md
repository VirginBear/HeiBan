# Windows 一般畫布與新增作品修正（2026-10-11）

## 階段 1：開工與回報
- 起點 cfd319176e4e58ff06fc19516fef41c739e4f5b1；git status 僅原未追蹤 .vscode/，保留。
- 使用者實機回報：螢幕畫布控制點游標有效，一般畫布仍無效果。上一階段只有編譯與靜態核對，不能稱一般畫布已驗收。
- 需求：一般畫布方向／旋轉游標；無邊界不顯示尺寸；有邊界黑板預設16:9簡報；背景提供空白／橫線／點狀／方格／五線譜。
- 明確清理授權：windows/dist/trials 的舊未發布試用包可刪以減少空間；保留新最新版、作品資料、已發布產物與Microsoft Store送審包。這次授權覆寫之前「所有舊試用產物保留」的規則；不刪 Git 歷史或正式 Release。
- 範圍 Windows／平台文件與私人壓縮摘要，不改 Mac／Web，不操作商店／發布新Release，未授權測試不執行。
- 已先讀開發索引及Windows狀態／架構／問題、私人AGENTS／狀態／產品資訊／日誌。

## 階段 2：調查（進行中）
- 舊一般畫布以 SetCursor＋WM_SETCURSOR 原生hook；WinUI另有XAML游標狀態，須把游標設定接到實際Canvas父控制項。
- 第一次 rg 使用 PowerShell 的 MainWindow*.cs 路徑失敗；改搜尋目錄＋-g pattern，無資料變更。
- 背景既有 renderer／SVG 已支援 blank／lines／dots／grid／staff，原 Background_Click 只開色輪。新增作品與現有背景共用樣式選单，未知樣式保留；取消不改作品，套用一次 undo，加入文件 epoch／reference 防舊對話框改新文件。
- 新增作品無邊界模式收起並停用尺寸；bounded 兩類分開記住預設，fixed 首次為16:9（1920×1080），notebook維持A4；使用者後續自選不被強制覆寫。
- 官方 API 證據：Microsoft InputCursor CreateFromHCursor 支援把HCURSOR轉成 WinUI InputCursor；官方 InputCursor 範例用繼承Panel設定 ProtectedCursor。一般畫布新增 CursorCanvasHost，只包CanvasControl，不影響工具列／輸入框；native旋轉游標轉為獨立WinRT cursor。
- 本機SDK Microsoft.UI.Input.InputCursor.Interop.h 確認 IID ac6f5065-90c4-46ce-beb7-05e138e54117、介面繼承IInspectable，CreateFromHCursor是第6個vtable slot。避免錯用IUnknown的第3格。移除一般畫布舊WM_SETCURSOR hook及引用，螢幕原生游標維持其原生路徑。
- 原一般畫布失效原因以使用者實測為證；WinUI重設推論來自不同游標擁有層，未執行本輪實機追蹤。新方式採官方XAML入口，仍須實機試用。
- 參考：https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/win32/microsoft.ui.input.inputcursor.interop/nf-microsoft-ui-input-inputcursor-interop-iinputcursorstaticsinterop-createfromhcursor
- 參考：https://github.com/microsoft/WindowsAppSdkResources/blob/main/WindowsAppSDK-Samples/1.8-stable/Input/cs-winui/InputCursor.xaml.cs

## 階段 3：建置（進行中）
- 維持原各類背景預設：notebook橫線、infinite／fixed點狀；格式切換記住各自選擇。只改背景樣式時保留原背景色字串，避免無意義色碼正規化或未知原色遺失。
- 首次 build 0warning／0error、39.18秒；log windows/.build/canvas-setup-build-2026-10-11.log。未跑測試／App。
- trials盤點5份解壓包，3份已有Data（只讀數量／bytes，不讀內容），總73,389 bytes需先保留；尚未刪除。
- `gh release list`／`gh release view windows-v1.0.12-preview.5 --json tagName,assets`核正式發行；trials版p6尚未發布。git ls-files沒有runtime二進位，trials為ignored；兩庫不儲存新二進位或作品，不需刪Git歷史。
- 第二次 x64 build 0warning／0error、27.47秒。其後靜態讀取本機WinRT.Runtime公開API metadata，確認ActivationFactory.Get(string,Guid)，改走和SDK projection相同的factory取得路徑（兼顧self-contained desktop activation），刪除直接RoGetActivationFactory／HSTRING PInvoke。這是interop邊界補強，無App啟動。
- 新增作品對話框加入高度限制與捲動，避免小視窗遮住新增背景樣式；產品手冊去除不必要WinUI實作詞。

## 階段 4：來源交付與清理方案

| 項目 | 變更檔案（windows/下） | 理由與邊界 |
|---|---|---|
| 一般畫布游標 | HeiBan.Windows/Views/CursorCanvasHost.cs、Views/ShapeCursor.cs、MainWindow.Input.cs／xaml／xaml.cs | XAML ProtectedCursor只作用Canvas父容器，HCURSOR由SDK interop複製為WinRT，快取handle＋DPI；移除無效舊subclass。螢幕原生路徑維持。 |
| 新建尺寸 | MainWindow.xaml.cs | infinite收起尺寸且存null；fixed首次16:9 1920×1080，notebookA4；各格式在單次對話框保存使用者選擇。 |
| 背景樣式 | MainWindow.xaml.cs | 新建／既有共用blank／lines／dots／grid／staff選單；既有套用一筆undo，取消不改，舊未知style與未改色碼保持。renderer／SVG原本支援，未改文件schema。 |
| 舊試用清理 | HeiBan.Windows/Packaging/Clear-ObsoleteTrials.ps1 | 新包成功後才呼叫KeepTrial；核GitHub已發布資產、StoreSHA、原始碼inventory，Data／unknown／modified逐SHA移至独立backup。LiteralPath＋實際範圍／reparse／運行中檢查，只刪舊trials，不刪正式發行、其他dist、SDK、證據或歷史。 |
| 使用與交接 | Assets/HeiBanUserGuide.html、README.md、docs狀態／架構／決策／問題／日誌、此日誌／inventory | 每階段記原因與實際結果，舊成功紀錄補使用者實機更正；聊天原20項與最新覆寫保留私人摘要。 |

### 最終編譯與靜態核對

- 第三次最終 x64 build：0warning／0error、25.98秒；命令 `dotnet build windows/HeiBan.Windows/HeiBan.Windows.csproj -c Release -r win-x64 -p:Platform=x64 --artifacts-path windows/.build/canvas-setup-build-final2-2026-10-11`，log同名.log。
- `Parser.ParseFile(Clear-ObsoleteTrials.ps1)` 0語法錯誤，僅做PowerShell語法解析，尚未執行刪除。`git diff --check`退出0；rg確認舊Attach／SetWindowSubclass／DefSubclassProc引用已移除。
- 未執行 Core／native／UI tests、App／主畫布游標實機、4K／DPI／滑鼠／觸控筆驗收、ARM64新包、Store／Release發佈。不沿用前批測試數字。
- Mac對照：CursorHelper／控制點Kind與Rotation方向、HomeView的infinite不顯示尺寸和fixed 16:9預設、背景五種GridStyle存取／Inspector背景入口；本批Mac未改，資料code契約相同。

### 本次舊試用留存政策

使用者明確要求縮小trials／GitHub佔用，舊「所有試用產物保留」政策在本批被覆寫。保留歷史source／SHA／build log／artifact紀錄，刪舊未發布ZIP／sidecar／解壓runtime；三份Data有52個檔案、73,389 bytes，先單獨保留且驗SHA，公開只記計數、bytes與備份根，不記作品檔名或內容。

清理入口（必須先完成新包）：`Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.12-preview.6-canvas-setup-2026-10-11-win-x64`。備份位於 `windows/dist/trial-data-backups/<本次ID>/<原試用名>/Data/`。新ZIP保持空Data；作品可從這些本機備份恢復。清理結果／完整ZIP SHA／釋放bytes完成後追加。

GitHub CLI查核已有Release名稱／資產，git ls-files無zip/msix/exe/dll/pdb runtime、git check-ignore trials成功；沒有新試用ZIP占用GitHub，不能為這次清理重寫Git歷史或刪正式Release。git count-objects：pack30.52MiB／loose2.09MiB，屬程式與既有Git資料。

## 階段 5：封裝與實際清理完成

來源 `c53462a4efbeafddef6fe0468047948d60ca06f9` 已commit／push／ls-remote main同本機，status保留原.vscode/。新包 `Package-PortableTrial.ps1 -Runtime win-x64 -Label canvas-setup-2026-10-11`退出0，App/helper publish log無warning/error。

- 新 ZIP `windows/dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-canvas-setup-2026-10-11-win-x64.zip`，131,543,340 bytes，SHA256 `0066ccfa530af13a21fd016f9a49fa5dc41f13fb7a9cd7600034bd4d2fae0759`。
- 同名解壓資料夾 HeiBan.exe；ProductVersion p6+c53462a、FileVersion1.0.12.6，空Data。559 archive／557 inventory／108 source SHA皆符合，guide／README／licenses／sidecar／App及helper PE0x8664静態核對通過。
- 封裝log／來源／保全位於 `windows/.build/portable-trial-9b79a00b5387409cb6a933f5488f910f/`；[artifact](CANVAS_SETUP_PORTABLE_ARTIFACT_2026-10-11.json)／[inspection](CANVAS_SETUP_PORTABLE_INSPECTION_2026-10-11.json)。沒有App／實機／tests執行，包未上傳Release／Store。

實際執行 `Clear-ObsoleteTrials.ps1 -KeepTrial HeiBan-Windows-Portable-1.0.12-preview.6-canvas-setup-2026-10-11-win-x64`退出0，清理5份舊trial runtime＋ZIP＋sidecar。釋放 **2,260,814,479 bytes（約2.106GiB）**，3份Data共 **52檔／73,389 bytes**搬移逐SHA核對後保留；沒有unknown／modified程式檔，舊Data內容未讀或公開。

- 作品備份根：`windows/dist/trial-data-backups/20261011-032945-612f03c3/`，各原試用名下Data；根目錄新增README恢復说明，不上GitHub，不混入新ZIP。
- 原始清理證據：`windows/.build/trial-cleanup-20261011-032945-612f03c3/cleanup.json`；公開[清理結果](CANVAS_SETUP_TRIAL_CLEANUP_2026-10-11.json)只記計數／bytes／根路徑與程式包SHA，不記作品檔名或內容。
- 靜態再核舊5資料夹／ZIP／sidecar均不存在，備份檔数與bytes符合；trials只剩新試用資料夹、ZIP、sidecar三項，新ZIP SHA不變。
- Store前後SHA同 `d7a49b63d88fa880b1a97b0c307361ad2cfbc9b3d58786048887093d7204ea7b`；其他dist、SDK、build log／來源／原歷史文件保留，已發布GitHub資產沒有刪除。
- 舊UX20／performance／ux-feedback歷史文件保留；其中本機trials路徑描述為當時交付位置，本輪已清掉二進位，不能再認定檔案仍存在。

本輪沒有實機App驗收，不把使用者指出的上一版一般游標失敗藏在成功摘要內；新XAML方式需實機試用。Mac比對依据／完整需求更正／最新留存規則已合併到私人壓縮摘要，本機作品資料不放PRIVATE Git repo。

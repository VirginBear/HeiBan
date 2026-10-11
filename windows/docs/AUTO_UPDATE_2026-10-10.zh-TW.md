# Windows GitHub 自動更新開發紀錄

## 開工（2026-10-10）

- 使用者授權直接實作 Windows 線上自動更新，並詢問 EXE／MSI 封裝與 MSIX 商店路線；本批不發布、不操作商店帳號、不改其他平台。
- 開工 `git status --short --branch`：`## main...origin/main`，無既有未提交內容。已讀開發索引及 Windows CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY。
- 現有版本 1.0.12-preview.5，WinUI 3／.NET 10、自包含 unpackaged；Inno Setup 每使用者安裝，作品根獨立；Portable 作品在 Data。
- 已確認 AppWindow.Closing 先提交草稿、保存螢幕註記與作品；更新交接必須在保存成功後，獨立 helper 等待主程序退出，不能強制關閉作品。
- GitHub 目前全為 prerelease，需使用 release 清單，依 Windows tag／CPU／安裝類型／語意版本篩選。Store package identity 下停用 GitHub 檔案替換。
- 此主機只有 .NET 8 runtime，沒有 SDK、Windows SDK 工具及 Inno Setup。先準備隔離 Windows 建置工具，記錄實際命令與結果；既有歷史 700 項成果不套用本批。

## 進行中

規劃：更新策略與下載驗證放 Windows Core；UI 提供關於／更新、背景檢查與開關；helper 在暫存區執行，等待程序退出並驗證 SHA-256。Installer 使用原 Inno 升級；Portable 更新僅程式檔、保全 Data 與未知檔。付費 CA 簽章不作為 GitHub 更新的前置條件，HTTPS／GitHub digest 為下載完整性邊界，不宣稱等同 Authenticode 或獨立發行者簽章。

實際結果、困難與未驗收項目持續追加。

### 建置環境與第一輪發現

- `dotnet --info` 證實只有 .NET 8 runtime；官方 `dotnet-install.ps1 -Channel 10.0 -InstallDir windows/.build/tools/dotnet -NoPath` 安裝 10.0.401。首次大小量測警告後解壓成功，實際 SDK 可執行。
- 合併下載及執行 Inno Setup 的首命令被自動審查以 `blocked by policy` 拒絕，未執行。改為先單獨下載官方 6.7.3，驗證 Authenticode `Valid`／Pyrsys B.V.，再以每使用者、明確隔離目的地執行官方安裝；退出 0。繁體中文語言檔使用官方 tag 的 Unofficial/ChineseTraditional.isl。
- 第一輪 Windows x64 Release build 成功，0 warning／0 error；後續關閉重入防護與 Portable rollback 調整後仍需重新建置。
- 新更新檢查首輪發現 .NET regex `$` 接受結尾換行，`1.0.0\n` 被錯判有效。改用 `\A`／`\z` 錨點；SHA 同步使用嚴格錨點，保留首失敗證據，不略過檢查。

### 更新流程驗證

- 第二輪測試 helper 只捕捉 IOException，未捕捉實際 InvalidDataException，導致「預期拒絕不安全 URL」檢查中斷；補正測試例外範圍，產品拒絕行為原本正確。
- `dotnet run --project windows/HeiBan.Update.Tests/HeiBan.Update.Tests.csproj -c Release`：69 項通過，包含 fake HTTP 下載／轉址／SHA／離線／取消、停用後不產生工作、下載重用及 Portable 中途失敗 rollback。這些測試不發布 Release、不連到測試下載站、不讀使用者作品。
- `dotnet run --project windows/HeiBan.Windows.Core.Tests/HeiBan.Windows.Core.Tests.csproj -c Release`：本批實際重跑 700 項通過。
- `Verify-UpdateIntegration.ps1 -DotnetPath windows/.build/tools/dotnet/dotnet.exe -IsccPath windows/.build/tools/inno/ISCC.exe`：隔離 x64 stand-in／真 helper／真 Inno。確認舊父程序存活時仍為 .6，退出後 .7；Portable Data hash／未知檔保留、損壞包拒絕；獨立 test AppId 的 Installer 升級成功、測試解除安裝註冊移除。原生 HeiBan UI 保存／使用者實際安裝與 ARM64 執行不由此推定通過。
- 收尾稽核發現 FileVersion preview.6 的第四碼 6 大於同版 stable 的 0；僅比較 FileVersion 會跳過轉正式版。helper 改用 ProductVersion 的語意版本判定是否已更新，再用 FileVersion 核對原／新二進位；需重封初次 x64 Installer 並補 stable 整合驗證。
- 初次 x64 Installer 退出 0，但 Inno 6.7.3 官方繁體語言檔缺少部分新錯誤／驗證訊息 key，compiler 提示使用英文 Default.isl 作後備；不是無警告建置。原語言檔保留，需在重封前補齊後備訊息。工具 license.txt 與既有 INNO-SETUP-LICENSE.txt 的 SHA 完全一致。
- 語言封裝修正：官方繁體檔補上 Default.isl 中 23 個缺少 key 的英文後備、移除 3 個已不支援的 key，保留現有譯文／來源署名，以 UTF-8 BOM 保存到 Packaging/Languages/ChineseTraditional.isl。Installer 改讀隨程式保存的版本，避免依賴機器上的翻譯檔。最終兩架構 Installer 重封後再核結果。
- 第二輪隔離 helper／Inno 整合成功，追加 preview.6 → stable 1.0.12（FileVersion .0）及其他舊視窗存在時延後、保留 pending 的檢查；result.json 全為 true。測試的 .7／stable 都是本機 stand-in，沒有發布測試版本。
- 最終 x64 Portable 解壓後 555 個 inventory 檔逐 SHA 通過，PE／helper 架構、當前手冊／README、空 Data／ZIP sidecar 通過；隔離資料根的真正 HeiBan x64 主視窗啟動及正常關閉退出 0。這不是硬體繪圖或真實 GitHub 發行後更新驗收。

### 最後來源封存前檢查

- helper 交接 work lock 加入 10 秒內的短期重試；在隔離整合中刻意持有交接鎖 500ms，helper 沒有提早失敗，釋放後仍等待父程序退出。第二個視窗存在時仍保留 pending，不更新／不強關。
- PrepareExit 再核程序架構；helper 在替換前核原 EXE、Portable 新 EXE 及安裝後 EXE 的 PE Machine。更新檢查新增 x64／ARM64 標頭與不安全 pending 情境，最終 73 項通過。
- 最後整合 `update-integration-sealed.log` 退出 0；result 全部 true，包含 HandoffLockRetry／ParentWait／OtherInstanceDeferred／PreviewToStable／PortableApply／DataHashPreserved／UnknownFilePreserved／CorruptPackageRejected／InstallerUpgrade／TestRegistrationRemoved。
- Core／手冊在最後程式變更後再執行一次，仍 700 項通過。最後來源四包的命令輸出分別保存 `.build/sealed-Installer-win-x64.log`、`sealed-Portable-win-x64.log`、`sealed-Installer-win-arm64.log`、`sealed-Portable-win-arm64.log`；實際產物與 SHA 待封裝結束後追加。

## 最終交付

- 最後四包的 Package-Installer／Package-Portable 依序執行完畢，總命令退出 0；两個 Inno Successful compile、最終四個 log warning／error 0。初版與重新封裝過程仍保留上文，交付使用最後來源。
- x64 EXE 90,364,271 bytes；ARM64 EXE 85,607,789 bytes；x64 Portable 131,466,798 bytes；ARM64 Portable 127,040,672 bytes。SHA／來源 snapshot／檢查結果及 log hash 見 [最終 manifest](ARTIFACTS_2026-10-10_1.0.12-preview.6.json)。每包 sidecar 與實體 SHA 相符。
- 封裝完畢後最後 Portable 驗證：x64 555／ARM64 551 檔逐 SHA；PE app／helper 架構、版本、手冊／README逐 byte、空 Data 和 ZIP sidecar 通過。最後 x64 真 App 用獨立資料根啟動主視窗、正常關閉退出 0。ARM64 只核靜態包，沒有在 x64 主機執行。
- x64 核對包裝命令曾以 `$LASTEXITCODE` 檢查純 PowerShell 腳本而退出 1；腳本未設定原生命令代碼，實際結果 JSON Success／MainWindowStarted／NormalClose 全 true。讀結果確認 SHA 与最後包相同，後續改按 JSON Success 驗證，不重用該 wrapper 退出值宣稱失敗或成功。ARM64 最後核對在封裝真正完成後重跑，讀取最後 SHA。
- 更新 CURRENT_STATUS／DEVELOPMENT_LOG／ARCHITECTURE／DECISIONS／ISSUE_HISTORY／BUILD_STATUS、Windows README 與離線手冊。沒有修改 Mac／Web、文件作品 schema 或使用者資料；沒有 commit／push／發布／Store 操作。公開 GitHub 仍 preview.5。
- 未執行：ARM64 原生更新／UI、真正新 GitHub Release 的線上更新、完整手寫／IME／多螢幕／混合 DPI、MSI／MSIX／Store 認證送審、突然停電／強制終止中途恢復。測試 stand-in 不宣稱這些已驗收。
- 最後 `git diff --check` 退出 0；git status 僅 Windows 變更、封裝 staging 為空。重新核 manifest 的 119 個來源 SHA 與 4 個產物 SHA 全相符，未把 `.build`／工具／測試 cache／使用者資料放入 Git。

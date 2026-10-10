# HeiBan Microsoft Store MSIX 封裝

## 開工

2026-10-10，使用者提供「HeiBan 黑板」正式 Product identity，延續先前 MSIX 與記錄／GitHub 同步授權。本批只修改 Windows。已讀 docs/DEVELOPMENT_INDEX、Windows CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY；`git status --short --branch` 乾淨，從已同步來源開始。封裝前建立本日誌，調查與實際失敗即時追加。

已取得套件 Name `DD7EC7CF.HeiBan`、Publisher `CN=90E6F226-B510-4821-A0CB-3D01D778A028`、PublisherDisplayName `純潔的熊`、顯示名稱 `HeiBan 黑板`、Store ID `9NV8T7RKV4MZ`。這些是公開套件身分；其他帳戶識別資料不為封裝所需，不保存到來源。

目標：可重現的 x64／ARM64 商店 MSIX／bundle、官方 SDK manifest 驗證、大小／SHA／來源與未驗收邊界；不購買 CA 憑證。未授權的 Store 送審、發布及私人帳戶操作不自行執行。依本次執行限制，不自行新增／執行程式測試；封裝工具本身的必要驗證照實記錄。既有四包及作品資料保留。

## 調查

現有專案是 WindowsPackageType=None、Windows App SDK 自包含，封裝公共腳本同時包含 GitHub helper 及 update-files.json。MSIX 發行需要獨立流程及確切產品身分；商店管道依既有 package identity 停用 GitHub 更新。SDK BuildTools NuGet 已有 10.0.26100.8249，下一步查 MakeAppx／MakePri 與 WinUI 啟動設定。

- 官方資料及本機 NuGet targets 確認 self-contained App 需要 WinRT 元資料／註冊與 PRI；Unpackaged app 的 native manifest 沒有 Win2D 的 MSIX WindowsMetadataReference 註冊，不能只用原 Portable 重新壓縮。
- 採用 Windows SDK BuildTools.MSIX 的正式 single-project 編譯管道，以 `HeiBanStoreBuild=true` 明確啟用；既有預設仍為 None。SDK 自行產生 WinUI／Win2D manifest extension 與套件 PRI，封裝時不帶 GitHub helper／Portable marker／作品。
- 新增正式 Store manifest／公開 identity JSON、既有 AppIcon 衍生的 44／150／50 像素及 100／200／400 scale PNG。沒有重新設計品牌。版本獨立為 `1.0.12.0`，產品版仍 preview.6；下一份同架構 Store 套件必須提高套件版本，不將 preview.N 直接放末段。
- 最低 OS 19041，與 Win2D 套件最低版本一致；MaxVersionTested 屬 SDK 宣告，不代表已執行完整 OS 測試。
- 初次 x64 `dotnet build ... -p:HeiBanStoreBuild=true -p:AppxPackageSigningEnabled=false` 正在執行，log 在本機 `.build/msix-initial-x64.log`。SDK 無需另外付費或 CA 憑證。
- 調查命令有兩次使用 Windows 路徑中的萬用字元直接交 rg，以及猜測不存在的 mrtcore 版本路徑；記為搜尋方式錯誤，改用 rg --files／實際 NuGet 路徑。MakePri createconfig／PRI dump 用於查看建置契約，不算 App 執行驗收。

## 封裝過程

- 初次 x64 SDK build 退出 0，產生 97,865,260 bytes MSIX；18 warnings／0 errors。PRI 誤把授權檔名的版本點號與 README 語系尾綴當 qualifier；另未安裝 mspdbcmf，symbol package 未產生。這不是無警告封裝。
- SDK self-contained 管道用 EXE 內嵌 native WinRT 註冊及自動初始化，會移除 package manifest 的 WinMD metadata registration。初包 manifest ActivatableClass 數為 0；上文「SDK 自行產生 WinUI／Win2D manifest extension」只是初步預期，實際依官方 self-contained targets 的結果，不手工杜撰 class 清單。SDK 產出 resources.pri，帶 25 份授權，不含 updater／Data／portable.dat。
- 新封裝脚本用 `--artifacts-path` 將 Store bin／obj 放在獨立 `.build/store-<batch>`，避免与既有 Unpackaged 中間產物混用；只排除純文件的 PRI index，仍保留完整授權內容。商店包不帶除錯 symbols，CLI `DebugType=none`／`DebugSymbols=false` 明確套用所有 project references。
- 第一次 Package-Store 執行在 PowerShell 字串 `$arch:` 語法階段失敗，尚未開始封裝；修正 `${arch}`。外層以未設定 LASTEXITCODE 判斷而回 0，不能算成功；後續採用 Stop／try-catch 回傳實際封裝錯誤。
- 隔離 SDK x64 build 成功，README qualifier／symbol warning 消失，但仍有 16 個授權 qualifier warning。第一次 PRI exclude 使用來源檔路徑，SDK 已改為 PackagingOutputs layout 路徑，因此沒有命中；修正為按 PackagingOutputs 的 TargetPath 選取，封裝前再還原。原授權 payload 不改名／不刪除。
- 新增封裝必要 guard：實際 MSIX 身分／架構、runtime／PRI／圖示、25 份授權與兩份手冊逐 SHA、不含作品／GitHub helper／debug symbols；guard 不算 App 執行測試。SDK strict manifest／package validation 保持開啟。
- 來源以 `8364e11` 提交後開始最後隔離封裝，以便包內產品資訊追蹤編譯基準；尚未推送，待封裝結果追加紀錄一起同步。文件批次來源 SHA 不取代 Git 換行正規化後的 blob SHA。
- 使用者在封裝期間確認第一版「免費提供」，已更新刊登草稿；沒有操作 Partner Center 價格或發布市場。
- 第二輪 PRI exclude 仍未排除 16 warnings。讀 SDK 的 filtered.layout.resfiles 確認索引仍含完整 Licenses 路徑，改為只在生成 PRI resfile 後過濾純文件行；Content packaging payload 不動。授權 guard 補成遞迴核對含 third-party 目錄的 25 份完整文件。SDK 產物本身合成 bundle 成功，仍需最後來源重新封裝。
- 包內 manifest 調查發現 SDK 用專案 TargetPlatformMinVersion=17763 覆寫了模板的 19041，與商店目標及 Win2D 最低版本不一致；Store build 分支明確設 19041（不改 Unpackaged 預設）及 zh-TW default resource language，封裝 guard 追加實際最低 OS 核對。先前包不是最終交付包，保持過程證據。
- PRI resfile 過濾方案的兩架構建置均 0 warnings／0 errors，25 legal documents 與手冊全部原 byte 保留、bundle 成功；最低 OS 修正後需最後再封裝。舊包不交付為最終包。新增 bundle identity／雙架構／版本與其內 MSIX 逐 SHA 核對，官方 SDK strict validation 未關閉。
- 已完成商店刊登、runFullTrust 審核說明及隱私說明草稿；第一版免費。公開支援入口、隱私正式政策／URL、市場、分級問卷及示範截圖尚需使用者確認／完成；不代填問卷、不自行送審。

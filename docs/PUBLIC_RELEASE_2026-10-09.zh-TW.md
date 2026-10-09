# 2026-10-09 公開發行稽核

狀態：完成。來源、Mac 與 Windows 公開預覽均已公開並核對。

## 授權與範圍

使用者授權把目前專案上傳 VirginBear/HeiBan 並公開，選 GPL-3.0。HeiBan 原創程式採 GPL-3.0-only。Mac／Windows／Web 既有來源與歷史保留，這次只整理發行文件、授權與封裝；沒有移植或修正 Windows 功能，沒有部署 Web。

Windows 實際 NuGet 包的 Windows App SDK／ML runtime 含 Microsoft 專屬條款，與 GitHub 原始庫的 MIT 不同。使用者已明確同意僅限 Windows 平台元件的 GPL 第 7 節連結／散布例外，保存在 windows/LICENSE-WINDOWS-EXCEPTION.txt。HeiBan 與衍生程式仍須 GPL 開源，runtime 按原始條款分發；原四包保持不變。

## 檔案邊界與資料檢查

- Git：來源、平台資源、建置腳本、手冊、開發日誌與排錯摘要。
- Release：平台各自的 DMG／ZIP、HTML 手冊、SHA256SUMS.txt、PUBLIC_ARTIFACTS.json。
- 保留本機、不上傳：使用者作品與 Data／ScreenAnnotations、參考軟體、node_modules、build／dist／bin／obj、憑證／私鑰、原始編譯日誌。
- 依現有 Git worktree 與可達歷史作憑證模式掃描，命中 9 筆 Firebase 用戶端公開識別設定／相關檢查字串；未發現 private key、GitHub token、AWS／Stripe secret 等掃描模式。這是模式檢查，不能宣稱完全的安全稽核。
- Firebase 用戶端設定可公開不代表資料庫開放；實際部署規則／配額／API 限制未確認，不部署 Web。依據 [Firebase API key 官方說明](https://firebase.google.com/docs/projects/api-keys)。

## 本次實際確認

Mac 既有 1.0.8 / 20261009.7 App：Info.plist、ARM64 lipo、codesign --verify --deep --strict 成功；產出 DMG／ZIP，ZIP 包含 App／GPL／說明，沒有作品或 Windows 元件。SHA-256 與 manifest 對應。不是 Developer ID／Apple 公證版。前批編譯／啟動版本觀察保留在當日日誌 02，不把它當成本輪功能驗收。

Windows 原四包與 ARTIFACTS_2026-10-09_preview5.json 的大小／雜湊吻合，Portable 無使用者 Data 檔。擬以 Installer ZIP 包裝原 Setup EXE，Portable 追加精確套件授權／notice，再計算公開雜湊；不覆寫原包，不把來源的最新版手冊冒稱已裝進舊二進位。最新 HTML 另供下載。

公開 README／安裝／建置／貢獻／隱私／安全／第三方聲明的本地檔案連結已檢查。既有 tracked Swift 行尾空白只作格式清理。全 staged diff 的第三方原文 CRLF／空白及先前 untracked 檔空白警告保留，沒有宣稱全 staged whitespace 檢查通過。400 個 tracked 檔沒有私有資料路徑／憑證模式／超限大檔。

## 困難與處理

- NuGet registration gzip 導致 UnicodeDecodeError：辨識 gzip magic 解壓再讀 JSON。
- deprecated licenseUrl 無完整條款：HTTP Range 讀官方精確 nupkg 內 license／third-party notices。Win2D 舊 URL 轉到無關教學頁，保留 metadata、附官方來源授權並列此缺口。
- hdiutil create 產出成功，有命令 deprecated 提示；未擅自改用較新 diskutil 命令造成最低系統工具不相容，後續另處理。
- Windows 編譯版手冊與來源的功能狀態不同：公開說明以最新線上文件為準，來源 HTML 分開下載。

## 本次未執行

沒有加／執行測試套件，沒有 Windows 重建／安裝／升級驗收，沒有正式簽章／公證，沒有 Web 部署。Mac 跨 App 透明畫布、完整幾何／工具互動、Windows x64 實機與性能仍待驗收；下載頁皆標記公開預覽。

## 公開結果

- 原始碼：38d9893 已推送 main；私人儲存庫改 PUBLIC，未改寫歷史。未登入的 GitHub API 與 raw README 讀取成功，GPL-3.0 偵測成功。
- Mac：macos-v1.0.8，5個 assets已 publish prerelease；遠端每個 asset 大小與 GitHub SHA-256 digest 等於本機，5檔完整。
- Windows：擁有者同意限定 SDK 例外，四個公開 ZIP 已產生；逐 entry 比對 Portable 原 payload 完全相同，Installer ZIP 內 EXE 與原 SHA 相同，附 GPL／exception／runtime terms／精確 SDK條款。7個 assets（四 ZIP／HTML／SHA／manifest）已 publish prerelease，Windows tag 指向 991835a。遠端7檔大小／SHA與本機一致。
- GitHub private vulnerability reporting 已啟用。公開 tags／下載 manifest保留追溯資料；來源／Mac與Windows版本獨立。

### 最終核對與來源邊界

兩個公開 prerelease 共12個 assets的 GitHub digest／size／uploaded 狀態與本機一致。未登入的6個主要包下載HEAD皆200；公開README／GPL資訊可讀；私人漏洞回報 enabled=true。Mac來源tag指向38d9893，Windows來源tag指向991835a，main後續只補發行完成紀錄，不移動tag。

發佈期間工作區另出現8個Windows程式變更（EditorSession、ToolbarPreferences、MainWindow Chrome／Input／XAML／主檔、NativeOverlayWindow、ScreenAnnotationWindow）。這些後續修改不在本次preview.5來源tag，保持未提交原樣，不混入本輪發行完成紀錄的commit。後續建置需另確認版本／來源／驗收。這一批沒有宣稱工作區完全乾淨或把並行的新程式當成本次下載包。

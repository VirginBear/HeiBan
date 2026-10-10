# Windows 第二批免安裝試用包

## 開工

使用者詢問未發布版本是否仍可有免安裝檔案試用；本批製作本機x64試用包、延續紀錄與GitHub同步授權。開工HEAD `3fa30f989cacd7fab1a861b0ade2176619ee92e2`，git status只有原未追蹤.vscode/，保留不讀／提交。已讀開發索引與Windows狀態／架構／問題。

版本仍1.0.12-preview.6，檔名／trial README標記perf2與來源，與原dist同版歷史包分開。新試用資料根在自己資料夾的Data，不移入使用者作品。原Store bundle／Installer／Portable保留，不操作Release或Store。開始即記日誌，實際結果與阻礙進行中追加。

## 調查與進行中紀錄

- 現行Package-Portable.ps1會Force覆寫同名p6ZIP及清除暫存，因此本批另加trial入口與唯一输出，不直接執行該覆寫路徑。
- performance publish含App但沒有封裝helper與Licenses；不能直接把診斷publish當完整Portable交付。沿用Publish-Common必要檔案／updater／inventory契約，以隔離artifacts重新publish。
- 讀Services/WindowsStorage.cs不存在，未取得資料；後續以實際portable.dat／Data契約与既有封裝入口為準，不讀使用者作品。
- 本批未執行新Core／native／smoke測試；前批2324／127屬前批來源驗收，不寫成本批重跑結果。封裝與靜態產物核對結果完成後記錄。
- 第一包成功後靜態檢視發現PowerShell逗號陣列中的`$zip+'.sha256'`會拆成zip與獨立.sha256項，沒有正確檢查sidecar既存；payload／ZIP守衛仍有效，沒有覆寫或影響App。本次改括號並另用r2 Label重封，初包與其原始紀錄保留，最終交付以r2為準。

## 未驗收

新試用包實機操作／真筆、ARM64本批封裝與執行、MSIX／WACK／Store更新未執行。Windows程式碼、Store版本與其他平台保持原範圍；本批只新增封裝／紀錄。

## 實際完成

- 新Package-PortableTrial.ps1輸出Label隔離的ZIP及可直接執行資料夾，存在即拒絕覆寫，失敗保留資料／log；Common只增加可選ArtifactsPath，原封裝呼叫預設不變。只新增封裝腳本、共用publish參數及平台／私人紀錄，沒有變更產品功能／版本／文件格式。
- App與Updater Release x64 self-contained publish完成，封裝退出0，log無warning/error；包含Licenses、README、離線手冊、portable.dat、空Data與update-files.json，沒有使用者作品。新93份來源byte SHA核對0不符。
- 最終本機ZIP：`windows/dist/trials/HeiBan-Windows-Portable-1.0.12-preview.6-perf2-2026-10-11-r2-win-x64.zip`，131,511,496 bytes，SHA256 `3ac4685ba0bef4f2e74b89f90f32a8150e1cb60a17fe83e8e072aca1a38dc36d`。同名不含.zip的資料夾可直接雙擊HeiBan.exe。版本1.0.12-preview.6＋source3fa30f9；這是local perf2 trial，原p6dist包未覆寫。初包131,509,447 bytes／SHA3f7a15b8…亦保留，交付以r2為準。
- 靜態ZIP逐entry SHA核對557 payload files一致、Data file=0、portable marker存在；App／helper PE machine皆0x8664，ProductVersion `1.0.12-preview.6+3fa30f989cacd7fab1a861b0ade2176619ee92e2`；手冊／封裝時README與原byte相同，ZIP sidecar一致。沒有執行App或新測試。
- Store bundle SHA前後仍`d7a49b63d88fa880b1a97b0c307361ad2cfbc9b3d58786048887093d7204ea7b`。產物／來源清單見[artifact](PORTABLE_TRIAL_ARTIFACT_2026-10-11.json)、[静態核對](PORTABLE_TRIAL_INSPECTION_2026-10-11.json)。試用ZIP／解壓版與build logs是ignored本機檔案，没有上傳到GitHub Release或私人Git repo。
- 既有手冊產品入口不變，trial另附README-Trial.zh-TW.md與TRIAL-SOURCE.json。更新CURRENT_STATUS／DEVELOPMENT_LOG與私人交接，Git同步結果收尾另記。

## 實際命令與紀錄

```powershell
git status --short
# 包裝命令在try/finally內將bundled dotnet目錄暫加PATH並恢复原值
& windows/HeiBan.Windows/Packaging/Package-PortableTrial.ps1 -Runtime win-x64 -Label perf2-2026-10-11
& windows/HeiBan.Windows/Packaging/Package-PortableTrial.ps1 -Runtime win-x64 -Label perf2-2026-10-11-r2
git diff --check
```

包裝log與artifact在`windows/.build/portable-trial-e0162956134f4da685b8003a1a0b37a7`，實際source93與artifact記於JSON；artifact中base commit＋working tree bytes，不宣稱全來自乾淨3fa30f9。靜態核對以ZipFile.OpenRead、SHA256.ComputeHash比對update-files各entry，Get-FileHash核來源／手冊／README／sidecar、BinaryReader讀PE、FileVersionInfo讀版本；退出0，inspection.json scope標明沒有App execution。Get-Content檢查Store保全，Copy-Item保存兩份非私人JSON，git diff --check退出0。

最終r2使用新`windows/.build/portable-trial-8aa5e9b45aaf4b83a0f4ac1ef684cbb2`重新publish／壓縮、退出0／log無warning/error；再做557 entry／93 source／空Data／PE／版本／手冊／README／sidecar靜態核對，全通過。公開artifact／inspection已更新為r2；初包及初次log／inventory留原ignored位置。93 hash与目前交付程式／腳本核對0不符，Store前後一致。補強逗號陣列guard沒有修改App功能，沒有執行新測試或啟動程式。

本批沒有Core／native／smoke／更新器整合測試、安裝／啟動App或硬體驗收；前批結果僅歷史參考。另一台電腦要重新封裝／核對，不把本機dist當已經隨Git同步。

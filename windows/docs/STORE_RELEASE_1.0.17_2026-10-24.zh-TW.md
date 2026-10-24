# Microsoft Store 1.0.17.0 更新 — 2026-10-24

## 2026-10-24 — Store 1.0.17.0已提交更新審查（使用者回報）

使用者回報已提交1.0.17.0更新審查，目前等待Microsoft結果。此為使用者提供的狀態，未另登入Partner Center核對；尚無本批通過認證／發布的確認。套件沿用已交付的x64＋ARM64 bundle，不重打包或進版。 [送審紀錄](STORE_SUBMISSION_1.0.17_2026-10-24.zh-TW.md)。


## 開工與授權

使用者試用brush-palette-r2後要求「OK 幫我打包 我要更新微軟商店的版本」，依windows/AGENTS.md取得明確「採用1.0.17／1.0.17.0」回覆。本批只Windows，起點34dc7d725a6e6fb2778cf45fa7f725b3438c1d9c；開工git status保留三份文件6／8／4行和三YouTube新檔。已讀平台索引／CURRENT_STATUS／ARCHITECTURE／ISSUE_HISTORY／DECISIONS、AGENTS與前版Store紀錄。

先保存既有Store檔SHA，再同步csproj／manifest／StoreIdentity及十語指南版本；使用既有Package-Store.ps1的正式入口。舊1.0.16.0與更舊套件保留byte。編譯及套件靜態完整性核對會執行；本批不新增App／實作測試、安裝升級／WACK或性能採樣。前批實測證據保留在原日誌，本批不套用為新結果。未自行上傳、送審、發布。

## 累積變更

- 主畫布活動筆跡直接呈現，分離指標預覽／永久物件，減少顯示排程等待；改善轉角跟筆。裝置／DPI仍有未驗收範圍，不聲稱0延遲或50ms保證。
- 擦除改輸入驅動單worker與隔離預覽，減少重複快照；保留一手勢一Undo。兩畫布共用平滑漸細雷射與光點，中鍵平移顯示手形游標。
- 修復畫布初始化被可選板擦資源阻擋的空白退化，首幀前避免新增不可見筆跡。
- 常用色可＋新增／管理移除／還原，兩畫布共用並記住；移除無材質效果的筆刷類型下拉，保留舊作品欄位。
- 選取及雷射跨工具分頁常駐；只有當前筆／繪圖工具顯示筆色色線，筆刷面板單層捲動。十語手冊與新操作指南同步，不覆寫使用者作品。

## 進行中

封裝與靜態核對尚未完成；實際結果、來源commit、SHA與限制完成後追加。

## 進行中紀錄

舊Store全樹共42份歷史檔（排除可更新的STORE_ARTIFACTS.json指標）已保存SHA／bytes；私人microsoft_store、credentials_stored、release_policy、windows_snapshot四欄亦保存baseline。PRODUCT_INFORMATION與私庫開工文件已讀、git乾淨、visibility PRIVATE。未把身分資料放入新的公開管理文件。

同步三處版本成功；Build-UserGuides.py成功生成十語，每語25節64段。十語版本新增功能已撰寫，描述實際改善，不聲稱固定延遲／0延遲。git diff --cached --check通過，來源commit 1ebbeea2872ec2dbfcb61dd397e5a54fd15f21a8。Package-Store.ps1 -Configuration Release -DotnetPath windows/.build/tools/dotnet/dotnet.exe -FormalVersionApproved進行中；使用獨立artifacts與SDK嚴格manifest validation，沒有啟動App／安裝／測試入口。

本批沒有刪除資料或舊產物、沒有新功能程式改動，只有版本與交付資料。前批x64實機與核心檢查結果詳見BRUSH_FOCUS／BRUSH_PALETTE_IMPLEMENTATION／CANVAS_RECOVERY；本批沒有重新執行，未以其數字填入新測試報告。

## 實際完成結果

正式商店包`dist/store/HeiBan-Store-1.0.17.0-x64-arm64.msixbundle`已完成，196654884bytes／SHA256 `f4caf4d9611ab901f236ec2640e0e0de2242d62f0b628ad48bbc7ec0f076ad78`，來源`1ebbeea2872ec2dbfcb61dd397e5a54fd15f21a8`。x64／ARM64建置56.80／59.69秒，均0warning0error；293來源SHA、兩架構manifest／十語資源／PRI／圖示與指南、ZIP CRC及內含包byte核同。42份舊Store檔（含18套件）SHA不變。未執行本批App／實作測試、安裝升級、WACK或性能採樣；未上傳、送審、發布。使用者可接續Partner Center上傳單一bundle。

## 命令、證據與未驗收

- Package-Store.ps1 -Configuration Release -DotnetPath windows/.build/tools/dotnet/dotnet.exe -FormalVersionApproved：完成x64、ARM64 SDK build、嚴格manifest validation與MakeAppx bundle，記錄windows/.build/store-fad7eb003570490a83e0db7a93bb39e1。未發生編譯或封裝失敗。
- inspect-store.py：核同293來源檔SHA、三產物SHA／sidecar／CRC、Store name／Publisher／version／架構／最小OS及唯一runFullTrust。bundle內含MSIX逐SHA與獨立檔相同，無使用者Data、Standalone Updater、debug PDB或簽章。
- 兩架構逐byte核對十語嵌入catalog、手冊／指南與51個Store PNG、14個ICO尺寸／42個targetsize variant；使用固定SDK MakePRI dump實際包內resources.pri，確認UNPLATED／LIGHTUNPLATED與14尺寸，不是僅檢查檔名。十語新指南單頁infinite、25章29工具。
- 42份歷史Store檔（含candidates的18個MSIX／bundle）SHA不變；STORE_ARTIFACTS.json僅更新latest指標，既有版本報告保留。沒有清理／更動試用資料、使用者作品或已公開產物。
- 本批App／實作測試／WACK／Store安裝升級卸載／ARM64實機／混合DPI／性能採樣未執行。前批實測請讀各原始日誌；未新增數字或宣稱已達50ms。未自行上傳Partner Center、送審、發布GitHub二進位Release或啟用排程。

## 使用者接續

1. Partner Center開啟HeiBan既有產品的新更新，套件頁上傳`HeiBan-Store-1.0.17.0-x64-arm64.msixbundle`一個檔案。x64及ARM64都在內，不需要分別上傳。
2. 處理完成後確認版本顯示1.0.17.0，貼入[十語此版本新增功能](STORE_WHATS_NEW_1.0.17_2026-10-24.md)對應語言。產品說明、免費售價與既有隱私原則不因本批新增資料傳輸而需要變更（本批未新增資料傳輸）。
3. 若再次要求runFullTrust理由，可沿用既有[短版說明](STORE_RUN_FULL_TRUST_2026-10-12.zh-TW.md)；本包未增加受限功能。
4. 提交認證由使用者操作。這是未自行簽章的Store提交包，不能當一般側載包直接安裝；正式簽章與認證／發布依Microsoft結果。Portable與Store作品位置不同，不自動跨通道搬移資料。

公開metadata／文案來源已提交；產物／驗證紀錄及私人壓縮交接分開提交，四受保護私人欄位不因本機封裝改寫成已上架。原三份6／8／4行與YouTube新檔保留。

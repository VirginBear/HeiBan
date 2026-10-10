# Windows 1.0.12-preview.5 GitHub 更新

2026-10-10，使用者明確要求更新VirginBear/HeiBan與清理過時Windows包。既有本機四包原版本／SHA／ARM64與x64 PE／當前手冊與授權已核對；Windows功能源於本輪前已交付版本，不為公開封裝另改程式。

公開Portable追加GPL／runtime條款與安裝說明，所有原entry逐byte保持；Installer ZIP包裝原Setup EXE，EXE逐byte相同。新增公開ZIP的SHA與原本機包不同，兩份manifest各自描述自己的檔案。公開腳本以csproj版本查ARTIFACTS manifest，不再使用過時固定日期；正規化Windows ZIP反斜線查詢及安全檢查。首輪手冊查詢KeyError與修正記錄於開發日誌。

相應來源只包含Windows與公開入口文件／公開封裝腳本；Mac的同期未提交內容保持原樣。77建置來源及公開包逐byte核對，164候選檔模式掃描無私有資料路徑／憑證模式／超限大檔；忽略作品／Data／recovery／build-logs／bin／obj／dist，不上傳原始測試日誌、QA作品及使用者資料。模式掃描不代表完整安全稽核。

已完成windows-v1.0.12-preview.5：draft上傳7assets（四公開ZIP、HTML、SHA、PUBLIC_ARTIFACTS），遠端digest／size核對後發布。發布成功後，移除舊windows-v0.1.0-preview.5的四ZIP及舊HTML，保留歷史Release／tag及SHA／PUBLIC_ARTIFACTS文本。舊資訊見GITHUB_RELEASES_BEFORE_2026-10-10.json。Mac公開Release另行管理，不混同Windows清理。

本批沒有重跑程式測試，以77來源與已驗證四包SHA保持不變為依據；先前700Core／ARM64原生／PDF結果保留，x64實機、安裝升級及完整硬體互動未驗收。發布／清理已完成。

## 公開完成核對

相應來源commit `fddf85e1b79c3cd5625cda1472b3c1de493fb3fb` 已推main，公開tag指向此commit，77建置來源blob逐SHA一致。Release ID 408808724，7assets全部uploaded，GitHub digest／size與本機公開包一致；未登入的7下載HEAD均HTTP200。公開入口：[Windows 1.0.12-preview.5](https://github.com/VirginBear/HeiBan/releases/tag/windows-v1.0.12-preview.5)。README下載列及Windows安裝／快速開始／限制均更新，Mac來源與Release未變。

舊windows-v0.1.0-preview.5的4ZIP與HTML共317,440,540bytes已逐ID／名稱／size／digest核對後移除；只保留2個文本assets（SHA256SUMS.txt／PUBLIC_ARTIFACTS.json）及Release／tag、原發行文字。歷史Git不用改寫，所有作品／Trash／Data／備份留在本機。所有本機Windows二進位及ZIP均為1.0.12-preview.5（原4包與公開4ZIP），沒有更早版本包。

公開過程失敗保留：首次Windows ZIP手冊索引反斜線KeyError，正規化後重跑逐byte檢查通過；第一次draft使用短SHA，HTTP422 target_commitish invalid，改完整SHA後建立；draft以tag endpoint讀取回404，改從releases清單／release ID核對，發布後tag endpoint成功。原包不改，不跳過assert；新版確認公開後才刪舊assets。

實際命令：`python3 scripts/package_public_release.py --platform windows`、`git add`限定Windows與公共入口文件、`git commit`／`git push origin main`；`gh release create --draft --prerelease`、`gh release upload`、API讀取digest核對、`gh release edit --draft=false`；curl未登入HEAD、API逐asset DELETE及舊Release文字更新。公開包byte核對／發布／清理JSON存於本目錄，原測試日誌不上傳。

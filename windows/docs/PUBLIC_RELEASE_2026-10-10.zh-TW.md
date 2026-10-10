# Windows 1.0.12-preview.5 GitHub 更新

2026-10-10，使用者明確要求更新VirginBear/HeiBan與清理過時Windows包。既有本機四包原版本／SHA／ARM64與x64 PE／當前手冊與授權已核對；Windows功能源於本輪前已交付版本，不為公開封裝另改程式。

公開Portable追加GPL／runtime條款與安裝說明，所有原entry逐byte保持；Installer ZIP包裝原Setup EXE，EXE逐byte相同。新增公開ZIP的SHA與原本機包不同，兩份manifest各自描述自己的檔案。公開腳本以csproj版本查ARTIFACTS manifest，不再使用過時固定日期；正規化Windows ZIP反斜線查詢及安全檢查。首輪手冊查詢KeyError與修正記錄於開發日誌。

相應來源只包含Windows與公開入口文件／公開封裝腳本；Mac的同期未提交內容保持原樣。77建置來源及公開包逐byte核對，164候選檔模式掃描無私有資料路徑／憑證模式／超限大檔；忽略作品／Data／recovery／build-logs／bin／obj／dist，不上傳原始測試日誌、QA作品及使用者資料。模式掃描不代表完整安全稽核。

預定windows-v1.0.12-preview.5：draft上傳7assets（四公開ZIP、HTML、SHA、PUBLIC_ARTIFACTS），遠端digest／size核對後發布。發布成功後，移除舊windows-v0.1.0-preview.5的四ZIP及舊HTML，保留歷史Release／tag及SHA／PUBLIC_ARTIFACTS文本。舊資訊見GITHUB_RELEASES_BEFORE_2026-10-10.json。Mac公開Release另行管理，不混同Windows清理。

本批沒有重跑程式測試，以77來源與已驗證四包SHA保持不變為依據；先前700Core／ARM64原生／PDF結果保留，x64實機、安裝升級及完整硬體互動未驗收。發布／清理仍進行中。

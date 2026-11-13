# Windows 1.1.4 — PDF 當頁圖片與螢幕畫布呈現

使用者選擇執行大型 PDF 開啟及記憶體改善、依實際顯示環境優化 4K 螢幕畫布。本批範圍為 Windows，直播合成已取消。已讀索引、平台現況、架構、決策、問題並保留開工狀態。

多頁作品目前在 OpenAsync 與 CreateResources 載入整份圖像，切頁依賴全份快取。螢幕畫布保留一張桌面尺寸合成影格，每次呈現讀回髒矩形，若多個遠距工具持續合併會擴大傳輸。

## 實作進度

- 當頁與跨頁共用的可見圖片才解碼，切頁立即釋放未使用的 GPU bitmap。快速翻頁只允許單一解碼進行，過期結果丟棄。從首頁離開作品釋放快取。縮圖使用自己的短期 renderer，截圖／PNG 既有獨立 renderer、多頁 PDF 匯出讀原始文件，皆不倚賴編輯快取。
- 依實際虛擬桌面像素限制更新區，固定尺規或圓規只在碰到更新區時重畫。筆畫完成以同一髒區更新已提交影格，點模式雷射只追前後兩個光點。保留原始座標、DPI、原畫質與多螢幕完整畫布。
- 首次建置發現 Windows.Foundation.Rect 沒有 IntersectsWith，已換成邊界比較。放開／取消的全範圍回退保留，延伸線亦走完整更新。

- 第二輪 x64 編譯通過（0 警告／0 錯誤）。後續保守保留待更新的全幀狀態，避免新筆畫覆蓋其他待處理工作。橡皮擦正常完成沿用已呈現的預覽；錯誤、取消或工作版本失效時重畫。靜止光點與藤條動畫結束後避免無變化的讀回；本批最終來源另由試用封裝編譯。

## 編譯、封裝與驗收

x64 Release 編譯命令為 dotnet build windows/HeiBan.Windows -c Release -r win-x64 -p:Platform=x64 --artifacts-path <scratch>/build。第二輪為 0 警告／0 錯誤。最終以 Package-PortableTrial.ps1 -Runtime win-x64 -Label pdf-screen-perf-2026-11-13-r1 編譯封裝。來源 66d570f88238a1f93a7d5fd01e13b8c57b7cdecf，ZIP 100,518,661 bytes，SHA256 86e25482d6b3d6e19f60c9fae7717dafa4fbbf2f8270f0575886dfc22a36533e。verify.py 核對 422 份來源、724 份清單、CRC、PE、十語資源及空白獨立 Data。前一試用及三件 Store 1.1.3.0 雜湊核同。

未執行 App、4K／多螢幕、OBS、ARM64、效能與記憶體實測或 Store 送審。試用請開一份數十頁 PDF，快速跳首中末頁後反向翻頁，再試 Undo、截圖與多頁 PDF 匯出，確認圖片完整。螢幕畫布可在 4K 及混合 DPI 桌面開尺規，在距尺規較遠處畫筆、拖動、擦除，切換操作模式並確認沒有殘影。實際改善幅度需用 ScreenRender／ScreenReadback trace 及記憶體量測。

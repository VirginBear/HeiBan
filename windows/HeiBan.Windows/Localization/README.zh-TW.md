# Windows UI 字串維護

十語：zh-TW、zh-CN、en、ja、ko、es、fr、de、pt-BR、ar；初次zh-TW。來源清單Sources.json／翻譯表translations.txt／生成器windows/scripts/Build-LocalizationCatalogs.py／嵌入Catalogs/*.json。所有表格來源鍵只限UI；T不是通用作品內容翻譯函式。

## 加入字串

1. 新UI固定文字加入Sources.json，插值用{0}等索引與格式；C#使用T("來源")或F(FormattableString)，XAML使用loc:Ui.Text／Content／Header／Placeholder／ToolTip／Name。
2. translations.txt每行來源別名（分號分隔）及en/ja/ko/es/fr/de/pt-BR/ar八列，用|分隔；換行寫\n、字串尾端空白寫\s，前後空白與數字placeholder格式必須保留。
3. 在Windows執行 `python windows/scripts/Build-LocalizationCatalogs.py`（從repo根）；簡體採Windows NLS＋區域術語，仍需校閱。工具遇missing、空值、placeholder不符拒絕寫出。正常dotnet build直接嵌入已提交JSON，不連線／不需Python。
4. 提交來源清單／翻譯表／十份JSON，更新平台日誌。重複alias不允許。翻譯長度／閱讀方向／母語自然度仍要另外驗收。

## 邊界

- 不把Text／Name／Title用戶值、ID、文件欄位、DockSide／bold等內部枚舉或路徑送T；只翻譯展示標籤。新建預設名称依當時語言，之後是用戶資料。
- language.json原子保存未知欄位，保存成功才更新Language；查不到資源回來源正體中文。XAML沒有任意替换TextBox.Text或已有資料binding。
- 首頁可切語言；開著工作區／螢幕畫布時不換語言。Home／dialog／flyout RTL、畫布LTR。不能把右向左文字排版混入world／screen座標。
- 原生Windows選檔／例外／手冊／法律文件有各自語言，WinUI資源override可能需要重啟。母語翻譯／UI校閱尚未執行。

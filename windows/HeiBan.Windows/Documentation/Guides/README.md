# Windows離線十語手冊維護

UTF-8 `*.txt` 是各語言人工編寫來源。每行以 `|` 分隔：鍵、標題與段落；七個頁面文字及25個穩定章節ID依Build-UserGuides.py契約排列，每章至少兩段。內容涵蓋全部現行操作，不複製使用者作品；禁止在文字中嵌入HTML或遠端資源。

在Windows執行 `python windows/scripts/Build-UserGuides.py`。zh-CN由zh-TW經Windows NLS及地區用語表產生；其餘八語有独立來源。輸出Assets/Guides十份獨立HTML及manifest.json，舊Assets/HeiBanUserGuide.html成為同內容zh-TW相容入口。生成檔要一起提交，普通.NET build不需要Python。改功能時同步各語對應章節，再生成，不能只改輸出頁。

App依當前Strings.Language選HTML，兩入口共用LaunchFile；未知／缺檔退回zh-TW相容入口。手冊頁的語言選單只換文件，保留章節anchor，不回寫App設定。所有CSS、JS、文字均在本檔，無網路請求。阿拉伯文dir=rtl，快捷鍵、路徑與部分數字用bdi隔離，canvas資料不受影響。

程式生成時檢查鍵順序、段落、空白與重複；包體另查每頁SHA及manifest。這些不是實機入口／搜尋／RTL驗收或母語校閱。本批十語各25章55段，共250章550段，母語校閱待安排。準確內容以相同章節來源維護，翻譯允许依語法重新組句。

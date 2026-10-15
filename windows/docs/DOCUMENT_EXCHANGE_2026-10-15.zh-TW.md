# Windows PDF／PowerPoint 交換與磁鐵設定契約

## 匯入

- 首頁匯入接受`.heiban`／`.json`，及新增`.pdf`／`.pptx`／`.ppt`。原生作品仍走原DocumentCodec；一般文件另建新作品身分，不覆寫來源或同ID作品。
- PDF使用Windows.Data.Pdf逐頁轉PNG，不需要Office。PDF顯示尺寸由96 DPI的DIP換為72 pt世界座標，預設每pt兩像素、長邊最多3072像素。每頁一個鎖定image物件及既有BoardPage；不同原始尺寸置中於最大頁面尺寸內。可以透過圖層解除鎖定，但不會還原PDF原文／向量為可編輯元素。
- 頁碼UI選起訖頁；每次最多200頁、已轉圖片合計100 MB。逐頁可取消，成功後才保存整份新作品，取消或失敗不提交半份作品。大文件可分範圍匯入。密碼PDF尚無密碼輸入入口，受保護／損壞文件可能失敗。
- PPT／PPTX需本機安裝桌面PowerPoint；以單獨STA操作COM、唯讀開檔、AutomationSecurity=3停用巨集，暫轉PDF再共用同一頁面管線。保留既有Office文件，不全域殺程序。沒有Office時明確引導先轉PDF，不提供空白或失真的簡化OOXML替代渲染；沒有打包Office或新增PDF／Office NuGet載荷。
- 結果為靜態外觀。動畫／影片／轉場／互動及元素編輯不保留；缺少字型、外部連結、加密、舊格式或損壞內容需以實際檔案比對。外部PDF／PPT不被宣稱為無損可編輯匯入。原生PDF source attachment的存在不改變此頁面匯入政策。

## 匯出

PDF沿原WebView2本機HTML／SVG列印，筆記本的「目前頁面／全部內容」範圍新增「PDF匯出全部頁面」。依BoardPage.Index逐頁加入相應可見物件，共用PageId=null的頁面物件仍逐頁可見；CSS明確分頁。選取物件／目前視野仍只輸出指定範圍，其餘格式保持原來範圍語義。列印HTML不再重複編碼整份文件JSON，最終PDF仍由既有PdfDocumentAttachment追加原稿。依原SDK最大紙張尺寸縮放，匯入的圖片頁在PDF內依然是圖片，不能宣稱向量重建。

## 文件／偏好相容

作品JSON不新增欄位或遷移：只使用既有notebook／BoardPage／image／鎖定欄位，未知JSON欄位仍由原codec保留。`Settings/toolbar.json`新增`displayMode`（icons／labels，未知值fallback icons）與`magnetEnabled`（預設false），並保留未知偏好欄位。Select工具固定顯示；Magnet可顯示／隱藏但不因隱藏而改其開關。磁鐵空間索引／選取詳細模式／當前工具列分頁是暫態，不寫作品、不建立Undo。

## 官方依據

- [Windows PDF載入與呈現](https://learn.microsoft.com/en-us/uwp/api/windows.data.pdf.pdfdocument)
- [PowerPoint唯讀開啟簡報](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.presentations.open)
- [PowerPoint SaveAs及PDF格式](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.presentation.saveas)
- [PowerPoint支援的文件格式](https://support.microsoft.com/en-us/powerpoint/file-formats-that-are-supported-in-powerpoint)

實際命令、成功與失敗證據、實機及未驗收項目見[本批開發日誌](DRAWING_WORKFLOW_2026-10-15.zh-TW.md)。

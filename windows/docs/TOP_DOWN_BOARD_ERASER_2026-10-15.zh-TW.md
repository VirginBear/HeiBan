# 原創俯視磁吸板擦 — 2026-10-15

## 開工與最新覆寫
- 基準1cf360b。開工已有CURRENT_STATUS、DEVELOPMENT_LOG、ISSUE_HISTORY未提交內容及三份YouTube文件，屬其他工作，保留；基準差異暫存ignored .build，不讀取或修改YouTube文件。
- 使用者更正視角：應垂直看向板面，像板擦磁吸貼在板上；不要三分之四商品攝影角度。原創紙白／霧綠風格延續，僅保留板面內旋轉。
- 先生成純俯視透明素材，再依新輪廓校準抓取與擦除，移除前批透視felt偏移。Windows限定、1.0.14開發候選不進版，測試未執行。
## 實作進度
- 內建imagegen純文字生成原創紙白／霧綠俯視磁吸板擦，沒有附照片。最終1599×984 RGBA、alpha0–255、690653bytes，替換原BoardEraser.png，不額外綑綁中途商品視角圖。
- 平面斜放角約20度，無側壁／felt側層。只讀alpha抽出12點凸輪廓，抓取、綠框及擦除共用；移除前批18點透視接觸面及獨立17點抓取面。顯示框160×98.461538DIP保持原比例。
- 既有EraserFootprint半平面裁切、抓取偏移、草稿／取消／一筆Undo沿用。作品JSON與開關不變。十語手冊25章62段已重新產生，退出0；本批未執行自動化測試或App。

## 最終生成提示（內建imagegen，未附任何圖片）
Use case: ui-mockup. Asset type: ONE transparent 2D UI sprite for HeiBan, a paper-white and sage-green whiteboard app. Draw an ORIGINAL magnetic whiteboard eraser as seen by a user looking STRAIGHT AT THE BOARD, so the eraser is FLUSH AGAINST THE SCREEN PLANE. STRICT ORTHOGRAPHIC TOP VIEW: camera exactly 90 degrees above its top face, ZERO perspective, ZERO foreshortening, ZERO visible sidewalls, ZERO visible felt side layers, ZERO isometric depth, ZERO product photography. Shape: a slim elongated rounded RECTANGLE about 2.6:1, modest rounded corners, ivory paper-white outer shell with a long rounded sage-green inset grip, a thin deeper sage perimeter. Calm, polished, soft flat illustration with only extremely subtle shading inside the top face. Keep all opposite edges parallel and lengths equal. Rotate this FLAT sprite about 28 degrees counterclockwise in the IMAGE PLANE, long axis rising to the right. The entire eraser must remain a flat overhead silhouette; in-plane rotation must not introduce camera tilt. It should look like a magnetic eraser stuck to a whiteboard viewed head-on, ready to drag around on that board. No lettering, logos, wood, textures resembling a commercial brand, hands, board, or extra objects. Center the complete object with small even transparent padding. GENUINELY TRANSPARENT background, no shadow cast outside its silhouette, no floor, no backdrop, no gray haze. This is a clean overhead app sprite, NOT a product render.

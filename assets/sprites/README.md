# 卡片與塔圖示素材

直接開啟 `scenes/cards/components/card_view.tscn`，在 Godot 的 2D 編輯器調整卡片尺寸、字型、留白與子節點配置。這個場景就是遊戲手牌使用的卡片，修改後不需要另外改生成程式。根節點的 Preview Tower 搭配預設資料夾中的第一個配置作編輯預覽，亦可指定自己的 Card。

## 自行繪製圖片

- `cards/card_background.png`：未染色的底紙，144 × 208。可直接使用繪圖軟體修改此 PNG。
- `cards/card_frame.png`：透明背景的灰階卡框，144 × 208。白色會被染成塔的 accent_color，灰色會變成較暗的色調，黑色保持黑色。
- `towers/sentry.png`：目前哨塔使用的自製圖示，保持原圖與 UID。使用透明背景，圖案的透明度決定輪廓；黑色、白色都會統一染成較深的 tower accent color，原圖不變。
- `cards/card_back.png`：可直接繪製的商店牌背，144 × 208，使用 NinePatchRect；保留目前手繪圖檔。
- `cards/shop_icon.png`／`cards/reroll_icon.png`：商店與重刷的透明底圖示，64 × 64。
- `cards/gold.png`：金色六邊形，32 × 32，用於卡片價格與金幣餘額。
- `interface/play.png`／`pause.png`：提前開始與暫停圖示。離線工具 `tools/assets/build_interface_icons.gd -- --pause-only` 只重建暫停 PNG。
- `troops/soldier.png`／`quickfeet.png`／`heavy.png`：兵種圖示；兵種 `.tres` 的 Icon 可替換為自己的 PNG，波次編輯器選單與時間軸會使用它。

可以直接用繪圖軟體修改這些 PNG，或將新 PNG 放進上述資料夾，再拖入對應 Inspector 欄位。圖片必須匯入 Godot；重新儲存同路徑圖片後會自動重新匯入。

## 指定素材

1. **某一種塔的圖示與色彩**：選取 `assets/data/towers/sentry.tres`（或新塔的 TowerDefinition），設定 Icon 與 Accent Color。所有使用該塔的卡片共用這兩個欄位。
2. **某張卡的卡面變種**：選取固定手牌的 BuildCard 資源，在 Card Artwork 設定 Background Texture／Frame Texture。留空沿用場景預設；不在卡片上另外維護色彩或塔圖示。
3. **所有卡片的預設素材**：選取 card_view.tscn 根節點，在 Default Artwork 設定 Default Background／Default Frame／Default Icon。Default Icon 只在塔尚未設定圖示時使用。
4. **金幣與卡背**：選取 `scenes/cards/card_shop_view.tscn` 根節點，在 Artwork 設定 Coin Texture／Card Back Texture。金幣會同步套用餘額與所有價格，卡背會同步套用五張牌；編輯器預覽也會立即更新。也可以直接覆寫 `cards/gold.png` 與 `cards/card_back.png`。

TowerIcon 以 alpha mask 顯示：透明處不繪製，不透明處使用 `accent_color.darkened(0.45)`；灰階／RGB 顏色不影響圖示的染色。請保留透明背景，不要畫成不透明的白底矩形。可在 card_view.tscn 根節點調整 Icon Darkening（預設 0.45）。卡框仍採一般灰階乘色，底紙與金幣／卡背維持原圖顏色。

Background 使用 NinePatchRect，保留中間圖面；Accent／Selection 使用 NinePatchRect，只畫外圍卡框。預設切片邊界四邊各 16 像素，卡框裝飾應放在外側 16 像素內。若製作其他尺寸的素材，請同時調整這些節點的 Patch Margin。畫滿整張卡的插畫可放 Background Texture，不要放只畫邊框的 Frame Texture。

Content 裡的 Header、TowerIcon、TileDiagram 可在編輯器調整尺寸與容器配置。根節點 Presentation 選 HAND 時，Header 左側為快捷數字、右側為靠右的卡名；中文前綴與塔名同一行，分別為 16 px Medium／Light；英文前綴在上方（12 px Medium）、塔名在下方（16 px Light），兩行靠右。選 SHOP 時，左側只顯示塔名、右側為價格。卡名的兩個 Label 位於 `scenes/cards/components/card_title.tscn`，佈局由 `card_title.gd` 更新。顯示內容由程式更新，因此請保留根節點下的 Background／Accent／Selection，以及帶有 unique name 的節點名稱。只有 TileDiagram 使用 `_draw()`；可在其 Inspector 調整地塊顏色、大小與間距。

TilePreset 的 Prefix Key 與塔的 Name Key 分別使用 `tile_preset.corner`、`tower.sentry.name` 等穩定識別碼。在 `assets/translations/card_names.csv` 新增中英文翻譯；`card.name_format` 決定完整名稱的順序與間距。商店不顯示前綴，切換 Godot 語言會同步刷新兩種卡面。

商店牌背可在 `scenes/cards/components/card_back.tscn` 調整 Artwork／Icon；展開與收回時，Icon 會切換商店／重刷圖片。卡背預設 144 × 208，Artwork 的 NinePatch 四邊切片各 12 px；金幣建議正方形透明 PNG，預設 32 × 32，保留長寬比縮放至價格 14 px／餘額 30 px。共用價格列在 `card_price.tscn`，放於商品 Header，以及重刷卡背內的上方中央（數字白色）；卡位在 `shop_slot.tscn`，整體介面與餘額在 `card_shop_view.tscn`，實際使用圖片由商店根節點的 Artwork 統一設定。`tools/assets/build_shop_art.gd` 是可選的離線重建工具，不會在遊戲中執行；手動執行會覆寫所選預設素材，加上 `-- gold` 可只重建金幣圖示。

- `effects/slowness.png`：透明底減速圖示；可自行替換 PNG，或修改 SlowEffect 的 icon。離線重建工具為 `tools/assets/build_effect_icons.gd`，手動執行會覆寫圖示。

卡片以 0.82 倍搭配小角度旋轉呈現；預設框線／底紙裝飾線至少 2 px，避免縮成不足一個像素。快捷鍵、價格與中文卡名為 16 px；英文卡名前綴 12 px、塔名 16 px。前綴與時間線目前 ACT 使用 `assets/fonts/NotoSansTC-Medium.ttf`（weight 500），塔名與一般介面使用 `NotoSansTC-Light.ttf`（weight 300）。分隔線保留 3 px 高度並以 ui_soft_edges.gdshader 柔化旋轉邊緣。新增素材時避免恢復 1 px 裝飾線。

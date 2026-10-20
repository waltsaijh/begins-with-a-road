# 地塊預設與塔的候選清單

每個地塊 `.tres` 是獨立的 `TilePreset`。每種塔另有自己的候選清單及權重；新增地塊檔案後，必須將它加入目標塔的候選清單才會抽到。

在 Godot 開啟 `assets/data/towers/sentry.tres`（或其他塔資源），展開 **Tile Presets → Tile Preset Candidates**。每個項目選擇 New TilePresetCandidate，設定：

- **Preset Path**：選取 `assets/data/tile_presets/*.tres`。
- **Weight**：相對權重。例如 Corner = 1、Bridge = 3，兩者機率為 25%、75%；0 表示不參與抽取。

不同塔可以引用相同地塊檔並設定不同權重。Sentry 初始包含 Corner、Bridge、Flank、Blasting，權重皆為 1。無效權重、空項目、找不到的檔案會跳過；若某塔沒有可用候選，它不參與隨機抽牌。所有塔都沒有可用候選時，不會扣款 reroll。

地塊檔案在 Inspector 可編輯：

- **Prefix Key**：翻譯 key，例如 `tile_preset.corner`；顯示文字放在 `assets/translations/card_names.csv`。留空表示沒有前綴。
- **Road Offsets**：相對塔中心的 `Vector2i` 陣列，第一個數字是地圖 X，第二個是地圖 Z。`(0, -1)` 在上方、`(-1, 0)` 在左側。塔的完整 footprint 底座會自動補齊；與塔重複的格子仍屬於塔。

| 預設 | 額外道路配置 |
| --- | --- |
| Corner | 塔上方與左側各一格 |
| Bridge | 塔上方橫排三格 |
| Flank | 塔左側三格，加下方一格 |
| Blasting | 塔周圍四個對角位置 |

這些名稱都是人工命名，沒有依地形評分或自動分類。新增時可複製現有檔案，或用 New Resource → TilePreset，存進本資料夾，再加入需要它的塔。修改後儲存並重新執行遊戲；刪除檔案後，仍指向它的候選會被跳過，亦可清除塔中的該項候選。

商店與初始手牌先從塔種 Catalog 抽塔，再依該塔的候選權重抽地塊。新卡可以重複配置；reroll 不改變已入手卡片的配對。固定 BuildCard 資源仍可明確指定塔與地塊，候選清單只決定隨機抽牌。售價來自塔資源的 Card Price。

塔種 Catalog 設定在 `scenes/cards/card_shop.tscn`。初始手牌張數設定在 `scenes/cards/card_placement.tscn` 的 Initial Card Count，預設三張；Cards 留空時隨機生成，亦可填入固定 BuildCard 資源。

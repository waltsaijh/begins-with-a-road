# 臨時交通設施

三份 TrafficStructureDefinition 可直接在 Inspector 調整；初始數值不是最終平衡。

| 資源 | 放置 | required_tags | 倍率 | 波數 | 價格 |
| --- | --- | --- | --- | --- | --- |
| flag.tres | 道路旁空格；四向相鄰影響 | ground | 1.5 | 3 | 3 |
| barricade.tres | 既有道路覆蓋 | small＋ground | 0.5 | 3 | 3 |
| narrow_passage.tres | 既有道路覆蓋 | large＋ground | 0.5 | 3 | 3 |

影響範圍使用 anchor 相對格子 influence_offsets，隨卡牌順時針旋轉。required_tags 必須全符合，excluded_tags 中任一標籤符合即排除；每座設施對整條候選最多作用一次，跨實例乘法疊加。設施不改威脅、道路或兵種數值。預設 occupancy_group=traffic、compatible_groups 空白，因此同格互斥；允許共存時必須雙方明列對方群組。

模型在 assets/models/traffic，圖示為 assets/sprites/traffic 的 SVG，皆為本專案自足、可編輯幾何。名稱與效果說明使用 card_names.csv 翻譯。新增設施後加入 scenes/cards/card_shop.tscn 的 Traffic Catalog，不加入塔 Catalog。BuildCard.from_traffic 保存抽出時價格；實例保存放置時效果與波數快照。

搜尋池及 Score Threshold 不改變；被排除的路線不能被倍率召回。沒有實際配額差時玩家預覽明示無變化，詳見 docs/systems.md。驗收入口為 tests/traffic/playground.tscn。

旗幟模型附一格石地及支柱（flag_ground.tscn），預覽一併顯示，並隨旗幟移除。這格是支撐基座，不會新增可通行道路。Phase 4 起拒馬以 required_tags=[small, ground] 限定小型地面單位；窄口要求 [large, ground]。standard 不受這兩者影響，armored 本身不代表大型，flying 不受地面設施誘導。

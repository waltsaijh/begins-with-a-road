# 地塊變種與原型美術整合

2026-10-16；Godot 4.7.2 Compatibility。

## 結構

- tile_constants.gd：原始連接類型與外觀 ID 的對應，原本 ID 0～6 保留。
- map/tile/appearance/tile_appearance_constants.gd：全域 TileAppearanceConstants，集中 seed、半徑、木橋比例／間距與動畫預設；直接讀取 const，不需 preload 或設定 Resource。
- tile_appearance_layout.gd：純資料選點，先配置必定存在的起終點柱，再依序找半徑外最近入口；木橋在非入口直線格抽選，間距嚴格大於 2。
- tile_appearance.gd：讀取現有入口圖、合併同幀刷新、只修改有差異的 GridMap 外觀，不觸發導航更新。
- tools/assets/build_tile_variants.gd：產生木橋／折面柱身的模型場景；tools/assets/build_tile_library.gd 按材質合併後烘焙為 14 項模型庫。

放置、參數、成本、路線與實際敵人移動仍使用原格子。顯示由獨立 GridMap 與少量動畫暫時模型處理，見 tile_animation.md；沒有新增導航格子。木橋外觀不自動更改 terrain_id 或 movement_multiplier。更新配置先保留合法舊橋／舊柱，再補選缺額。

## 造型來源

木橋沿用 card-tower-defense 的 bridge_detail 尺寸：六塊 0.63 格寬木板，兩側扶手、四根立柱及承重梁，暖色木板與深色扶手。14 個零件烘焙為 3 個材質 surfaces。

柱子以原型 terrain_mass 的層狀折面為參考，使用倒角截面與不規則石層；原地塊頂面保持，底部延伸至 Y=-4。pillar_fade 延用原型 cliff_fade 的不透明顏色漸變，底部融入雲海。石色、道路與光照使用原型正式 diorama 的暖砂色／冷石色搭配。

雲海使用三層平面形成 Y=-2～-4 的厚度：底雲 Y=-4，中層 Y=-3、上層 Y=-2，兩層最大透明度 0.55／0.72。不同雲形尺度與流速產生視差；柱底只在 -2～-4 間融入雲海。三層共用 plane mesh，以及載入時一次生成的 256×256 無縫噪聲貼圖；每個 fragment 一次貼圖取樣，取代原有即時計算的 hash／多頻噪聲。透明雲不寫深度，仍正常測深，先於除錯圖層繪製。不使用體積霧、屏幕深度貼圖或逐格粒子，平面數仍為 3（共 6 個三角形），未量測 FPS 提升。

## 驗證

tests/maps/tile_variants.gd 通過：半徑邊界、最近入口、固定 seed、木橋數量／間距、三張地圖的起終點支撐、柱底高度、外觀切換前後的道路 ports 完全相同、規劃器未失效、木橋變岔口自動恢復、死路維持略過導航更新、雲海與兩層薄霧高度及共用幾何。

| 場景 | 柱子 | 木橋實際／目標 |
| --- | ---: | ---: |
| main | 2 | 1／1 |
| 9x9 | 30 | 21／21 |
| 11x11big | 6 | 6／9 |

11x11big 的非入口直線格與間距限制使實際木橋少於目標；配置使用隨機貪心，不保證最大可放數量。保留條件，不為湊數放在入口或寬區。

Windows 的 tile_placement、dead_end_edits、debug_overlay、towers、enemies 回歸均已通過。三張場景已以實際 OpenGL Compatibility 渲染並人工檢視預覽；9x9 預覽使用較遠的鏡頭以涵蓋全圖，遊戲場景的鏡頭設定保留。

Web release 主場景已在 Edge 的 WebGL2／SwiftShader 載入，主雲面、兩層薄霧、柱底漸變與木橋可正常顯示，F1／F2／F3 切換後沒有 script、shader 或 browser console error。Web 未執行 9x9／11x11big 的完整功能回歸，也未量測 GPU 效能；Windows 的其他場景驗證不視為 Web 測試。

預覽：tile_variants_main.png、tile_variants_9x9.png、tile_variants_11x11big.png、tile_variants_web_main.png。Web 檢查結果獨立記錄於 tile_variants_web.json。

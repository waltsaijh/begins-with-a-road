# 遊戲系統與實作說明

本文件保留系統責任、演算法與功能細節；開發共識見 [AGENTS.md](../AGENTS.md)，專案結構見 [architectures.md](architectures.md)，遊戲體驗見 [首頁](../README.md)。正式關卡與獨立試驗場景的行為分開描述；下文的 64 隻自動生怪及單塔工具屬於獨立試驗流程。兵種與塔的即時數值以 `assets/data/` 為準，歷史摘要放在 `reports/`，當次測試 JSON／截圖放在 `.godot/test-results/`，不能將舊摘要視為目前通過證據。

目前共用一張保留雙向道路與環的入口圖。所有兵種統一使用有限候選池：先以正成本探索，再依原始 evaluation 加總與 threshold 篩選。所有兵種在出生前決定完整行程，三者皆可對 threshold 內候選選擇 Uniform 等機率或 Softmax(-score / route_temperature) 加權機率；soldier 預設 Uniform，其餘預設 Softmax。每波以波內序號／總數對應累積機率區間分配，固定配額後打亂出發順序。場景自動生成一波 64 隻敵人，到終點後刪除；兵種與 Uniform／Softmax 由波次 Resource 設定，關卡起點上方的對話框手動開始下一波。沒有全域 DAG、ZDD 或 Yen。

腳本責任如下；場景仍使用原本的 TilePlacement／PortalMap／PortalOverlay 節點名稱。

| 腳本 | 責任 |
|---|---|
| `camera/map_camera.gd` | 平移、縮放與鏡頭定位 |
| `map/tile/tile_constants.gd` | `TileConstants`：地塊模型 ID 與四向接口常數 |
| `map/tile/appearance/tile_appearance_constants.gd` | `TileAppearanceConstants`：柱距、木橋配置與地塊動畫預設值 |
| `map/tile/tile_placement.gd` | 卡牌地塊批次變更、鄰格模型刷新與座標拾取 |
| `map/tile/tile_parameters.gd` | 每格資料與變更通知 |
| `map/tile/tile_parameter_store.gd` | 依座標保留每格資料、每兵種成本陣列快取 |
| `navigation/road_graph_snapshot.gd` | GridMap → C++ 用的整數座標／接口陣列 |
| `navigation/portal_map.gd` | 重建、評分失效、原生／候選池規劃與抽樣 API |
| `navigation/routes/candidate_routes.gd` | 共用有限代表路線池、原始 signed 評分與 threshold 篩選 |
| 原生候選核心 | 批次展開、完整逐格去環、路長／節點／分段重建、去重評分與機率表 |
| `navigation/visualization/region_paths.gd` | 從距離表還原供預覽的同成本方向 |
| `navigation/visualization/portal_overlay.gd` | F1 兵種路徑與 vertex／F2 威脅、地塊參數查看與切換列 |
| `enemies/enemy.gd` | 沿出生時固定的逐格行程移動，抵達後刪除 |
| `enemies/spawning/enemy_wave.gd` | 每波 64 隻、每次 1 隻、間隔、重播與人數 |
| `enemies/rendering/enemy_visual_separation.gd` | 依 tile 分群、固定取樣上限的 O(N) 左右視覺分離 |
| `enemies/rendering/enemy_multimesh.gd` | 共用 mesh／走路 shader、密集 instance slot 與批次顯示 |
| `enemies/enemy_constants.gd` | 全域 `EnemyConstants`：波次、移動與候選搜尋預設值 |
| `enemies/rendering/enemy_render_constants.gd` | 全域 `EnemyRenderConstants`：步態、轉向與視覺分離常數 |
| `enemies/rendering/enemy_pose.gd` | 每隻敵人的顯示朝向、步態與動畫進度，不回寫邏輯狀態 |
| `enemies/presentation/enemy_wave_controls.gd` | 開始波次意圖與可用狀態，不負責尋路或生成 |
| `towers/tower_constants.gd` | 全域 `TowerConstants`：防禦塔共用預設值 |
| `towers/tower_definition.gd` | `TowerDefinition`：塔種名稱、模型、佔格、範圍與威脅 |
| `towers/tower.gd` | `DefenseTower`：共用實例基底、位置／佔格與可變影響資料 |
| `towers/tower_map.gd` | 右鍵放置／移除、佔格驗證、路網與局部影響更新 |
| `cards/definitions/build_card.gd` | `BuildCard` Resource：塔與 TilePreset 的配對、價格、卡面資料與旋轉配置 |
| `cards/definitions/tile_preset.gd` | 獨立的名稱前綴與道路偏移 Resource |
| `cards/definitions/tile_preset_candidate.gd` | 每種塔的地塊候選檔案與相對權重 |
| `cards/card_placement.gd` | 手牌庫存、選卡、旋轉、預覽失效與成功放置後消耗 |
| `cards/presentation/card_view.gd` | 編輯器可預覽的場景 UI、卡面材質與塔圖示染色 |
| `cards/presentation/card_tile_diagram.gd` | 依配置複用可編輯的地塊格子場景 |
| `cards/presentation/card_hand.gd` | 保留既有卡面的手牌排列、疊牌與從底部插牌動畫 |
| `cards/presentation/card_fan_layout.gd` | 手牌／商店共用的連續鏡像弧線、間距、hover 提起與座標命中 |
| `cards/presentation/card_button.gd` | 提起時保留原牌下緣的點擊範圍，供正面與牌背共用 |
| `cards/presentation/card_preview.gd` | 單一 footprint mesh 與共用塔模型預覽 |
| `cards/shop/card_shop.gd` | 波次獎勵、商店庫存、購買與重刷交易 |
| `cards/shop/shop_constants.gd` | 全域 `ShopConstants`：經濟、排版與動畫預設 |
| `cards/presentation/card_shop_view.gd` | 商店價格、售後向右靠攏、重刷插牌、展開／收回與翻面動畫 |
| `enemies/troops/troop.gd` | 兵種數值、加權 evaluation、尋路、模型與圖示設定 |
| `enemies/troops/troop_catalog.gd` | 自動發現新增／刪除的 .tres，供地圖、波次及編輯器共用 |

實際搜尋演算法與路線池資料留在 `native/src/`；GDScript 負責資料、輸入、協調與顯示。

`TileConstants` 使用 `class_name` 註冊為全域型別，放置與快照腳本直接讀取 `TileConstants.DIRECTIONS`／`BASE_MASKS`，不用各自 preload，亦不需要 Autoload Node。四向位元順序與模型遮罩是 MeshLibrary 的固定契約，不是用來調整難度的參數。Godot 的 [具名類別](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html#registering-named-classes) 可直接跨腳本使用。

所有共用常數類統一使用 `class_name XxxConstants`、`extends RefCounted` 與大寫 `const`：`TileConstants` 管理地塊契約，`TileAppearanceConstants` 管理地塊外觀／動畫預設，`EnemyConstants` 管理敵人邏輯預設，`EnemyRenderConstants` 管理敵人顯示預設，`TowerConstants` 管理塔的預設。任何 script 都能直接使用，不需 preload、建立 instance、Resource 資源或 Autoload。

兵種設定存成 `assets/data/troops/*.tres`，不需為每個兵種建立 GDScript 類別。`Troop` 繼承 Resource，保留變更通知與評分快取失效機制；`TroopCatalog` 以檔案路徑保留共用設定。每隻敵人的目前血量、位置與行程獨立保存。一般共用常數修改後重新執行生效；已有場景覆寫的 `@export` 值優先於共用預設。

## Tile 規格

MeshLibrary ID：石地 0、直路 1、轉角 2、獨立道路地塊 3、道路端頭 4、T 字路口 5、十字路口 6。所有模型共用 1 × 1 格尺寸、0.10 石面厚度、0.27 石底厚度及約 2/3 格道路寬度。石面位於 Y = 0；道路中心 Y = 0.01，轉角保留手動調整後的接合位置。直路預設沿 Z 軸；轉角預設連接 -Z 與 +X，其他方向使用 90 度旋轉。

示範地圖參考原型 `MapDefinition.frontier()` 的主幹：24 格長、單格寬的筆直橋面，不含側枝。橋中央位於世界原點。道路兩端延伸至地圖外緣，不需要額外端點模型。GridMap 使用 `cell_size = (1, 1, 1)`、`cell_center_y = false`；局部格心為 `(x + 0.5, 0, z + 0.5)`。

模型簡化自 `card-tower-defense/art/environment/skybridge_environment.gd` 的 `stone_tile`、`road_module`。沿用原型的幾何比例、暖灰石面與藍灰底座；道路統一使用較深的砂色，讓無裝飾的地圖也能辨識路徑。所有 tile 使用相同材質，不包含隨機色差或邊界變體。另依原型加入紅旗火炬起始點與藍旗水晶終點，位於首尾格中心並朝向橋面，起終點模型與敵人／戰鬥邏輯分開。

### 外觀變種與雲海

連接類型與外觀分開：`TileConstants.base_item()` 取得原有 0～6 的連接類型，`item_for()` 套用 STONE／PILLAR／WOOD 外觀。MeshLibrary 保留原本 ID，新增 7～12 為六種道路的柱子版、13 為直線木橋；所有變種沿用原接口與旋轉。外觀不修改 TileParameters、兵種成本或原生導航。

`scripts/map/tile/appearance/` 中，`tile_appearance_constants.gd` 是全域常數類、layout 是不依賴場景的純選點演算法、tile_appearance 讀取入口圖並只更新有差異的 GridMap 格、tile_visuals 管理顯示與浮起動畫。三張遊戲場景均包含 TileAppearance／TileVisuals。直接調整 `TileAppearanceConstants.SEED_VALUE`、`PILLAR_RADIUS`、`TILES_PER_WOOD_BRIDGE`、`WOOD_SPACING` 後重新執行即可使用；不再透過設定 Resource 載入。

新增地塊時，先保留仍在入口、仍符合距離限制的既有柱子，以及仍為非入口直線格、仍符合間距的木橋；只移除失效位置並補足木橋缺額。新入口不會因為距離更近而排擠合法舊柱，新候選也不會讓合法舊橋重新抽籤。外觀配置因此與修改順序有關；相同修改順序與 seed 仍可重現。

地圖資料立即提交，TileVisuals 使用獨立、無碰撞的顯示 GridMap，原 TileMap 隱藏但仍提供資料與接口。第一次載入直接顯示最終地圖；之後只有新增地塊或外觀變種改變的格子參與動畫；純接口變更直接更新接合模型。舊顯示立即移除，新地塊與木橋從設定深度浮起，目前共用預設為 Y=-0.75、0.5 秒定位。柱子新增／移除時固定石質頂面，只讓柱身向下伸出／收回；柱子換木橋時，橋面浮起、原柱身收回。快速連續修改會以最新模型替換暫時模型並保留浮起進度，未改變的模型不重新播放。完成後回到 GridMap 的靜態合批，動畫管理器停止逐幀處理。可調整 `TileAppearanceConstants.ANIMATE`／`ANIMATION_DURATION`／`RISE_DEPTH`，也可在 TileVisuals Inspector 覆寫 animate／duration／rise_depth。每次修改仍掃描格子比對差異，只有差異格寫入顯示層；沒有每幀重建地圖或延後尋路資料。回歸入口為 `tests/maps/tile_animation.tscn`。

所有起終點必定設柱。首次以第一個起點開始，從已建好的入口節點中選出 3 格半徑外最近的一個，並要求與任何已選柱子距離都大於 3，再以新柱為中心繼續；更新時保留合法舊柱後再選取。距離採格心 XZ 平面的歐氏距離，等距以座標決定順序，終點與額外起點也參與排除距離。直路中央沒有入口就不額外插入柱子。柱子保留原道路頂面，沿用原型 terrain_mass 的分層折面語彙：倒角截面、略有起伏的石層，延伸至 Y=-4，並以不透明材質的顏色漸變融入雲海，不使用透明石柱。模型來源為 variants/pillar_support.tscn。

木橋在不含入口／柱子的直線道路格中，保留合法舊橋後以固定 seed 洗牌補選，數量目標是 floor(道路格數/16)，任兩木橋格心距離必須大於 2。位置不足時保留實際可放數量，不放寬條件；屬隨機貪心配置，不保證達到所有可能擺法的最大數量。模型沿用原型 bridge_detail 的六塊交錯木色窄橋面、兩側扶手與立柱，再加橋面下的承重梁；預設沿 Z 軸。新增道路改成岔口時，原木橋會自動恢復成合適的石路。新增死路也會更新外觀，但不因此要求重建入口圖或路線池。烘焙器把純色寫入頂點並共用 solid_color.tres；一般石路／木橋各為 1 個 surface，帶柱道路為純色頂面與特殊柱底共 2 個 surfaces。

`CloudLayer` 在 Y=-4 放置不透明底雲，Y=-3／-2 放置兩張半透明雲面，以不同雲形大小、密度、流速產生厚度與視差，流速為初版的 1.5 倍；兩層的最大透明度分別為 0.55／0.72。深度測試與 render_priority 讓雲不蓋過地面及除錯線。三層共用平面幾何及一張 256×256 無縫噪聲貼圖，貼圖在載入時生成一次；每個雲／柱底 fragment 僅取樣一次，不逐像素執行噪聲 hash 或多層 FBM。柱身的霧化範圍也改為 Y=-2～-4。沒有逐格雲物件、逐幀建圖或光線步進。雲面根據道路範圍加 padding 建立，新增格只有擴大邊界時才改尺寸。可隱藏 CloudLayer 整體停用雲海。depth 是底層深度，兩層雲面固定比底層高 1／2 格；若調整 depth，柱子材質 pillar_stone.tres 的 cloud_height／cloud_top 也應配合修改。

雲海與柱底漸變是 Compatibility／Web 的空間近似，不是體積霧；三層平面會增加滿版像素繪製成本。Compatibility 不支援 FogVolume，這裡不需要 Forward+ 或深度貼圖。見 [Godot 渲染器支援表](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)。

製作來源：先執行 tools/assets/build_tile_variants.gd 產生木橋／柱子的可編輯場景，再執行 tools/assets/build_tile_library.gd 更新共用模型庫；若直接在 Godot 編輯生成場景，只執行後者即可保留手動修改。造型與霧參考 card-tower-defense/art/environment/skybridge_environment.gd、art/sandbox/terrain_mass.gd、cliff_fade.gdshader、cloud_noise.gdshaderinc 與 art/diorama/production_profile.gd；執行時無跨專案依賴。

tests/maps/tile_variants.gd 包含配置、接口不變、起終點、模型高度、動態刷新與雲海高度驗證。

## 操作

- 點卡片或 1～9：選擇對應手牌；再次選同卡取消。也可按住手牌拖到地圖後放開放置，拖曳過程沿用位置 hologram 與旋轉提示。
- 選卡時左鍵：一次放下塔、底座地塊與周圍道路，成功後消耗一張；R 或右鍵順時針旋轉，Esc 取消。在同一格的 hologram 停留 0.5 秒後，塔上方會浮出 R 鍵與順時針箭頭提示；換格、移入 UI 或取消選卡時隱藏。
- 波次結束後點右下商店牌組：展開四張商品與最左側重刷牌；點商品購買加入手牌，點外側或 Esc 收回。
- 地塊由建造卡加入，未選卡時點擊空格不會放置道路，也不顯示單格預覽。
- 未選卡時右鍵：在道路放置／移除防禦塔。
- 左鍵從卡牌以外的位置拖曳：以滑鼠相對目前 focus 投影（畫面中心）的前後向量計算有號角差，跨越 ±π 仍累積最短角差；未超過轉速上限時，順時針／逆時針一圈對應地圖同向一整圈，不受圓半徑、解析度或縮放影響。只改 azimuth，不改仰角、距離、縮放及地形。地面、柱側、天空及其他 UI 都可起拖，不再掃描 GridMap 模型判斷天空。Camera3D 的 `orbit_drag_threshold` 預設 4px，超過才啟動旋轉；`orbit_dead_zone` 預設 16px，前後任一向量落入中心範圍時不計角差。CardButton 透過 `camera_drag_blockers` 群組提供含 hover 下緣與旋轉／縮放的實際命中區，涵蓋手牌、商品、牌背與重刷牌，包含停用牌；只在按下時檢查。相機在 GUI 前暫存非卡牌左鍵按下，拖曳時攔截，若放開前未超過門檻則在 deferred 階段依原位置／修飾鍵遞送按下與放開，保留原 GUI → gameplay 的點擊流程，避免放塔／選入口／按鈕在起拖時先提交。實際旋轉在 Camera3D 的 `_process` 以單調時鐘的真實秒數推進，每幀轉角限制為 `maximum_orbit_speed × real_delta`，目前預設 360°/s，不受 1x／2x／4x 或零 time_scale 影響。同幀滑鼠角差累加後除以真實 delta，得到目標角速度並夾在 ±`maximum_orbit_speed`，每幀取用後清零；沒有未完成角度或多圈佇列。只對目前角速度做 `lerp(current, target, 1-exp(-response × real_delta))`，`response = log(100) / orbit_smoothing_seconds`；預設 0.15 秒消除 99% 速度差。加速、減速、反向與放開皆用同一條響應：滑鼠停止移動或放開後目標角速度為 0，速度低於 0.01°/s 時歸零，不再使用獨立緩停動畫。角度位移採此速度響應的精確積分 `target × delta + (previous-target) × follow / response`，使持續相同輸入時的過渡不依賴幀率；釋放時沒有新的旋轉目標，尾段轉角約為當前角速度 / response，與先前畫幾圈無關。未超過轉速上限的圈數在速度收斂後維持角度比例，超過上限的輸入不補轉。新非卡牌左鍵手勢、離開視窗、失焦或切換中鍵立即重設輸入與速度，中鍵優先平移。旋轉開始後跨過卡牌或 UI 仍持續。暫停時相機保持運作，但原點擊仍經 HUD 的遊戲輸入鎖定，不推進時間。
- 滾輪縮放，中鍵拖曳平移。中鍵按下、帶中鍵的滑鼠移動及放開都在相機 `_input` 階段先處理，避免 GUI 吞掉 `_unhandled_input`，可跨過手牌、商店卡牌／價格或其他 UI 持續平移，也可直接從卡牌上按中鍵起拖；不觸發購買／重刷等動作，放開即停止平移。最遠縮小為初始鏡頭的 0.6x（Camera3D 的 `minimum_zoom_scale`），放大仍沿用 `minimum_size`。拖曳直接將鏡頭 focus 的 X／Z 夾在初始中心 ±`pan_range` 內（預設 ±24，形成 48×48 的正方形）；不檢查畫面四角、雲層幾何或視窗比例，縮放不會推移中心或改變拖曳邊界。暫停時同樣適用。
- F1：切換本波每個兵種的完整路徑與目前路網的 vertex 圓點／V 編號；soldier 青色、quickfeet 金色、heavy 紫色，共用路段並排顯示。
- F2：切換 threat 熱圖；指向地塊查看參數，越紅代表威脅越高。
- R／起點按鈕：多起點場景切換目前查看與下一波使用的起點。

兩個圖層可獨立切換，預設全部關閉；開啟任一圖層後才顯示除錯切換列與說明。一般遊戲保留卡牌文字、價格與金幣數字，不顯示滑鼠懸停 tooltip、手牌操作提示、張數與常駐波次統計。兵種與分配方式由波次資源設定，起點上方的對話框手動開始下一波。

## 建造卡

三張地圖均包含 `scenes/cards/card_placement.tscn`。初始三張卡先抽塔種，再依該塔的候選權重抽地塊配置；Sentry 目前包含 Corner、Bridge、Flank、Blasting。放置成功消耗、失敗保留；波次結束可由商店補充。卡面使用 `scenes/cards/components/card_view.tscn`，可在 Godot 2D 編輯器調整。底紙與灰階卡框使用 NinePatchRect，獨立塔圖示使用 TextureRect，文字使用 Label；地塊配置示意使用共用場景範本。塔的 `icon`／`accent_color` 統一提供圖示與染色，同種塔的卡片因此共用同一色彩。

每張 `BuildCard` 引用獨立的 `TowerDefinition` 與 `TilePreset`；後者的 `road_offsets` 為相對塔中心的 Vector2i 陣列，塔完整 footprint 的底座也會自動補齊。卡片與塔都以同一個 `TowerDefinition.cells_at()` 計算旋轉後佔格。道路可合併既有道路，保留既有地塊參數／合法外觀；不能覆蓋塔、石地或任何起終點。預覽以綠／紅顯示整組範圍與塔模型，滑鼠在 UI 上時隱藏。

Corner、Bridge、Flank 是人工命名的預設，分別為塔上方＋左側兩格、上方橫排三格、左側三格＋下方一格，沒有地形評分。新增／編輯／刪除方法見 `assets/data/tile_presets/README.md`；`tests/cards/tile_presets.tscn` 驗證塔專屬候選與相對權重、存檔與刪除、preset 變更通知、初始手牌及空清單的重抽處理。

`TowerMap.validate_card(card, cell, turns)` 只讀候選快照：同時加入整組地塊、排除塔 footprint，再以一次 BFS 確認所有起點仍能到達終點。它不修改真實 GridMap，也不建立候選路線池。`place_card()` 點擊時重新驗證，另外保護待生成／存活敵人已固定的剩餘行程；綠色預覽不是提交許可。成功才加入全部地塊、刷新受影響接口、登記塔與威脅資料，觸發一次入口圖重建，再發送新增地塊通知。失敗不產生地塊、塔、威脅或路網 revision 的部分變更。跨橋卡因此可同時新增繞路與堵住原路的塔，不會誤用修改前的道路判斷封路。

手牌由 CardHand 在 GUI 前捕捉左鍵按下與放開，移動超過 `drag_threshold`（預設 8px）才發出拖曳開始訊號並選中卡牌；未達門檻且在同張牌上放開則發出原本的選取訊號，避免 Button.pressed 重複觸發。手牌凍結捕捉中的 hover 排列，但滑鼠移動仍交給 GUI，讓 world hologram 能依目前 UI hover 正確顯示／隱藏。拖同一張已選牌保留旋轉，R／右鍵仍可轉向。放開時先清除捕捉，再由 CardPlacement 檢查目前階段、卡片索引、viewport 範圍及 GUI hover，呼叫既有 `place_selected` 重新驗證並提交；成功才消耗一張。放在任意可見卡牌上（自己、其他手牌、商品或牌背，包含停用牌）會取消選牌與預覽，不消耗卡片，也不觸發落點卡牌；以 CardButton.has_card_at 共用鏡頭的可見卡牌命中邏輯，包含縮放、旋轉與上提延伸，優先於一般 GUI hover 判斷。放在無效地塊或其他 UI 上則不消耗卡片並保留選取，仍不觸發落點按鈕。取消選牌／Esc、暫停、開波、商店或 ACT 鎖定、離開 viewport 與視窗失焦會取消拖曳；保留吞掉該次放開事件的狀態，避免取消後放開誤放。卡牌起拖不交給鏡頭旋轉，商店商品與牌背仍維持點按購買／展開／重刷。

卡片與舊單塔工具共用 TowerMap 的驗證／提交流程；批次地塊由 `TilePlacement.add_cells()` 去重後一次刷新所有相鄰接口。地塊服務不處理滑鼠輸入，也不建立單格預覽；選卡時停用單塔工具的滑鼠輸入。預覽只在游標換格、旋轉或地圖失效時更新；被拒絕的預覽每 0.25 秒重試，敵人通過後可恢復，未選卡時停止逐幀處理。每次檢查成本為 O(地塊＋相鄰邊)，不枚舉路線。

新增地塊配置時，在 `assets/data/tile_presets/` 新增 TilePreset `.tres`，設定 Prefix Key 與 Road Offsets，再加入需要使用它的塔資源之 Tile Preset Candidates。每個候選有 Preset Path 與 Weight，各塔可引用同一地塊並設定不同權重；權重 0、失效檔案與空項目不參與抽取。新塔種則在 `assets/data/towers/` 建立 TowerDefinition，並加入 `scenes/cards/card_shop.tscn` 根節點的 Catalog；塔的 Card Price 決定新卡售價。商店與初始手牌先抽塔，再依該塔自己的候選清單及權重抽 preset。沒有可用候選的塔不參與抽牌。CardPlacement 的 Initial Card Count 預設三張；Cards 留空時隨機生成，填入 BuildCard 時保留固定初始手牌。舊的三張 sentry＋地塊組合資源已移除。資料、輸入、UI、預覽及世界提交各自獨立，不需複製管理腳本。`turns` 採 90 度順時針步數，原點為塔 anchor；API 的 `cell` 使用 GridMap 格座標。

命名分成兩個欄位：TowerDefinition 的 Name Key 指向塔名（例如 `tower.sentry.name`），TilePreset 的 Prefix Key 指向地塊前綴（例如 `tile_preset.corner`）；不要再儲存完整卡名。`BuildCard.localized_name()` 組合兩者，沒有前綴時只回傳塔名。商店標題列左側只顯示塔本名，右側靠右放金幣與實際售價；手牌左側顯示快捷數字，右側依語言排版：中文同一行，地塊前綴用 Medium、塔名用 Light，均為 16 px；英文分兩行靠右，上方前綴 12 px Medium，下方塔名 16 px Light。沒有前綴時不保留空白行。

`assets/translations/card_names.csv` 使用 Godot 內建翻譯，`keys` 欄使用點號分隔、小寫 snake_case 的穩定識別碼，`en`／`zh_TW` 欄放翻譯；加入新塔名或地塊前綴時新增一列即可。`card.name_format` 這一列決定組合順序與間距，因此完整純文字名稱為英文 `Corner Sentry`、繁體中文 `轉角哨塔`；卡面使用獨立前綴／塔名節點呈現對應字重與行數。Godot 匯入 CSV 後產生 `.translation`，已登錄於 Project Settings → Localization → Translations；預設依系統語言，缺少對應語言時回退 `zh_TW`。程式可呼叫 `TranslationServer.set_locale("en")` 或 `TranslationServer.set_locale("zh_TW")`，既有卡面會更新。`tests/cards/card_names.tscn` 驗證語言切換、獨立命名、標題列對齊與價格更新。

自製圖片：將 PNG 放入 `assets/sprites/cards/` 或 `assets/sprites/towers/`。塔種的 `assets/data/towers/*.tres` 設定 Icon／Accent Color；圖示以透明度作輪廓，統一染成較深的 accent（預設 darkened 0.45，可於卡面根節點 Icon Darkening 調整）。固定 BuildCard 資源可在 Card Artwork 指定底紙或卡框變種；隨機生成卡片沿用場景根節點 Default Artwork。預設卡面 144×208、圖示 64×64、NinePatch 四邊切片各 16 像素；卡框仍採灰階乘色，底紙保持原色。`scenes/cards/card_shop_view.tscn` 根節點 Artwork 可統一替換 Coin Texture 與 Card Back Texture（預設 gold.png／card_back.png），同步套用所有價格、餘額與五張卡背。編輯器預覽與變更會同步更新，沒有逐幀更新卡面。完整繪圖、切片及替換說明見 `assets/sprites/README.md`。

驗證入口為 `tests/cards/cards.tscn` 與 `tests/cards/card_preview.tscn`。

### 卡面資源編輯與熱更新

修改 TowerAttackArea.offsets 會經 TowerDefinition.changed 通知手牌及商店卡面。CardView 在編輯器合併延後更新，確認卡面、文字及價格子節點可用後才套用；節點重建完成時補上更新，離場實例忽略通知。已開啟場景若仍保存舊版根層 artwork，亦可正常更新，不需要為此修改 offsets 或重建資源；新場景仍使用 Visuals 作為選牌搖動的顯示層。`tests/editor/card_resource_refresh.gd` 在實際編輯器驗證新舊卡面、腳本熱更新、範圍資源變更、部分節點重建與離場通知。

### 回合商店

每波敵人全數抵達或被擊殺後，右下升起五張背面牌，最上方顯示商店圖示。點擊展開時，左下手牌疊起並暫停建造工具；商品標題列左側顯示塔名，右側靠右顯示金幣與價格，最左側背面牌用於重刷，其價格放在卡片內的上方並水平置中，數字固定白色。購買後商品與價格立即移除，其餘商品連同重刷牌向右靠攏，不留空洞；買入卡從畫面下方滑入疊起手牌的最上方。重刷保留重刷牌，圖示以二次 ease-in-out 在 0.5 秒內旋轉 360 度，四張新商品從畫面下方插入；旋轉期間不會重複扣款。金錢不足時，重刷牌與商品一樣淡灰且不可購買。點商店外的空白處或 Esc 收回，恢復手牌與建造。開始下一波時，商店自動收回並隱藏。每波只發一次獎勵，開關商店不會重抽商品。

手牌新增只建立一個卡面，消耗只移除對應卡面，既有卡面保持同一實例；快捷鍵與點擊索引隨順序更新。插牌預設 0.28 秒、商店靠攏 0.22 秒，位於 CardFanLayout。連續購買、快速收合或重新排版會從當前動畫位置接續，不把插入中的牌重新丟回畫面外；插入期間該手牌不接受點擊，商店靠攏／補牌時也短暫停用商品點擊。商店商品的固定索引與顯示序號分開，靠攏後仍購買正確商品。

商店直接顯示在遊戲畫面，不使用 Dimmer、全螢幕攔截區或標題面板。鏡頭平移／縮放可繼續操作；只有收回商店的那次地圖點擊會被消耗，避免誤放地塊。展開的手牌與商店共用 `CardFanLayout`：左側手牌從左向右逐漸降低，右側商店從右向左逐漸降低，形成朝螢幕外側抬高的鏡像弧度。卡牌上端的中心位於同一圓弧上，旋轉角度沿圓弧切線計算，讓相鄰上緣平順銜接；高度不再另設獨立落差。最大旋轉 4°、相鄰邊緣僅重疊 8 個原始像素（正常顯示約 7 px），卡片統一縮至原尺寸的 82%。原始卡面場景維持 144×208，方便編輯素材。

Hover 沿卡牌自身上方提起 6 原始 px（正常顯示約 5 px）；手牌選中上提 24 原始 px（約 20 px），選中優先於 hover，不相加。Hand 的 `selected_lift`／`selection_seconds` 控制選中高度與切換時間，預設 24px／0.22 實際秒；hover 使用 CardFanLayout 的 6px／0.14 秒。切換、移開或取消選中都從當前位置接續 Tween，上提與命中區的 `hover_lift` 同步過渡。選中卡面在可編輯的 Visuals 子節點以 ±0.6°、3.6 秒週期輕晃，選取振幅在 0.22 秒內淡入／淡出；CardView 的 Selection Motion 可調整幅度、週期與混合時長。只有正在選中或淡出中的卡面逐幀更新搖動，速度獨立於 1x／2x／4x；暫停依場景樹凍結。外層 Button 不跟著晃動，所以命中與拖曳穩定，且不與扇形布局的旋轉 Tween 競爭。所有卡牌維持原尺寸與順序，不放大或置頂。正面與牌背共用 CardButton，提起時保留原位置下緣的命中範圍；CardFanLayout.pick 也使用當前命中延伸，讓選中牌移開 hover 後仍可從原下緣操作。命中依旋轉／縮放後座標，只在實際滑鼠移動時重新挑選；動畫不會反覆觸發布局，折疊時清除上提與焦點。

預設初始金幣 0、每波獲得 10、每張卡 3、重刷 1。`ShopConstants` 管理共用預設；card_shop.tscn 可在 Inspector 覆寫金幣、波次獎勵、重刷價格與 seed，塔資源的 Card Price 決定每次抽出卡片的價格；已抽出的 BuildCard 保存當時價格。購買扣款並加入手牌，同一商品不能重複購買；重刷重新產生四張商品。塔種使用洗牌袋補足四個位置，地塊預設則為每張卡依所屬塔的候選權重獨立抽取，因此可能重複同種組合。商店有自己的 RNG，不影響敵人選路。

可編輯 UI 為 `scenes/cards/card_shop_view.tscn`（商店整體）與 `scenes/cards/components/` 下的 `shop_slot.tscn`（卡位）、`card_back.tscn`（背面與圖示）、`card_price.tscn`（共用金幣與價格列）。商品正面沿用同資料夾的 `card_view.tscn`，Presentation 選 HAND／SHOP 會切換標題列配置。價格跟著正面一起翻轉與移動，點擊價格也能購買。動畫使用 Tween，沒有逐幀重建卡面。`tests/cards/card_shop.tscn` 驗證插牌、靠攏後購買、卡面實例保留、金幣、重刷、輸入隔離、消耗、波次切換、弧形重疊與快速收合；Web 可用 `tools/web/verify_enemy_web.cjs --shop` 比對當次原生輸出。

### 除錯顯示的資料

F1 直接繪製本波敵人完整行程中的相鄰格連線，不再從單一兵種的入口節點／edge 聯集推斷。準備期用相同 index／total 配額預覽每個出生群組及入口，且不洗牌、不消耗出發順序的隨機數；開波後切換為已固定的行程，包含尚未出生、已抵達或被擊殺的敵人，直到下一波配方載入。預設 soldier 青色、quickfeet 金色、heavy 紫色；色彩由各兵種資源的 Debug Color 決定，圖例列出本波兵種。同種兵共用線段只畫一次，不同兵種整條路徑各平移一條窄色線，重疊道路仍可看到每個顏色。

F2 以固定的 threat 尺度加深紅色與不透明度，0 不覆蓋。游標資料包含 threat、num_towers_around、terrain_id、movement_multiplier、damage_per_second、cover。關閉 F2 就停止每幀的地塊查看。

F3 舊除錯流量圖層已移除；Routing Sandbox 的準備期玩家中心線見下節，無獨立模式切換。每個除錯圖層各用一個 mesh，資料修改時才重建；敵人移動或出生不重畫，開波後塔／成本變更也不會把既有行程換成新候選池。F2 關閉時不進行每幀地塊查看。

`tests/navigation/debug_overlay.tscn` 驗證混合兵種、預覽與實際行程一致、共用線段的多色顯示、多入口、未出生敵人、下一波更新及圖層切換；亦驗證 vertex 編號與格子位置、路網更新、F1 開關與不逐幀重建，共用橋檢查使用獨立合成地形。

### Routing Sandbox：下一波敵軍與道路流量

正式關卡的 `LevelHUD/WorldActions/EarlyStart/NextWaveIntel` 使用 `scenes/levels/components/next_wave_intel.tscn`，依 WaveSpawnSchedule 不洗牌排程中的 start_index 與 Troop Resource 加總各入口實際分配的數量；名稱／圖示取自資源，不列舉固定兵種。情報嵌入開始下一波按鈕內：按鈕寬 216px、標題下方顯示最多三列，超出採垂直捲動；兵種列仍支援 hover 篩選，點擊會轉送開波動作。單項範本 `troop_intel_item.tscn` 分開顯示圖示、可截短名稱與固定數量，並保留預設隱藏的 Info 節點供未來首次登場入口使用；目前沒有圖鑑行為。

每個入口都使用相同的開波命令，點擊任一標題或兵種列會開始整波，不是只啟動該入口。HUD 保留 EarlyStart 作為既有波次 controls 的唯一開波入口，其餘 EarlyStart2、EarlyStart3… 轉送至同一命令；共用開場動畫進度，同步鎖定／收回，重複點擊不會重啟計時或重複生怪。清波、ACT 新增入口、暫停及重開會同步更新全部按鈕；各按鈕獨立投影與裁切。零配額入口仍顯示按鈕及 ×0。若路線暫時無效，使用與正式排程共用的入口分配 helper 顯示正確原定數量，不假造流量，也不誤顯示全波總量或零人。

`wave_flow_preview.gd` 監聽 LevelSession.preparation_changed、EnemyWave.routes_changed、PortalMap.graph_changed／plan_changed 與 tile_parameters.costs_changed（包含非目前選取兵種）。失效先清除舊 mesh，待導航不在 computing 時合併重算一次。直接呼叫 `WaveSpawnSchedule.build(definition, controller, first_id, false, additional_starts)`；與開波共用跨群組、跨入口的完整配額流程，僅略過出發洗牌，不使用 global RNG，也不修改 pending／committed routes。預測是當前有限候選池的分配結果，不是所有可能道路的機率。

`RoadFlowForecast` 對每份完整行程的相鄰格以 Vector4i(from.x, from.y, to.x, to.y) 計數，保留 all、by_troop、by_origin、by_troop_origin 四種彙總；相反方向不合併，重訪區段計入實際通過次數，非四鄰步驟略過。無有效排程時只顯示兵種清單、中心線清空。Hover 只讀已快取的「兵種＋入口」彙總並重建顯示 mesh，不重新取得行程或消耗 RNG；移至同一按鈕的標題、空白或捲軸時顯示該入口全部兵種，離開整個按鈕才恢復所有入口。每幀依實際 GUI 命中子控制項確認入口與兵種，避免列間切換暫時恢復全波。動畫相位只由篩選後的完整行程建立，全體資料只提供共同強度尺度，正反方向的幾何皆保持在道路中央。`RoadFlowForecast.animation` 依入口／兵種延後快取 `RoadFlowPhases`，相同行程只建立一份時鐘但保留全部流量計數。每條有向邊保留全部到達步數，每個實際連續轉彎另保留通過中央格的步數；不再對聯集網路做 BFS 取單一相位，避免長支路在匯流時中斷，或環路重訪消失。

`scenes/navigation/road_flow_renderer.tscn` 保留有向區段，正反方向疊在道路中央，每個道路格只建立一個不重疊的 quad，整批一份 mesh／ShaderMaterial。格內線形以 RGBAF ImageTexture 保存端點、流量強度、局部進度、兩端流量強度與相位列／基準步數，每個 primitive 使用三個 texel：端點、兩端強度／相位，以及兩端裁切法線；相位基準步數／查表列放於整數部分，局部進度 [-0.5,1] 放於小數部分。最多 48 個 primitives；直段在格內完全筆直，每個實際 90 度轉向（包括匯流／分岔）皆以半徑 0.22 的局部四分之一圓角銜接，圓角離開後仍為直線，不再對整段道路作 Bezier 彎曲。雙向道路正反方向使用完全相同的中央幾何，hover 保持中央位置，兩方向仍各自使用流量、寬度與行進相位。每個實際相鄰轉向按該轉向的抵達相位建立線形；所有路口的 90 度轉向均由「直段＋解析四分之一圓弧＋直段」組成，不再因路口有第三條邊而退回直角。圓弧以負的終端強度標記，shader 依精確半徑與有向夾角計算距離及進度，取代八段折線；中央幾何令圓心可直接由兩個弧端點相加得到。共用切線裁切面連接直段與弧線，避免接縫與內部端帽突出。不同流量的進出邊不再以固定較小流量畫整段弧線：每段保存兩端強度，shader 以 smoothstep 插值強度，並用 `Line Width×0.5×lerp(0.4,1,strength)` 推導半寬；線寬及透明度在每個接點連續，邊界仍匹配原有向邊流量。只平滑樣式，不改變幾何或行程動畫相位；資料紋理／draw call／primitive 數不增加。只有完整行程的起點／終點使用圓頭，並保留獨立相位集合；格子邊界及內部接點不畫端帽。內部裁切不做透明度漸淡，避免聯集 max 在接縫變暗，外側輪廓及真正端點仍抗鋸齒。shader 對同一格內線形計算聯集，以最大覆蓋透明度而非 alpha-over 合成，岔路重合不會額外加深；跨格 quad 不重疊，端點相位銜接。只保留一小段米白筆觸，高流量較粗、較清楚，前後漸淡至透明；道路其他位置完全沒有固定底線，沒有箭頭、虛線、粒子、Bloom 或 emission。surface_height 預設 0.075，保留深度測試、不寫深度、不投影。

相位查表把到達步數減去最小值後去重，相同抵達間距共用一列；單一到達時間的區段共用同一列。週期為 `max(4, 最長完整行程步數+1, ceil(2×Highlight Length))`。RGBA8 紋理每列每個整數時刻以兩組 16-bit 整數保存前後最近到達相位的距離（低／高 byte 分占兩個通道，避免 Web 浮點紋理讀回的截斷），shader 依小數部分精確還原最近距離，再沿用原 smoothstep 筆觸。每個有覆蓋的 primitive 固定查一次相位表，不隨路線數增加片元迴圈；透明區直接略過。相位紋理按篩選快取，hover 只首次建立該篩選的資料，不重設 shader 的 TIME。

準備期顯示；開場等待、戰鬥、最後完成與 ACT 新入口選擇立即清空中心線。暫停隱藏清單／中心線並清除 hover，恢復後顯示未選兵種的預測；重開或卸載由場景樹回收。F1／F2 開啟期間只暫時隱藏玩家中心線，避免與除錯線／威脅混淆，原功能完整保留。

資料統計成本為已分配行程總步數，相位收集依去重行程總步數，查表建立／記憶體為週期乘以不同抵達間距列數；顯示重建依有流量道路格與有向區段，不每幀重算；shader 每格片元迭代實際 primitives，容量為每格最多 48（八個 90 度轉向各三段、四個直行及四個折返各兩段，加八個起終點半段），固定上限不隨路線數成長。此法增加少量片元距離計算以避免透明線段重疊加深。極大量群組仍可能造成同步預覽停頓，本階段沒有新增路線演算法或做容量上限宣稱。

自動驗證 `tests/levels/road_flow_preview.tscn` 與 `tests/levels/road_flow_continuity.tscn`；後者逐段檢查長短支路匯流、環路重走同邊、反向分線、抵達終點、週期接縫及 70 個抵達相位，實際渲染另取樣所有行程邊的中點與終點，以及亮段軟尾和遠離到達相位時保持透明；接點驗證另含四種朝向的突出區透明、路口圓弧及切線連通、雙向中央重合與獨立動畫、重合透明度聯集、真正端點圓頭與滿容量十字接點；另在四種朝向、流量 1／16 的雙向寬窄過渡上實測 56 個輪廓寬度，驗證弧線與直段接點樣式連續。結構資料從 CPU 幾何檢查，Web 浮點紋理讀回會截斷負法線與大於一的計數，實際 shader 行為由像素驗證。人工 F6 開啟 `tests/levels/road_flow_playground.tscn`，使用獨立雙入口、環路與三兵種資源，不改正式地形或波次。F5 經 Boot 預熱及主選單選圖後進入正式關卡；F6 可直接執行此獨立試驗場。截圖及原始測試 log 存 `.godot/`。

## 簡易敵人

正式 Soldier／Quickfeet／Heavy 的來源分別為 `assets/models/enemies/grunt.tscn`、`runner.tscn` 與 `brute.tscn`，保留模型、武器與配色。三者各有一個 MultiMesh、共用 `solid_color.gdshader`；Troop 的 GPU Model 引用離線烘焙的網格、支點與步態參數。Quickfeet／Heavy 由目前保存的來源場景直接烘焙，不重建原型；保留原 Walk 的 17 個線性插值關鍵影格、0.8／約 1.176 秒週期，以及 Quickfeet 3.0 播放倍率。模型動畫不改變既定路線或邏輯移速。模型說明與重建入口見 [模型說明](../assets/models/enemies/README.md)。

避讓採平滑阻尼，約 0.8 秒到位，鄰兵離開後保留側向位置，不回彈到中央；轉彎時仍忽略接觸。內建 grunt 使用 MultiMesh，兵種可指定匯入的 GLB／glTF／TSCN 模型、動畫與 PNG 圖示；匯入模型保留自己的材質與骨架。

main、9x9、11x11big 三張場景都包含 EnemyWave。入口圖準備完成後自動生成 64 隻紅衣步兵，每次 1 隻、間隔 0.2 秒，速度 2.5 世界單位／秒；抵達終點即 queue_free。右下角顯示生成／存活數，全數抵達後可按「生成 64 隻敵人」再次生成。Inspector 可修改 EnemyWave 的 enemy_count（預設 64）、batch_size（預設 1）、spawn_interval、速度、auto_start、兵種與起點；尾批不足 batch_size 時只生成剩餘數量。慢幀不會同幀補生多批，下一批從此次生成後重新等待間隔；間隔設 0 也至多每幀一批。null 兵種沿用 PortalMap，start_index=-1 使用目前 R 選取的起點。

小兵以原始逐格中心線行進；不再使用出生時的隨機偏移。EnemyMultiMesh 每 0.1 秒將小兵按 tile 分群，檢查同格與周圍八格，每格最多取 2 個代表者、固定 2 次迭代，讓重疊模型沿各自行進方向的左右法線分開。相同 pair 在一次迭代只處理一次；完全重疊時使用穩定 enemy_id 決定左右，避免依更新順序互推。目標間距為 0.36 格，最大顯示偏移為 0.22 格；每幀平滑更新模型位置與轉彎方向。

轉彎時忽略視覺接觸：模型朝向與移動方向差超過 5° 時，該敵人暫時不參與避讓，直行鄰居也不會被它推動；側向偏移維持原值，轉完再恢復。可調整 EnemyRenderConstants.VISUAL_TURN_TOLERANCE_DEGREES。

分離只修改 MultiMesh instance transform，不修改小兵 Node 的位置、速度、waypoints、抵達時間或固定行程保護。所有邏輯移動完成後，由 MultiMesh 統一提交顯示資料。沒有碰撞、停等或重新尋路。大量小兵無法在單格寬度內全部不重疊，本方法在固定預算下改善視覺穿插，不保證擁擠時完全分離。

每次分離最多檢查 9 × 2 × 2 × N = 36N 個候選，同格極端壓力測試為 4N；不排序、不列舉格內所有 pair，也不先全掃再挑最近者。分群、工作陣列與去重集合使用 O(N) 空間，hash 分群採一般 O(1) 查詢，因此整體 O(N)；同格人數增加不會導致 O(N²)。未生成敵人時停止逐幀處理。參數集中於 EnemyRenderConstants 的 VISUAL_* 常數，回歸入口為 `tests/enemies/enemy_visual_separation.tscn`。

各兵種／起點快取所選模式的機率表。先保留 `score - min_score < score_threshold` 的完整候選（等號排除；INF 停用門檻），Uniform 對每條保留候選給予 `1 / 候選數` 的機率；Softmax 計算 `p_i = exp(-(score_i - min_score) / route_temperature) / sum(weights)`。route_temperature 預設 4，越小越偏好低成本，設 INF 為等機率；等分候選的機率相同。soldier 預設 Uniform，quickfeet／heavy 預設 Softmax。每波以 `i / total`（i 從 0 開始）查找累積機率區間，固定各路線人數，再打亂出發順序；全域 enemy_id 不參與選路，相同計畫與總人數得到相同配額，預覽不影響實際分配。候選池有限，區塊內至多 4 個代表走法也分別計入候選權重。

每波開始時便固定所有待生成者的逐格路線與世界座標，之後修改地圖／評分只影響未來波次；重新建立計畫會重建對應機率表。敵人每幀只花移動距離走下一段，不做尋路。三種正式模型依 GPU Model 各共用一個 MultiMeshInstance3D，每隻僅保留行程／位置 Node3D、相位與避讓資料，不建立逐隻 MeshInstance 或 AnimationPlayer。來源場景或選中動畫與 GPU Model 不符時，保留匯入場景的材質、Skeleton 與 AnimationPlayer，不繪製占位 grunt。網格均為單一 surface，UV／UV2 保存四肢分類與支點，烘焙工具不在執行時使用。

assets/shaders/solid_color.gdshader 共用腿／手臂擺動、起伏與側擺公式，步態參數離線寫入網格 CUSTOM0，粗糙度／反光寫入 CUSTOM1；全部引用同一份 solid_color.tres，不按兵種複製材質或 shader。Soldier 相位依實際距離推進、出生錯開、停止時回中立；Quickfeet／Heavy 依模擬時間 × 動畫倍率 × 移動 blend 推進，停止時凍結當前姿勢，與原 AnimationPlayer 相同。shader 對兩者的 16 個關鍵影格間隔重現線性插值，不直接換成理想正弦。各網格持有獨立緊密 slot、容量與末尾搬移；頭頂狀態仍維持全敵群的獨立順序。開波依模型人口預留容量；移動後提交 transform／custom data，不重建網格、動畫或導航。轉角以 `lerp_angle` 和 `1-exp(-turn_sharpness*delta)` 平滑轉向，不改變既定路線與速度。Inspector 的 EnemyWave.turn_sharpness 越大轉得越快。

共用預設參數集中在 `EnemyConstants`，其他 script 可直接使用 `EnemyConstants.MOVE_SPEED` 等值，不需 preload。波次數量／批次／間隔／速度／轉向速度仍可由 EnemyWave Inspector 覆寫；步幅、擺幅與起伏等顯示預設集中在 EnemyRenderConstants。這是編譯時常數，修改後重新執行生效。


隨機分配方式與兵種下拉選單已移除。每個兵種可在 Troop Resource 的 **Route Selection** 設定 **Uniform** 或 **Softmax**，已預約行程保持固定；程式也可修改該資源：

```gdscript
TroopCatalog.find("soldier").route_selection = Troop.RouteSelection.UNIFORM
```

Uniform 忽略 temperature，對通過門檻的有限完整候選給予相同機率。每波固定配額：三條 Uniform 路線、五隻敵人時，i / total 為 0、0.2、0.4、0.6、0.8，分配為 2、2、1 隻，再打亂出發順序。Softmax 用相同分配方式對應加權 CDF；機率邊界屬於下一個非零區間。threshold=0 時都沒有合格路線。

`controller.allocate_route_for(profile, index, total, start_index=0)` 確保計畫存在，再依波內 index / total 分配完整候選。`next_route_for(profile, seed, start_index=0)` 保留為探查／預覽抽樣 API，波次不使用它。`sample_for(profile, seed, start_index=0)` 使用同一機率表；第四參數 route_index 可直接檢視指定候選（不抽樣）。回傳 selection_probability 可查看該條的選上機率，計畫的 route_selection、route_probabilities 與 route_temperature 提供整個池的設定。所有路線仍來自完整雙向入口圖的 Dijkstra 結果。

測試：tests/enemies/enemies.tscn 驗證完整行程、移動／刪除、波次與多起點，以及固定配額、打亂出發順序。tests/navigation/route_distribution.tscn 驗證數值穩定、負分、極端分數、threshold 邊界、temperature 快取失效、出生前固定行程、三路五兵 2／2／1 配額與兩種模式的波次分配；可用 tools/web/verify_enemy_web.cjs --distribution 驗證 Windows／Web。當次輸出放在 `.godot/test-results/navigation/`。

`tests/enemies/enemy_multimesh.tscn` 驗證容量成長、slot 搬移、外部刪除、距離步態、平滑轉向與幀率一致性；GPU buffer 讀回需實際顯示裝置。`tests/enemies/enemy_walk_render.tscn` 在實際 Compatibility 繪製兩種姿勢，檢查配色與畫面差異；Web 對照使用 `tools/web/verify_enemy_web.cjs --walk-render`。

## 敵人頭頂狀態

頭頂狀態使用 `scripts/enemies/presentation/enemy_status_overlay.gd`，整批敵人共用一個 CanvasLayer／Control 及單一 MultiMeshInstance2D，沒有逐隻 UI 節點；位置跟隨模型 MultiMesh 的避讓後位置，不讀回 GPU buffer。每幀依原先逐隻、背景到填色到圖示的順序，將可見矩形寫入可重用 PackedFloat32Array，整批提交一次；容量按倍數成長，以 visible_instance_count 排除舊資料。每幀成本仍為 O(敵人數＋效果圖示數)，不代表位置投影與資料填寫已移到 GPU。敵人全數離場後立即清空可見 instance、釋放圖示快取並停止更新；同幀多次移除只排程一次顯示刷新，避免逐次重建整批。

- 綠色血量＋右側淺藍護盾共用一條狀態條，依 `max_health + max_shield` 比例顯示，未填部分保留深色底。兵種設定 `max_shield`（預設 0），出生時複製護盾上限與目前值；傷害先扣護盾，再扣血。執行時 `enemy.add_shield(amount)` 可增加護盾與必要的上限。
- `enemy.skill_progress` 預設 -1，隱藏下方黃色技能條；設為 0～1 顯示進度，設回 -1 隱藏。僅提供顯示資料，沒有額外實作敵人技能。
- `enemy.set_effect_icon(id, texture)` 新增／更新頭頂效果圖示；同 id 不重複、依加入順序橫向排列，傳入 null 移除。SlowEffect 的 `icon` 使用 `assets/sprites/effects/slowness.png`，圖示跟隨合併後的最強減速，較弱命中只延長時間、不覆寫圖示，合併狀態到期移除；可在資源中換成自製 PNG。自訂效果負責在自身開始／結束時更新圖示。
- 尺寸、顏色與邊框集中在 `scenes/enemies/components/enemy_status_appearance.tscn` 的節點與樣式；批次 renderer 讀取單一範本，維持共用 overlay。條與圖示使用固定螢幕像素尺寸，跟隨攝影機縮放／平移後的頭頂座標；overlay 在暫停時仍重新投影凍結的頭頂世界座標，因此鏡頭移動不會讓血條、護盾、技能與圖示留在舊位置。不接收滑鼠事件，不影響卡片放置。

圖集與 instance 提交分別位於同目錄的 enemy_status_atlas／enemy_status_batch 模組。材質使用 `assets/shaders/enemy_status.gdshader`，每個 instance 保存顏色及圖集像素範圍；血量、護盾、技能填色共用白色像素，效果圖示共用帶邊緣延伸的動態圖集。圖集擴大保留既有像素座標，僅新增圖片時上傳。靜態 Texture2D 首次使用時快取；不逐幀擷取動畫、ViewportTexture 或同一圖片物件的內容更新。

外觀範本在顯示層建立時讀取，執行期間變更需重建顯示層。目前的無圓角／陰影／斜切 StyleBoxFlat 由 shader 解析繪製，避免分數縮放下的二次過濾；其他 StyleBox 由暫時 SubViewport 一次烘焙，之後釋放該 viewport。烘焙樣式縮放時可能產生紋理過濾差異，headless 不驗證其像素。

驗證場景 `tests/enemies/enemy_status.tscn` 同時展示血量、護盾、技能與效果圖示；對照 tests/fixtures 的舊版繪製，檢查分散／重疊像素、不同圖示、圖集及 buffer 成長、移除與空批次重用。畫面寫入 `.godot/test-results/enemies/enemy_status.png`，Web 驗證使用 `tools/web/verify_enemy_web.cjs --status`。一次性效能場景已清除，過去的量測結論見 [歷史摘要](../reports/performance_2026-10-20.md)。

## 防禦塔與地塊參數

三張場景都包含 TowerMap。右鍵在既有道路格放置哨塔，再次右鍵其任一佔格移除。防禦塔是障礙，整個 footprint 會從尋路快照排除，放置／移除後重建共用入口圖及各兵種路線池；底下的實體地塊與參數仍保留，移除後恢復通行。F1 顯示的有效路線與下一波敵人都會繞過塔，不能以低成本 evaluation 穿過障礙。

放置前對候選快照執行一次 BFS，確認所有起點仍可抵達終點；同時檢查完整 footprint 的地塊、重疊與起終點保護。若會封死道路便拒絕，沒有先提交再回復的中間狀態。已選定行程的待生成／存活敵人會保護尚未經過的路段，建造不能截斷這些行程；敵人走過且不再被其他敵人保留的格子可建造。拒絕原因顯示在介面。主場景的單格寬橋可以先補道路，或在本波結束後用跨橋卡一起放置塔與繞路。

`TowerDefinition` 是共用塔種 Resource，`DefenseTower` 是可繼承的實例基底，`TowerMap` 管理放置、佔格與影響提交。`assets/data/towers/sentry.tres` 定義哨塔，`scenes/towers/sentry.tscn` 繼承共用 tower.tscn。模型取自原型 art/towers/skybridge_towers.gd 的木架弩哨塔，由 tools/assets/build_tower.gd 離線烘焙成固定底座與可瞄準弩機兩份共用 mesh（各一個 surface，合計 265 三角形），正式執行不需原型。

哨塔占一格，攻擊區域引用 `assets/data/towers/ranges/sentry_forward.tres`，形狀以目前 offsets 為準，可直接在 Inspector 修改。最初設計圖的 3×5 格（X=-1..1、Z=-3..1）僅保留在獨立回歸範例，不能據此還原使用者修改的資料。其他血量、傷害、冷卻與威脅以目前 sentry.tres 為準。使用帶漸淡短拖尾的高速灰色箭矢，命中才扣血。可在 sentry.tres Inspector 調整塔種數值，實例的 attack_radius／threat setter 仍會更新影響；attack_radius 僅在 attack_area 空引用時提供圓形範圍。新增塔種時建立自己的 TowerDefinition 與繼承塔場景，再設定 TowerMap.tower_scene，或使用 `place_tower(cell, custom_scene)`；多格 footprint 沿用相同佔格／驗證流程，不需複製管理器。共同預設值直接使用 TowerConstants，不需 preload。按 F2 後指向地塊，可查看鄰塔數與威脅值。

- `tile.num_towers_around`：周圍上下左右與對角共八格的塔數，不含本格的塔。
- `tile.threat`：所有攻擊區域包含本格的塔之 threat 加總（不額外擴張投射物的範圍傷害外溢）。自訂 TowerAttackArea 對 offsets 去重後依 rotation_steps 轉向；attack_area 空引用則使用圓形距離 `dx²+dy² <= radius²`，含本格與半徑邊界，半徑 3 仍覆蓋 29 格。

TowerAttackArea 資源可在 Godot Inspector 編輯 offsets，Sentry 預設資源與例圖見 [ranges/README.md](../assets/data/towers/ranges/README.md)。放置時 `scenes/cards/components/card_preview.tscn` 的 Ground 顯示卡片地塊，AttackArea 以淡金色填色與細框顯示完整攻擊格（包含空地）；Preview 的 valid_color／invalid_color／range_fill_color／range_border_color 可調整外觀。預覽與實際塔都呼叫 TowerDefinition.attack_cells_at，不在每幀重建 mesh。

重疊塔會相加；移除、修改範圍／威脅值會更新影響。僅修改暫緩地塊時發出參數顯示通知，不使現有路線成本快取失效。每次只處理前後範圍格子聯集與八鄰格，整批更新僅發出一次成本失效通知，不重建道路幾何。空格也保留稀疏覆蓋資料，因此之後新增道路時立即繼承數值。已經為本波固定的敵人行程保持不變。

soldier 的 evaluation(tile) 仍回傳 1；塔的威脅資料與實際攻擊互相獨立。自訂兵種若要評估塔威脅，可使用 `1.0 + risk_weight * tile.threat`，或讀取 `tile.num_towers_around`；不會自動修改 damage_per_second。

`tests/combat/towers.tscn` 驗證圓形邊界、八鄰域、自格排除、影響疊加、移除、範圍／威脅調整、新道路繼承、右鍵、每次一次通知，以及既有行程不變。`tests/combat/tower_obstacles.tscn` 驗證單格／多格障礙、繞行、移除恢復、參數保留、多起點、封路拒絕及待生成／存活敵人保護。Windows／Web 一致性可用 `tools/web/verify_enemy_web.cjs --towers --tower-obstacles` 比對。

## 攻擊與效果

在 `assets/data/towers/sentry.tres` 的 Combat 設定 max_health、default_damage、attack_interval、attack，以及 aim_pivot_path、muzzle_path（相對模型根節點）；無發射點標記時才使用 muzzle_offset。瞄準只旋轉 AimPivot，底座保持固定；ArrowRelease 標記位於箭尖，光束與投射物均從該處發射。攻擊區域以塔 anchor 與敵人所在格座標判定整格覆蓋，規則和 threat／預覽一致；attack_area 可引用可編輯的 TowerAttackArea `.tres`，offsets 使用 Vector2i(X,Z)，(0,0) 為塔中心，(0,-1) 為模型前方一格。可建立直線、L 型、有缺口或不連續範圍；空清單屬錯誤，不偷偷回退圓形。attack_area 空引用才使用 attack_radius 圓形；自訂形狀不再被半徑裁切。不使用模型中心的世界距離，也不做障礙遮擋判定。每幀持續瞄準最近格的敵人（等距挑 enemy_id 較小者），冷卻時也平滑轉向。圓形範圍保留射程＋1 格的預瞄，且不擴大實際射程；自訂範圍只在覆蓋格中選取目標，避免範圍外更近的敵人搶走射擊機會。無目標時保持最後方向。首次攻擊或換目標若尚未對準，會等誤差小於 3° 才開火，不會在發射時瞬間轉向。轉向速度、容許角度及預瞄格數集中在 TowerConstants 的 AIM_TURN_SPEED、AIM_TOLERANCE、AIM_LOOKAHEAD_TILES。塔實例各自複製攻擊 Resource，可在程式修改 damage、attack_interval、attack.effects 等，不影響同種其他塔。

- `ArrowAttack`：快速單體箭矢，只追蹤原先鎖定者，抵達後扣血；目標已死亡或抵達終點時飛至最後位置後消失，不轉移目標或造成範圍傷害。sentry_arrow.tres 可調 speed（世界單位／秒，預設 24）、arrow_length／arrow_width、trail_length／trail_width／color。
- `BeamAttack`：立即對目標扣血，再顯示短暫灰色軌跡。sentry_beam.tres 可調 trail_duration／trail_width／color。
- `ProjectileAttack`：飛向發射時鎖定的落點格；經 flight_time 後對該格周圍 splash_radius 內**當時仍在場**的敵人結算。0 半徑代表落點一格。可調拋物線高度與外觀大小。範例為 attacks/explosive_projectile.tres，預設 0.6 秒、1.5 格半徑並附減速效果；將塔的 Attack 指向此資源即可使用。
- `HitEffect`：覆寫 apply(target, source, damage) 新增命中效果。同類效果不疊加，以最佳強度及最長剩餘時間合併成一份狀態，不加總強度或時間；不同效果種類可各自存在。內建 SlowEffect 可設定 speed_multiplier／duration，倍率越低越強：合併時倍率取 min、時間取 max(既有剩餘時間, 新 duration)。例如 0.4 倍速剩 1 秒遇到 0.8 倍速持續 3 秒，合併為 0.4 倍速持續 3 秒，期間不退回 0.8；已經過的時間不重新補滿。效果在基本傷害後套用，死亡者不再套用狀態。未來新增同類狀態也須遵循此規則，並自行定義最佳強度的比較方式。

攻擊發射時保存當次傷害與效果數值；塔被移除後，已發射投射物仍會命中。`DefenseTower.damage_against(target)` 可覆寫特定傷害規則；其他發射機制可繼承 TowerAttack.fire()。Attack 留空時只當障礙塔。塔／敵人透過 take_damage(amount) 扣血；塔死亡會釋放障礙並更新地圖。敵人死亡立即退出 Wave 與 MultiMesh，killed 與到達終點的 completed 分別計數；全數死亡也能結束波次，目前敵人不會反擊塔。

每張地圖只有一個 CombatSystem，在敵人移動後建立一次地塊索引，再讓冷卻完成的塔查詢覆蓋格；覆蓋偏移與命中查表依實例快取，半徑／方向／範圍 Resource 改變才失效。沒有逐塔掃描整張地圖、RayCast、PhysicsBody 或逐發 Timer。軌跡與投射物標記合併為一個 unshaded 透明 mesh，支援 Compatibility／Web。AOE 命中與敵人死亡改用可編輯且會回收的圓環／低多邊形碎片場景：死亡半徑 0.35 格、0.3 秒，AOE 視覺半徑為傷害半徑的 0.65 倍、0.4 秒，造型參考 card-tower-defense；實際傷害、死亡與波次結算不受特效影響。場景與參數見 [scenes/effects/README.md](../scenes/effects/README.md)。這是輕量固定落點投射物，沒有物理碰撞或自動追蹤。

規則回歸入口為 `tests/combat/combat.tscn`；`tests/combat/combat_preview.tscn` 驗證兩種攻擊的實際繪製。Web 工具為 `tools/web/verify_enemy_web.cjs --combat`。

## 入口圖

所有兵種共用正成本候選探索，再以原始 evaluation 加總與套用 threshold。搜尋成本與最終評分分開處理。

四方向且模型接口相接才算道路邊；石地與斜角不連通。每四格完整形成 2×2 方圈時，視為可換道的填滿面。無洞的連續寬區直接合併成一筆區段資料；有洞的寬區則沿掃描線在分開／匯合處切分，1 對 1 相接的區段持續合併，不因寬度變化切成多個矩形。

節點放在寬區與細路的接合處、區段共享開口、真正的外部岔點、端點。起終點位於寬區內時也保留其位置。開口保留完整格子範圍，標記只選一個代表點。外部無分岔走廊壓成一條 edge，平行道路與閉環保留。

同一寬區的入口以 `region.nodes` 表示互通關係，不建立中央實體岔點。拓撲驗證仍使用沒有座標的區段 incidence vertex；`stats.cycles` 指填面空間的獨立環，不包含局部路線配對產生的組合。

每個區塊用填滿面的邊建立局部道路，不把區塊外的相鄰細路混入。依兵種成本執行 Dijkstra；同區各格成本相同時使用 BFS 快速路徑。共享正向／反向距離表還原全部最低成本 DAG，不逐條列舉；成本相同但步數不同的走法也保留。計數超過 64-bit 正整數範圍時只將顯示數字標為下限，實際 DAG 不截斷。

F1 顯示本波各兵種完整行程，並以深色圓點與 V0、V1… 編號顯示目前 graph.nodes 的全部入口圖 vertex，包含起終點及未被當波路線使用的節點；不顯示區域填色。編號是目前圖的 node.id，重建後可能改變。標記範本位於 scenes/navigation/components/vertex_marker.tscn，可調整圓點、字級與外框；文字朝向相機，無碰撞或輸入。節點獨立依 graph_changed 失效並延後合併更新，F1 關閉時不建立／重建標記，也不逐幀重建。戰鬥期間路線仍顯示已固定行程，節點則顯示目前路網；關閉 F1 同時隱藏兩者。F2 的資料定義見上方除錯介面。

放置時只更新至多五格的模型。首次完整建立入口圖與路線；之後先用 RoadEditGuard 檢查新增地塊。孤島、單一接點的死路與封閉支環會保留原圖／路線池；只有新道路連接到有效路網的兩個不同位置才以最新快照完整重建，同幀多次修改合併一次。使用整數座標與連接遮罩的 packed arrays，原生端判斷雙向連接；不傳每格 Dictionary 鄰接表。除錯圖層各使用一個 mesh，沒有逐格繪圖物件。

RoadEditGuard 在完整建圖後，以迭代 Tarjan 建立 block-cut forest，找出連接所有起終點的區塊；非有效區塊依單一接點歸併。新增只需四鄰格查詢與並查集合併，攤銷接近常數時間；累積的死路一旦接回另一處就觸發更新，不因形成小環而誤判。刪除／搬動起終點及直接改 GridMap 的工具仍應明確呼叫 rebuild()。回歸入口為 `tests/navigation/dead_end_edits.tscn`。

新增地塊只存在本次遊戲中。建圖與路線池建立同步執行。局部最短路以目前入口代表地塊為兩端，不是整個開口任意位置的最短距離。全域連線將途中遇到其他入口的路線拆開，避免漏記節點訪問；只有不經過其他節點的局部最低成本走法才作為單條全域連線。區塊內原有的完整配對資料仍保留供驗證。原生探索來源未限制區塊重訪或跨區段地塊重用；正式候選在完整展開後去環，最終行程不重踩格子。

完整入口圖保留雙向選項，不設定 rank，也不封鎖共用必經道路。每次搜尋成本為 `原始成本 + overlap_penalty × edge.length × 探索使用次數`，正反向的同一條實體道路共享懲罰，仍保留各自的原始成本。平行道路保持分開。搜尋使用正成本 Dijkstra，因此每條產生的節點路線都不重複 vertex；方向聯集可以有環，不能把其出邊重新任意串接成路線。

第一條是不加懲罰的正成本最佳路線，後續候選以道路使用懲罰分散探索，去除相同 edge 序列。此階段固定使用 INF，不依原始 evaluation 門檻篩選。重複的候選也會增加探索懲罰，以繼續尋找其他選項；這不是實際敵人流量，不會改變最終路線評分。最多 search_budget 次搜尋（1～256，預設 64），或連續 8 次沒有新增路線便結束一般搜尋，並觸發一輪未探索道路的中繼補路。超過 threshold 的一次結果不代表其他有效路線不存在；此方法不窮舉，也不保證收齊所有可用路線。soldier 的 threshold=INF，停用成本門檻；quickfeet／heavy 則在有限候選池套用原始評分門檻 25。搜尋仍受工作預算限制，threshold=0 不保留路線。

連續 8 次未新增時，將一般探索次數為 0 的實體道路作為中繼 edge，各方向分別嘗試起點 → edge.from → edge.to → 終點。先共用起點正向與終點反向最短距離表；兩段無重複節點時直接拼接，有衝突時分別固定前段／後段，封鎖其節點後重搜另一段，取較低原始成本的合法結果。這是有限修補，不保證找齊全部 simple path 或每條必經 edge 的全域最優解。補路只執行一輪，路線仍去重；不是對未探索道路打折。64 次預算只限制原先的懲罰搜尋，額外補路可能增加計算與路線池大小。只有耗盡預算而未達連續 8 次停滯時不觸發。回歸入口為 `tests/navigation/waypoint_routes.tscn`。

每次進入某格才計算成本，起始格免費，入口不重複計費，正反向成本分別計算。成本／兵種設定改變使對應全部起點的計畫失效；實際重建地圖時清除全部；跳過的死路新增保留現有快取與機率表。區塊內同探索成本走法在建池時有限抽樣，完成後先對完整逐格路徑去環、重建資料，再去重與評分。敵人生成器依兵種的 Uniform／Softmax 設定分配保留的完整候選；不保證所有可能的逐格行程均勻分布。

### 多起點

`PortalMap.start_paths` 設定起點標記的 NodePath 陣列，預設只有 `../Start`。`11x11big.tscn` 已設定 `../Start` 與 `../Start2`；第二個起點位於原起點沿 −Z 方向 5 格，另補上 5 格道路連接既有路網。兩者使用同一份實體入口圖與終點，各有自己的路線池與計畫快取。獨立地圖可用 R 切換下一波使用的起點；開波後 F1 保留已固定行程。關卡模式依各出生群組指定的入口同時顯示全部兵種，不以 R 篩選路徑。

```gdscript
# start_index 從 0 開始；先為該兵種／起點取得計畫，再抽取行程。
var plan = controller.plan_for(profile, 1)
var route = controller.sample_for(profile, enemy_id, 1)
```

省略 start_index 時使用第一個起點，保留原有呼叫方式；`sample_route(seed)` 則從目前選取的起點出發。所有兵種共用實體圖，每兵種 evaluation 分數陣列跨起點共用；幾何代表池依搜尋設定與起點共用，各兵種另有正成本探索與原始評分篩選快取。兵種或地塊資料變更會使對應全部起點計畫失效。

所有起點作為額外 terminal 傳入原生入口圖建構器，走廊中段、寬區與共享窗口中的起點也會保留為明確節點，避免建塔後鄰接度改變而消失。起點須在未被障礙佔用的道路上；每個來源仍持有自己的計畫及機率表。

## Tile 參數與兵種評分

`scripts/map/tile/tile_parameters.gd` 是每格獨立的 Resource 資料紀錄，包含 terrain_id、movement_multiplier、damage_per_second、cover、num_towers_around、threat，以及 set_parameter/get_parameter 的擴充欄位。集中由`scripts/map/tile/tile_parameter_store.gd` 以座標維護，不新增逐格 Node。暫緩建圖的死路地塊仍立即建立資料；all_tiles() 供 F2 查看所有實體地塊，ordered 僅對應目前原生圖的成本欄位。重建入口圖會保留仍存在地塊的參數；目前屬於遊戲執行期間的資料，沒有新增存檔格式。

兩者的數量與責任不同：**每格一份 tile_parameters；每張地圖一份 tile_parameter_store**。前者只描述該格的資料並在修改後通知；後者保存「座標 → 該格資料」，同步新增／移除的地塊，並依兵種 evaluation 產生成本陣列、快取及處理失效。兵種的 evaluation 收到的是單格 tile_parameters。store 本身不尋路。

`Troop` 是全兵種共用的 Resource，每個兵種各有一個 `.tres`，透過每格基本成本與各地塊權重設定 evaluation；實際小兵使用共用 Enemy 移動節點。每個 Resource 保存 max_health、speed_multiplier、evaluation(tile)、score_threshold、route_temperature、search_budget 等設定。當前 health、行程與移動位置保存在單隻 Enemy，不放進共用 Resource。

各兵種的 HP、護盾、速度倍率、尋路權重與 threshold 請直接查看 `assets/data/troops/*.tres`；這些值可由 Inspector 編輯，文件不重複固定一份平衡表。

兵種為 `assets/data/troops/*.tres`，可在 Inspector 新增、修改、刪除；資料與模型匯入說明見 `assets/data/troops/README.md`。`TroopCatalog.all()` 自動發現目錄及子目錄中的資源，`find(id)` 取得共用設定。波次編輯器用資源身分辨識兵種，選單及時間軸顯示各自 icon；不再以 GDScript 類別區分。速度乘上 EnemyWave.move_speed，基準為 2.5，各兵種的實際速度為基準乘上其資源中的速度倍率。開波時固定當波血量、速度與完整路線。關卡儲存 Troop Path，移除兵種後仍可開啟關卡修正群組，缺少兵種的波次不會開始。

關卡依波次 Resource 設定兵種，F1 同時顯示本波所有兵種，不再顯示兵種下拉選單。也可直接設定 EnemyWave.troop；null 沿用 PortalMap。各兵種使用自己的 route_selection（soldier 預設 Uniform，其餘 Softmax）對保留候選建立配額；Uniform 等機率，Softmax 使用 route_temperature（預設 4）。soldier 的 INF 僅代表不依長短排除候選，Softmax 仍會偏好較短者；它不代表窮舉全圖所有路線。

### 統一搜尋與評分

所有兵種只需覆寫 evaluation，沒有 scoring_mode、shuffle_candidates 或額外的成本轉換覆寫。

1. 共用以長度探索的有限節點路線池；依相同 search_budget／overlap_penalty 與起點重用幾何代表資料。
2. 取得全圖原始分數陣列。如果最低分 m ≤ 0，搜尋成本設為 `evaluation + (1 - m)`；否則保留原正成本。這個共同平移保留地塊之間的偏好順序，讓所有搜尋成本為正。以此加入兵種偏好候選；若全部搜尋成本已為 1，直接重用中性池，避免重跑相同搜尋。
3. 每個節點路線抽至多 4 個區塊內同探索成本走法。原生 candidate_walk_core 在建池時以堆疊與密集格子索引表做 O(L) 去環：遇到仍在堆疊中的格子，移除其後繞回的部分；每格最多推入與移除一次。重建 cells／length／nodes／edges、indices 與連續 ranges，分段涵蓋相鄰 vertex 間實際保留的格子。相同分段使用相同 ID；原生 edge ID 可能因剪接失效，因此正式候選分段 ID 屬於各候選池／計畫，不能拿去索引原生 choice_edges。相同原始樣本先避免重做去環，所有不同原始樣本仍在去環後按完整路徑重新去重，不列舉全部走法。
4. 對每個去環後的完整候選重新加總原始 evaluation，起始格不計費；探索來源的 score／best_score 不保留作為正式行程分數。soldier 為總步數，quickfeet 為總 threat，heavy 為負總 threat。
5. 計算池內 min_score，僅保留 `score - min_score < score_threshold`，等號排除；INF 停用硬篩選。保留者依 route_selection 採 Uniform 等機率或穩定 Softmax 計算機率，以波內序號 / 總數決定路線配額，再打亂出發順序。

平移只用於搜尋，會影響不同長度候選的探索次序，不能保證與原始總分有相同排序；最終評分與 threshold 一律使用未轉換的分數。此方法處理正／零／負值，拒絕 NaN／無限地塊評分。這是有限候選中的最佳分數，不保證全圖最優 simple path，也不保證保留所有同分逐格走法。search_budget 限制搜尋次數，不是路線數 K；有限代表數由 EnemyConstants.CANDIDATE_LOCAL_SAMPLES 控制。

候選運算透過 RoadRoutePlanner.candidate_representatives 整批執行：直接在 C++ 以格子整數 ID 抽取有限局部走法，對原始樣本去重，再去環並重建分段，最後才一次轉成腳本使用的 packed buffers。密集索引 scratch 跨樣本重用，只重設走過的格子，不為每條路線清空整張地圖。分段登錄仍由各幾何池／兵種計畫持有，保持先出現者的 ID 與候選順序。

search_costs 在原生端驗證及轉換正成本；rank_candidates 合併中性／偏好候選、保留第一個相同完整行程、加總原始 signed 分數、執行嚴格門檻及穩定 Uniform／Softmax。route_distribution.build 為原生機率表的薄介接，seeded 隨機抽樣仍用原 Godot RNG；批次配額索引在 C++ 以相同 index / total 與 CDF 上界規則計算。快取、失效、兵種 Resource、波次規則及快照生命週期仍由 GDScript 協調；不增加敵人移動工作。純 GDScript 去環參考移到 tests/fixtures/candidate_walk_reference.gd（保留 UID），只供獨立對照，不作執行期備援。

正式 `PortalMap.plan_for(profile, origin)` 回傳輕量摘要（分數、候選數、機率、門檻及探索診斷）；不含最終候選的 active_nodes／used_edges／steps／directions。原生來源的同名欄位也不混入正式摘要，避免顯示去環前的資料。需要上述除錯聯集時呼叫 `debug_summary_for`，第一次掃描保留候選建立並快取，後續回傳防修改副本；計畫失效時一併清除。`debug_graph_for` 的加權分段圖仍獨立按需建立。F1 依當波完整行程畫線，不要求這份除錯摘要，因此一般遊戲與 F1 不為摘要聯集增加建池工作。

`PortalMap.prepare_route_batch(profile, total, origin)` 每個兵種／入口只檢查與準備一次計畫，再以既有 CDF 對全部 `index / total` 批次分配，回傳 routes 與 pool_size；不改候選順序、分數、Uniform／Softmax 或門檻語意。公開單筆 `allocate_route_for` 仍維持原本的準備檢查，供探查及單筆呼叫使用。批次相同候選只建立一次獨立於計畫快取的路線快照，再給每名敵人各自的 Dictionary；其中 packed 路線 buffers 約定唯讀，不能直接修改共用路線。

`WaveSpawnSchedule.build` 先跨同兵種／入口的所有群組計算總配額，批次準備各來源，再按原 group 的出生刻度與洗牌規則產生排程。route_waypoints 在該次 build 中以完整 cells 作 key，同一條實體路線只轉換一次世界座標，亦可由不同兵種共用。快取僅存在該次呼叫，下一次預覽／開波重新捕捉地圖 transform，不能回寫或重用先前波次的座標資料；獨立場景的 legacy 開波與預覽也使用批次配額。排程快照保存共用唯讀 points，Enemy 只共用該 buffers，各自改變 _next、位置與狀態；對外一般 `Enemy.follow` 仍防禦性複製輸入，只有內部排程明確使用 shared_snapshot。移動與傷害流程不新增建表、轉換或去環。

回歸入口 `tests/navigation/route_batch.gd` 驗證除錯摘要延後建立與失效、256 名批次與單筆結果一致、跨群組一次準備、座標快照共用／變換更新、當波分數隔離、外部輸入防禦複製、獨立移動進度及預覽不消耗亂數。
去環、重建分段、評分與機率表只在候選池／計畫失效時執行並快取，sample／allocate 與敵人移動不呼叫去環。summary 的 normalization_us／loop_erased_routes／loop_erased_steps／raw_samples 描述該計畫所用幾何與兵種代表的建池工作（共用池的工作可能已由其他計畫快取），不是每次快取查詢的耗時。去環後不同來源可能合併，候選數、最佳原始分數與配額可因此改變；不保留繞圈來累加負分。

回歸入口為 tests/navigation/loop_erasure.gd，包含移除 vertex 的跨段去環、被移除格子的再次進入、資料重建、嚴格門檻、正負評分、去重與 256 名敵人的 Uniform／Softmax 配額，並檢查 32×32 合成房間網路的全部候選。

### 新增兵種

1. 在 `assets/data/troops/` 新增或複製 Troop `.tres`，設定唯一兵種 ID、名稱、模型、數值、評分權重與選路模式。
2. TroopCatalog 自動發現目錄及子目錄的資源，不需新增兵種腳本子類別或修改硬編清單。
3. 在波次編輯器選取新兵種並儲存；詳細欄位與刪除處理見 [兵種說明](../assets/data/troops/README.md)。
重用同一份 Resource，避免每隻小兵重新建表。每次新參數快照只對每格呼叫一次 evaluation；幾何與兵種候選計畫快取後，出生只取得已準備的路線。匯出 setter 會 emit_changed()；自訂會影響評分的欄位也應發出相同通知。地塊變更使原始分數與偏好探索失效，物理地圖變更再清除幾何代表池。

F1 的路徑來自本波每隻敵人的完整行程，不受評分正負值影響；預覽沿用實際分配，開波後維持固定行程。回歸入口為 `tests/enemies/troop_profiles.tscn`，Web 對照使用 `tools/web/verify_enemy_web.cjs --troops`。


## 關卡、ACT 與波次

F5 先完成啟動顯示預熱並進入開始選單，經選圖與本局設定後載入 `scenes/level.tscn`；關卡設定在 `assets/data/levels/frontier.tres`。範例包含三個 ACT、每個三波。準備階段無時間限制，第一波及後續波次都由玩家點任一起點上方的「開始下一波」對話框確認，沒有 60 秒倒數、自動開波或提早開始獎勵。每次確認後等待 1.5 秒才進攻。

介面場景是 `scenes/levels/level_hud.tscn`，包含頂部金幣、時間線、倍速與暫停，以及 `WorldActions/EarlyStart` 起點對話框；已實例化於 `level.tscn` 的 `LevelHUD`。時間線本身是 `scenes/levels/wave_timeline.tscn`，可直接在 2D 編輯器預覽。選取 WaveTimeline 後，可在 Inspector 的 Preview 調整波次索引、準備進度與戰鬥狀態，Appearance 可調字型、字級與顏色；執行時由關卡進度接管。時間線的節點數與 ACT 名稱來自 Level 資源。

- `LevelDefinition`：穩定 ID、前置關卡 ID、必含端點的地形 GridMap 場景與 ACT 列表。標題／描述 key 由 ID 推導為 `ui.maps.title.<id>`／`ui.maps.description.<id>`，不保存額外名稱、翻譯 key、起終點座標、來源開關或 Marker Height。高度由 TerrainEndpoint.height_offset 控制，ACT 新入口及其預覽沿用第一個地形入口在 GridMap 局部座標中的高度偏移。準備時間、自動開始、開波額外獎勵與全局 ACT 擴張欄位已移除；各波完成獎勵仍由 WaveDefinition.reward 設定。
- `ActDefinition`：ACT 名稱、有順序的波次列表與 `add_start_after_completion`（預設 true）。完成這個 ACT 後若還有下一個 ACT，勾選才進入新增出生點流程；取消則直接進入不限時、手動開始的下一波準備。最後 ACT 直接完成關卡，即使選項勾選也不額外擴張。不同 ACT 各自保存設定。
- `WaveDefinition`：出生群組列表、共用移動速度與完成獎勵。
- `WaveSpawnGroup`：兵種、開始刻度、總數、每批隻數、批次間隔刻度與入口索引。
- `level_session.gd`：在遊戲節點 ready 前載入預設地形與端點，依序準備波次；完成最後一波後停用開波按鈕。

可在 Inspector 開啟 frontier.tres 編輯，或另存一份關卡 Resource，指定到 level.tscn 根節點的 Level。地形使用可獨立編輯的 GridMap `.tscn`，不把地形資料混進敵人生成程式；範例引用 `scenes/maps/tile_map.tscn`。既有 main／9x9／11x11big 場景仍可獨立用於地圖與功能測試。

Godot 底部的「波次編輯器」可直接開啟關卡 `.tres`，分開選擇 ACT 及該 ACT 的波次。ACT 列提供新增／刪除 ACT 與「結束後新增出生點」checkbox，預設勾選；波次列提供新增／刪除波次，原有群組新增／複製／刪除及兵種、入口、開始時間、數量、每批隻數、批次間隔編輯保留。新增 ACT 附一個波次，新波次附一個使用預設兵種的獨立群組；新增 ACT 放在最後並選中，新波次插在目前波次之後。可以刪到沒有 ACT／波次，再透過新增按鈕重建，資料無效時禁止儲存；刪除 ACT 一併移除其波次，復原會完整恢復資料及原選取。

切分支後舊 dock 可能仍持有舊節點樹，新 tool 腳本先以安全查詢確認 ACT／波次控制項；缺失時跳過場景快取、讀取目前 wave_editor.tscn，只重建子介面並重新設定 unique owner／signal，保留根節點及其未儲存資料、選取與 Undo／Redo。刷新期間與離場通知有狀態守衛，不對不存在的 ActPicker 呼叫方法。實際編輯器回歸會重現舊 dock 並驗證恢復。

拖曳色塊可移動開始時間；預覽滑桿顯示指定時刻各兵種的累計出生數。按「儲存關卡」寫回原檔，或使用 Godot 儲存操作一起儲存；ACT／波次／checkbox、群組編輯與拖曳皆支援原生復原／重做及未儲存狀態追蹤。切換關卡可先儲存再切換。外掛已在專案設定啟用；若編輯器尚未重新載入設定，可在「專案 → 專案設定 → 外掛」啟用「波次編輯器」。介面場景位於 `addons/wave_editor/wave_editor.tscn`。

出生排程以開波為 0，所有時間保存為整數：`start_tick` 與 `interval_ticks`，每格固定 0.25 秒。例如開始 6 格 = 1.5 秒、間隔 2 格 = 0.5 秒。結束刻度由「開始 + (批次數 − 1) × 間隔」自動計算，間隔 0 表示同時出生。準備期與開波動畫獨立於出生排程。既有九波已轉成群組資料，原先 0.2 秒的出生間隔對齊為 1 格（0.25 秒）。

同波群組可重疊或留下空檔；即使當下無存活敵人，也要等未來群組全部出生並清場後才結束。同一兵種與入口跨群組共用整波的 `index / total` 路線配額，再只打亂各組內路線的出發順序。開波時固定路線、血量與速度，後續資料修改不會改寫待出生敵人。排程以絕對整數刻度判斷，慢幀會補上已到期的批次，不會把整段出生時間往後移。

`tests/levels/wave_spawn_groups.tscn` 驗證整數邊界、混合與重疊群組、空檔不提早結束、慢幀、快照、多入口及跨組配額。`Godot --editor -- --test-wave-editor` 在實際編輯器內驗證群組編輯、拖曳吸附、原生復原／重做，以及儲存後重載整數資料。

頂部時間線寬度為畫面的 50%，水平置中；每波佔一個等長區間，圓點代表一般波次，ACT 的最後一波由分隔直線表示，起點另有直線；目前 ACT 使用 Noto Sans TC Medium。金幣在時間線左側，右側只有倍速與暫停，商店不另外顯示重複餘額。沒有獨立位置游標。準備期時間線停在已完成節點，不隨等待時間前進。按「開始下一波」後，時間線以二次 ease-in-out 於前 1 秒走完下一段，到達下一節點後停留 0.5 秒才進攻。等待期間停用開波按鈕並鎖住建造與商店。戰鬥期間固定在該波節點；本波完成後進入不限時的下一波準備。

頂部保持透明，倍速與暫停只顯示低彩度青灰色圖示；正常、懸停、按下與停用狀態都沒有按鈕背景，透過圖示顏色與透明度區分。樣式位於 `assets/themes/level_controls.tres`。點擊倍速圖示依序切換 1x → 2x → 4x → 1x，以一、二、三個箭頭區分，影響遊戲時間、開場等待、出生、移動與動畫。按暫停立即暫停 SceneTree 並將 Engine.time_scale 設為 0，同時鎖住選牌、旋轉、放置、商店與手動開波；1x／2x／4x 都不經過減速過渡。暫停時仍可滾輪縮放、中鍵平移與左鍵在卡牌以外拖曳旋轉鏡頭，其他遊戲輸入由 HUD 攔截。暫停請求接受後立即停用頂部倍速與暫停按鈕，同時忽略其 hover／點擊；暫停期間也不接受程式發起的倍速切換。恢復後才重新啟用。右下選單使用右對齊的細字與透明底，不使用 hover／focus 底線，暫停／繼續時皆以實際 0.35 秒淡入／淡出，不受倍速或零 delta 影響；時長可在 `pause_menu_fade_seconds` 調整，淡出途中不攔截地圖點擊，連續切換會從當前透明度接續。樣式位於 `assets/themes/pause_controls.tres`；手牌與商店的呈現根節點在實際 0.35 秒內一起滑至畫面下方，時長由 LevelHUD 的 `pause_seconds` 調整，僅控制介面收合，保留選牌、商品及展開狀態；恢復時反向滑回。背景使用 `PauseBlocker/WhiteVeil` 的白色 ColorRect（透明度以場景中的 color.a 為準），隨右下選單一起淡入／淡出，圖示與選單保留原色。繼續遊戲或 Esc 會還原卡牌位置／選取及選定速度，未完成的開波過渡也會接續；介面收合途中恢復會立即繼續模擬，並從當前位置與透明度反向還原。「回到主畫面」會結束目前關卡，白色過渡遮住畫面前保持暫停，返回後可重新開始全新進度。選單節點位於 `scenes/levels/level_hud.tscn`，互動由 `scripts/levels/presentation/level_hud.gd` 管理；`tests/levels/level_hud.tscn` 與 `tests/levels/pause_navigation.tscn` 驗證 1x／2x／4x 下的立即暫停、暫停鏡頭、血條投影像素、選單淡入淡出、遊戲與交易鎖定、快速切換與繼續；返回主畫面的完整往返由 menus/main_menu 回歸驗證。

暫停選單依序為「繼續遊戲／重新開始／設定／回到主畫面」，支援英文。每列使用 `scenes/levels/components/pause_menu_item.tscn`，固定 Control 包住可動畫的 Button，hover 於實際 0.2 秒以二次 ease-in-out 左移 12px，文字變黑但不縮放；移開後反向還原。Button 的 Hover Shift／Hover Seconds 可在範本中調整。命中範圍包含原列與變形後的按鈕，HUD 也以相同範圍放行滑鼠；動畫不受 0 delta 或 1x／2x／4x 影響。鍵盤仍可切換四個選項，以文字顏色表示焦點。

重新開始先解除暫停並還原 1x，再以 SceneTree.reload_current_scene() 重載目前場景，回到第一波準備，重置敵人、商店金幣及初始手牌；關閉舊場景沿用清理保護。設定會開啟 `scenes/settings/settings_page.tscn`，隱藏暫停選單文字但保留背景遮罩與暫停狀態。返回或 Esc 只關閉設定並將焦點還給設定按鈕。`tests/levels/pause_menu.tscn` 使用實際滑鼠及渲染檢查 hover 進出、原邊緣命中、無橫線、雙語與設定，再由 4x 戰鬥中暫停並點擊重新開始，檢查重載後狀態。

開波對話框位於 `scenes/levels/components/start_wave_callout.tscn`，無情報時大小為 128×46，有情報時寬 216px、高度依最多三列敵軍調整，文字依語言顯示「開始下一波」／「Start next wave」，不加問號或顯示獎勵。每個入口各有一份範本實例，分別投影到對應入口上方，向下尖角指向入口，隨相機平移／縮放更新；部分超出視窗仍保留顯示，由視窗自然裁切，完全離開畫面才隱藏。邊框為固定完整輪廓（Shape/Border），無倒數裁切。Hover 以 0.15 秒過渡到淡青底色與較深邊框，略為放大並上浮。開波時以 0.24 秒二次 ease-in 縮小、移入起點塔；下一波準備時以 0.36 秒二次 ease-out 回到原位，動畫隨暫停停止。LevelHUD Inspector 的 Start Retract Seconds／Start Reveal Seconds 可調整時長，Start Collapse Height 可調整塔內收回位置。商店開啟仍可點擊可見的對話框。

開波不發金幣，只有清完每波時發放 WaveDefinition.reward。已移除關卡的 Early Start Max Bonus、倒數比例計算與浮動獎勵文字場景；重複點擊不改變金額或重新計時。

水平線、波次圓點與 ACT 分隔線共用同一個由左至右的填色邊界，進度經過圖形時逐部分覆蓋，包含手動開波的 ease-in-out 動畫；填色終點對齊標記右緣，使該波開始時圓點或直線已完全填滿，戰鬥與下一段準備期之間不跳動。`wave_timeline.tscn` 的 Track／Progress 共用軌道與標記場景，Progress 以 Control 的 clip_contents 水平裁切，ACT Label 不受裁切。完整 UI 場景索引見 [scenes/UI_README.md](../scenes/UI_README.md)。

每波進入開場等待時立即取消選卡、旋轉狀態及卡片／地塊放置預覽，手牌滑到畫面下方，建造輸入暫停；點擊開波後立即執行，不等時間線動畫結束。等待期間商店會隱藏且不能重新開啟或交易。關閉商店不會解除等待／戰鬥鎖定；波次結束才恢復手牌與建造。商店仍於每波完成後發放該波獎勵。關卡使用各波指定配方，兵種與分配方式從 Resource 設定，不再顯示下拉選單。金幣顯示會同步獎勵、購買與重刷。

`tests/levels/level_flow.tscn` 驗證地形載入、ACT 切換、不限時準備與僅能手動開波、無開波獎勵、每波 1.5 秒開場等待（1 秒 ease-in-out＋0.5 秒停留）、慢幀與戰鬥停留、半寬置中佈局與餘額同步、手牌收回與 hovering 取消、不同波次獎勵、完成後禁止多開波次，以及多起點。

關卡清理與正常清場分開處理：關閉視窗時 HUD 可能先離開場景樹，之後最後一隻敵人的 `tree_exiting` 仍會觸發波次完成。LevelSession 在進入下一波前確認自身未排程刪除且 HUD 仍在場景樹；HUD 對離場後的準備期通知與投影呼叫直接返回，使用 viewport 前再次檢查有效性。`tests/levels/level_teardown.tscn` 覆蓋倍速、按鈕／內部開波入口、不同出生階段、場景移除與延後刪除，也保留正常完成及獎勵的正向驗證。

## 建置與驗證

C++ GDExtension 建置為 bin/road_graph.editguard.*，避免覆寫先前已載入的 DLL；Windows／Web 各自使用 debug／release 版本。SDK 與重新建置方式見 `native/README.md`。新擴充需重新啟動 Godot 後載入。

```powershell
./tools/build/build_native.ps1 -Platform windows -Target template_debug
godot --headless --path . --script tests/maps/tile_placement.gd
godot --headless --path . --script tests/navigation/portal_graph.gd
godot --headless --path . tests/cards/cards.tscn
godot --path . tests/cards/card_preview.tscn
```

`tests/native/portal_graph.cpp` 可獨立以 C++17 編譯；測試包含圖片配置、寬區入口、障礙兩側、外部支路、開口端點、2×2 換道、9×9 交會點迷宮、50×50 全滿，以及 3000 張隨機圖對照獨立障礙 flood-fill。

`tests/native/portal_routes.cpp` 以窮舉小圖核對所有最短路、距離、方向與計數，並測試多入口、障礙邊界、50×50、計數溢位與共用距離表。

`tests/native/diverse_routes.cpp` 對五節點圖的 25,600 組起終點以 simple-path 窮舉核對原圖最佳成本，驗證共用橋、反向繞行、非對稱成本、無重複節點、門檻與工作預算。`tests/navigation/route_planner.gd`、`tests/navigation/tile_costs.gd`、`tests/enemies/troop_profiles.tscn`、`tests/navigation/multiple_starts.tscn` 驗證實際地塊行程、局部同成本抽樣、設定失效、多起點與操作。

一次性尋路效能場景與歷史原始輸出已清除；`tests/navigation/navigation_optimization.gd` 與 `tests/native/tile_costs.cpp` 保留現行核心回歸。舊 ST／Yen／detour 演算法與失效測試也已移除。

## 更新模型

修改 `assets/models/tiles/` 的來源場景後：

```powershell
godot --headless --path . --script tools/assets/build_tile_library.gd
```

只更新模型庫，保留地圖。只有要重設示範直橋時才加 `-- --demo`，它會覆寫 `scenes/maps/tile_map.tscn`。

## Web 匯出

維持 Compatibility／WebGL 2.0、單執行緒與 Extensions Support。需要對應 Godot 版本的 Web GDExtension export templates，以及 `bin/road_graph.*.wasm`：

```powershell
godot --headless --path . --export-release Web build/web/index.html
python tools/web/serve_web.py
```

開啟 http://127.0.0.1:8765/index.html。伺服器提供 COOP／COEP 標頭，正式部署也需對應的跨來源隔離設定。

Web 匯出引用 `assets/web/shell.html`，先以不依賴 WebGL 字型的頁面文字呈現「載入遊戲資源／啟動遊戲」。下載只有在位元組總量已知時顯示實際進度；未知時只顯示狀態。引擎啟動 promise 與 ScreenTransition 首個 `frame_post_draw` 通知都完成後，才在下一個 rAF 移除 HTML 遮罩；不在 canvas 尚未畫好時提早撤掉，也不因提早收到 draw 通知而隱藏啟動失敗資訊。頁面自帶英／繁中初始文字，沒有額外字型下載依賴。


## 設定頁面

`settings_page.tscn` 使用全畫面透明 Control，process_mode 為 Always，直接加入 LevelHUD 的 CanvasLayer；與暫停選單共用主 viewport／canvas 及文字採樣，不經過 Window／SubViewport 的額外合成。頁面本身仍是可獨立重用的場景，不負責暫停、恢復或存取鏡頭，呼叫者決定開啟時機。

左側分類使用獨立 ScrollContainer，中央選項以 setting_row.tscn 排列左側 key 與右側 value，右側固定顯示原生垂直捲軸。全畫面根節點吸收內容外的滑鼠事件；中央 Panel 隨視窗尺寸調整至 90%，最大 1120×720，保持原有留白與整數座標置中。外觀由 assets/themes/settings.tres 與場景設定。

`configure(definitions, current_values)` 接受分類字典陣列及目前值；每分類有 label、options，每個選項有 key、label、kind（radio／checkbox；舊 dropdown 也映射為文字 radio），選擇型另外提供 choices（label、value），可提供 default。畫面保存獨立副本，發出 option_changed(key, value)，不存取關卡或修改引擎。radio 使用 ButtonGroup 保證互斥；切換分類保留值並回到清單頂部。open() 開啟，close() 關閉並發出 closed；主畫面與暫停選單使用同一介面。

`game_settings.gd` 是獨立引擎介接層，提供分類資料、讀取與套用設定：一般分類的語言文字 radio（繁中／英文）、顯示分類的 MSAA radio（關閉／2×／4×）、音效分類的全部靜音 checkbox。LevelHUD 負責連接 signal、提供目標 viewport，並依 visibility_changed 協調宿主的背景輸入鎖定。設定立即生效，目前沒有磁碟持久化；不要描述為已完成設定存檔。新增功能只需擴充資料及介接層；新控制項種類才修改列元件。

`tests/levels/pause_menu.tscn` 包含實際渲染／滑鼠操作，驗證分類、互斥、套用、翻譯更新、合成長清單、空白邊緣及清單上的點擊／拖曳／滾輪隔離、鍵盤啟用／焦點限制、返回／Esc 保持暫停，以及重新開啟與重開關卡。亦核對頁面與暫停選單的 viewport／canvas 相同，將設定文字與同位置、同字型／字級／顏色的主 HUD Label 逐像素比對。截圖放 `.godot/test-results/settings/`。
設定頁面以 StyleBoxEmpty 保持背景透明，不建立子視窗或離屏渲染目標。LevelHUD 使用原本 WhiteVeil，在 0.2 實際秒內增加到 Settings Veil Alpha（預設 0.82，至少保留原場景透明度），返回時恢復原值；不另加白色面板。設定開啟時隱藏起點開波對話框，避免背景按鈕干擾文字。

頁面內的分類、返回、radio 與 checkbox 共用 `scenes/settings/components/settings_button.tscn` 及 `scripts/settings/settings_button.gd`。透明 StyleBoxEmpty 保留命中尺寸，hover 僅將文字變黑，保留 Noto Sans TC Light 字重、原尺寸、布局及命中範圍，移開恢復原字色，不縮放。共用場景與暫停文字按鈕均啟用 oversampling_with_scale，讓字型採樣隨視覺縮放調整；NotoSansTC-Light.ttf.import 的 oversampling 維持 0.0，恢復依 viewport 自動取樣。固定 4.0 的全域改動在實際介面造成一般文字過細與破碎邊緣，已撤回；hover 不再縮放文字，不改動全域字型匯入倍率。視覺改善需比較實際畫面，不能僅以功能回歸通過判定。維持原本 Light 字重、字級、實際 scale 與命中範圍，沒有新增子 viewport 或位圖文字快照。一般按鈕焦點底線依實際時間以 smoothstep 由中心向兩側漸展，離焦反向收回，Focus Seconds 預設 0.2。分類、radio 與 checkbox 的底線只依 button_pressed 表示值；取消選中即收回，即使按鈕保留鍵盤焦點也不維持底線。radio 不使用圓點，checkbox 是純文字開關，不畫方框、勾或圖示，仍使用原生 Button 切換及 ButtonGroup 互斥。所有標籤與按鈕保存翻譯 key，由 Godot 原地更新翻譯；切換語言不重建列或分類、不搶回分類焦點，保留當前選項實例與底線動畫進度。白色遮罩與底線動畫皆不受暫停或倍速影響。右側捲軸採細線軌道與窄滑塊，hover 僅改色。主暫停選單維持既有動畫；上述樣式限定在設定頁面。
設定頁面顯示時攔截非 UI 鍵盤操作與未處理事件，Tab／Shift+Tab 在頁面可見、可用的控制項內循環，方向鍵也不能離開頁面；Esc 僅關閉設定並吞掉該次輸入。透明根 Control 用 GUI 事件攔截全畫面點擊，讓列元件、捲軸及 hover 仍可正常處理事件。

鏡頭的 `set_navigation_locked(bool)` 是通用宿主介面，與設定頁面沒有直接引用。LevelHUD 監看頁面可見性，在開啟時鎖定鏡頭並清掉已有角速度／按下手勢；鎖定也拒絕延後重播點擊。HUD 在設定顯示期間不執行原暫停輸入路由，讓頁面先處理 GUI。返回、程式解除暫停或 HUD 離場時解除鎖定；既有卡牌／交易鎖定與 SceneTree 暫停持續生效。`camera_orbit` 覆蓋設定返回後的正常鏡頭、卡牌及商店操作；`level_teardown` 覆蓋設定開啟時移除 HUD 的鎖定清理。
## 共用模型材質

道路、木橋、塔、端點非發光零件及正式三兵種共用 `assets/materials/solid_color.tres`。純色與原頂點色相乘後寫入 COLOR；CUSTOM1 保存原本粗糙度／反光，包含亮木板的差異。CUSTOM0 保存帶方向的四肢擺幅、起伏、側擺及關鍵影格間隔數 + 1；w=0 的靜態模型不執行步態。每幀相位與 blend 提交方式不變，不為材質整合新增節點、逐模型材質或移動時計算。來源 CPU 動畫仍保留，GPU Model 擺幅變更需重新烘焙。詳見 [材質格式與工具](../assets/materials/README.md)。

轉換工具直接處理目前保存的場景與 MeshLibrary，不重生原型或改路網；保留變換、動畫、項目編號及特殊材質。每格純色面合為一個 surface，柱底另列。雲、柱底漸變／生長、端點發光、透明戰鬥特效與 2D UI 不套用共用不透明材質。啟動仍明確繪製普通 MeshInstance 與敵人 MultiMesh，因為同一材質的不同繪製路徑可能有不同引擎 program。

## 開始選單

F5 先載入 `scenes/menus/boot.tscn`，完成共用顯示準備後以白色轉場進入 `scenes/menus/main_menu.tscn`。啟動場景明確保存相機、方向光、原敵人 renderer 與載入介面，與關卡引用同一份 `assets/data/rendering/level_environment.tres`；沒有關卡、敵群、導航或商店。主選單參考原型的左側徽記／標題／操作與右側折線雲橋構圖，使用目前專案內素材與 Compatibility 渲染。Home 的 VBox、Label、開始／設定／離開按鈕、SettingsVeil 與共用 SettingsPage 均明確保存於場景，文字仍使用翻譯 key，透過主 CanvasLayer 繪製；按鈕沿用設定頁的 Light 字重、僅變黑、不縮放的 hover 與底線互動，開始／設定／離開使用相同的青灰色一般狀態、黑色 hover 與深青色焦點，不為開始按鈕單獨覆寫金色。

`scenes/menus/components/menu_stage.tscn` 是純顯示場景，明確保存 58 個道路模型實例、固定石柱、起終點、Camera3D、光源、Environment 及三張雲層 PlaneMesh。沒有 GridMap、路網建圖或遊戲控制器，不依賴原型專案路徑。可直接在 3D 編輯器移動／替換模型；Bridge 的 0.8 秒浮起與 Home 的 0.6 秒淡入由場景 AnimationPlayer 保存。相機無遊戲鏡頭輸入腳本。專用 `assets/shaders/menu_cloud_layer.gdshader` 重用共用噪聲，降低透視遠景的高頻紋理並漸淡到 Environment 色；其他兩層雲採低透明度，沒有體積霧或 Forward+ 依賴。

`scripts/menus/main_menu.gd` 只連接明確節點的意圖與場景切換，沒有在執行時建立 UI／地形。開始遊戲開啟選圖頁，在原頁按「下一步」把描述區替換為本局設定，確認「開始作戰」後一次性交接選中 Level Resource，透過共用 level.tscn 執行；有重複點擊保護，回到 1x、未暫停的第一波準備。沒有存檔時不顯示繼續遊戲。正式關卡仍可直接以場景執行。

開始選單實例化共用設定頁，透過同一個 GameSettings 介接層讀取／套用目前 viewport 設定。開啟設定時隱藏 Home，以實際 0.2 秒加強白色遮罩；設定頁攔截全畫面滑鼠與鍵盤焦點。返回／Esc 還原選單並將焦點交給設定按鈕，選單背景雲層持續顯示。語言、MSAA 與 AudioServer 靜音於本次執行跨關卡切換保留，沒有新增磁碟保存。桌面離開會關閉遊戲，Web 隱藏離開項目。

`tests/menus/main_menu.gd` 以 SceneTree 測試實際選單、三種視窗尺寸、顯示橋景與按鈕取景、共用設定、雙語、開始遊戲的真實場景切換及進入後的暫停設定。截圖寫入 `.godot/test-results/menus/`。Web 測試匯出工具依目前 main_scene 欄位替換測試入口，不綁定舊關卡入口。
### 地圖選擇

`scenes/menus/map_selection.tscn` 明確保存標題、徽記、地圖名稱、切換箭頭、索引、描述、關卡規模、固定本局選項與返回／下一步／開始作戰按鈕，使用主 CanvasLayer，不建立子 viewport。風格沿用透明背景、淡青文字、Light 字重、僅變黑、不縮放的 hover、底線與 0.35 秒淡入。返回／下一步／開始作戰均沿用共用按鈕的一般青灰色、黑色 hover 與深青色焦點，不設定金色的一般狀態覆寫；失焦及底線收回時回到一般青灰色。中間留給正交地形預覽；頁面沒有卡片填色或額外彈窗。單張地圖的左右箭頭使用透明停用樣式，只有多張時才啟用循環切換。

選圖資料自動掃描 `assets/data/levels/` 及子目錄的 LevelDefinition，使用 ResourceLoader.list_directory 相容匯出後的 remap。Level 自己保存穩定 ID 與 Required To Complete Levels，標題／描述 key 由 ID 推導；不需單獨的選單 Resource 或遊戲場景。目錄產生 MenuMapDefinition 作為暫時顯示資料，ACT／波次數直接由 Level 計算，獨立測試場景不列入。`scripts/menus/map_selection.gd` 只更新固定控制項、選擇索引及流程步驟，發出 map_changed／launch_requested(definition, run_options)／back_requested；主選單協調預覽顯示、相機與真正關卡切換。

`scenes/menus/components/map_preview.tscn` 是單一延遲載入的預覽宿主與正交相機。選中時直接實例化該 Level 的 terrain，保留道路與端點。切換先釋放舊地形，不同時建立所有地圖。副本在進樹前移除腳本並停用處理與碰撞；不初始化關卡、交易、路線規劃或波次。格子範圍在換地圖時量一次，視窗改變只重算相機尺寸。Top Clearance／Bottom Clearance／Horizontal Fraction 可在 Inspector 調整相機為 UI 保留的取景空間，Zoom 以自動取景為基準縮放顯示。相機俯角維持 45°，X 較長時水平旋轉為 0°、Z 較長時為 -90°，使主要長軸水平；場景明確設定 Zoom 為 1.0、Bottom Clearance 為 280px，預覽比原 1.25 倍縮小 20%；Footer 寬 900px、上緣距畫面底部 265px，地圖名稱／資訊區較前版上移 60px，底部操作仍靠近原畫面下緣，不改動正式地形。

選圖時隱藏主選單的裝飾折線橋，切到正交相機與真實初始地形；在選圖步驟按返回或 Esc 還原原透視橋景及開始遊戲焦點。本局設定中的返回或 Esc 先回選圖並保留暫定值；選圖再返回才還原主畫面。完成兩步並按開始作戰後，以選定選項的關卡場景載入，保留語言、MSAA、靜音及第一波手動準備規則。新增選項與前置 ID 的設定見 [關卡說明](../assets/data/levels/README.md)。

LevelCatalog 建立 ID 字典及去重鄰接清單，以 Kahn O(V+E) 檢查前置關係並逐層產生拓撲列表：先列出無前置的根，每層按 ID 字典序排序，整層完成才進入下一層。所有前置先於後代，同層不受父節點、目錄掃描或通關狀態影響；含排序的完整建立成本為 O(V log V + E)。重複 ID、缺失前置、環與錯誤分支的後代鎖定，錯誤項目留在正常 DAG 後按 ID／資源路徑排列，其他分支正常。解鎖為全部直接前置已通關，通關事件以字典刷新狀態，不在每幀走圖。未解鎖可預覽，顯示缺少的前置名稱，下一步／開始與宿主啟動均攔截；草稿顯示資料尚未完成。空目錄顯示沒有關卡。

LevelProgress 只在最後一波完成時保存穩定 Level Id 到 user://level_completion.cfg，跨次啟動保留；Web 為網站的持久檔案系統。只保存通關集合，不保存進行中局面；壞檔讀取不覆寫既有記憶體集合。LevelLaunch 只作一次性資料交接，在 LevelSession 進樹前套用，沒有改寫預設 PackedScene／Resource；重開關卡重新交接目前 Level，失敗及返回主選單清理待交接。

`tests/menus/main_menu.gd` 也驗證開始遊戲不直接進關卡、三種尺寸的地形取景與操作、唯讀地形一致性、單地圖箭頭停用、雙語資訊、返回／Esc 相機恢復與選定 Level 的真正切換。選圖截圖位於 `.godot/test-results/menus/map_selection_*.png`。

### 本局設定

本局設定與選圖共用同一個 MapSelection、地形預覽與主畫布。頁面用 MAP／OPTIONS 兩個步驟，在 Footer/Column/Details 的固定 104px 高區域內切換 Info 與 RunOptions；前者保存索引、描述及 ACT／波次數，後者使用水平排列的兩個 CenterContainer，各自包住一個 VBoxContainer，形成兩欄、兩排，左上難度、右上起始手牌、左下額外事件、右下暫定提示，欄間距 64px、排間距 24px，兩欄各 418px；選項文字 18px，提示 12px。置中的是每欄完整的 VBox 內容，內部 HBox 與提示文字均左對齊；_align_option_keys() 在就緒與翻譯更新時依該欄最寬的標籤設定共用 Key 寬度，對齊選項起點。Key 的 OptionLabelPadding 保留左側 12px 透明內距。Details/Divider 在中央以 1px 淡青 ColorRect 分隔兩欄，只於選項步驟顯示且不攔截滑鼠。Heading 的標題與三段流程標示保持原樣。各單選列在頁面就緒時綁到同一個實例內 ButtonGroup，避免共用按鈕範本各自複製群組後失去互斥。操作沿用透明文字、hover 僅變黑、不縮放與選中底線；不另外生成設定頁、對話框或視窗。

第一步按下一步只展開本局設定，不載入關卡或使用全畫面過渡；返回／Esc 在設定步驟只回選圖，保留原控制項、地圖與值。_set_step() 保留仍可見控制項的焦點，滑鼠點返回時讓返回底線持續展開，原開始按鈕正常收回；僅在焦點不存在或原選項已隱藏時才把焦點交給下一步，避免一次點擊造成焦點往返與底線反轉。切換時不調整 Footer 位置、相機、地圖倍率或頁面標題；地圖名稱與箭頭保留原位置，設定步驟只停用換圖操作。底部 Actions 使用場景中固定位置／尺寸的按鈕，只把下一步文字改成開始作戰，避免文字變長後推動返回按鈕。CompactOption 是共用 Theme 的 Button variation，使用 18px 字級、32px 最小高度及原本色彩／hover；選項底線的 Underline Inset 為 1px，其他共用按鈕仍為 5px。get_run_options() 每次回傳獨立字典，包含 difficulty、starting_hand、extra_events，最後按開始作戰才隨 launch_requested 發出。這些選項目前僅為可操作原型，頁面明示尚不影響戰局；主選單接受啟動意圖但不把暫定值套用到 Level、商店、波次或 GameSettings。新主畫面實例恢復標準／隨機／關閉事件的預設值。

實際渲染回歸另比較切換前後固定節點的位置與尺寸、相機 transform／size／v_offset、描述區內容不溢出，並驗證同場景與 viewport、三種尺寸、單選互斥與文字開關、雙語切換、逐步返回並保留值、最後一次性啟動意圖與新局預設；截圖為 `.godot/test-results/menus/run_setup_*.png`。

### 白色畫面過渡

選圖最後按「開始作戰」時使用 `ScreenTransition.change_scene(path, &"prepare_for_play")`。完整白畫面呈現後先顯示「載入戰場」，等待 UI 繪製才同步載入目標；此階段沒有可靠百分比，因此隱藏進度條。一般主畫面／選圖切換及返回主畫面維持原本過渡。

可選準備契約讓轉場層暫存並停用新場景的 processing，呼叫指定方法並接受 `report(completed, total, translation_key)`；轉場層不讀取 Level、EnemyWave 或 PortalMap。使用方法名稱而非來源節點回呼，避免選單釋放後失效。完成後還原 processing，再淡出白畫面與載入介面；準備失敗或目標離場時回到來源場景。輸入鎖定持續到淡出結束。

LevelSession 依序準備入口圖、第一波獨立兵種／入口的候選池、尚未準備的顯示代表；這階段的總工作數已知，完成一項才推進一格。目前 Frontier 第一波有三個兵種／入口組合，正常啟動後為 4 項；直接開選單、跳過啟動預熱則為 5 項（額外一個共用顯示代表）。耗時不相等，因此條形不是時間估算。候選池只查詢 plan，不分配配額或打亂出發順序。準備期間拒絕開波，完成後仍為手動第一波準備。

`enemies/rendering/display_warmup.gd` 是保留 Resource 與完成紀錄的 Autoload。`enemy_render_signatures.gd` 依有效材質的儲存設定、shader code、紋理身分、每個 surface 的頂點格式及 primitive、一般／MultiMesh、蒙皮／blend shape、陰影與 overlay 計算組合；排除網格形狀、模型名稱、變換動畫及 Resource 名稱。含腳本或非變換動畫軌的場景保守區分。三種正式 GPU 模型共用 shader 與頂點格式，僅 Soldier 作為繪製代表；各自步態參數不產生新的 shader source。啟動場景另以塔底座的純顯示網格實際繪製普通 MeshInstance 路徑，與敵人 MultiMesh 共用材質；因引擎可能依繪製方式分出 program，仍保留兩種繪製代表，不初始化塔或戰鬥。外部場景材質仍保守區分，不宣稱已枚舉引擎所有 shader 版本。

完成紀錄以主 viewport、MSAA、Environment 設定、可見光源種類與陰影配置分組；改設定、新材質或不同配置會重新準備。代表 Resource 保留到執行結束，避免換場景釋放材質；不跨次啟動保存 GPU 編譯結果。獨立 `enemy_render_warmup.gd` 將代表放在目前相機前，使用原 renderer 推進模型／步態與頭頂狀態並等待實際 draw，再移除；目標 renderer 中途離場則取消，未完成項目不記入快取。代表不進入正式敵群，不操作行程、戰鬥或 RNG；不重建 256 個敵人，也不增加正常移動的工作。Headless 只完成工作計數；直接 F6 執行關卡不經選單準備契約。新特效或執行期更換材質未保證涵蓋；單個同步動作仍可能令載入 UI 暫停，沒有假動畫進度。

載入外觀明確保存在 `scenes/interface/components/loading_display.tscn`，由啟動及轉場共用，為置中標題、階段文字、2px 細線 ProgressBar 與完成數，支援英／繁中。`tests/menus/startup_loading.gd` 驗證啟動代表去重、透明材質不誤合併、資源保留、關卡重用及 MSAA 改變補漏；`tests/menus/scene_loading.gd` 驗證直接開選單的補漏路徑、未知／已知進度、代表繪製、RNG／波次隔離、正常開波、清理及失敗／取消恢復；失敗案例會產生預期轉場錯誤訊息。

Boot 的初始階段文字直接保存在場景，依序呈現整理資源及準備角色／狀態。預熱完成後呼叫 `ScreenTransition.change_scene(path, &"", &"ui.loading.menu")`，通用轉場在開始時即接手顯示「準備主選單」，先實際畫出文字才換場景，並保留至首次主選單繪製及淡入結束；來源介面在成功交接後才隱藏。第三個參數僅是可選翻譯 key，不讓轉場層依賴主選單規則。未知工作量清掉進度條及計數，避免顯示舊的完成值。一般未指定訊息的短過渡不變。

主畫面與地圖選擇雙向切換、確認本局設定並進入遊戲，以及暫停選單「回到主畫面」，共用 `scenes/interface/screen_transition.tscn`。它是持續跨場景存在的 ScreenTransition Autoload，明確保存頂層 CanvasLayer 與全畫面白色 ColorRect；根節點 Duration 預設 0.5 秒。`scripts/interface/screen_transition.gd` 的 `run(action)` 在白畫面下執行呈現切換，`change_scene(path)` 切換真正場景，透過 started／covered／finished(error) signal 提供生命週期；呼叫者決定目的地及遊戲狀態，過渡層不引用選單、關卡或鏡頭。

前半段 0.25 實際秒以二次 ease-in-out 變白，等待完整白畫面完成繪製後才執行切換，接著以 0.25 秒淡出；場景載入時間額外保持白色。Tween 忽略 Engine.time_scale 並在 SceneTree 暫停時繼續。過渡接受後立即攔截輸入，拒絕重複切換；Autoload 維持在 root 的最後一個子節點，使其先於場景的 GUI 前置輸入處理器阻擋滑鼠、鍵盤與鏡頭操作。新場景加入後重新維持順序，淡出完成才解除遮罩與輸入鎖定。主選單與暫停宿主不再用 Button.disabled 表示離場鎖定，保留文字、焦點底線及 hover 動畫的正常呈現；重複呼叫仍由 _starting／_returning_home 與 ScreenTransition.active 防護。暫停 Theme 另明確指定透明的 disabled StyleBoxEmpty，避免未指定時回退到 Godot 預設灰色底框。

從暫停返回時，LevelHUD 立即標記離場狀態並透過通用 navigation lock 清掉已有鏡頭手勢；舊關卡保持暫停及零模擬速度，直到白畫面下移除。主畫面就緒時恢復未暫停與 1x；再次開始建立新關卡、初始金幣、手牌及第一波手動準備，語言、MSAA 與靜音沿用本次執行設定。切換失敗也會淡出遮罩，由宿主恢復可操作選單。

`tests/menus/main_menu.gd` 驗證完整往返、每次 covered 的白色像素、過渡期間 Esc／重複操作隔離、4x 戰鬥暫停返回、舊關卡釋放與再次開始的全新進度。白畫面截圖與結果寫入 `.godot/test-results/menus/`。


### 手動調整流量中心線外觀

在 Godot FileSystem 開啟 `scenes/navigation/road_flow_renderer.tscn`，選根節點 RoadFlow，Inspector 展開 **Flow Appearance**：

| 欄位 | 預設 | 用途 |
| --- | --- | --- |
| Highlight Color | RGBA (0.953, 0.914, 0.804, 0.96) | 局部亮段顏色；RGB 改色，A 控制亮段對比與強度。 |
| Highlight Length | 0.50 | 亮段長度（格）；越大亮段越長，間隔依最長完整行程步數配置，不會每兩格重複。 |
| Line Width | 0.055 | 高流量線寬，單位為格；增大更粗，低流量自動較細。 |
| Flow Speed | 0.28 | 筆觸滑行速率；0 停止筆觸，值越大越快。 |

儲存場景後重新 F5／F6 即套用。這些 export 值會在每個 renderer 就緒時寫入其獨立 ShaderMaterial，請優先在根節點調整，不要只改 Material 的同名參數，否則開始遊戲時會被 export 值覆寫。Shader 原始碼位於 `assets/shaders/road_flow.gdshader`；phase_offset 供像素測試使用，不需手調。中心線的樣式改變不影響配額或實際敵人行程。

米白筆觸不保留任何固定底線。只有有限長度的柔和細線沿道路前進，前後端以 smoothstep 完整漸淡至透明；不使用 glow／emission。渲染器從已分配的完整行程保留每次到達相位，不修改路線、配額或 RNG；全體／篩選重用同一 shader TIME，但分別使用各自完整行程的相位表及週期，間隔依最長完整行程設定，避免每兩格重複一個亮段。Highlight Color／Highlight Length 控制筆觸外觀，Line Width／Flow Speed 的場景覆寫仍優先。

Highlight Length 的 Inspector 滑桿範圍為 0.10～20.0，Flow Speed 為 0～10.0；兩者皆允許直接輸入更大的數值。增加長度時，筆觸週期至少為長度的兩倍，保留前後透明區間，避免長筆觸重疊成永久底線。這些範圍不會重設場景既有數值。

## 效能量測的分段與對照

### 顯示預熱與實驗分支

舊版由 EnemyWave 自動執行的兵種顯示預熱、LoadingOverlay 場景、processing 鎖定及 presentation_ready／presentation_prepared 已移除，避免與已 PR 的 `feat/outer_game_ui` 啟動預熱及地圖轉場載入重複。目前統一由 DisplayWarmup、Boot 與 ScreenTransition 負責顯示準備；本分支維持路線建池、配額與移動資料優化。

正式 F5 入口經 Boot 與主選單；直接 F6 執行關卡或 mixed_256 試驗場才略過選單預熱。開波維持道路計畫、start_allowed、戰鬥／ACT 階段及 1.5 秒正式開場等待等原有檢查。移除的是顯示載入流程，不是 C++ 候選池或其快取；不能把歷史預熱報告當成目前的首次出兵表現。

LevelSession 的準備期 signal 同時包含載入鎖定，所有入口按鈕、情報及中心線在 prepare_for_play 期間一起停用並於完成後恢復；共用設定頁也隱藏全部入口，不只第一個。StartWaveCallout 的 NextWaveIntel 實例明確保存 anchors 布局模式及標題下方 32px 起點，布局由宿主場景提供，不依賴被實例化場景根節點的偏移，避免 Web 匯出後清單回到零偏移、覆蓋標題。

`tests/enemies/mixed_256.tscn` 保留報告相同負載供手動重現，啟動時建立合成地圖、16 塔與三兵種測試副本，完成建池後等使用者按開始，不含自動量測。清場重開使用正常敵人離場路徑，等待刪除完成並清除飛行攻擊／效果，再以相同 EnemyWave 與候選快取建立下一批；不重新建立地圖或偷偷重載 renderer。「重新載入場景」則重建整個場景，Web 頁面冷啟動仍須重新整理瀏覽器。操作入口見 [測試說明](../tests/README.md)。

P99 判因採固定 simulation delta／相同暖機與取樣步數，核對完整路線、末端戰況及逐幀工作計數；wall 幀間隔仍直接量測。以 process_priority 前後的 Time.get_ticks_usec 探針分開節點更新、戰鬥、模型／避讓、狀態及 pre/post draw，viewport CPU／GPU 計時另列。Performance.TIME_PROCESS／TIME_PHYSICS_PROCESS 是定期更新統計，不代替逐幀分段值。固定工作量校準、硬體計數及同版本互比可辨識環境吞吐量變化；保留全部有效慢樣本，不把校準後或挑選較快輪次當作遊戲修正收益。調查證據與範圍見 [P99 判因報告](../reports/p99_investigation_2026-10-22.md)。

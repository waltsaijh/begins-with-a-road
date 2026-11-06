# 20＋1 塔體、射程與放置預覽

後續道路修正（2026-11-03）已移除逐格重複木板與兵營補體，保留原武器／基座、等級零件並重新貼地。裁切規則與當次驗證見 [道路修正](road_visual_and_placement_refinement.md)；下方測試／限制是先前20＋1階段的歷史證據。


核對日期：2026-11-03。工作目錄 `D:\games\begins-with-a-road-routing`，分支 `experiment/routing-sandbox`，HEAD `e87f8288cb97b85d71c4b38dcb7dc7a67754bb63`（完整 HEAD 以 Git 為準）。在既有未提交施工／編輯器成果上接續修改；沒有 commit、merge、rebase、reset、clean 或 push，未操作 main worktree。

## 正式來源

來源是 [原有 catalog](../assets/data/tower_tiles/user/catalog.tres) 的「基礎版」，穩定組合 ID 為 `user_4ea591eaf8db87325145ea223ad529af`，新增 `variant_group = base` 標記。組合內原有二十份幾何、名稱、權重及 ID 均直接沿用；另明確加入既有 `barracks_01.tres`。沒有複製一份正式地塊。

五種塔的 TowerDefinition 設 `preset_group = base`；`preset_candidates()` 從標記組合取得成員，依 catalog 的最新權重抽取。空組合、封存、缺檔及無效權重不回退舊池。兵營仍引用既有唯一配置。主遊戲初始手牌、商店與用 `first_tile_preset()` 補牌的測試皆經這個入口；商店的獨立測試覆寫池仍優先。切換 Playground 的其他測試組合不改正式來源。

編輯器仍列出原內建候選與自建檔；儲存同一 ID 會刷新 Resource 快取，新卡使用新幾何，已持有卡／已建塔保留快照。組合改名保留 base 標記，另存新組合不自動取得標記。基礎版的兵營成員明確豁免該組的排除內建選項，其餘組合規則不變。編輯器新增其他形狀不會自動進入正式組合。

| 塔 | 基礎版名稱 | 實際塔體 |
|---|---|---|
| 哨塔 | 直線、角落、T型、對角 | 每份 1×1 |
| 弩砲 | 旁直線路、彎曲路、凹字型、直線路 | 1×2 主弩架＋左／右側 1 格裝填區 |
| 側舷砲（遊戲名：空艇舷炮） | 直路、兩側、直路反、前後 | 每份 1×2 |
| 十字火力（遊戲名：交叉火力） | 直路、轉角、兩側、對角 | 每份 2×2 |
| 迫擊砲 | L型、兩側、廣場、斜廣場 | 每份 2×2，錨點可在不同角落 |
| 兵營 | 原有兵營配置 | 1×1；既有道路及合法駐點限制 |

完整資源引用與 ID 見文末表格。

## 外觀與等級

`scripts/towers/body_visual.gd` 共用低面數造型組件，依實際 footprint 建立平台與兵器，使用既有 `solid_color.tres` 材質及頂點格式。同一形狀快取 PackedScene，靜態零件按父組件合併 mesh；不逐幀重建，不逐塔複製材質。視覺組件與砲口沿同一朝向旋轉，保留原有音效與後座。

| 塔 | Lv1 | Lv2 | Lv3 |
|---|---|---|---|
| 哨塔 | 保留原木架與可瞄準弩機 | 後側高支架及橫樑 | 旗幟、旗桿與底座包邊 |
| 弩砲 | 跨兩格的雙軌、輪架、絞盤、前弩臂；第三格放箭匣 | 裝填區兩側護板 | 上層第二組弩臂 |
| 側舷砲 | 長船殼、甲板、雙側六砲口、駕駛艙與煙囪 | 雙側護欄 | 桅杆及帆旗 |
| 迫擊砲 | 整座 2×2 平台、中央八角砲座、斜砲管、角落彈架 | 側盾 | 砲管加固環及平台橫向支架 |
| 十字火力 | 2×2 基座、中央核心、四向發射臂 | 四角護柱與砲臂裝甲 | 中央尖塔及四向上層組件 |
| 兵營 | 保留原模型 | 沿用原模型 | 沿用原模型 |

升級切換現有 Level2／Level3 子組件的可見性，保留塔、瞄準節點、砲口、血量比例、冷卻、部署與後座狀態。哨塔因遺物升到 Lv4 以上，數值照原曲線，視覺維持 Lv3。

## 攻擊幾何

`TowerBodyGeometry` 把 preset 格子轉成「相對塔錨點、已扣除 facing_steps」的局部座標。DefenseTower 在建立時快取該資料；放置預覽、威脅／路線預測與戰鬥使用同一來源。原有整數錨點繼續識別單一塔與占格，攻擊中心可以在半格位置，不搬動塔的邏輯身份。

- **迫擊砲／十字火力**：範圍與炮座以整個 2×2 中心為準，四角錨點均正確。保留原半徑、傷害、間隔及命中方式。圓形目標仍按敵人的實際水平位置測距；導航威脅將同一圓形按格中心取樣。炮口跟隨完整平台；迫擊砲落點仍是發射時目標實際位置，非追蹤／預瞄。
- **側舷砲**：基礎 footprint 為 `(0,0),(0,1)`，左右各 `x=±1…±3, y=0…1`，合計十二格；四向旋轉同步作用到船身、砲口、預覽及索敵。不涵蓋船首／船尾。右舷遺物與巡航沿用原機制，巡航只平移一次攻擊錨點，固定底座不移動，預覽與威脅顯示巡航可達聯集。
- **弩砲**：由最長縱向塔格列選主弩架，等長時優先靠近錨點；四份 L 形都沿相同 `x=0` 主軸向前射四格。側邊裝填格不把射線拉偏。砲口位於前端而非整個 L 形的重心。
- **哨塔**：維持目前 Resource 的單格錨點與範圍，包括支援攻擊倍率。
- **兵營**：沒有改變生成數、駐點、接戰或路網檢查。不能放在只有單一通道且會封路的位置；需先擴建可繞行道路。

模型位移仍只改視覺；建議正式基礎版保持零位移。沒有加入視線遮擋或重新平衡傷害、攻速、價格及成長。舊空 footprint 配置繼續使用原有單格模型／攻擊幾何。

## 放置預覽三層

1. **塔體**：青色實際占格與帶光照／深度預通道的完整塔模型 hologram，覆蓋原道路的塔格用橙紅提醒；綠／紅輪廓表示是否合法。
2. **道路**：米金色獨立格面；合併道路為淡青。不繪製道路接口、中心短線或方向筆畫，編輯器格網仍保留接口操作。
3. **攻擊範圍**：稍高於道路的淡金半透明連續色面。圓形塔畫 96 段圓盤與外圈；格形塔畫無縫聯集，只在外露邊畫輪廓，內部沒有格線或格間空隙。

保留拖放、R／右鍵旋轉、非法落點、升級提示與取消；射程只隨候選、方向或失效更新。升級預覽顯示下一級、最多 Lv3 的造型，不新增道路。`card_preview.tscn` 原有 range_fill_color／range_border_color 仍可調整。

## 人工驗收入口

可直接在 Godot 執行，也可使用 PowerShell：

```powershell
& C:\tools\Godot.exe --path D:\games\begins-with-a-road-routing res://tests/tower_tile_editor/playground.tscn
& C:\tools\Godot.exe --path D:\games\begins-with-a-road-routing res://tests/tower_visuals/gallery.tscn --resolution 1600x1100
```

Playground 右上選「基礎版」，選塔種與配置，按「補入選定塔＋配置」。點牌／拖牌、R／右鍵旋轉、點地圖提交。每種塔依序測四份配置；同種再補兩張，放到原塔任一格升至 Lv2／Lv3。開始波次仍點入口菱形。兵營要先有可繞路的地面與連通駐點。

Gallery 是唯讀展示：`1–6` 切塔種、`R` 旋轉、`A` 切換射程；四列為配置，三欄為 Lv1／2／3。它不取代實際遊戲驗收。截圖在 `.godot/test-results/tower_visuals/`，包含等級表、射程表與六塔實際預覽。

## 本次驗證

- `tower_visuals/rules`：1722 檢查通過；20＋1 組、全部二十份四向真實提交、幾何／預覽／威脅、Lv2／Lv3 不改道路與冷卻／血量比例，以及實際商店抽到全部21份。
- `tower_visuals/combat`：104 檢查通過；四向真實目標邊界、砲口、實際傷害、迫擊砲飛行快照、巡航第二排範圍與右舷限制。
- 既有 headless 通過：tower_tile_editor/rules（458）、cards、tile_presets、combat、tower_restoration、relics stacking／mechanisms（113）／rewards、construction geometry（51）／regression（54）、traffic integration（104）、balance rules（67）。
- 真渲染通過：tower_tile_editor/input（48，含兩波）、combinations_input（29）、card_drag_placement。tower_visuals/input（118）透過真實 selector／點牌／R／放置／升級與開波驗證全部21份；兵營使用測試專用既有道路廣場，不繞過正式放置檢查。
- Frontier 正式 level：180 幀 Compatibility 渲染啟動通過。Gallery 已產生12張對照圖並人工檢視（由 agent 檢視，非使用者試玩）。
- 最後 headless editor import 無腳本／資源解析錯誤；本機仍無權建立 Godot 的使用者設定目錄，亦有 shader cache 目錄警告，因此不把 import 當作完整 Editor 互動驗收。

初輪舊測試的單格中心、方塊高度、直接候選陣列及相同 Resource 身份假設已更新；純遺物機制 fixture 明確使用原單格配置，新多格戰鬥由獨立 suite 驗證。初輪失敗 log 保留於 `.godot/tower-visual-*.log`，最終結果另存 `*-final.log`，不把失敗執行標為通過。

## 限制

本次是接入與幾何一致化，不代表新大塔體的數值平衡已驗收。未跑 Web 匯出／瀏覽器、Windows release、效能量測、真人操作或 Frontier 全十五波；沿用既有 C++ DLL，未修改原生核心。

目前造型由共用 GDScript 組件產生並快取，不是每份配置各自一套人工 DCC 模型。正式二十份已驗證；任意新畫的不規則形狀使用同一套邊界／主軸適配，極端凹形或寬短船體仍需美術檢視。兵營保留原模型；後續道路修正已移除自訂多格兵營的 footprint 補體，地面由 TileVisuals 連續繪製。兩種圓形塔的連續命中邊界與格中心威脅取樣是不同精度，保留原世界座標戰鬥方式。

## 資源對照

| 塔 | 名稱 | 共用檔案 | 權重 |
|---|---|---|---|
| mortar | L型 | [user_6657902a4f1b0f4ce0c1b3be3c808484.tres](../assets/data/tower_tiles/user/user_6657902a4f1b0f4ce0c1b3be3c808484.tres) | 2.0 |
| mortar | 兩側 | [user_4df6099dda6ec376c3ac74aa29b0a57b.tres](../assets/data/tower_tiles/user/user_4df6099dda6ec376c3ac74aa29b0a57b.tres) | 2.0 |
| ballista | 旁直線路 | [user_21e2b9c1eb361515971245b701b6fc86.tres](../assets/data/tower_tiles/user/user_21e2b9c1eb361515971245b701b6fc86.tres) | 3.0 |
| ballista | 彎曲路 | [user_38b433d7a19ee4d2ccadb9989d2a8122.tres](../assets/data/tower_tiles/user/user_38b433d7a19ee4d2ccadb9989d2a8122.tres) | 3.0 |
| ballista | 凹字型 | [user_ff896b9edfb3536c4a0fb9ba52971adb.tres](../assets/data/tower_tiles/user/user_ff896b9edfb3536c4a0fb9ba52971adb.tres) | 1.0 |
| ballista | 直線路 | [user_26388afc1a12c270d7cdddbb898b5ec8.tres](../assets/data/tower_tiles/user/user_26388afc1a12c270d7cdddbb898b5ec8.tres) | 2.0 |
| broadside | 直路 | [user_17c8dc78705573a24b5c07ef37567b68.tres](../assets/data/tower_tiles/user/user_17c8dc78705573a24b5c07ef37567b68.tres) | 4.0 |
| sentry | 直線 | [user_b46a4aa7ce037ee15ceb475612745a2a.tres](../assets/data/tower_tiles/user/user_b46a4aa7ce037ee15ceb475612745a2a.tres) | 3.0 |
| sentry | 角落 | [user_af7e5750d9fe8be33a7da3195c85670f.tres](../assets/data/tower_tiles/user/user_af7e5750d9fe8be33a7da3195c85670f.tres) | 3.0 |
| broadside | 兩側 | [user_f903328567eebacb9b1a4ddf20d9eb64.tres](../assets/data/tower_tiles/user/user_f903328567eebacb9b1a4ddf20d9eb64.tres) | 1.0 |
| crossfire | 直路 | [user_889e85b850619a8eb20d0fc7e832bfe5.tres](../assets/data/tower_tiles/user/user_889e85b850619a8eb20d0fc7e832bfe5.tres) | 2.0 |
| crossfire | 轉角 | [user_4643b5ca3ad53500c2bf1cf88473b12a.tres](../assets/data/tower_tiles/user/user_4643b5ca3ad53500c2bf1cf88473b12a.tres) | 2.0 |
| crossfire | 兩側 | [user_f1ca13d7ba6ed8a4a214ee838a00572c.tres](../assets/data/tower_tiles/user/user_f1ca13d7ba6ed8a4a214ee838a00572c.tres) | 2.0 |
| sentry | T型 | [user_fbe8902badb7f20193a2a51725eddd87.tres](../assets/data/tower_tiles/user/user_fbe8902badb7f20193a2a51725eddd87.tres) | 1.0 |
| sentry | 對角 | [user_075bab5d548d3b2e01273fd44b9dfed1.tres](../assets/data/tower_tiles/user/user_075bab5d548d3b2e01273fd44b9dfed1.tres) | 1.0 |
| broadside | 直路反 | [user_87ffb76437702086465eb9587a325201.tres](../assets/data/tower_tiles/user/user_87ffb76437702086465eb9587a325201.tres) | 2.0 |
| broadside | 前後 | [user_258d56751852a0ffc06f6d6133fef2f6.tres](../assets/data/tower_tiles/user/user_258d56751852a0ffc06f6d6133fef2f6.tres) | 2.0 |
| crossfire | 對角 | [user_91f250543edb84d4e68efaf06ad60573.tres](../assets/data/tower_tiles/user/user_91f250543edb84d4e68efaf06ad60573.tres) | 1.0 |
| mortar | 廣場 | [user_4dede9ac87ae5418717f2677d5ed9297.tres](../assets/data/tower_tiles/user/user_4dede9ac87ae5418717f2677d5ed9297.tres) | 1.0 |
| mortar | 斜廣場 | [user_8cddd0320f4136d3a4954e6868e8d398.tres](../assets/data/tower_tiles/user/user_8cddd0320f4136d3a4954e6868e8d398.tres) | 1.0 |
| barracks | 兵營 | [barracks_01.tres](../assets/data/tile_presets/barracks_01.tres) | 1 |

# 已核對的專案建模契約

核對：2026-11-03，分支 `experiment/routing-sandbox`，HEAD `9b9a7f9`，開始時工作樹乾淨。以下為程式／場景事實；Skill 的美術取捨與來源目錄是本次新增規範，不代表既有模型已全部符合新風格。

本文的專案路徑均相對 repository 根目錄。先核對實際檔案，尤其不能用歷史報告覆蓋目前 Resource。

## 格子、座標與高度

| 項目 | 已確認值 | 依據 |
| --- | --- | --- |
| 邏輯格尺寸 | `GridMap.cell_size = (1,1,1)`，地圖在 XZ 平面 | `scenes/maps/tile_map.tscn` |
| 垂直／格心 | +Y 向上，`cell_center_y=false`；局部格心 `(x+0.5, 0, z+0.5)` | 同上、`docs/systems.md` Tile 規格 |
| 格子資料 | Vector2i 的 x 對應世界 X，y 對應世界 Z；需經 map 的 global_transform | `scripts/towers/tower_map.gd` |
| 四向 | 北 −Z、東 +X、南 +Z、西 −X | `scripts/map/tile/tile_constants.gd` |
| 正面 | 武器局部 −Z；右舷為局部 +X | `tower_definition.gd`、`tower.gd`、`restored_tower_visual.gd` |
| 卡牌旋轉 | 每步順時針 90°；格子 `(x,z)→(-z,x)`，Godot Y 軸角度 `−steps*PI/2` | `build_card.gd`、`tower_map.gd` |
| 遊戲顯示路面／塔地基 | Y=0；路肩 Y=0.065，斜面寬 0.045 | `scripts/map/tile/appearance/road_surface.gd` |
| 塔根掛載高度 | `map.map_to_local(anchor) + UP*0.025`，再乘 map.global_transform | `TowerConstants.GROUND_OFFSET`、`tower_map.gd` |

1 格 = 1 Godot 世界單位。本次統一以 Blender Metric、Unit Scale=1、1 Blender unit 對應 1 Godot unit 製作；「1 公尺」是工具尺度約定，不宣稱世界觀的實際建築只有一公尺高。

模型局部底面預設 0，套入現有塔根後會有既有 0.025 的離地量；在 Godot 檢查接觸。如需精確貼地，在外觀子件／wrapper 處理差值並記錄，不更改 GROUND_OFFSET、錨點或全專案高度。端點的 0.0305 Height Offset 是另一套端點規格，不能套到塔。

`scenes/main.tscn` 的 TileMap 有平移 `(-12,0,-0.5)`；正式 LevelSession 會載入所選 Level 的 terrain。勿把此平移或某張圖的世界原點烘焙進通用資產。

`docs/systems.md` 舊 Tile 規格提到道路中心 0.01；目前遊戲顯示層以 RoadSurface 的 0／0.065 為準。地面由 TileVisuals 提供，不能為新塔再鋪一層逐格平台、木板或路面，造成重疊。

## 正式正交攝影機

來源：`scenes/level.tscn` 繼承 `scenes/main.tscn`，Camera3D 使用 `scripts/camera/map_camera.gd`。

| 項目 | 值／行為 |
| --- | --- |
| Projection | Orthogonal |
| 初始 size | 18.5 |
| 執行期 elevation／azimuth | 45°／30° |
| distance | 35；正交下不決定模型畫面大小 |
| focus | 使用中 GridMap 格心的世界 AABB 中心 |
| pose | `focus + (sin(a)*cos(e), sin(e), cos(a)*cos(e))*35`，look_at focus、UP=+Y |
| 縮放 | 最小 size 2；最大 `min(48,18.5/0.6) ≈ 30.8333`；初始/目前 size 即 zoom 比例 |
| 檢查畫面 | 視窗覆寫 1280×800；正式執行的 viewport 比例與 Camera.keep_aspect 仍需核對 |

場景中保存的相機 transform 會在 `_ready()` 被 update_pose 取代，不能只複製編輯器 transform。先在 size=18.5 及約 30.8333 檢查辨識，再放大檢查結構；可繞 Y 軸轉一圈，至少補查四方位。size=2 只作近景檢查，不作主要美術驗收。

主光／環境取 `scenes/main.tscn` Sun 與 `assets/data/rendering/level_environment.tres`：暖光 Color(1,0.9411765,0.8470588)、能量1.12；背景(0.9,0.925,0.94)，藍灰 ambient 能量0.23。Blender 用於構圖近似，Godot Compatibility 的實際畫面才是顏色／陰影驗收依據。不要為匹配 Blender 改遊戲光源。

選圖預覽相機的 45°／自動取景不是戰鬥鏡頭；主選單橋景也不是模型比例的基準。

## 塔節點與真正的模型來源

`scenes/towers/components/tower.tscn` 只有帶 `tower.gd` 的 Node3D；`DefenseTower._ready()` 建立名為 `Visual` 的外觀。TowerDefinition 的 `model: PackedScene`、`aim_pivot_path`、`muzzle_path` 是掛載介面，路徑相對 Visual 根。TilePreset 的 model_offset 只移外觀。

**目前不能假設換 model 就換所有外觀：** 非空 `TowerBodyGeometry.local_cells(preset)` 且不是兵營時，走 `TowerBodyVisual.create()`。哨塔沿用 definition.model 再增加 Level2／Level3；弩砲／側舷砲／迫擊砲／十字火力的多格外觀由 body_visual.gd 組裝，definition.model 在該分支只提供原有聲音等來源。兵營與空 footprint 的舊路徑直接實例化 definition.model。

| 塔 | 正式基礎版 footprint | 功能輪廓／掛載特性 |
| --- | --- | --- |
| Sentry 哨塔 | 1×1 | 垂直支架＋高位可瞄準武器；`AimPivot`→Weapon，`AimPivot/ArrowRelease` 為 Marker3D |
| Ballista 弩砲 | 1×2 主軸＋左或右1格裝填區，L形 | 低長雙軌／弩臂；保持主軸 −Z、裝填區不能拉偏砲口 |
| Broadside 空艇舷炮 | 1×2 | 縱長船身＋雙側六砲；FixedBase 固定，Airship 單獨巡航，艇身內 RecoilAssembly 分 Port／Starboard |
| Crossfire 交叉火力 | 2×2 | 中央核心＋四向發射臂，具四向辨識 |
| Mortar 迫擊砲 | 2×2 | 寬低砲座＋粗短仰角砲管，錨點可能在不同角落 |
| Barracks 兵營 | 1×1 | 駐軍建築／入口，保留前方道路駐點；不因造型新增士兵或占格 |

來源：`docs/tower_visuals_and_preview.md`、`docs/road_visual_and_placement_refinement.md`、`assets/data/tower_tiles/user/catalog.tres`、`scripts/towers/body_geometry.gd` 及各 TowerDefinition。外觀功能特徵作辨識基線，未要求照抄舊幾何細節。

多格局部座標由 `(footprint_cell - tower_offset)` 再扣除 facing_steps 得到，不能一律以外接矩形中心設根原點。TowerBodyGeometry.origin 決定攻擊中心：哨塔／兵營保持錨點，迫擊砲／十字火力取整體中心，弩砲依最長主軸列。正式2×2常有半格偏移。

其他塔沿用 `restored_tower_visual.gd` 的 `RecoilAssembly`、`muzzle_paths` metadata 與 `motion_root()`；Broadside 另有 `moving_body_path=Airship`、左右炮組 `side=-1/+1`。部分砲口是 Node3D，不是 Marker3D。Blender Empty 不會自行成為 Godot Marker3D，也不保證 glTF extras 自動滿足這些 metadata；wrapper 必須保留實際型別與路徑。

目前 Level2／Level3 以節點可見性切換；哨塔 Lv4 以上保留 Lv3 外觀。未建立通用的任意 GLB 多格外觀替換介面；Skill 只規定資產交付與掛載契約，不暗中新增接入系統。

## 資產與匯入現況

- `assets/models/towers/`：六塔 `.tscn`，Sentry 另用 `sentry_base_mesh.res`、`sentry_weapon_mesh.res`；其他分類含 tiles／traffic／endpoints／enemies／allies；MeshLibrary 為 `assets/models/mesh_library.tres`。
- `assets/data/towers/`：模型引用、accent、攻擊、成長；`assets/data/tower_tiles/`／`tile_presets/`：道路與占格。這些不是可為美術重設的資料。
- `tools/assets/`：既有離線產生與烘焙；`restore_towers.gd` 會重建五塔且可能蓋掉手工變更；`build_tile_library.gd --demo` 會重設地圖，不能作新模型匯入流程。
- `assets/materials/solid_color.tres` 與 `assets/shaders/solid_color*` 是現有不透明純色顯示管線。body_visual 色盤為 WOOD #846b55、DECK #c2aa80、IRON #405763、LIGHT #e8dcc0；RoadSurface 為道路 #bca77b、石面 #d2c6aa、側面 #60768a。可沿用色系，不要求全部同時使用。
- 開始時全 repo（含隱藏路徑、排除 Git／快取／外部SDK）未發現既有 SKILL.md；現有追蹤資產未見 `.blend`／`.glb`／`.gltf`。本次為新增 GLB 工作規範，沒有聲稱已完成 GLB 接入。
- 專案共識為 Godot 4.7.2、Compatibility、Windows／單執行緒 Web；`project.godot` 宣告4.7與 gl_compatibility，未以此證明本機執行檔版本。

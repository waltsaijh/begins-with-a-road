# Art Slice D — Functional Color & Animation

2026-11-05 完成交付；建模與 Godot 匯入驗證於 11-04 執行，11-05 接續用量中斷的預覽、重跑檢查與包裝。使用 `$bwar-modeling`。以既有 Great Ballista 第二輪與 tower_family 的五座模型為來源，沒有替換正式 TowerDefinition 或改寫遊戲邏輯。

## 資產與動畫

| 資產 | 占格／量體 X×深度×高度 | 動畫名稱與秒數 | 功能 |
|---|---|---|---|
| great_ballista | L形三格；1.78×1.905×0.80 | `attack` 2.9583s | 沿用拉弦、發射、後座、裝填；可匯出 TRS |
| watchtower | 1×1；0.68×0.73×1.4925 | `fire` 1s | 頂部武器後座0.065、復位，獨立 AimPivot |
| barracks | 1×1；0.88×0.86×0.89 | `open_close` 3s | 兩片內縮門扇向外轉82°、停留、關閉 |
| mortar | 2×2；1.78×1.78×1.295 | `fire` 1.5s | 沿砲身後縮、上部承重組微沉0.018，接地砲床不動 |
| crossfire | 2×2；1.86×1.86×0.77 | `fire_north/east/south/west` 各1s | 四個獨立發射臂，各自後座0.085並復位 |
| broadside_airship | 1×2；0.96×1.79×1.62 | `fire_port/starboard` 各1.3333s | 每舷三砲各有pivot，依序錯開2幀、後座0.055 |

所有動畫24fps、一次性、無自動播放；起訖復位。飛行艇本輪不另加艇身反作用力，避免單格寬度溢出及左右動畫互相改寫船身位置；六砲與所有載具構件都在 Airship 子樹，FixedBase獨立，可整體移動。沒有巡航、攻擊判定、碰撞體或粒子系統。

保留原幾何；只有兵營新增兩片有厚度的功能門板，三角形由716增至804。其他五塔仍為巨弓1352／哨塔484／迫擊砲492／十字612／飛行艇936。兵營原入口後方深色面保留為內室背景。門扇關閉底部位於Z=.18，與內室地板保持間隙。

巨弓採用既有第二輪72幀動作取樣；原 hide_render/hide_viewport 改為 BoltCarrier 的可匯出非零縮放0.001，在箭離開後縮至不可辨識，再補箭復位。這是目前預覽箭矢，未來正式接入須與遊戲的權威 projectile 分工，避免雙重箭矢或動畫決定傷害；未使用透明材質。飛行中的箭可離開 footprint，塔體不離開。

## 配色

同一套常量色：主體 `#D7D2C6`、次要結構 `#AAAFA8`、機械內膛 `#48575C`、功能強調 `#B77C57`。赭色只用在巨弓滑塊和兵營門板，無第三色平均分塊。粗糙度.88、非金屬、不透明、啟用背面剔除；沒有貼圖、噪聲、法線貼圖、磨損或發光。砲膛深色沿用實際內壁面的材質索引，沒有黑色孔洞貼片。

## 根、朝向與掛載

沿用1格=1單位；Blender Z上/+Y前 → Godot Y上/−Z前。根原點是邏輯錨點，scale1，底面0；沒有烘焙塔根既有0.025偏移。footprint、來源SHA、AABB、砲口位置見 [manifest.json](manifest.json)。

- 巨弓：`(0,0),(0,1),(1,1)`，右後裝填格；左側裝填等其他卡牌配置仍須獨立適配。
- 哨塔、兵營：`(0,0)`。
- 迫擊砲：`(0,0),(-1,0),(-1,1),(0,1)`，中心Godot(-.5,0,+.5)。廣場配置需外觀(+1,0,0)，斜廣場需(+1,0,-1)；不移動邏輯錨點。
- 十字火力：`(0,0),(1,0),(0,-1),(1,-1)`，中心Godot(+.5,0,-.5)。
- 飛行艇：`(0,0),(0,1)`，中心Godot(0,0,+.5)，右舷+X、左舷−X。

節點保留 `BWAR_D_<asset>__<function>` 前綴。砲口的局部−Z軸已對準實際射向：迫擊砲沿仰角，十字四方位，飛行艇左右±X。原始GLB的Empty匯入為Node3D；烘焙外觀場景已轉為Marker3D。實際NodePath、位置、射向與動畫track路徑見 [Godot檢查](godot-check.json) 及 [烘焙後檢查](godot-baked-check.json)。

主要層級：

- 巨弓：GreatBallista → FixedBase／LoadingBay／WeaponMount → Slider、BoltCarrier、兩個LimbPivot、Muzzle。
- 哨塔：Model → FixedBase／AimPivot → RecoilAssembly → 武器、ArrowRelease。
- 兵營：Model → FixedBase／DoorLeft／DoorRight；兩門pivot位於各自門鉸位置。
- 迫擊砲：Model → 接地LoadBearingBed／Suspension → FixedBase、AimPivot → RecoilAssembly → ShortBore、Muzzle0。
- 十字：Model → FixedBase／RecoilAssembly0–3 → 各自砲管與Muzzle0–3。
- 飛行艇：Model → FixedBase／Airship → RecoilAssembly → Port／Starboard → 各自Gun1–3 → 砲管與砲口。

## 交付路徑

Blender來源在本目錄每座塔的 `model.blend`，統一場景是 [model.blend](model.blend)。每座塔有 `build.py`入口，共用根目錄 [build.py](build.py)／[geometry.py](geometry.py)；入口明確重建整套六塔，避免配色或共享匯出規格漂移。來源依賴是之前完成的六個 `.blend`，打包時一併附上，請保留相對目錄。

遊戲資產準備位於 `assets/models/towers/art_slice_d/`（repo根目錄相對路徑）：

- 六份 `<id>.glb`，自含模型及動畫，無圖片／外部buffer／預覽燈光／相機／骨架。
- 六份 `.glb.import`：24fps、root scale1、停用自動LOD與不必要切線，套用此批專屬的 `import_visual.gd`。
- 六份 `<id>_visual.tscn`：已烘焙的獨立外觀，不帶戰鬥腳本、不被任何TowerDefinition引用。
- `<id>_meshes/part_*.res`：經既有 `tools/assets/solid_mesh_baker.gd` 離線處理，保留UV/UV2、COLOR、CUSTOM0(static w=0)、CUSTOM1，共用既有 `assets/materials/solid_color.tres`。

GLB是交換來源，`.res`／`_visual.tscn`是衍生物。重新匯出後需重新執行匯入、烘焙與驗證；它們不是會自動更新的繼承wrapper。全專案的bake_solid_models工具沒有執行，既有資產沒有被重烘焙。

Godot會為不同動畫補上其他方向的固定軌道；本批專屬EditorScenePostImport只移除十字／飛行艇片段不屬於自身方向的軌道，並設定非循環、autoplay空白。因此單方向動作不會重設另一方向。這個腳本只做匯入整理，不是執行期戰鬥邏輯。

## 視覺與驗證

- [六塔色彩比較](previews/Family7.2.png)、[Blender正式距離](previews/Family18.5.png)、[最遠縮放](previews/Family30.833333.png)。使用同尺度、45°俯角；近景方位210°便於看入口，正式距離方位30°、正交跨度18.5、1280×800。
- [六塔動畫與關鍵影格索引](preview-gallery.md)。各塔都有 `previews/static.png`、12fps APNG `animation.png`及每個clip的關鍵畫面。十字與飛行艇預覽依序展示獨立clip，不表示遊戲內必須綁定連播；25幀動畫的六格板最後兩格為同一復位姿態。預覽為逐幀取樣，循環尾端多留一個取樣幀，GLB精確時長以上表為準。
- [Godot實際渲染近景](previews/godot_family.png)、[Godot正式距離](previews/godot_game_scale.png)：Godot4.7.2 Compatibility、RTX4060 Laptop，在獨立驗證專案載入烘焙後資產，使用現有level_environment與正式相機公式。不是正式關卡遊戲截圖，也未套用正式HUD或顯示預熱。
- [manifest.json](manifest.json)：每個clip每幀塔體footprint越界0、低於地面0、首尾局部矩陣誤差0；發射中的巨弓箭矢排除於塔體占格檢查。
- [source-check.json](source-check.json)：兩次程序化重建數量／規格一致、原六個來源SHA不變、兵營雙門73幀與牆體／彼此無表面交叉。耳軸、砲架、滑塊的有意機械接合與遮蔽保留；沒有做全場物理碰撞模擬。
- [godot-check.json](godot-check.json)／[godot-baked-check.json](godot-baked-check.json)：兩階段均實際載入並播放10個片段，尺寸、方向、track target、獨立方向、末幀復位通過；Airship平移不影響FixedBase，全部側砲及砲口隨船移動。
- [bake-check.json](bake-check.json)：所有目標surface均受現有baker支援，沒有強制替換不支援材質或新增專用shader。

## 正式接入仍需的工作

已具備可供遊戲載入與事件播放的第一版視覺資產，尚未接入正式塔系統。接入需要：

1. 在TowerBodyVisual的多格分支提供外觀來源適配，不能只改TowerDefinition.model；套用各preset錨點、巨弓裝填側與迫擊砲偏移。
2. 將現有AimPivot、muzzle_path／muzzle_paths、moving_body_path綁到實際NodePath；保留飛行艇整體Airship移動層，而不要移動FixedBase。
3. 將現有射擊、左右舷選擇、兵營部署事件接到AnimationPlayer。替換同一組件的舊程序化後座，避免兩套動畫同時寫入同一transform；本輪沒有更改舊腳本。
4. 決定攻擊動作與現有冷卻、彈體生成的時間協調。巨弓約3秒視覺片段不等於更改既有1.4秒攻擊間隔；正式事件應裁分、調速或重觸發，不能讓動畫改寫戰鬥數值。方向同時播放需要多個player或AnimationTree分層，資產tracks已獨立。
5. 實作／確認Lv2、Lv3外觀與hologram、顯示預熱、死亡清理、飛行艇遺物巡航。現有升級插槽保留，但未新增升級零件。
6. 在正式關卡與Web驗收遮擋、色彩／陰影、動畫中斷、連續射擊及效能。本輪未宣稱通過這些測試。

## 重建

無第三方Python依賴，Blender5.2.3 LTS；Godot4.7.2。下列命令自repo根目錄執行，工具路徑可依本機調整。

```powershell
$blender = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
$python = 'C:/Users/USER/AppData/Local/Python/pythoncore-3.14-64/python.exe'
$slice = 'tools/assets/blender/art_slice_d'
& $blender --background --python "$slice/build.py" -- --build --finalize
& $blender --background "$slice/model.blend" --python "$slice/build.py" -- --render
& $blender --background "$slice/model.blend" --python "$slice/build.py" -- --render-anim
& $python "$slice/prepare_validation.py"
& C:/tools/Godot.exe --headless --editor --path "$slice/godot_validation" --import
& C:/tools/Godot.exe --headless --path "$slice/godot_validation" --script res://validate.gd
& C:/tools/Godot.exe --headless --path "$slice/godot_validation" --script res://bake_visuals.gd
& C:/tools/Godot.exe --headless --path "$slice/godot_validation" --script res://validate.gd -- --baked
& $python "$slice/assemble.py"
```

`prepare_validation.py`把必要來源複製到隔離Godot專案，初次從完整交付包重建時保留 `.glb.import` 與該專案的測試腳本。`assemble.py`組裝真實渲染幀並複製已驗證的衍生資產，沒有重生圖像。`verify_source.py`可在背景Blender另行重跑來源檢查。

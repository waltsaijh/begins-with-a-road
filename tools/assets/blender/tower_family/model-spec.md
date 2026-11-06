# 防禦塔家族：純建模交付

2026-11-04；核對 experiment/routing-sandbox，HEAD 9b9a7f9。五座新模型以 Great Ballista C 的簡潔功能幾何及第二輪兩色為基準。巨弓僅載入既有 GLB 作比較，不重製或覆寫。全部為工具側 Art Slice，未接入 Godot。

## 已核對的設計與占格

1 格 = 1 單位；Blender Z 上／+Y 前，GLB → Godot +Y 上／−Z 前。根原點保持邏輯錨點，比例1；底面0，未烘焙遊戲塔根既有0.025高度。

下表 footprint 為 Godot 局部 (X,Z)；所有目前選定 preset 的 facing_steps、tower_offset、model_offset 均為預設0。表中的高度含最高幾何，非遊戲能力數值。

| 塔 | 實際 tower body / footprint | 幾何尺寸 X×深度×高 | 主要輪廓、功能件 | 預留層級 |
|---|---|---|---|---|
| Watchtower 哨塔 | Small，(0,0) | 0.68×0.73×1.493 | 細高四腿、斜撐、上平台、單弓武器，透空塔身 | FixedBase、AimPivot、ArrowRelease、UpgradeSocket |
| Barracks 兵營 | Small，(0,0) | 0.88×0.86×0.89 | 矮厚堡壘、實際入口與內腔、牆厚、四角防護 | FixedBase、DeploymentExit、UpgradeSocket |
| Mortar 迫擊砲 | Large，(0,0),(-1,0),(-1,1),(0,1) | 1.78×1.78×1.295 | 八角厚底座、雙耳軸支架、短粗仰角砲與真實內膛 | FixedBase、AimPivot、RecoilAssembly、Muzzle0、UpgradeSocket |
| Crossfire 十字火力 | Large，(0,0),(1,0),(0,-1),(1,-1) | 1.86×1.86×0.77 | 低中央核心、四向同型發射臂、十字承重底座及四角負空間 | FixedBase、四組 RecoilAssembly／Muzzle、UpgradeSocket |
| Broadside Airship 飛行艇 | 1×2，(0,0),(0,1) | 0.96×1.79×1.62 | 尖首船殼、甲板／駕駛艙、懸吊升力艇體、尾舵、兩側各三砲 | FixedBase、Airship、RecoilAssembly／Port／Starboard、六砲口、UpgradeSocket |

前方均是 −Z；飛行艇右舷 +X，砲口朝 ±X；十字火力四向對稱，仍保留標準根方向。兵營的前路駐點不算塔體占格，也未新增士兵。空艇停泊支座屬 FixedBase，船體、升力艇體、側砲全屬 Airship。預留 Empty 不是 Godot Marker3D，尚未建立 wrapper；未製作動畫或升級模型。

## 實際資料與掛載差異

- TowerDefinition 的舊 footprint 多數仍寫單格，正式基礎版實際由啟用的 tower tile catalog／TilePreset 決定，不能直接照舊欄位建模。
- 哨塔：`assets/data/tower_tiles/user/user_b46a4aa7ce037ee15ceb475612745a2a.tres`，其他啟用版本也為單格。
- 兵營：`assets/data/tile_presets/barracks_01.tres` 的 tower_footprint 留空，沿用 `assets/data/towers/barracks.tres` 單格。
- 迫擊砲主版本：`user_6657902a4f1b0f4ce0c1b3be3c808484.tres`／`user_4df6099dda6ec376c3ac74aa29b0a57b.tres`，攻擊中心 Godot (-0.5,0,+0.5)。`user_4dede9ac87ae5418717f2677d5ed9297` 需要相對本模型外觀平移 Godot (+1,0,0)；`user_8cddd0320f4136d3a4954e6868e8d398` 需要 (+1,0,-1)。這些是未來 wrapper 的配置適配，不能移動邏輯錨點或更改遊戲資料。
- 十字火力：`user_889e85b850619a8eb20d0fc7e832bfe5.tres`，另外三份啟用配置 footprint 相同，中心 Godot (+0.5,0,-0.5)。
- 飛行艇：`user_17c8dc78705573a24b5c07ef37567b68.tres`，四份啟用配置皆1×2，中心 Godot (0,0,+0.5)。不採擴大船寬以容納側砲；六砲均收在實際單格寬度內。
- 依 `body_geometry.gd` 扣除 tower_offset／facing_steps；`body_visual.gd` 仍程序化建立多格塔，不能只替換 model 宣稱完成接入。哨塔保留 AimPivot／ArrowRelease 語意，兵營走直接實例化，其餘需後續外觀掛載適配。
- 既有 `solid_color` 需要專案自訂頂點通道，這批 GLB 是簡單 PBR 交換模型，尚未烘焙正式材質。未改任何遊戲場景、TowerDefinition、道路、放置或戰鬥系統。

## 來源與使用

每個目錄內均有 `model.blend`、`build.py`、同名 `.glb` 及 `previews/front.png`、`rear.png`、`game.png`：

- [Watchtower](watchtower/model.blend) ／ [GLB](watchtower/watchtower.glb) ／ [腳本](watchtower/build.py)
- [Barracks](barracks/model.blend) ／ [GLB](barracks/barracks.glb) ／ [腳本](barracks/build.py)
- [Mortar](mortar/model.blend) ／ [GLB](mortar/mortar.glb) ／ [腳本](mortar/build.py)
- [Crossfire](crossfire/model.blend) ／ [GLB](crossfire/crossfire.glb) ／ [腳本](crossfire/build.py)
- [Broadside Airship](broadside_airship/model.blend) ／ [GLB](broadside_airship/broadside_airship.glb) ／ [腳本](broadside_airship/build.py)

[全塔比較原始檔](model.blend)、[比較圖](previews/family.png)、[遊戲尺度](previews/game_scale.png)、[最遠尺度](previews/game_farthest.png)。另有120／210／300°比較。所有比較保持實際相對尺寸，不逐塔縮放。

單塔 entry script 使用本目錄共用 `build.py`／`geometry.py`，請保留解壓後相對結構；沒有 pip／第三方素材依賴。重建整組比較需隨包附上的既有巨弓 C GLB。固定程序無隨機數。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/assets/blender/tower_family/build.py -- --build --finalize
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background tools/assets/blender/tower_family/model.blend --python tools/assets/blender/tower_family/build.py -- --render
# 單塔重建（以迫擊砲為例）
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/assets/blender/tower_family/mortar/build.py
```

Blender 5.2.3 LTS；匯出 GLB、Y-up、selection + active scene、normal、extras；無 animations／skins／morph／textures／cameras／lights／外部 buffer。來源隔離於父層 `.gdignore`，正式 GLB 暫不放 assets 避免誤認已接入。

## 色彩、預覽與判斷

主色 #DFD9CE、功能深色 #465155，roughness .88／metallic0，無貼圖或額外特效。使用與巨弓相同 EEVEE 舞台光與材質；Blender 色彩／陰影僅近似遊戲，未驗收 Godot Compatibility 最終顯示。

單塔兩角度為方位30／210°、俯角45°、相同垂直跨度3.5；正式尺度1280×800、正交垂直跨度18.5，最遠30.8333。使用 camera.view_frame 校正垂直跨度；game.png 沒有裁切放大。遊戲尺度附示意道路，不是正式地形快照。

哨塔的高度與透空支撐、兵營的厚牆、迫擊砲的重量、十字塔的對稱，以及飛行艇的載具輪廓可直接區分。飛行艇的側砲受單格寬度限制，遠景首先讀到艇體；後續最值得觀察的是側砲的可讀性與兵營入口的陰影對比。迫擊砲的仰角砲口高於十字塔，但主要重量集中底座，並未做成高塔。

## 驗證與限制

幾何 AABB、三角形及封閉拓樸見 [inspection.json](inspection.json)，GLB 匯出頂點／surface／材質及無外部依賴檢查見 [glb-check.json](glb-check.json)。五塔所有頂點皆位於各自主版本 footprint 聯集內，底面0，沒有非流形邊。其餘迫擊砲配置須使用上列偏移，尚未接入任何配置。

[validation.json](validation.json) 記錄重跑前後物件387、網格197、材質5、collection27、scene21完全相同（含舞台與巨弓參考），五塔尺寸／三角形相同；巨弓來源SHA保持不變。五份GLB重新匯入Blender的AABB最大誤差小於0.00000012單位，根變換正確，無負行列式、退化三角形或同mesh重複三角形。獨立模型保留可編輯結構件，尚未做正式遊戲的靜態合批／surface優化。

建模期間 Blender 5.2.3 在寫入含集合實例的多場景 library 時出現 EXCEPTION_ACCESS_VIOLATION，MCP 回報 WinError 10054。改由隔離背景程序保存正常工作檔，單塔來源仍分別保存；不覆寫使用者原工作檔。此問題不影響交付 GLB。沒有執行 Godot／Web／戰鬥／效能測試。

完成後已重新啟動本次獨立預覽、恢復MCP，透過get_scene_info與look檢視全塔群。單塔迫擊砲入口腳本已實際重建並保存成功；其餘使用同一共用入口流程。

# Art Slice E：六塔正式 Godot 接入

核對／完成：2026-11-05，Godot4.7.2、Compatibility，experiment/routing-sandbox。保留開始時的Skill、前輪資產與文件修改，本輪沒有重新建模、變更戰鬥數值或改動導航演算法。

## 接入結構

六份 `assets/data/towers/*.tres` 新增 `visual_model`，指向 `assets/models/towers/integrated/<kind>.tscn`。既有 `model` 保留作為舊幾何／音效來源，未覆寫原有塔場景。`TowerBodyVisual.create()`先檢查新外觀與當次tower body是否相容，再建立新外觀；不相容的自訂形狀走既有模型／程序化fallback。

每個獨立wrapper持有 `imported_tower_visual.gd` 與GLB衍生的 `Art` 子場景，沒有直接編輯匯入快取。`tools/assets/build_integrated_towers.gd`讀取Art Slice D原始GLB，透過既有solid_mesh_baker烘焙純色頂點通道，只合併同一剛體群組中未被動畫直接控制的網格，保存新的 `.res`／`_art.tscn`。動畫控制節點、砲口及來源GLB保持獨立。

| 遊戲塔／wrapper | GLB來源 | 新網格實例數 | 功能節點／動畫 |
|---|---|---:|---|
| sentry 哨塔 | watchtower.glb | 2 | AimPivot → RecoilAssembly／ArrowRelease；fire |
| ballista 巨弓 | great_ballista.glb | 10 | WeaponMount、Slider、BoltCarrier、LimbPivot、Muzzle、LoadingBay；attack |
| barracks 兵營 | barracks.glb | 3 | DoorLeft／DoorRight；open_close |
| mortar 迫擊砲 | mortar.glb | 3 | Suspension → AimPivot → RecoilAssembly／Muzzle0；fire |
| crossfire 十字火力 | crossfire.glb | 5 | RecoilAssembly0–3／Muzzle0–3；fire_north/east/south/west |
| broadside 飛行艇 | broadside_airship.glb | 8 | MotionRoot → Art → Airship → Port／Starboard → Gun1–3／六砲口；fire_port/starboard |

來源路徑前綴為 `res://assets/models/towers/art_slice_d/`。Art內功能節點沿用 `BWAR_D_<asset>__<function>` 名稱，adapter按完整後綴找節點；`AimPivot`與Marker3D的位置／旋轉來自原資產，不以新增假砲口取代。六塔合計31個網格實例，原Art Slice D共132個；所有新網格共用既有solid_color材質，沒有新增shader、紋理或光源。

飛行艇的FixedBase在ready時保持世界變換移到wrapper固定層，整份Art移至邏輯錨點上的MotionRoot。動畫路徑仍相對Art，船體／側砲隨MotionRoot移動，FixedBase不動；既有departure遺物可繼續操作，不新增巡航規則，也不把船殼pivot當成攻擊中心。

## 尺度、占格與預覽

沿用1格1單位、根比例1、Godot−Z正面。哨塔／兵營1×1、迫擊砲／十字2×2、空艇1×2；巨弓依L形主軸與裝填格適配。2×2按實際body中心平移外觀；巨弓只平移LoadingBay適配左／右、前／後裝填格，不鏡射武器或拉偏主軸。不同尺寸的自訂body不硬縮放模型，交回舊版fallback。

塔根與TowerBodyGeometry.origin沒有修改。Art子件補償既有GROUND_OFFSET 0.025，使底面接觸地面；邏輯錨點、占格、威脅與碰撞／放置驗證維持原值。所有21份啟用配置、每份4個旋轉，共84組皆完成實際card commit與每個模型頂點的占格檢查。

正式模型與CardPreview共用同一factory。新外觀預覽停用動畫並保留原色，合法／非法的紅綠狀態繼續由既有格面、輪廓及占格提示呈現；舊版fallback仍使用既有hologram材質。預覽不覆寫新模型的材質或比例；84組逐網格世界變換／mesh資源與正式塔一致。

既有升級倍率與等級標籤維持運作；這批來源只有Lv1幾何，Lv2/3沿用同一新模型，本次沒有設計新的升級零件。

## 實際事件與同步

- CombatSystem原有 `prepare_shot → attack.fire → present_shot`仍是傷害／投射物的權威；present_shot只把視覺事件及本塔當前attack_interval交給新adapter。
- 哨塔、迫擊砲、十字與空艇從後座前緣開始播放，把原片段前面的靜止幀略過，發射事件與後座緊接。動畫速度依當前攻擊間隔壓縮回位時間；重觸發從當次片段起點取樣，可連續射擊。
- 巨弓在已有目標且冷卻接近完成時取樣原attack片段的拉弦段，真正開火時接到釋放／回位段。第一發不等待額外蓄力。壓縮的是視覺時間，沒有延遲傷害或更改原1.4秒間隔。原Art Slice D用於展示的飛行箭隱藏至裝填回位，避免與遊戲權威攻擊畫面重疊。既有巨弓普通攻擊仍沿用其原本的瞬時beam／命中規則；沒有為模型額外新增彈體或更改命中時機。
- 十字火力現有Mode.ALL會命中所有合法敵人；每個實際victim的prepare_shot累積發射方向，只播放這次命中的方位。多個方位可同時播放，沒有無條件四面齊射。
- 空艇按目標相對移動原點的左右舷選擇，左右動畫使用獨立AnimationPlayer；各自三砲的原錯開時序保留。新播放路徑不再疊加舊RestoredTowerVisual程序化後座。
- 兵營在BarracksSystem建立友軍、以及FriendlySoldier完成既有重生時呼叫present_deployment。相同批次兩名士兵共用一次開門週期，不改出兵人數、駐點、復活秒數或移動規則。
- 新播放器採manual advance，由視覺根的模擬delta推進，受遊戲倍速與暫停控制；只有活動動畫啟用_process，靜止塔不逐幀更新。動畫缺失時仍可完成傷害，沒有讓傷害依賴AnimationPlayer訊號。

## 本次實際驗證

| 項目 | 結果 |
|---|---|
| 六GLB在正式專案匯入、剛體純色烘焙／合併、再建立wrapper | PASS；2／10／3／3／5／8個網格實例 |
| tower_integration新增測試 | PASS；84次實際放置，所有頂點占格、正式／預覽逐網格一致、配色保留 |
| 遊戲事件 | PASS；五座射擊塔由CombatSystem真正開火觸發、兵營初次部署與重生開門 |
| 動畫 | PASS；當前間隔調速、12次快速重觸發後完成、缺少動畫不影響傷害、十字四向／空艇兩側獨立及兩通道同時播放 |
| 舊tower_restoration／towers | PASS；既有單體／全體／迫擊砲延遲傷害與冷卻回歸 |
| 舊tower_obstacles | PASS；464條取樣路線、拆塔恢復、固定行程保護；只把舊固定節點路徑斷言改為同義的兩個剛體單surface檢查 |
| 舊cards／card_drag_placement | PASS；旋轉、交易原子性、失效預覽、拖放取消與鏡頭排除 |
| 舊relics/mechanisms／stacking | PASS；113項機制檢查、疊塔、既有空艇遺物行為 |
| 舊traffic/integration／construction/placement | PASS；104項交通整合、34項建造／端口／fallback檢查 |
| Frontier正式場景GPU畫面 | PASS；六塔透過真實validate_card/place_card放入正式地形，原camera size18.5／45°及環境未改 |
| 192個活動視覺實例GPU短測 | 完成；RTX4060 Laptop／Compatibility，180幀平均5.46ms、1072 draw calls；是單機短測，不代表Web或所有硬體效能 |
| Web Export | FAIL／外部依賴缺失；未執行瀏覽器驗證 |

Web實際使用既有 `tools/web/export_test.ps1` 匯出新增整合測試，Godot回報：

```text
Failed to open 'res://bin/road_graph.candidates.web.template_release.wasm32.nothreads.wasm'.
Project export for preset "Web" failed.
```

目前工作區只有Windows DLL，缺少既有路網GDExtension的Web release binary；本次沒有用舊版WASM替換或假稱Web通過。匯出腳本已於finally完整還原project.godot與export_presets.cfg。需補齊與目前原生核心一致的Web檔後，再執行匯出與瀏覽器測試。

本次證據存於 `.godot/test-results/combat/tower_integration.json`、`tower_integration_view.json`、`tower_integration_stress.json`及同目錄PNG。正式場景畫面：

![Frontier六塔](../.godot/test-results/combat/tower_integration_frontier.png)

192塔短測畫面：

![192塔](../.godot/test-results/combat/tower_integration_stress.png)

未執行真人輸入驗收、完整十五波、Web執行或長時間效能／記憶體量測。首輪桌面可放置、顯示及事件動畫已完成，後續人工宜檢查鏡頭旋轉時的遮擋、低幀重觸發及美術升級需求。

## 重匯入與測試入口

```powershell
# 新GLB匯入後，重建本批新外觀，不重建Blender模型。
& C:/tools/Godot.exe --headless --editor --path . --import
& C:/tools/Godot.exe --headless --path . --script res://tools/assets/build_integrated_towers.gd
# Art Slice F啟用後，同時更新B色盤衍生網格，詳見art_slice_f.md。
& C:/tools/Godot.exe --headless --path . --script res://tools/assets/build_integrated_towers.gd -- --identity
& C:/tools/Godot.exe --headless --path . res://tests/combat/tower_integration.tscn
```

`tests/combat/tower_integration_view.tscn`可用F6檢視正式Frontier放置結果；附加`-- --stress`執行192塔測試。這些獨立測試不改寫正式地形或波次Resource。

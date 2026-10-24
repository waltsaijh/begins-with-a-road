# Routing Sandbox — Phase 1–4 交接

核對日期：2026-10-23（Asia/Taipei）。本文件是新工作階段的起點；玩法共識看 [AGENTS](../AGENTS.md)，細節看 [systems](systems.md)、[Phase 3](phase3.md)、[Phase 4](phase4.md)。測試結果只對下述版本及環境成立。

## 1. 目標與 Design Pillars

- 建造卡同時決定道路形狀與火力配置；路網必須保留所有入口到終點的通行。
- 分流是主要戰術：兵種偏好、交通設施及敵軍協同，讓玩家能藉路線拆散火力掩護、治療與癱瘓威脅。
- 預覽必須說真話：顯示正式配額的完整行程，不能把倍率、候選數或動畫當成實際敵軍數。
- 準備期不限時、手動開波；戰鬥採固定行程，呈現與避讓不改導航或傷害權威。
- 資料由 Resource 編輯，能力狀態屬實例；維持微縮沙盤、簡潔 UI、Compatibility 與單執行緒 Web 方向。

目前是三 ACT、每 ACT 三波的原型，最後一波完成後停止開波。完整基地生命／勝敗結算、存檔、五 ACT 與特殊事件尚未完成。

## 2. Git 與工作目錄

| 項目 | 交接時核對值 |
|---|---|
| 唯一可修改工作目錄 | `D:\games\begins-with-a-road-routing` |
| 分支／HEAD | `experiment/routing-sandbox`／`2e2de2a`（ft:6個新敵人單位） |
| Offboarding 開始狀態 | `git status --short`、`git diff --stat` 無輸出；`git diff --check` 通過 |
| 前四筆提交 | `1e36ee5` UI／測試修正；`477580c` 疊塔與遺物；`297d6dd` 交通設施及塔；`0d78db6` 先前合併 |
| 本次交付 | 必要 Markdown 文件變更；驗證產物在忽略的 `.godot/offboarding-2026-10-23/` |
| 正式／舊專案 | `D:\games\begins-with-a-road`／`D:\games\card-tower-defense`，本次均未修改 |

本次沒有 commit、merge、rebase、push、reset、clean 或刪檔。開始時 Phase 1–4 已提交至上述 HEAD，不能沿用上一階段「1e36ee5＋未提交 Phase 4」的工作目錄描述。Sandbox 尚未整合到正式專案／main；有舊合併提交不表示本批成果已整合。

本次文件清單：新增 `docs/HANDOFF.md`；更新 `README.md`、`AGENTS.md`、`docs/{architectures,systems,phase3,phase4}.md`、`native/README.md`、`tests/README.md`、`tests/{traffic,relics,synergy}/README.md`，共 12 份 Markdown。遊戲程式、Resource、場景、SDK 與建置設定沒有變更。交付時 `git diff --check` 及修改文件的連結檢查通過。

## 3. Phase 1–4 實作狀態

下表已核對現行原始碼，不只依據歷史報告。完成指功能實作與驗證入口存在，不代表正式平衡或所有平台驗收完成。

| Phase | 已實作與目前行為 | 主要來源／既有測試 |
|---|---|---|
| 1 流量 | 每入口菱形驚嘆號，hover 展開實際兵種／個體數；列 hover 篩選入口與兵種，標題保留該入口全部。道路呈現沿有向流量滑行的米白短筆觸；不是永久箭頭。多入口共用正式排程配額。 | `start_wave_callout`、`next_wave_intel`、`wave_flow_preview`、`RoadFlowForecast`、`road_flow_renderer`；`tests/levels/road_flow_preview.tscn` |
| 2 交通 | 互斥體型＋複合 Tags；旗幟 ground ×1.5、拒馬 small＋ground ×0.5、窄口 large＋ground ×0.5。每設施每完整路線作用一次，跨設施乘法。參與完整波次才扣壽命，第三波清理，跨 ACT 保留。商店上四塔／下二輔助；建造候選沿用正式配額，岔路 ↑／↓ 只表示個體流量差。 | `TrafficStructures`、`TrafficWeights`、`TrafficFlowDelta`、card shop；`tests/traffic/{weights.gd,integration.tscn,input.tscn}` |
| 3 構築 | 同種塔牌原地升級、預設 Lv.3；TowerGrowth 與遺物分開。catalog 為 17 專屬＋4 通用。ACT 結束等待投射物後，通用／弱關聯／全池隨機三槽選一，再擴入口或結束。迫擊砲固定落點、延遲落地傷害；巡航、處決、貫穿、擊退、增援及全局效果均接入既有戰鬥。 | `TowerMap`、`TowerGrowth`、`RunRelics`、`RelicCombat`、`AttackPayload`；`tests/relics/{stacking,rewards,mechanisms,input}.tscn` |
| 4 協同 | 鼠群按整群分入口／路線、尾群不足不補；盾衛合法單體嘲諷；血法師範圍治療且 Uniform；飛翼獸實際最短路／飛行／對空規則；偵查兵最新完整路線硬性資格；爆破手前搖及限時癱瘓。六模型／圖示／動畫、首次提示／可重開情報、預測均已接入。 | `Troop`、`WaveSpawnSchedule`、`RouteHistory`、`RoadSpecialRoutes`、`EnemyAbilities`；`tests/synergy/{routing,combat,input}.tscn` |

**Frontier 的實際狀態**：`assets/data/levels/frontier.tres` 的 ACT 1／Wave 2 已有 1 名 `shield_guardian`，並有 Soldier 群組；其餘五種新兵種尚未配置進 Frontier。完整六兵編成、節奏與平衡整合尚未進行，不能寫成全部未加入或全部已整合。A–D 合成波次只在獨立 Playground。

## 4. 執行、Playground 與 Editor 入口

| 用途 | 入口與操作 |
|---|---|
| 正式 F5 | `project.godot` → `scenes/level.tscn` → `assets/data/levels/frontier.tres`，地形取 Resource 引用 |
| Phase 1 | F6：`tests/levels/road_flow_playground.tscn`；驗證雙入口、hover 與流量 |
| Phase 2 | F6：`tests/traffic/playground.tscn`；三設施、雙入口、壽命及候選分流 |
| 六塔 | F6：`tests/combat/tower_restoration_playground.tscn` |
| Phase 3 | F6：`tests/relics/playground.tscn`；F7 全專屬、B 補缺塔牌、F9 清波，右上逐件增添／移除遺物 |
| Phase 4 | F6：`tests/synergy/playground.tscn`；右上 A–D、B 補缺塔／設施牌、D 的 N 建同波雙新路及空中打擊開關、F9 清波 |
| 波次 Editor | Godot 底部「波次編輯器」；`addons/wave_editor/`，由 project.godot 啟用。真實 Editor 回歸：`--editor -- --test-wave-editor` |
| 獨立舊入口 | `scenes/main.tscn`、`9x9.tscn`、`11x11big.tscn`；可能自動生怪／提供單塔工具，不是正式操作規則 |

一般操作、拖牌／旋轉／鏡頭／暫停見 [README](../README.md)。F1／F2 是除錯圖層；**F8 是 Godot 停止執行，不能綁補牌**。Playground 熱鍵與資源授予不能視為正式遊戲功能。

## 5. 核心架構與資料流

1. **建造**：TowerDefinition（塔、攻擊、成長、地塊候選）＋TilePreset（相對道路）→ BuildCard（含價格快照）；輔助卡改引用 TrafficStructureDefinition，與塔互斥。CardPlacement 意圖 → TowerMap 驗證整批道路／占格／所有入口 BFS／既有固定行程 → 原子提交 → TileParameters／PortalMap 失效。升級沿原實例，忽略新 TilePreset、不增路。
2. **一般 Cost**：GridMap／障礙快照 → RoadPortalGraph → CandidateRoutes／RoadRoutePlanner 有限正成本探索 → 原始 signed score 與 strict threshold → RouteDistribution 的 Uniform／Softmax → TrafficWeights 的 log 倍率 → CDF。
3. **硬性巡路**：同一已提交路網 → RouteHistory（端點、接口、wave 快照）→ RoadSpecialRoutes 精確最短格距／最新有效通路代表 → 同一分布與設施管線。硬性資格不受普通 Cost pool／threshold 漏路影響。
4. **預覽與出兵**：Level／ACT／Wave／SpawnGroup → WaveSpawnSchedule，按兵種／入口跨群組分配，鼠群先分群 → 個體 pending。預覽 `shuffle_departures=false` → RoadFlowForecast → hover／流量／候選差；正式只打亂出發順序，固定行程、HP、shield、速度與能力快照。UI 不另抽配額。
5. **戰鬥**：Enemy 移動後 → EnemyAbilities（priority 40）建立共用 EnemySpatialIndex、治療／癱瘓 → BarracksSystem（45）→ CombatSystem（50），共用同一索引；必要時有補建索引分支。合法候選內才做嘲諷排序。AttackPayload 保存發射時效果，模型／特效不決定傷害。
6. **構築與階段**：TowerGrowth 基礎成長 → RunRelics 每局持有與效果 → 塔實例／RelicCombat／FriendlySoldier。LevelSession 清波後等投射物 → ACT 遺物選擇 → 擴入口／下一波或結束。交通壽命與死亡清理各由持有者處理。

模組責任看 [architectures](architectures.md)，詳細演算法與參數看 [systems](systems.md)。

## 6. 重要程式檔案索引

以下路徑相對專案根目錄；不搬移檔案、不更改 UID。

| 責任 | 主要檔案 |
|---|---|
| 關卡／排程 | `scripts/levels/level_session.gd`、`scripts/levels/definitions/{level_definition,act_definition,wave_definition,wave_spawn_group}.gd`、`scripts/enemies/spawning/{wave_spawn_schedule,enemy_wave}.gd` |
| 卡片資料／提交／商店 | `scripts/cards/definitions/{build_card,tile_preset}.gd`、`scripts/cards/card_placement.gd`、`scripts/cards/shop/card_shop.gd`、`scripts/towers/tower_map.gd` |
| 塔／成長 | `scripts/towers/{tower_definition,tower_growth,tower}.gd`、`assets/data/towers/` |
| 普通導航／分布 | `scripts/navigation/portal_map.gd`、`scripts/navigation/routes/{candidate_routes,route_distribution}.gd`、`native/src/{portal_graph,route_planner}.cpp` |
| 硬性導航 | `scripts/navigation/routes/{route_history,special_routes}.gd`、`native/src/special_routes.cpp`；原生類別 `RoadSpecialRoutes` |
| 道路保護 | `scripts/navigation/road_graph_snapshot.gd`、`native/src/road_edit_guard.cpp`；地塊資料在 `scripts/map/tile/` |
| 交通 | `scripts/traffic/{traffic_structure_definition,traffic_structure,traffic_structures,traffic_weights,traffic_flow_delta,traffic_delta_overlay}.gd`、`assets/data/traffic/` |
| 流量／情報 | `scripts/levels/presentation/{wave_flow_preview,start_wave_callout,next_wave_intel,troop_intel_item}.gd`、`scripts/navigation/routes/road_flow_forecast.gd`、`scripts/navigation/visualization/road_flow_renderer.gd`、`scripts/enemies/presentation/enemy_intelligence.gd` |
| 遺物 | `scripts/relics/{run_relics,relic_catalog,relic_definition,relic_choice}.gd`、`assets/data/relics/catalog.tres`、`scripts/combat/relic_combat.gd` |
| 戰鬥／索引／接戰 | `scripts/combat/{combat_system,enemy_abilities,enemy_spatial_index,barracks_system,friendly_soldier}.gd`、`scripts/combat/attacks/attack_payload.gd`、`scripts/enemies/enemy.gd` |
| 兵種／模型 | `scripts/enemies/troops/{troop,troop_catalog}.gd`、`assets/data/troops/`、`assets/models/enemies/`、`scripts/enemies/rendering/` |
| 原生依賴／工具 | `road_graph.gdextension`、`native/SConstruct`、`native/src/register_types.cpp`、`tools/build/build_native.ps1`、`addons/wave_editor/plugin.gd` |

## 7. 已定規則與不可破壞條件

- 所有入口可達終點；四向接口、整數座標，斜角不通。道路幾何、兵種評分與流量權重各自失效。
- Cost 保留 `score − min_score < threshold`，等號排除、0 無候選、INF 關閉 cutoff。搜尋用正成本不代表原始評分必須為正；有限池不保證全圖最優或所有同分路線。
- Uniform／Softmax 是基礎分布，設施倍率其後正規化；不讓設施召回失去硬性資格或 threshold 排除的路線。倍率不等於敵人數變化。
- 預覽不改正式效果、不消耗出發 RNG；敵人開波後不尋路，尚待出生個體也不能被重定向。
- 鼠群整群分入口與路線；跨 SpawnGroup 不拼群，最後可不足 5 隻；列表與流量計個體數。
- 偵查兵身份是端點＋完整物理格序列；初圖 wave 0，同波同齡，重搜／快取重建不是誕生，恢復相同行程保留首次出生。
- 同塔升級只消耗一張同種卡，預設 Lv.3；「成為主角」可解除哨塔上限。不能增路、改方向、重設冷卻或寫回共用 TowerDefinition。
- 嘲諷只重排合法單體目標，不擴射程／方向／對空；ALL 攻擊仍打全體。治療不復活、不超 max HP，多名法師各有時鐘。
- 飛翼獸沿最短合法道路上空飛行；兵營近戰不攔截，普通迫擊砲不索敵也不濺傷，空中打擊解鎖；其他射擊塔及神射手可對空。
- 癱瘓多來源各自計時、取最大剩餘值不加秒數；來源死亡移除該份效果，波次結束／卸載／重開清除。既有投射物繼續，塔等級／道路保留。
- 準備不限時；開波有 1.5 秒等待，戰鬥／獎勵／擴入口鎖建造與交易；ACT 遺物先於入口擴張，最後 ACT 亦先選遺物。
- 視覺避讓、浮起動畫與流動筆觸不改邏輯道路、route 或傷害；禁止以候選方向聯集讓敵人自由走邊。

## 8. 引擎、建置與技術限制

本機核對 Godot **4.7.2**、Compatibility／OpenGL、RTX **4060 Laptop**。AGENTS 中舊效能比較所記 GPU 是當時環境，不能套成本次環境。

執行需要 GDExtension，不能只複製 GDScript。固定 `native/godot-cpp` commit `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`，內附 API 是 **4.5**、C++17；擴充 `compatibility_minimum=4.5`，目標引擎是 4.7.2，兩者不是同一個版本欄位。SDK、`bin/` 與 `.godot/` 均被忽略，新的 clone 不會自帶完整可執行依賴。

Windows 工具為 Python 3、SCons 4.11.1、MSVC 14.44.35207、SDK 10.0.26100.0。本機引擎為 `C:\tools\Godot.exe`；可用 Python 在 `C:\Users\USER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`，預設 python／py 別名不可直接假設可用。工具支援 `-Python/-MsvcTools/-WindowsSdk`，可從 x64 Developer PowerShell 執行；詳見 [native/README](../native/README.md)。

- `road_graph.gdextension` 指向 `bin/road_graph.editguard.phase4.*`，不是舊版無 phase4 前綴的輸出。`reloadable=false`，建置後重啟 Godot；勿刪除正在被其他 editor 載入的舊 DLL。
- Windows debug／release 先前已成功建置；本次確認 debug DLL 584,704 bytes、release DLL 538,112 bytes 存在，debug 載入回歸通過；**本次未重建、未執行 release 專用執行測試**。歷史建置 log：`.godot/phase4-native-{debug,release}.log`。
- Web 目標 Emscripten 4.0.20、`threads=no`，匯出 `extensions_support=true`、`thread_support=false`；需對應支援擴充的匯出樣板及 wasm。Phase 4 的 wasm／瀏覽器尚未驗證，不把舊 Web 結果推廣為現版本 PASS。
- 非單調道路歷史（刪除／恢復／重接）最多 **200,000 次搜尋展開**；超限顯示提示並拒絕開波，避免錯選舊路。單調增建用每條可行邊的完整通路代表，最短路用 DAG 邊代表；都不宣稱枚舉所有簡單路線。
- 大路網同步規劃可能停頓，歷史快照及代表集有記憶體成本；長局、反覆編輯、Web 與效能上限尚待量測。

## 9. 已知問題與歷史測試陷阱

| 項目 | 判讀與處理邊界 |
|---|---|
| 本次應用程式錯誤 | 代表性測試無 GDScript／斷言失敗；不等同整個專案無 Bug。Offboarding 沒有修改程式。 |
| 渲染環境訊息 | sandbox 無法建立 `user://` shader cache，兩個渲染 log 有 `ERROR: Can't create shader cache folder`；GPU、實際滑鼠斷言與正常退出仍完成。這是快取限制，不得寫成零引擎錯誤訊息。 |
| 原生 DLL 鎖定 | 歷史舊輸出曾被 editor 鎖住，改 phase4 輸出共存；不能為建置強制關閉使用者 editor。 |
| Editor 權限 | 歷史普通 editor 無法寫 Roaming/Godot 設定；自包含 editor 驗證成功，尚有 profiler user:// 訊息。本次 editor 未重跑。 |
| 舊 route_planner／tile_placement | 硬編可編輯 main 為固定直路及固定 score 等假設；未修復／未重跑，遇失敗先分辨 fixture 與正式資源，不能回退地圖來配合。 |
| troop_profiles | 歷史固定三兵種與 Quickfeet 1.5 的測試已改獨立 fixture／動態 catalog；原正式數值未回退。本次未重跑此項。 |
| hover／F8／遺物選單 | 先前菱形至面板收回、情報入口遮擋、F8 停遊戲、只有單項的選單均已有修正；本次 road_flow 實際 hover 重跑通過，遺物 input 與補牌工具本次未重跑。 |
| 文件與數值 | 本次修正「新兵全部未進 Frontier」及「其餘兵種全 Softmax」等過時文字。數值以現行 Resource／場景覆寫為準，不從歷史報告恢復。 |

## 10. 本次驗證、歷史結果與 NOT RUN

本次在 **2e2de2a** 開始驗證，2026-10-23 20:41–20:43 +08:00，Windows Godot 4.7.2。原始 log／退出碼：`.godot/offboarding-2026-10-23/{headless-results,render-results}.json`，各測試 log 同目錄。測試會更新固定輸出位置，事先將原 `synergy/traffic/relics` 結果複製至該目錄的 `prior-results/`，未刪舊證據。

| 分類 | 結果 | 本次範圍／完成標記 |
|---|---|---|
| Routing／多入口 | **本次 PASS** | `navigation/route_distribution.tscn`（ROUTE_DISTRIBUTION_CHECK）、`multiple_starts.tscn`（MULTISTART_CHECK）；退出 0，無斷言／script error |
| Traffic | **本次 PASS** | `--script tests/traffic/weights.gd` 25 checks；`traffic/integration.tscn` 99 checks；PHASE2 標記 failures=[] |
| Tower Restoration | **本次 PASS** | `combat/tower_restoration.tscn`，failures=0，headless |
| Relics／Stacking | **本次 PASS** | `relics/{stacking,rewards,mechanisms}.tscn`；failures=[]，mechanisms 113 checks |
| Synergy Routing | **本次 PASS** | `synergy/routing.tscn`，357 checks、failures=[]，含 128 小圖 oracle、群體、多入口及預覽一致性 |
| Synergy Combat | **本次 PASS** | `synergy/combat.tscn`，47 checks、failures=[]，嘲諷／治療／對空／癱瘓 |
| 實際渲染 Smoke／輸入 | **本次 PASS** | `levels/road_flow_preview.tscn`，rendered=true、failures=0，真實滑鼠／hover／GPU 流量／重開與 RNG |
| 正式關卡啟動 | **本次 PASS（有限 Smoke）** | `scenes/level.tscn` 實際渲染 180 frames，退出 0、無 script error；沒有操作或跑完整九波 |
| 功能 FAIL | **本次 0** | 上述 10 項 headless＋2 項 rendered；保留 shader cache 環境訊息，不將其藏成無錯誤 log |
| 其餘已驗功能 | **歷史 PASS，本次未重跑** | Phase 4 `synergy/input` 67 checks；遺物／traffic input、pause_menu、level_flow、wave_spawn_groups、48-case teardown、waypoint_routes、troop_profiles、enemy_status 規則、實際 wave editor；見歷史 `.godot/phase4-*.log` 及 synergy/acceptance.md |
| 全套與其他環境 | **NOT RUN** | 全套回歸、現版 Web wasm／瀏覽器、長局平衡／記憶體／效能、release runtime、本次 native 重建、本次 editor |

歷史 Phase 4 合計 **471 checks**（357＋47＋67）；本次只重跑其中 routing／combat，不能把 471 寫成本次結果。歷史 acceptance.md 記的是當時 `1e36ee5` 加未提交實作，現已是提交 `2e2de2a`；原始檔如不在新環境，以上追蹤中的摘要仍保留判讀依據。

## 11. 下一階段：Phase 5 尚未開始

只記錄待討論方向，沒有本次實作或已核准平衡值：

- 五 ACT 節奏與九種兵種的完整編成；補完 Frontier 的六新兵整合（目前只有一名盾衛試配）。
- 鼠群／盾衛／血法師／爆破手的協同強度、對空與硬性選路在長局中的比例。
- 遺物取得節奏、風險交換型特殊事件、Gold 經濟及商店規則變更。
- 長局平衡、難度曲線與效能／Web 驗收；與正式專案／main 的整合計畫。

建議起點是先確認五 ACT 的節奏與經濟／獎勵設計，再決定 Frontier 的資源配置；不要直接把 A–D 合成波次或所有新兵塞入正式關卡。新增事件、ACT、塔、遺物或重構需新指令。

## 12. 新工作階段啟動與驗證

1. 先讀本文件與 AGENTS，確認 cwd／分支／HEAD，執行 `git status --short`、`git branch --show-current`、`git log -5 --oneline`、`git diff --stat`、`git diff --check`。這份文件交付後的 Markdown 差異是預期成果，不要 reset／clean。
2. 確認 Godot 4.7.2、SDK 固定 commit、phase4 DLL 與 `road_graph.gdextension`。依賴缺失時按 native/README 建置，保留原 DLL；重啟 editor 載入，不改正式或舊專案。
3. 用 [tests/README](../tests/README.md) 的最小交接回歸命令重跑必要項目；每次使用新 log 路徑，先保留會被覆寫的歷史輸出。以退出碼、完成標記與錯誤共同判斷，不能只看程式啟動成功。
4. F5 確認正式關卡，F6 選對 Playground；實際驗收 hover／拖牌／像素／動畫須渲染，波次編輯器須真實 editor。headless 不替代上述驗證。
5. 需要 Windows PowerShell 等待 GUI Godot 結束時，使用 `Start-Process -FilePath $godotExe -ArgumentList ... -WindowStyle Hidden -PassThru -Wait`，檢查傳回的 ExitCode 及指定 log；直接 `& Godot.exe` 不作為已等待完成的證據。
6. git diff 應只包含授權範圍。需要 Git checkpoint 時由使用者另行下令；本次文件與代表性檢查適合 checkpoint，但不代表可直接合併 main 或發布 Web。

# 防禦塔資料與舊塔來源

TowerDefinition → 每塔 TilePresetCandidate → 獨立 TilePreset → BuildCard → TowerMap 驗證／提交 → DefenseTower → CombatSystem。
塔清單由 `scenes/cards/card_shop.tscn` 的 catalog 明確引用；維持新版等權洗牌袋，沒有依檔案自動發現或兵營半權重。

## 已移植的五塔

來源為 `D:/games/card-tower-defense/scripts/card_data.gd`、`scripts/tower.gd`、`scripts/soldier.gd` 與 `scripts/soldier_manager.gd`。這些是來源註記，遊戲執行不讀取外部專案。

| 資源 | 原傷害／間隔 | 來源範圍與現版行為 | 原卡價 |
| --- | --- | --- | --- |
| mortar | 8／2 秒 | 索敵圓半徑 3、目標中心爆炸半徑 1；落地時依實際位置扣血 | 14 |
| ballista | 15／1.4 秒 | 前方 1–4 格，單體、不貫穿 | 11 |
| broadside | 8／1 秒 | 左右各 1–3 格，每次單體，按側別選砲口 | 12 |
| crossfire | 4／0.8 秒 | 圓半徑 2 內全部有效敵人 | 13 |
| barracks | 每友軍 4／1 秒 | 兩名友軍；各駐位半徑 1.5 接敵 | 15 |

Sentry 資源、模型、攻擊、範圍與四個現有候選保持原樣。新塔的 `max_health=200`、`threat=1` 沿用新版 TowerConstants，**不是舊塔原始平衡值**；舊版沒有對應塔生命／Cost Routing 威脅參數。Phase 3 已加入卡牌升級與本局遺物；不新增正式 Boss、法術或局外升級。

`VolleyAttack` 共用單體／延遲迫擊砲／全體策略。舊塔保留出生順序優先；圓範圍採格子索引收集候選後精確檢查實際平面距離，方向塔使用 TowerAttackArea。迫擊砲現在以速度 6 格／秒、最短 0.25 秒飛向鎖定的實際位置，落地才結算球形範圍傷害及單次爆炸；保留基本傷害 8 與爆炸半徑 1。其他新版 Arrow／Beam／Projectile 語意不變。

新道路配置逐一轉自 CardData.PATTERNS，每塔四項候選等權 1；兵營只有一個空道路配置，仍需覆蓋既有道路。舊變體沒有獨立前綴名稱，移植配置的 prefix_key 留空，不編造名稱。弩砲舊 +X 朝向整組正規化至 -Z，模型、攻擊與道路一起旋轉。不要把舊道路配置覆寫進 Sentry 目前的地塊。

## 兵營接戰

BarracksDeployment 保存原兩名友軍、生命 40、傷害 4、間隔 1 秒、5 秒重生、移速 64/48 格每秒、接戰距離 16/48 格、駐點接敵半徑 1.5、局部道路搜尋界限 2.1 格。兵營前方道路保留為駐點，塔放置不能覆蓋其他兵營駐點；士兵不占導航格。

兵營卡面攻擊格與新版威脅以駐點中心半徑 1.5 的整格投影呈現，隨塔旋轉；實際接敵仍以兩名士兵各自略微分開的駐位作精確距離判斷，不以卡面格子裁切。

BarracksSystem 在敵人移動後、塔攻擊前更新友軍，沿可行道路局部移動，不更改敵人 route／waypoints／配額。接戰時 Enemy 的移動進度暫停，減速計時仍推進；友軍死亡、目標死亡、塔移除或波次結束會解除接戰。暫停隨 SceneTree 凍結，卸載回收全部友軍。死亡槽位只在戰鬥且駐點仍合法時重生。

原兵種反擊對應 Soldier=5/1 秒、Quickfeet=3/0.8 秒、Heavy=9/1.2 秒，放在各 Troop Resource，於敵人 follow 時複製到實例；這些是舊 grunt／runner／brute 的數值。新兵種預設 melee_damage=0，表示尚未指定，不偷偷借用其他兵種設定。敵人只反擊接戰友軍，不攻擊塔。

## 資產

`tools/assets/restore_towers.gd` 只讀原型，將五塔模型、原配色、砲口、後座組件及友軍剛體關節烘焙進專案場景，並從原 synth_audio 合成四種射擊 PCM 音效；不改 Sentry。重建前檢查手動變更，重建會覆寫這五塔的產生資源。

`restored_tower_visual.gd` 保留各塔後座，`restored_bursts.gd` 移植原視覺爆散曲線與迫擊砲落地呈現；其小型美術 helper 與原協調系統分離。音效共用六聲道播放器、同種最短 25 ms 間隔，使用實際時間；兵營原本沒有專屬射擊音，不新增音效設定。

空艇模型 `broadside.tscn` 已手動拆成 FixedBase（底座／支架）與 Airship（艇身／吊艙／六支砲管及 RecoilAssembly），砲口 paths 隨階層同步更新。moving_body_path 指向 Airship；「出發」與右舷判斷均使用此移動原點，後座仍只推動左右砲組。原型重建工具不包含這次手動分層，重建前須保留此變更。

卡面圖示由原塔模型渲染，沒有以新圖像替代。圖示與場景內模型是否符合桌遊視覺仍可用驗收場景人工檢查。

## 驗證入口

自動：`tests/combat/tower_restoration.tscn`（headless 與渲染）；原有 combat、attack_area、tower_obstacles、card_shop、card_drag_placement、level_flow、road_flow_preview、level_teardown 分別驗證共用流程。

人工：F6 執行 `tests/combat/tower_restoration_playground.tscn`，為獨立雙入口、六塔與三波測試關卡。準備期可 hover 各入口情報，點任一開始按鈕；放大檢查後座、左右砲口、全體射擊、迫擊砲彈道、雙友軍接戰與血條。測試兵種生命 250 及移速 1.6 僅屬測試配方，不改 Frontier。加 `-- --smoke` 會自動開波、拍照並結束。正式 F5 仍使用原 Frontier。

升級倍率與遺物效果見 [Phase 3](../../../docs/phase3.md)。成長 Resource 位於 growth/，迫擊砲與兵營採 damage_only，其他塔採 standard。

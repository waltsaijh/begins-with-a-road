# 三種兵種類別

| 類別 | 腳本 | HP | 速度倍率 | 原始 evaluation | threshold |
|---|---|---:|---:|---|---:|
| SoldierTroop | soldier_troop.gd | 100 | 1.0 | 1 | INF |
| QuickfeetTroop | quickfeet_troop.gd | 50 | 1.5 | threat | 25 |
| HeavyTroop | heavy_troop.gd | 500 | 0.5 | -threat | 25 |

兵種腳本位於 scripts/enemies/troops/，共用 Troop 基底。預設值直接在類別內維護，原有三份 `.tres` 已移除。TroopCatalog 各建立一份共用實例；PortalMap.troop 與 EnemyWave.available_troops 引用相同物件。每隻 Enemy 的當前血量、位置與行程仍獨立。

EnemyWave 右下選單切換下一波與 F1 查看兵種，戰鬥中鎖定。UI、MultiMesh、步態與轉向、視覺分離已移至 scripts/enemies/rendering/；enemy.gd 不引用渲染器，不保存動畫狀態。EnemyWave 自行追蹤存活敵人，路線保護不依賴渲染列表。渲染器在抵達或外部刪除時釋放 slot。

## 評分與候選

三個兵種統一採用候選搜尋 → 原始評分 → 門檻篩選。已移除 scoring_mode、shuffle_candidates、candidate_threshold 別名，以及兵種專屬 candidate_search_cost 覆寫；保留單一 score_threshold 欄位。所有保留候選固定洗牌輪巡，用完一輪才重複。

先共用中性探索的代表池，再加入以原始評分轉為正成本的偏好路線。若全圖最低分 m ≤ 0，以 evaluation + (1-m) 搜尋；最低分為正則維持原值。搜尋值全部為 1 時重用中性池，不重跑。

- soldier：搜尋每格 1；最終以步數評分，INF 保留所有找到的候選。
- quickfeet：通常搜尋成本 1+threat；最終分數為總 threat。
- heavy：通常搜尋成本 1+全圖最大 threat-threat；最終分數為負總 threat。
- 每個節點路線最多取 4 個局部同探索成本走法，依完整地塊序列去重。
- 起點不計費，最終一律保留 score-min_score < threshold，等號排除。

共同平移保留地塊偏好順序，但會改變不同長度路線的搜尋排序；不能將探索最優當成原始分數的全圖最優。負分不進入 Dijkstra；此方案只在有限候選池挑選，不列出所有 simple path 或全部局部同分走法。幾何代表池跨兵種共用；評分／探索計畫按兵種與起點快取，參數改變時失效；重建物理圖清空所有資料。原生正成本 API 保持不變。

## 單隻狀態

開波時複製 max_health、基準速度×speed_multiplier 及完整路線到當波資料。單隻 Enemy 的 health、max_health、move_speed 與位置獨立；不把當前血量放進共用 Profile。修改共用設定只影響未來波次，包含已排入當波但尚未出生者均保留原值。塔攻擊已透過 Enemy.take_damage() 扣血；死亡會清除邏輯與顯示 slot，Wave.killed 與抵達的 completed 分別計數。

## 驗證

`tests/enemies/troop_profiles.tscn` 檢查三種預設、原始正／零／負評分、危險與安全支路、門檻等號排除／INF、較長安全局部繞道、計畫快取、參數失效、洗牌不重複、三種實際生成的血量速度、待生成者的屬性快照，以及 9x9／11x11big 所有起點。

每個實際地圖套用可重現的 threat pattern 後，抽查輸出 score 與逐格 evaluation 加總完全相同。solve_us 記錄包含建立／探索／篩選，soldier 可能已有場景初始化的快取；測量為功能測試單次讀值，非嚴謹基準。原始 Windows／Web 紀錄見 troop_profiles_windows.json／troop_profiles.json。

統一流程通過 enemies、tile_costs、route_planner、debug_overlay、multiple_starts 回歸。Web 單執行緒 Compatibility 驗證工具為 `tools/web/verify_enemy_web.cjs --troops`。O(N) 小兵視覺分離的行為與複雜度保持不變。

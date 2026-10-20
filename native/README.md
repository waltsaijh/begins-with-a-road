# Road portal graph and diverse route pool

Godot 4.7.2 Compatibility、C++17、單執行緒 Web GDExtension。RoadPortalGraph 建立共用幾何；RoadRoutePlanner 直接在完整、有環的雙向入口圖上執行 Dijkstra，沒有 st-numbering 或全域 DAG。

## 建置

godot-cpp 固定 commit e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77，4.5 API；Python 3／SCons 4.11.1；Windows MSVC 14.44.35207／SDK 10.0.26100.0；Web Emscripten 4.0.20、threads=no。

```powershell
./tools/build/build_native.ps1 -Platform windows -Target template_debug
./tools/build/build_native.ps1 -Platform windows -Target template_release
./tools/build/build_native.ps1 -Platform web -Target template_debug
./tools/build/build_native.ps1 -Platform web -Target template_release
```

可提供 -Python、-MsvcTools、-WindowsSdk、-Emsdk。輸出 `bin/road_graph.editguard.*`，road_graph.gdextension 指向各平台版本；reloadable=false，需重啟 Godot 載入。舊已載入 DLL 保留，避免破壞正在開啟的編輯器。

## 資料與 API

RoadPortalGraph.build(cells, ports, start, goal, include_routes=true, extra_terminals=PackedVector2Array()) 的入口／寬區／細走廊縮減保持原本設計。PortalMap 傳 false，避免建圖階段先算一遍全 1 路線；extra_terminals 保留每個額外起點，包括走廊中段、寬區與共享窗口內的 terminal。prepare(graph) 只重建共用實體幾何並清空計畫；不建立定向、rank 或 incidence forest。

```text
prepared = planner.prepare(graph)
plan = planner.find_paths(profile_key, tile_costs, start=-1, goal=-1,
                          score_threshold=10, overlap_penalty=1, search_budget=64)
local = planner.get_region_paths(profile_key)
debug_graph = planner.get_debug_graph(profile_key)  # lazy, for F1 only
route = planner.sample_route(profile_key, seed=0, route_index=-1)
planner.invalidate(profile_key)  # 空字串清全部
```

tile_costs 是與 graph.tiles 同序的 PackedFloat64Array，空陣列為全 1；成本必須為正有限數。進入格才收費，起點免費，反向邊分別計分。每種兵種、每個起點以獨立 key 快取；相同成本可重用該 key 的局部資料與雙向選項。直接改 threshold／penalty／budget 只重建路線池；Resource.changed 的控制器流程會使該兵種所有起點快取失效。障礙佔格在 Snapshot.capture 時排除，不以無限成本交給兵種 evaluation；底下的 TileRecord 保留，但不出現在 ordered 成本欄位。

## 路線池

1. 在完整入口鄰接表跑零懲罰 Dijkstra，保留原圖最佳成本與第一條路線。
2. 在每次搜尋後，累加候選使用過的實體道路計數。搜尋成本是 `edge.cost + penalty * edge.length * uses`。
3. 正反向共享計數；region／corridor／端點共同識別實體道路，平行道路分開。區塊內同成本但步數不同時 edge.length 使用其最少步數，只作探索懲罰尺度，不改變原始成本。
4. 只保留 `route.score - best < threshold` 且 edge 序列未出現的候選。重複／被拒候選仍加探索懲罰，避免停在相同搜尋結果。
5. 一般懲罰搜尋最多 budget 次（1～256）；連續 8 次未新增便進入一輪中繼補路。這是啟發式停止，不證明路線已耗盡。threshold 允許 INF；0 不保留路線。penalty=0 只保留第一條最佳節點路線。

中繼補路以一般探索次數為 0 的實體道路為目標，各方向分別嘗試。先建立共用起點正向／終點反向樹，拼接兩段原始成本最短路與指定 edge；若重複節點，嘗試固定前段重搜後段、固定後段重搜前段，取合法且較便宜者。只執行一輪、去除相同 edge 序列，不列舉 simple path。獨立兩段無衝突時達到該中繼的最短成本下界；修補有衝突的情況不保證全域最優或完整覆蓋。只達 budget 上限而未連續停滯 8 次時不觸發。

正成本最短路不會重複 vertex，但可重訪同一寬區或重用其他路段已經走過的地塊。方向聯集可能有環；已移除 choose_next，敵人須出生時抽取完整路線，而非在聯集中任意選邊。

sample_route 的 route_index=-1 先以 seed 從池條目偽隨機選擇；非負值指定池索引，越界或小於 -1 回傳空。兩種模式都再從區塊內全部同成本走法抽樣，原二參數呼叫的 seed 結果保持一致。回傳 nodes/edges/cells/length/score/best_score/route_index。原生層不追蹤敵人流量，亦非全體逐格路線均勻抽樣；正式遊戲的 PortalMap.allocate_route_for 在 GDScript 端對 threshold 內完整候選依 Troop.route_selection 建立 Uniform 等機率或 Softmax(-score / route_temperature) 表，再以波內序號 / 總數對應累積機率區間，固定路線配額後打亂出發順序；soldier 預設 Uniform，其餘 Softmax；原生 sample_route 的選擇規則保持原樣。EnemyWave 出生前取好本波全部行程（預設 64 隻、每次 1 隻），不在移動時重新查圖。最短路資料只在區塊內以局部 DAG 壓縮同分走法，並未用此 DAG 限制全域道路方向。

## 摘要與複雜度

plan 欄位：valid/error/reachable、score（原圖最佳）、routes（門檻後的候選數）、attempts/expanded/rejected/duplicates/stop_reason、waypoint_attempts/waypoint_searches/waypoint_expanded/waypoint_added、score_threshold/overlap_penalty/search_budget、choice_edges/used_edges/active_nodes、steps/directions（已收錄路線方向聯集）、cached/geometry_cached、cpu_us/local_us/choices_us/search_us/plan_bytes。

區塊局部場及 first-contact 選項建構沿用 BFS／Dijkstra，遇其他入口停止穿越，保留每對全部同分走法。全域 R 次搜尋約 O(R(V+E) log V)，工作量受預算控制；若補路目標有 U 個有向選項，補路額外共用 2 次搜尋；有衝突時每個選項最多 4 次修補搜尋，最壞 O(U(V+E) log V)。補路路線不占一般搜尋預算，常駐路線池 O((R+U)V)，無 simple-path 全列舉。prepare.geometry_bytes 與 plan_bytes 是主要 C++ vector capacity 估算，排除 Godot Variant／摘要／Resource／配置器／暫存／程序峰值，不能當作整個遊戲記憶體用量。

tests/native/diverse_routes.cpp 的 25,600 組小圖起終點對照 simple-path oracle。Godot 的 route_planner／tile_costs／troop_profiles／multiple_starts 測試涵蓋兩張實際場景、局部同分與多起點。跨平台功能比對使用 tools/web/verify_enemy_web.cjs；一次性效能量測場景已清除。舊 ST／detour 核心與失效測試已移除；加權地塊測試直接使用現行 diverse_routes_core.hpp。

## 除錯資料

get_debug_graph(key) 回傳候選池有效 nodes（PackedInt32Array）與 edges（Array）。各 edge 包含 id/from/to/cost/links；cost 是未加探索懲罰的原始成本，links 是該 edge 所有局部同成本走法的實體格座標對。第一次呼叫才封裝並快取，不做額外尋路；回傳深層副本，計畫重建時清除。F1 顯示開啟時才讀取，不增加一般規劃摘要的資料量。

F1 顯示本波各兵種已分配的完整路線，F2 讀取地塊 Resource 顯示威脅與參數；F3 已移除。兩個圖層皆可獨立關閉，無節點 Label3D。

## 新增地塊前置檢查

RoadEditGuard.prepare(cells, ports, terminals) 在完整快照後建立迭代 Tarjan block-cut forest，凍結連接所有起終點的有效地塊為不同 anchor，其餘連通塊至多有一個 anchor。多起點共用檢查。RoadEditGuard.add_cell(Vector2i) 以四鄰格與 union-by-size／path-compression 並查集維護暫緩地塊；只有合併不同 anchor 才回傳 true，需要完整重建。相同接點的死路環不會誤觸發。重建前 guard 已標記 dirty，之後需重新 prepare。初始化 O(V+E)，新增攤銷 O(alpha(V)) 與 hash 查詢，不做路徑列舉。

新增操作遵循 TilePlacement 的自動四向接口刷新；刪除、接口任意修改、移動起終點等操作請呼叫 PortalMap.rebuild()。檢查只影響新增幾何，不攔截塔或兵種成本變更。暫緩地塊仍有 TileRecord；參數顯示與原生 ordered 成本快照分開，避免新增死路導致成本陣列錯位或無效重算。

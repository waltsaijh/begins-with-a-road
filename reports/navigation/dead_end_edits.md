# 新增死路時保留入口圖與路線池

2026-10-16，Godot 4.7.2 Compatibility，Windows／單執行緒 Web。

首次仍完整建立入口圖與候選路線。之後新增道路先交給原生 RoadEditGuard：孤立地塊、只接到同一位置的死路延伸，以及只有單一接點的封閉支環，都不清除原圖、原生規劃器、成本快取或選路進度。累積道路接回有效路網的另一處時，才完整重建並納入所有已暫緩的地塊。同幀多個新增共用一次重建。

## 方法與成本

完整快照後，以迭代 Tarjan 求雙連通區塊及 block-cut forest，標記連接所有起終點的區塊，保留障礙兩側與寬路的實體連通性。非有效部分依單一接點歸併；沒有接點的孤島也保留。新增格只做四鄰格查詢與並查集合併，首次連接到兩個不同有效位置便要求重建。這能辨識接在單一岔口的封閉環，沒有只用 degree 判斷。

初始化 O(V+E)，新增攤銷 O(alpha(V)) 加 hash 查詢；持續保留的檢查資料為 O(V)。不執行 BFS／Dijkstra，也不逐條列舉路線來決定新增地塊是否為死路。初始化採迭代走訪，避免 Web 的遞迴深度限制。

本機制適用 TilePlacement 的新增操作與自動接口刷新。刪除、手動改接口、移動起終點或工具直接修改 GridMap，應明確呼叫 PortalMap.rebuild()；成本／兵種修改仍走原本失效流程。

## 地塊資料

暫緩格仍立即取得 TileRecord，繼承塔覆蓋的 threat／num_towers_around，F2 可顯示與查看。資料集合的 all_tiles() 包含所有實體格，ordered 僅包含目前原生圖的成本欄位。僅修改暫緩格時通知顯示更新，不改變目前成本陣列或重算路線；接通後保留相同 Resource 與自訂參數，再同步到新成本快照。

## 驗證

- tests/native/road_edit_guard.cpp：3,584 次單格／累積新增，逐次對照獨立的 simple-path 窮舉；另驗證單接點支環、重複新增，以及 50×50 全滿區域外連續延伸 1,000 格仍不觸發重建。
- tests/navigation/dead_end_edits.tscn：首次建立、死路保留同一規劃器與成本快取、接回才重建、舊支環／孤島、同幀合併，以及暫緩格塔參數、自訂欄位與 F2 查看。
- route_planner、tile_costs、enemy_profiles、tile_placement，以及敵人／塔／三個除錯圖層回歸測試通過。
- 重新建置 Windows／Web 的 debug／release 擴充。Web release 在 Edge 的結果與 Windows 一致；敵人、塔、除錯與死路新增四組測試均無 console error。

原始結果：dead_end_edits.json、enemies.json、towers.json、debug_overlay.json。執行 tools/web/verify_enemy_web.cjs --towers --debug --dead-end 可收集對照結果。

擴充檔名 road_graph.editguard.*，需重啟 Godot 載入；舊 DLL 保留。

# 連續八次停滯後的中繼補路

2026-10-16，Godot 4.7.2 Compatibility，C++17／單執行緒 Web。

一般重用懲罰搜尋連續 8 次未新增候選後，對探索次數為 0 的實體道路做一輪補路；正反向分別嘗試。先共用起點正向／終點反向最短距離樹，以原始成本拼接起點 → 中繼 edge → 終點。兩段不重複節點時，結果達到該中繼的最短成本下界。有重複時，分別固定前段與後段，封鎖固定段節點後重搜另一段，取較便宜的合法結果。

修補不窮舉所有 simple path，不能保證所有可行中繼都成功或修補結果皆為全域最佳。只做一輪、路線去重，保留原圖最佳第一條。threshold 仍預設 INF；未修改原始評分或對未探索道路折價。補路不占一般搜尋的 64 次預算，池大小可能超過 64。只有耗盡預算而未連續停滯 8 次時不觸發。

## Windows 前後對照

同一主機、Windows template_debug，3 次暖身後 20 次中位數。每次重建規劃器與成本計畫；計時包含局部最短路、入口選項、全域路線池及摘要封裝，不含實體建圖、抽樣或繪製。小幅時間差包含量測雜訊，不能解讀成固定倍率。

| 場景 | 修改前路線／有向 edge | 修改後路線／有向 edge | 修改前規劃 ms | 修改後規劃 ms |
|---|---:|---:|---:|---:|
| 對稱雙環 | 2／6 | 4／8 | 0.063 | 0.089 |
| 9x9 | 63／240 | 63／240 | 2.121 | 2.156 |
| 11x11big，第一起點 | 3／10 | 5／12 | 0.354 | 0.370 |

雙環普通搜尋在第 10 次達到連續 8 次停滯，原本完全不用中央連接。補路只需共用 2 次 Dijkstra，即新增兩種中央穿越路線。11x11big 普通搜尋第 15 次停止，補路嘗試 4 個有向選項、包含修補共 9 次搜尋，新增 2 條路線。9x9 在第 64 次耗盡一般預算，沒有觸發補路，結果保持不變。

## Web 驗證

Edge headless、WebGL 2 Compatibility、template_release、threads=no。相同 3 次暖身／20 次量測，修改後規劃中位數：雙環 0.238 ms、9x9 1.855 ms、11x11big 0.305 ms。Windows 是 debug、Web 是 release，數值不作跨平台速度比較。Web 沒有本次修改前的量測，不能據此推斷 Web 前後速度變化。

Windows／Web 路線數、成本、中央穿越數、探索／補路次數完全相同。敵人、塔與 F1／F2／F3 三組 Web 測試亦通過，沒有 console error。

## 正確性與成本

- tests/native/diverse_routes.cpp：25,600 組小圖起終點對照 simple-path oracle，確認最佳成本、連通、節點不重複、去重、有限 threshold 相容、8 次觸發與預算提前耗盡。另驗證死路不能拼成繞返路線，以及兩段重疊時的修補。
- tests/navigation/waypoint_routes.tscn：逐條抽樣三張配置的候選，檢查四向相鄰、起終點與入口不重複。雙環必須有 4 條路線，其中 2 條經中央。
- route_planner、enemy_profiles、multiple_starts、enemies、towers、debug_overlay 回歸測試通過。
- 最多 U 個未探索有向選項：共用 2 次 Dijkstra，重疊時每個選項最多 4 次修補。最壞額外時間 O(U(V+E) log V)，路線池記憶體 O((R+U)V)。無路徑指數列舉，但不保證極端圖的補路成本仍小。

原始資料：waypoint_routes_baseline_windows.json、waypoint_routes_windows.json、waypoint_routes_web.json。測試入口：tests/navigation/waypoint_routes.tscn；Web 收集：tools/web/verify_enemy_web.cjs --towers --debug --waypoint。原生 API 新增 waypoint_attempts／waypoint_searches／waypoint_expanded／waypoint_added，普通 attempts 仍僅計算懲罰搜尋。

擴充輸出 road_graph.waypoint.*；需要重啟 Godot 載入，舊 DLL 保留。

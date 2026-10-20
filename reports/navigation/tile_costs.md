# Tile 參數、兵種評分與加權最短路（2026-10-15）

此報告保留早期加權地塊量測。現版採雙向有環的有限候選池，並支援 Uniform／Softmax 分配；最新演算法見 [diverse_routes.md](diverse_routes.md)，分配方式見 [route_distribution.md](route_distribution.md)。下文 API 與數據為歷史紀錄。

已實作每格一份參數 Resource，由座標表集中維護，不新增逐格 Node。兵種 Resource 的 evaluation(tile) 使用隱含 self，預設固定回傳 1.0。每份新成本快照逐格評分一次，再將 PackedFloat64Array 交給 C++；尋路和出生抽樣均不回呼 GDScript。

Tile 具名欄位或擴充參數變更、兵種 emit_changed 會立即停用舊快取。保留原座標地塊的參數，即使重建幾何圖也不丟失；目前是執行期間資料，沒有新增存檔系統。評分須為正有限數值。

## 最低成本與全部同分走法

區塊內以加權 Dijkstra 計算正反向距離場，成本全相同時使用 BFS 快徑。全域使用入口圖 A*。成本定義為進入某 tile 時收費，起始 tile 不收費，跨入口不重收，正反向成本分開計算。區塊內可選較長但總成本更低的路線；同分但步數不同的路線全部保留於 DAG。

同分使用相對容差 1e-10，且 DAG 每步距離嚴格增加，不產生迴圈。路線計數飽和只影響顯示，不截斷走法。抽樣保留全部同分選項，但不宣稱完整路線均勻分布。沒有 ZDD 或敵人實體。

## Windows 效能

Godot 4.7.2，Windows x86_64 template_release 擴充。**僅量測兩個使用者場景**，沒有用生成地圖代替。每格 evaluation 都是 1.0；暖機一次、20 次取中位數，場景 SHA256、完整數字在 tile_cost_benchmark.json。

每輪建立全新的 tile 參數紀錄、兵種成本快照與原生規劃器，包含首次初始化成本，沒有以快取命中代替搜尋。實際執行時，幾何重建會重用既有 tile Resource；兵種／tile 參數未變更時會共用成本與路線快取。

| 場景 | 實體格 | GDScript 逐格評分 | C++ 加權資料＋A* 查詢 | 完整首次建立 | 每隻抽定路線 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 9x9 | 312 | 0.152 ms | 0.291 ms | 3.780 ms | 0.00457 ms |
| 11x11big | 146 | 0.073 ms | 0.238 ms | 1.626 ms | 0.01597 ms |

「查詢」含兵種局部距離場、有向入口選項、全域 A* 及回傳資料；原生 A* 核心分別為 0.033 ms／0.005 ms。9x9 沒有寬區，因此局部距離場成本接近零；11x11big 有兩個寬區，局部場約 0.089 ms。

完整建立包含快照、入口與基礎局部建圖、全新 tile Resource、GDScript evaluation、共用幾何、兵種搜尋及顯示資料封裝；不包含場景載入、模型刷新、實際繪圖、敵人生成。各欄中位數不必恰好相加。最大單輪完整建立為 5.109 ms／2.197 ms，不是所有地圖的幀時間上限。

評分每個未快取兵種分別呼叫 312／146 次；快取命中與抽樣都是 0 次。抽樣每輪 100 次，共 2000 次／場景，表列各輪平均的中位數。預設總成本仍為 23／33。

原生常駐資料估算：共用幾何約 21,408／6,924 bytes；每個兵種快取約 55,648／21,800 bytes。包含有向選項與加權局部場，不包含 GDScript Resource、Godot Variant／場景、配置器開銷、暫存或程序峰值。

## 正確性

- C++ 512 種 3×3 tile 成本，與獨立窮舉全部物理路線核對最低成本、走法集合與計數。
- 高成本中心格會改走四步低成本繞行；中心格降至合適成本後，兩步直走與四步繞行同分，三種走法全部存在並可抽出。
- 起始格成本 7、終點格成本 2 的案例，正向成本 5、反向成本 10，沒有端點重收；小數成本亦核對同分。
- GDScript 記錄實際 evaluation 次數，確認每格一次、快取與抽樣不重評分。檢查兩兵種隔離、參數變更立即失效、資料跨重建保留、不合法成本清除舊結果。
- 原入口與局部路線、A* 全部同分集合與兩個真實場景抽樣回歸測試通過。

Windows／Web debug、release 均已建置。Web 保持 Compatibility、WebGL 2.0、threads=false；只做功能一致性驗證，不測速度。兩個實際場景與加權同分案例，各比對 16 條 Windows／Web 抽樣路線，圖統計、成本、最佳選項及完整逐格路線完全一致。加權案例亦確認兩步／四步同分路線都能抽出；N／P 預覽與正式主場景均通過，沒有瀏覽器錯誤。結果記錄於 tile_cost_web.json，預覽截圖為 tile_cost_9x9_preview.png、tile_cost_11x11big_preview.png、tile_cost_weighted_preview.png。

## 使用

PortalMap.troop 指定共用兵種設定；controller.tile_parameters.get_tile(Vector2i(x,z)) 取得該格資料。自訂兵種繼承 scripts/map/troop_profile.gd 並覆寫 evaluation(tile)。自訂設定變更後呼叫 emit_changed；擴充 tile 欄位使用 set_parameter。

先 controller.plan_for(profile)，再於出生時 controller.sample_for(profile, seed)。參數變更後重新取得該兵種 plan。N 預覽一條完整最佳路線；P 檢查區塊內配對的全部同成本方向；Esc 回總覽。原生擴充更新後需重新啟動 Godot。

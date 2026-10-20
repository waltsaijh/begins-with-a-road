# 完整入口圖與分散路線池

測試日期：2026-10-15。Godot 4.7.2 Compatibility；Windows release；Web 為 Edge 無頭瀏覽器、WebGL 2.0、單執行緒 release。兵種每格成本 1、overlap_penalty=1、search_budget=64。

直接在完整雙向入口圖上執行 Dijkstra，沒有全域 DAG 定向。首條保留原圖最佳；後續以探索懲罰分散，原始成本分差必須嚴格小於 threshold。連續 8 次沒有新增或達到預算便停止。不是全部路線，也不是前 K 佳。

9x9 是使用者現有複雜場景：345 格、110 節點、602 個雙向成本選項；11x11big 是目前加入第二起點後的場景：151 格、10 節點、24 個選項。效能表量測各場景原起點；11x11big 兩起點另有功能測試。

Windows 每組三輪、每輪暖機 3 次後保留 20 次，共 60 次；Web 每組暖機 3 次後保留 20 次。Cold 包含快照、建圖、每格 Resource、evaluation、prepare、局部資料、路線池與局部顯示資料封裝；不含載入場景、渲染、測試斷言。搜尋欄只含全域候選池生成。

| 地圖 | threshold | 路線池 | 搜尋次數 | Windows cold 中位／P95 ms | Windows 全域搜尋 ms | Web cold 中位／P95 ms |
|---|---:|---:|---:|---:|---:|---:|
| 9x9 | 10.0 | 10 | 28 | 5.593 / 12.900 | 0.460 | 8.008 / 15.805 |
| 9x9 | 25.0 | 62 | 64 | 6.378 / 8.041 | 0.957 | 7.062 / 8.020 |
| 9x9 | inf | 63 | 64 | 6.104 / 8.218 | 0.931 | 7.025 / 8.760 |
| 11x11big | 10.0 | 1 | 9 | 1.519 / 2.019 | 0.016 | 2.123 / 2.515 |
| 11x11big | 25.0 | 3 | 15 | 1.584 / 2.394 | 0.023 | 2.158 / 2.590 |
| 11x11big | inf | 3 | 15 | 1.612 / 2.372 | 0.024 | 3.862 / 5.965 |

| 地圖／threshold | Windows 抽一條 µs | Web 抽一條 µs | C++ 幾何＋計畫容量估算 KiB |
|---|---:|---:|---:|
| 9x9 / 10.0 | 4.91 | 6.83 | 157.5 |
| 9x9 / 25.0 | 5.28 | 6.04 | 167.8 |
| 9x9 / inf | 5.26 | 5.86 | 168.0 |
| 11x11big / 10.0 | 5.60 | 5.27 | 28.3 |
| 11x11big / 25.0 | 6.94 | 5.88 | 28.5 |
| 11x11big / inf | 6.96 | 10.44 | 28.5 |

容量是主要常駐 C++ vector capacity 估算，排除 Godot Variant／已封裝摘要、Resource、配置器、暫存與程序峰值，不是整個遊戲的記憶體用量。

## 路線分散

每組以相同 256 個 seed 抽樣；Windows／Web 六組候選數與完整逐格行程 fingerprint 全部一致。

| 地圖／threshold | 抽到的不同節點路線 | 中後段離開主路再往前匯回的樣本數 | 最大樣本原始成本 |
|---|---:|---:|---:|
| 9x9 / 10.0 | 10 | 23 / 256 | 31.0 |
| 9x9 / 25.0 | 61 | 14 / 256 | 47.0 |
| 9x9 / inf | 61 | 13 / 256 | 55.0 |
| 11x11big / 10.0 | 1 | 0 / 256 | 33.0 |
| 11x11big / 25.0 | 3 | 0 / 256 | 43.0 |
| 11x11big / inf | 3 | 0 / 256 | 43.0 |

中後段指從 y=0、x≥12 的入口離開主路，之後在更大的 x 回到 y=0；這個指標主要用於 9x9 的中央直路診斷。全域最優仍為 9x9 的 23、11x11big 原起點 33、第二起點 38。保留最佳不代表每批抽樣必然抽到最佳。

9x9 在 threshold=10 時只收錄 10 條，連續無新增而提前停止；不表示圖上只有 10 條合規路線。threshold=25 時收錄 62 條，INF 時 63 條，均受 64 次搜尋限制。局部同成本走法另行保留，不計入節點路線池數量。

## 驗證與重測

- tests/native/diverse_routes.cpp：25,600 組小圖起終點對照 simple-path oracle；原圖最優、反向道路、共用橋、無重複節點、非對稱成本、threshold 等號排除與預算限制。
- tests/navigation/route_planner.gd、tile_costs.gd、enemy_profiles.gd、multiple_starts.tscn：兩張現有場景、逐格實際行程、局部全部同分走法、成本／兵種失效、多起點與 N／R 預覽。
- tests/navigation/diverse_benchmark.tscn：本次 Windows／Web 使用相同測試。tools/benchmarks/benchmark_diverse.cjs 收集 Web，tools/benchmarks/summarize_diverse.py 彙整三份原生 log 與 Web JSON。

四種 Windows／Web debug／release 擴充皆已重建。原始資料保存在 diverse_routes_windows.json 與 diverse_routes_web.json；場景與擴充 SHA256 位於 JSON。舊 DAG 報告屬於不同演算法，不能把其路線總數當成本版候選池數量比較。

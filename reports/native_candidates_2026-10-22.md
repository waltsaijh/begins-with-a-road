# 候選池運算移至 C++（2026-10-22）

後續已完成[P99 判因對照](p99_investigation_2026-10-22.md)：查到 CPU 有效執行速度波動放大既有每幀成本，未發現候選 C++ 搬移增加每幀工作；下文保留搬移當次原始數字，不把它直接判為回退。

本輪比較搬移前的腳本快照（已包含摘要延後、批次配額與波次共用座標）及新的 C++ 批次實作，兩組皆啟用去環。不是與 main 或停用去環比較。兩組共用同次建置的原生圖／搜尋／抽樣核心，以隔離腳本與原生批次後處理的差異；搬移前候選腳本副本已於後續清理移除。

## 搬移範圍與結果一致性

- 局部走法直接在 C++ 展開成整數格子 ID，原始樣本去重、O(L) 去環、路長／實際節點／分段／格子索引重建、去環後去重，整批回傳 packed buffers；不再逐條 sample_route 跨腳本邊界。
- 正搜尋成本驗證與平移、中性成本判斷、合併幾何／偏好代表、原始 signed 評分、嚴格門檻、Uniform／穩定 Softmax 機率表，以及整波 CDF 配額索引改由 C++ 計算。
- 保留原候選順序、第一個重複來源、分段 ID 的首次出現順序、seeded 抽樣、門檻等號排除與 index / total 配額。共用幾何分段登錄不受兵種偏好修改。
- GDScript 保留 Resource evaluation、快取與失效、波次與快照生命週期、唯讀世界座標、場景及除錯顯示。敵人移動與戰鬥迴圈未新增工作；建池函式不由移動迴圈呼叫。
- 原腳本去環移到 `tests/fixtures/candidate_walk_reference.gd` 並保留 UID，只作對照，遊戲不載入測試備援。

新回歸逐條對照 286 條中性／偏好候選及格子、節點、分段、來源順序與診斷數；另以原始分數重算去重、嚴格門檻、CDF 與 256 名配額，涵蓋零機率區間及精確邊界。排程 A/B 的全部快照逐欄相同。六次渲染的敵人路線指紋均為 `3d34a34834cfd982265ecbb9a12f9b8cb6fe948330216f057ed2bf50deca2f0e`（enemy_id 排序之路線 index／cells／score／selection_probability）。各計畫候選條目加總均為 1397、重踩格子的候選為 0，開始與結束皆存活 256 名。

## 環境與方法

32×32 合成地形、801 格道路、16 個房間與窄連接／區內障礙、16 座 Sentry，91 個 vertex／19 個 region。正式關卡與數值沒有為量測改動。沿用目前可編輯兵種設定，Quickfeet 的 path_base_cost 為 0.25，兩組一致；這也使本輪候選與分數不同於早先 0 基礎成本的報告，不跨輪相減。

256 混兵為 Soldier 86、Quickfeet 85、Heavy 85，同時出生；測試副本生命 1,000,000、速度倍率 0.45、波次基準速度 2.5，維持整段負載。Windows、Ryzen 5 4600H、RTX 3050 Laptop GPU、NVIDIA 591.86，Godot 4.7.2 stable editor runtime／template_debug GDExtension、Compatibility，1280×800、VSync 關閉、FPS 不設上限、F1/F2 關閉。相機 near=0.1、far=150，完整取景；原始 PNG 併存。

- 冷建池為全新 native planner + prepare + 三兵種計畫，含共用幾何池重用；不含地圖建圖、Resource evaluation 輸入產生、模型生成與渲染。headless 只量 CPU；一對暖機後交錯前後各 12 次。
- 快取排程為完整行程快照、配額、世界座標與出生刻度，不含模型；一對暖機後交錯各 12 次。256 名共用 213 組不同路徑世界座標。
- 實際渲染交錯 before1 → after1 → after2 → before2 → before3 → after3，各次 3 秒暖機、12 秒 wall 幀間隔取樣；表格採每次統計的中位數。保留全部六次，未剔除較慢樣本。未固定 CPU 時脈與背景負載。
- 12 次中位數取中間兩個排序值的平均；P95／P99 最近秩都對應最大樣本，不據此估計長時間尾端。

## CPU 結果

| 指標 | 搬移前 | C++ 批次後 |
| --- | ---: | ---: |
| 三兵種冷建池平均 | 151.30 ms | 59.03 ms |
| 三兵種冷建池中位數 | 153.45 ms | 58.05 ms |
| 冷建池 P95／P99 | 162.12 ms | 68.17 ms |
| 已快取的 256 名完整排程平均 | 14.34 ms | 13.72 ms |
| 已快取的 256 名完整排程中位數 | 14.13 ms | 14.21 ms |
| 排程 P95／P99 | 16.21 ms | 15.95 ms |

冷建池中位數減少 95.40 ms（62.2%），約為原來耗時的 38%。本輪沒有測得快取排程改善。三兵種建池階段中位數（各自獨立統計，不能相加當總中位數）：Soldier 42.93 → 17.19 ms、Quickfeet 51.26 → 19.41 ms、Heavy 48.65 → 18.75 ms；Soldier 包含首次建立共用中性池。

## 實際渲染與生成

| 指標（三次結果的中位數） | 搬移前 | C++ 批次後 |
| --- | ---: | ---: |
| 平均幀時間 | 12.08 ms | 13.43 ms |
| 各次平均幀時間範圍 | 11.79–13.02 ms | 12.03–15.47 ms |
| P95 幀時間 | 15.90 ms | 18.63 ms |
| P99 幀時間 | 19.04 ms | 27.20 ms |
| 實際渲染程序內的開波排程 | 13.81 ms | 13.16 ms |
| 排程至 256 名全部生成，含首幀等待 | 70.54 ms | 78.34 ms |
| 上列生成的各次範圍 | 63.16–135.26 ms | 58.84–285.46 ms |

本輪平均幀時間及尾端較高，未測得穩態 FPS 或模型生成改善。after2 同時出現排程 55.97 ms、整批生成 285.46 ms 及較高幀間隔；保留此樣本，不以猜測背景負載而剔除。程式呼叫核對顯示搬移的函式只在建池／機率表建立／開波配額時執行，並未加入移動或戰鬥迴圈；本輪短測仍不足以確定渲染差異原因，也不能宣稱整體遊戲每幀已加速或已證明沒有回退。已確認的效益是上述交錯 CPU 冷建池差異。

## 驗證與產物

本輪通過 13 項 Godot 回歸：native_candidates、loop_erasure、route_batch、route_planner、route_distribution、tile_costs、multiple_starts、troop_profiles、wave_spawn_groups、act_spawn_expansion、level_flow、level_teardown（48 cases）及實際渲染 debug_overlay；另通過獨立 C++ candidate_walk 核心測試。troop_profiles 的純威脅示例改用測試副本 path_base_cost=0，避免把正式 Quickfeet 可編輯的 0.25 誤當實作錯誤；未更改正式 Resource。

Windows debug／release 與單執行緒 Web debug／release 四個擴充建置均成功。本輪未執行瀏覽器 Web 遊戲量測，也未做長時間穩定性測試。

原始資料為 `.godot/test-results/navigation/native_candidates_256/` 的 pool_ab.json、schedule_ab.json、summary.json、native-before-1/2/3.json、native-after-1/2/3.json 及 PNG。一次性量測工具及前版腳本快照已依清理要求移除；原始樣本、截圖與 log 保留於本機 `.godot/`，本頁不提供已移除工具的重現入口。本輪誤用 route_planner／tile_costs 的場景入口，之後已改以正確 script 入口重跑；兵種回歸在隔離可編輯成本後重跑，以上通過結果皆以最後有效執行為準。

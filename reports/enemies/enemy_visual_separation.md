# Tile 分群的視覺分離

小兵邏輯位置沿原始中心線行進。只有 MultiMesh 的顯示位置偏移，不改路線、速度、行進距離、抵達時間或塔的已選行程保護。舊出生隨機偏移與 enemy_path.gd 已移除。

## O(N) 預算

每 0.1 秒以 GridMap 的 tile 座標分桶，掃描每隻的同格與八鄰格。每格以索引固定取最多 2 個代表者，固定 2 次迭代；不排序、不先掃完整桶挑最近者、不做格內所有 pair。

- 候選檢查上限：9 × 2 × 2 × N = 36N。
- 全部擠在同一格：2 × 2 × N = 4N。
- 分桶、累積位移、工作陣列與當次 pair 去重皆為 O(N) 空間。Hash 查詢採一般 O(1) 模型，沒有隨桶內人數平方成長的迴圈。
- 固定取樣是一種近似，極端擁擠不保證完全分離。

重疊 pair 沿各自移動方向的左右法線分攤位移，完全重疊時用穩定 ID 打破平手。目標間距 0.36 格，顯示偏移限制為 0.22 格；保持小幅偏移並在轉彎時平滑旋轉。每幀最後由共用 MultiMesh 更新顯示，沒有每隻物理碰撞或減速。預設 1×1 地塊的中心線與偏移限制讓模型維持在橋面附近。

## 測試

`tests/enemies/enemy_visual_separation.tscn`：同位置、跨 tile 邊界、負座標、反向／垂直匯流、slot 順序互換、平滑轉彎、平移／旋轉／縮放的地圖、顯示與邏輯位置分離、刪除中間 slot、最後一隻離場後停止處理。Windows OpenGL 與 WebGL2 皆通過。

極端同格測試每種數量連做 3 次，以下為分群與分離求解的平均毫秒；不含移動、繪製或完整遊戲 FPS。每次成本集中在求解那一幀，並非逐幀分攤。

| 小兵數 | 檢查次數 | Windows | Web |
|---:|---:|---:|---:|
| 64 | 256 | 0.89 ms | 1.60 ms |
| 256 | 1024 | 3.66 ms | 6.57 ms |
| 1024 | 4096 | 15.41 ms | 18.24 ms |
| 4096 | 16384 | 71.19 ms | 59.74 ms |

這是簡短功能壓力測試，受暖機與機器負載影響；線性工作量由固定候選上限保證，不以計時曲線證明。原始數據在 enemy_visual_separation_windows.json／enemy_visual_separation.json。測試工具：`tools/web/verify_enemy_web.cjs --separation --multimesh --walk-render`。

Windows 回歸亦通過 enemies、tower_obstacles、enemy_multimesh、enemy_walk_render。更新的遊戲畫面見 tower_obstacles.png。調整項目集中於 EnemyConstants 的 VISUAL_* 常數。

## 轉彎期間忽略接觸

當模型顯示朝向與實際移動方向相差超過 5 度時，暫時將該敵人從視覺避讓的分桶與鄰居查詢中排除；它不推開別人，也不被直行者推開。轉彎期間保留原本的側向位移向量，不跟著新法向反覆調整，也不強制回到中央。朝向收斂後恢復正常的側向避讓與平滑過渡。角度可由 EnemyRenderConstants.VISUAL_TURN_TOLERANCE_DEGREES 調整。

這是顯示層的接觸例外，轉彎時允許短暫重疊；不修改邏輯路線、速度、行進時間、占格或戰鬥碰撞判定。tests/enemies/enemy_visual_separation.tscn 驗證左右轉、雙向接觸排除、直行鄰居目標不變、轉完恢復，以及原有 O(N) 工作上限。

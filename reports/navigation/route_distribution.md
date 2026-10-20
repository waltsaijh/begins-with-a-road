# Uniform／Softmax 波次配額

soldier 預設 Uniform，quickfeet／heavy 預設 Softmax。模式從 Troop Resource 的 Route Selection 設定，介面的兵種與分配下拉選單已移除。

先保留 `score - min_score < score_threshold` 的有限完整候選；等號排除，INF 停用門檻，0 不保留候選。

- Uniform：每條候選機率為 1/N，忽略 temperature。
- Softmax：p_i = exp(-(score_i - min_score) / temperature) / sum(weights)，temperature 預設 4。

## 決定路線，再打亂出發順序

每波使用局部序號 i = 0…total-1，將 i / total 對應到累積機率區間。邊界屬於下一個非零區間，不使用全域 enemy_id 作 RNG seed。

例如三條 Uniform 路線、五隻敵人：分位數 0、0.2、0.4、0.6、0.8，路線索引為 0、0、1、1、2，固定配額 2、2、1。Softmax 依加權 CDF 使用相同分位數。每條路線的整數配額與 total × probability 相差小於一隻（浮點誤差除外）；極少機率路線可能沒有敵人。當敵人少於路線數，只有部分路線分到敵人。

準備好所有路線與世界座標後，打亂待生成隊列。隨機只影響哪隻先出發，生成間隔與 batch_size 保持原設定；相同候選、模式與總數的路線配額固定。全域 ID 持續唯一，仍供戰鬥等功能識別敵人。

途中修改兵種、模式或地圖不改變本波已預約行程。F3 統計實際分配的人數。sample_for／next_route_for 保留作為探查與預覽抽樣介面，EnemyWave 使用 allocate_route_for。

## 驗證

`tests/navigation/route_distribution.tscn` 驗證三路五兵的真實波次為 2／2／1、Uniform／Softmax 配額、零機率與 CDF 邊界、非法序號／總數、跨波 ID 與打亂順序不改變分配、兵種預設、多起點快取失效、threshold 與已固定路線保護。

`tests/enemies/enemies.tscn` 驗證實際生成／刪除與逐隻配額對應。跨平台報告比較配額，忽略刻意隨機的出發次序。

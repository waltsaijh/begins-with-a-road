# 小兵顯示偏移

目前採用 tile 分群、固定取樣預算的 O(N) 視覺分離，實作為 scripts/enemies/rendering/enemy_visual_separation.gd。小兵邏輯位置保持原始路線中心；只有 MultiMesh 顯示位置平滑左右分開。

沒有出生隨機偏移、每隻避讓路線、碰撞或減速。每波仍預設 64 隻、每次 1 隻、間隔 0.2 秒。

演算法、複雜度限制、Windows／Web 測試與量測見 enemy_visual_separation.md。

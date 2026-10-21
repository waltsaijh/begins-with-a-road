# 防禦塔攻擊格子

在 Godot 建立 `TowerAttackArea` Resource 並存成 `.tres`，再指定給塔資源的 **Attack Area**。在 Inspector 編輯 **Offsets**，每個 Vector2i 代表相對塔中心的一格；第一軸為 X，第二軸為 Z，`(0, -1)` 是模型前方一格。重複座標只計一次，空清單會拒絕放置。

不指定 Attack Area 時，沿用塔的 Attack Radius 圓形範圍。指定後以格子清單為準，可自由增加、刪除或留空格；預覽、實際攻擊與威脅都使用同一份資料，隨卡牌順時針旋轉。

`sentry_forward.tres` 的實際形狀以目前 Offsets 為準。以下是最初的 3×5 範例（獨立測試使用，不限制此資源）：X 從 -1 到 1、Z 從 -3 到 1，總共 15 格。前方為圖上方，塔在 `(0, 0)`：

```text
xxx   Z=-3
xxx   Z=-2
xxx   Z=-1
x箭x  Z= 0
xxx   Z= 1
```

若要完全不含後方，刪除 Z=1 的三格；若要延伸前方，新增更小的 Z。這些修改直接保存在資源中，不需要修改塔腳本。

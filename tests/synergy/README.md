# Phase 4 敵軍協同驗收

獨立合成地圖、雙入口與三個重複測試波次，不修改 Frontier。完整資料與限制見 [Phase 4](../../docs/phase4.md)。

## 手動遊玩

1. 重啟 Godot 以載入新增的 `RoadSpecialRoutes` 原生類別。開啟 `tests/synergy/playground.tscn`，按 **F6**。F5 仍開正式 Frontier。
2. 右上選 A／B／C／D，切換會重建獨立測試關卡。已有六種塔、150 金幣、六塔牌及三設施牌；**B** 或按鈕只補手上缺少的種類。可照一般規則放牌、升級、旋轉、平移、縮放、暫停及調整倍速。
3. Hover 入口菱形展開列表，再 hover 兵種查看對應流量；數量是個體數。點列尾 **?** 查看 Tag、能力與巡路，左側「敵軍情報」可重開已見過的種類。
4. 點「套用分流」在上路放拒馬、下路放窄口，立刻比較實際配額；它建立真正的 TrafficStructure，使用正式權重及三波壽命。也可自行拖放手上的三設施。切換回同場景可重置，比較未分流版本。
5. 點任一入口菱形開波。**F9** 僅在本場景快速清完本波；正常完成則觀察戰鬥。波次間照既有流程選遺物，再準備下一波；第三波結束停止。

| 場景 | 操作與觀察 |
|---|---|
| A 盾衛兵＋鼠群 | 分流前後比較個體流量；單體塔優先攻擊可合法索敵的盾衛，十字火力仍打全體。拒馬改變鼠群整群路線，窄口改變盾衛分布；鼠群被拆離掩護時單體塔可直接攻擊它們。 |
| B 盾衛兵＋血法師＋重裝兵 | 留意血法師綠圈及友軍 HP 回升。窄口調整 large 主力但不調整血法師，血法師不自動追隨；用旗幟可進一步調整適用兵種的分配。 |
| C 鼠群＋爆破手 | 觀察橘色施法圈／指向線／技能條，塔頂閃電表示癱瘓。2.5 秒後或施法者死亡後恢復；兵營也暫停攻擊。 |
| D 飛翼獸＋偵查兵 | 準備期按 **N** 或新增道路按鈕，同波增加兩條較長外圍路。偵查兵分到兩條新路，飛翼獸保持較短原路。按「取得／移除空中打擊」比較迫擊砲；飛翼獸沿道路上空飛行且不被兵營攔住。 |

補牌／分流／新路／遺物開關只在準備期生效。這些快捷鍵是本場景工具，不改正式關卡熱鍵。模型、塔與數值取正式 Resource；測試波次基礎速度為 0.9。

## 自動回歸

在專案根目錄將 `godot` 換成 Godot 4.7.2 執行檔：

```powershell
godot --headless --path . res://tests/synergy/routing.tscn
godot --headless --path . res://tests/synergy/combat.tscn
godot --path . res://tests/synergy/input.tscn
```

- `routing`：六兵種資料、128 張小圖完整 oracle 對照、穩定出生身份、死路、同波雙新路、新路失效與恢復、普通搜尋預算／threshold 隔離、舊路旗幟資格、非單調搜尋超限、整群分配／不足尾群、跨群組多入口個體總數及預覽一致性。
- `combat`：合法與越界嘲諷、穩定優先級、真實單體／ALL 傷害差異、減傷、治療時鐘／多來源／上限／死亡、對空與迫擊砲遺物、飛行不攔截、前搖與癱瘓重疊／死亡／波次清理／恢復攻擊。
- `input`：真實渲染的 A–D 場景、實際滑鼠 hover／?／分流／開波、UI 個體數、雙新路、取得移除空中打擊、正式排程與預覽完整流量相同，戰鬥中實際治療及癱瘓；產生每場景準備／情報／戰鬥截圖。不可用 headless 代替此項。

相關回歸包含 `relics/{stacking,rewards,mechanisms,input}`、`combat/tower_restoration`、`traffic/{weights,integration,input}`、`levels/{wave_spawn_groups,level_flow,level_teardown,road_flow_preview,pause_menu}`、`navigation/{route_distribution,multiple_starts,waypoint_routes}` 與 `enemies/{troop_profiles,enemy_status}`。

當次結果位於 `.godot/test-results/synergy/{routing,combat,input}.json` 及 `acceptance.md`，log 位於 `.godot/phase4-*.log`。Headless 不代表像素驗證；本次 Windows 實際渲染使用 RTX 4060 Laptop、Compatibility。Web 建置／瀏覽器及長時間平衡／效能尚未執行。

# Construction Playground 與回歸

Godot 4.7.2 開啟 `playground.tscn`，F6 可玩；F5 仍是 Frontier。操作、測試補助、兩種獎勵、九組對照、已知限制及當次驗證見 [原型說明](../../docs/construction_prototype.md)。本目錄不參與正式關卡流程。

| 場景 | 方式與責任 |
|---|---|
| shapes.tscn | headless：五配置、四向旋轉、接口、占格、舊格式與 Resource 往返 |
| placement.tscn | headless：複合即時放置、碰撞、原子性、偏移與接口合併 |
| regression.tscn | headless：草稿生命週期、最終聯集、手牌、歷史、升級、多入口及三種兵種排程 |
| geometry.tscn | headless：兩種規則的實際加成、攻擊／威脅、撤回與純卡牌觸發 |
| input.tscn | **真渲染**：實際 SubViewport 鼠鍵輸入、草稿、商店、開波與過波；不等同真人驗收 |
| comparisons.tscn | headless 或真渲染：三情境 × A／B／C；後者另保存 GPU 截圖 |

輸出透過 TestArtifacts 寫入 `.godot/test-results/construction/`。成功須有 `CONSTRUCTION_*` 完成標記及空 failures／零 failures；退出碼本身不足以判定。`fixture.gd` 供給獨立道路／波次／卡牌，`geometry_metrics.gd` 從實際雙向格圖獨立量測，不使用敵人候選數當策略評價。

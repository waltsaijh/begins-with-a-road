# 測試

測試依功能分類；同一項的 `.gd`、`.gd.uid` 與 `.tscn` 保持在同一目錄。`fixtures/` 放共用測試資料，`native/` 放獨立 C++ 核心測試。測試資料與預設值盡量獨立於使用者正在編輯的關卡與塔數值。

| 目錄 | 範圍 |
| --- | --- |
| `cards/` | 卡牌命名、配置、放置、商店與旋轉提示 |
| `combat/` | 塔、障礙物、索敵、攻擊與特效 |
| `enemies/` | 兵種資源、移動、MultiMesh、狀態與視覺避讓 |
| `levels/` | 波次排程、ACT 擴張、地形端點、時間線、暫停與鏡頭 |
| `maps/` | 地塊放置、變種與浮起動畫 |
| `navigation/` | 入口圖、候選路線、配額、多入口與效能 |
| `editor/` | 實際波次編輯器、Undo／Redo、儲存重載與熱重載 |
| `fixtures/` | 固定卡牌與道路配置 |
| `native/` | 不依賴 Godot 畫面的 C++ 測試 |
| `performance/` | Windows／Web 極端路網、多入口、敵群、戰鬥與顯示成本 |

在專案根目錄執行，將 `godot` 換成你的 Godot 4.7.2 執行檔：

```powershell
godot --headless --path . res://tests/levels/level_flow.tscn
godot --headless --path . res://tests/levels/terrain_endpoints.tscn
godot --headless --path . res://tests/levels/wave_spawn_groups.tscn
godot --path . res://tests/cards/card_shop.tscn
godot --path . res://tests/levels/act_spawn_expansion.tscn
godot --editor --path . -- --test-wave-editor
```

滑鼠 hover、像素取樣與動畫截圖測試需要實際渲染，請使用一般執行模式；`--headless` 適合資料與排程驗證。截圖及歷史結果寫入 `reports/` 對應功能目錄；暫時產物放 `.godot/`。Web 驗證工具見 [tools](../tools/README.md)。

跨平台壓力測試使用 `performance/extreme.tscn`，需要實際渲染。執行方法、量測限制及結果見 [效能報告](../reports/performance/extreme_2026-10-20.md)。這是獨立負載場景，使用固定種子及合成地形，不修改正式關卡或兵種數值。

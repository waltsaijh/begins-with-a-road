# 測試

保留可驗證目前行為的功能回歸；一次性效能量測與重複截圖場景已清除。同一項的 `.gd`、`.gd.uid` 與 `.tscn` 保持在同一目錄。測試資料與預設值盡量獨立於使用者正在編輯的關卡與塔數值。

| 目錄 | 範圍 |
| --- | --- |
| `cards/` | 卡牌命名、配置、放置、輸入、商店與旋轉提示 |
| `combat/` | 塔、障礙物、索敵、攻擊、實際繪製與特效 |
| `enemies/` | 兵種資源、移動、MultiMesh、狀態與視覺避讓 |
| `levels/` | 波次排程、ACT 擴張、地形端點、時間線、暫停、清理與鏡頭 |
| `maps/` | 地塊放置、變種與浮起動畫 |
| `navigation/` | 入口圖、候選路線、配額、多入口與編輯失效 |
| `editor/` | 實際波次編輯器、Undo／Redo、儲存重載與熱重載 |
| `fixtures/` | 固定卡牌、道路、像素比對基準與輸出路徑工具 |
| `native/` | 不依賴 Godot 畫面的 C++ 核心測試 |

在專案根目錄執行，將 `godot` 換成你的 Godot 4.7.2 執行檔：

```powershell
godot --headless --path . res://tests/levels/level_flow.tscn
godot --headless --path . res://tests/levels/terrain_endpoints.tscn
godot --headless --path . res://tests/levels/wave_spawn_groups.tscn
godot --headless --path . res://tests/levels/level_teardown.tscn
godot --headless --path . --script res://tests/navigation/portal_graph.gd
godot --path . res://tests/cards/card_shop.tscn
godot --path . res://tests/levels/act_spawn_expansion.tscn
godot --path . res://tests/levels/pause_menu.tscn
godot --path . res://tests/enemies/enemy_status.tscn
godot --editor --path . -- --test-wave-editor
```

滑鼠 hover、像素取樣與動畫截圖測試需要實際渲染；`--headless` 適合資料與排程驗證。JSON 與截圖由 `fixtures/test_artifacts.gd` 建立目錄，寫入 `.godot/test-results/<功能>/`；log 及其他暫存也放 `.godot/`。這些產物不進版本控制或遊戲匯出。Web 驗證見 [工具說明](../tools/README.md)。

`pause_navigation`、`level_hud` 與 `pause_menu` 驗證立即暫停、1x／2x／4x 恢復、介面動畫、鏡頭及血條投影、交易鎖定與重新開始。

`level_teardown` 驗證不同倍速、按鈕／內部開始入口，以及開場等待、尚未出生與存活敵人的關卡清理。一般渲染模式加 `-- --window-close` 會啟動 2x 手動開波視窗，可手動關閉檢查退出錯誤；加 `--4x`／`--direct` 可切換其他情境。

`enemies/enemy_status` 驗證同類減速取最佳強度與最長剩餘時間合併，涵蓋兩種施加順序、到期、短／長刷新及敵人重用；另使用 fixtures 內的舊版繪製進行像素比較，包含分散與重疊順序、不同圖示、圖集／容量成長、樣式烘焙、移除與重用；headless 會略過像素比較。`cards/card_preview` 與 `combat/combat_preview` 雖名為 preview，仍驗證實際輸入提交及攻擊繪製，供 Web 比對使用。

過去的壓測數字僅保留於 [歷史摘要](../reports/performance_2026-10-20.md)，不代表本次回歸結果。未來若需要新的負載量測，依當時問題建立測試並保存當次方法與樣本。

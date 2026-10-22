# 測試

保留可驗證目前行為的功能回歸；一次性效能量測與重複截圖場景已清除。同一項的 `.gd`、`.gd.uid` 與 `.tscn` 保持在同一目錄。測試資料與預設值盡量獨立於使用者正在編輯的關卡與塔數值。

| 目錄 | 範圍 |
| --- | --- |
| `cards/` | 卡牌命名、配置、放置、輸入、商店與旋轉提示 |
| `relics/` | Phase 3 疊加升級、21 件遺物、抽取、協同、真實迫擊砲與實際拖放／三選一 |
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
godot --headless --path . res://tests/levels/road_flow_preview.tscn
godot --path . res://tests/levels/road_flow_preview.tscn
godot --headless --path . res://tests/levels/level_teardown.tscn
godot --headless --path . --script res://tests/navigation/portal_graph.gd
godot --path . res://tests/cards/card_shop.tscn
godot --path . res://tests/cards/card_drag_placement.tscn
godot --path . res://tests/combat/attack_area.tscn
godot --path . res://tests/levels/act_spawn_expansion.tscn
godot --path . res://tests/levels/pause_menu.tscn
godot --path . res://tests/levels/camera_orbit.tscn
godot --path . res://tests/enemies/enemy_status.tscn
godot --editor --path . -- --test-wave-editor
godot --editor --path . -- --test-card-resource-refresh
```

滑鼠 hover、像素取樣與動畫截圖測試需要實際渲染；`--headless` 適合資料與排程驗證。JSON 與截圖由 `fixtures/test_artifacts.gd` 建立目錄，寫入 `.godot/test-results/<功能>/`；log 及其他暫存也放 `.godot/`。這些產物不進版本控制或遊戲匯出。Web 驗證見 [工具說明](../tools/README.md)。

`pause_navigation`、`level_hud` 與 `pause_menu` 驗證立即暫停、1x／2x／4x 恢復、介面動畫、鏡頭及血條投影、交易鎖定與重新開始。

`road_flow_preview` 驗證跨群組加總、兵種 Hover／移開、按鈕標題保留入口篩選、雙入口同兵種的實際 GPU 線段／流量資料隔離、篩選動畫相位獨立、分岔／合流／環路／雙向區段、多入口的獨立按鈕／實際配額、零配額入口、任一按鈕實際點擊開波、無有效路線、非選取兵種成本與幾何失效、RNG／正式配額一致性、列表溢出，以及開波、清波、ACT 選入口、暫停、重開和卸載。渲染模式額外送入實際滑鼠事件並比較明暗漸變相位及無中心線畫面，並驗證動畫不改變 mesh、直段／圓角、雙向側向位置與複製重合線形的像素一致性（允許一階 8-bit 輸出量化差異），輸出 `levels/road_flow_*.png`；headless 不宣稱像素通過。人工驗收可在 editor 開啟 `tests/levels/road_flow_playground.tscn` 按 F6：開始下一波按鈕內有三兵種，下方為兩入口環路，hover 篩選、移開恢復，按開始下一波確認中心線收起；F1／F2 暫時讓出玩家中心線。測試地形及波次為獨立實例，不修改 Frontier。

`level_teardown` 驗證不同倍速、按鈕／內部開始入口，以及開場等待、尚未出生與存活敵人的關卡清理。一般渲染模式加 `-- --window-close` 會啟動 2x 手動開波視窗，可手動關閉檢查退出錯誤；加 `--4x`／`--direct` 可切換其他情境。

`combat/tower_restoration.tscn` 驗證恢復五塔資源／模型／音效、舊塔優先索敵、延遲落地爆炸不重複傷害、全體／單體／方向區分、四向手牌預覽／消耗放置、兵營雙友軍與駐點、反擊、固定行程暫停／繼續、死亡／5 秒重生／塔移除、等權塔種與每塔候選權重。可 headless 或實際渲染。人工 F6 開啟 `combat/tower_restoration_playground.tscn`；加 `-- --smoke` 自動開波並輸出準備／戰鬥截圖至 `.godot/test-results/combat/`。測試資源不寫回 Frontier。商店 UI 回歸使用獨立價格，避免正式塔售價影響動畫／交易測試。

`enemies/enemy_status` 驗證同類減速取最佳強度與最長剩餘時間合併，涵蓋兩種施加順序、到期、短／長刷新及敵人重用；另使用 fixtures 內的舊版繪製進行像素比較，包含分散與重疊順序、不同圖示、圖集／容量成長、樣式烘焙、移除與重用；headless 會略過像素比較。`cards/card_preview` 與 `combat/combat_preview` 雖名為 preview，仍驗證實際輸入提交及攻擊繪製，供 Web 比對使用。

過去的壓測數字僅保留於 [歷史摘要](../reports/performance_2026-10-20.md)，不代表本次回歸結果。未來若需要新的負載量測，依當時問題建立測試並保存當次方法與樣本。

`camera_orbit` 使用實際輸入與獨立 viewport 驗證旋轉速度上限、目前角速度平滑過渡到目標角速度、加速／反向／減速一致、快速多圈不累積及放開後停止、正反向完整畫圓、變動半徑、地面／非卡牌 UI 起拖、中鍵跨過商店卡牌及卡牌上起拖／放開、中心死區、跨 UI 捕捉／放開、卡牌排除、點擊與拖曳分流、暫停選單及地形不變。`camera_limits` 保留方形平移範圍與 0.6x 縮小限制驗證。

`cards/card_drag_placement` 使用獨立 viewport 與實際滑鼠輸入驗證較小的 hover 上提、選中上提與平滑切換、卡面搖動及穩定命中範圍，另驗證手牌拖放、點選後點地圖、有效／無效落點、拖到手牌或商店牌背時取消選取、UI 排除、保留旋轉、鏡頭不被起動，以及 Esc／暫停／開波／離開視窗取消。拖曳預覽截圖與結果寫入 `.godot/test-results/cards/`。

`combat/attack_area` 驗證格子資源儲存重載、Sentry 例圖、四向旋轉、預覽／索敵／威脅一致、非圓形遠角目標、範圍外近敵不搶目標、Resource 修改失效、新道路稀疏影響與圓形備援。預覽截圖與結果寫入 `.godot/test-results/combat/`。原有 combat／towers 的圓形回歸使用獨立範本，避免設計師修改 Sentry 範圍影響測試。

`--test-card-resource-refresh` 透過已啟用的編輯器外掛啟動測試，驗證修改塔範圍 offsets 時的新舊商店卡面、腳本熱更新、部分節點重建與離場通知。測試只修改複製的 Resource，不儲存正式塔資料；結果寫入 `.godot/test-results/editor/`。可使用 headless 編輯器驗證節點生命週期。若正式專案的 GDExtension 被另一個編輯器鎖住，使用預先完成匯入的隔離專案副本（保留 assets、scripts、scenes、addons、測試 fixtures 及本測試，啟用相同編輯器外掛），勿移除正式專案的擴充或關閉使用者的編輯器。

`traffic/` 驗證 Phase 2 標籤、權重、三波設施、雙池商店與真實輸入／流量差；入口及人工步驟見 [traffic/README.md](traffic/README.md)。

Phase 3 的分段自動化與人工操作見 [relics/README.md](relics/README.md)；獨立 `relics/playground.tscn` 提供六塔、同種手牌及逐件授予遺物。現有 ACT／流量／交通設施回歸已在 ACT 邊界先完成遺物選擇。

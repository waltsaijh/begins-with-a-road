# 測試

保留可驗證目前行為的功能回歸；一次性效能量測與重複截圖場景已清除。同一項的 `.gd`、`.gd.uid` 與 `.tscn` 保持在同一目錄。測試資料與預設值盡量獨立於使用者正在編輯的關卡與塔數值。

| 目錄 | 範圍 |
| --- | --- |
| `cards/` | 卡牌命名、配置、放置、輸入、商店與旋轉提示 |
| `combat/` | 塔、障礙物、索敵、攻擊、實際繪製與特效 |
| `enemies/` | 兵種資源、移動、MultiMesh、狀態與視覺避讓 |
| `menus/` | 開始選單的明確橋景／介面、雙語設定、尺寸與真正進入關卡 |
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

`level_teardown` 驗證不同倍速、按鈕／內部開始入口，以及開場等待、尚未出生與存活敵人的關卡清理。一般渲染模式加 `-- --window-close` 會啟動 2x 手動開波視窗，可手動關閉檢查退出錯誤；加 `--4x`／`--direct` 可切換其他情境。

`enemies/enemy_status` 驗證同類減速取最佳強度與最長剩餘時間合併，涵蓋兩種施加順序、到期、短／長刷新及敵人重用；另使用 fixtures 內的舊版繪製進行像素比較，包含分散與重疊順序、不同圖示、圖集／容量成長、樣式烘焙、移除與重用；headless 會略過像素比較。`cards/card_preview` 與 `combat/combat_preview` 雖名為 preview，仍驗證實際輸入提交及攻擊繪製，供 Web 比對使用。

過去的壓測數字僅保留於 [歷史摘要](../reports/performance_2026-10-20.md)，不代表本次回歸結果。未來若需要新的負載量測，依當時問題建立測試並保存當次方法與樣本。

`camera_orbit` 使用實際輸入與獨立 viewport 驗證旋轉速度上限、目前角速度平滑過渡到目標角速度、加速／反向／減速一致、快速多圈不累積及放開後停止、正反向完整畫圓、變動半徑、地面／非卡牌 UI 起拖、中鍵跨過商店卡牌及卡牌上起拖／放開、中心死區、跨 UI 捕捉／放開、卡牌排除、點擊與拖曳分流、暫停選單及地形不變。`camera_limits` 保留方形平移範圍與 0.6x 縮小限制驗證。

`cards/card_drag_placement` 使用獨立 viewport 與實際滑鼠輸入驗證較小的 hover 上提、選中上提與平滑切換、卡面搖動及穩定命中範圍，另驗證手牌拖放、點選後點地圖、有效／無效落點、拖到手牌或商店牌背時取消選取、UI 排除、保留旋轉、鏡頭不被起動，以及 Esc／暫停／開波／離開視窗取消。拖曳預覽截圖與結果寫入 `.godot/test-results/cards/`。

`combat/attack_area` 驗證格子資源儲存重載、Sentry 例圖、四向旋轉、預覽／索敵／威脅一致、非圓形遠角目標、範圍外近敵不搶目標、Resource 修改失效、新道路稀疏影響與圓形備援。預覽截圖與結果寫入 `.godot/test-results/combat/`。原有 combat／towers 的圓形回歸使用獨立範本，避免設計師修改 Sentry 範圍影響測試。

`--test-card-resource-refresh` 透過已啟用的編輯器外掛啟動測試，驗證修改塔範圍 offsets 時的新舊商店卡面、腳本熱更新、部分節點重建與離場通知。測試只修改複製的 Resource，不儲存正式塔資料；結果寫入 `.godot/test-results/editor/`。可使用 headless 編輯器驗證節點生命週期。若正式專案的 GDExtension 被另一個編輯器鎖住，使用預先完成匯入的隔離專案副本（保留 assets、scripts、scenes、addons、測試 fixtures 及本測試，啟用相同編輯器外掛），勿移除正式專案的擴充或關閉使用者的編輯器。

設定頁面回歸併入 pause_menu：文字單選與文字開關、透明背景與遮罩還原、底線動畫、分類、雙語、實際滑鼠、長清單與滾輪輸入隔離、返回及重新開啟；截圖位於 .godot/test-results/settings/。
設定 hover 回歸亦驗證 Light／黑色與 110% 放大、移開恢復 100% 且布局寬度不變、文字開關在仍有焦點時收回底線，以及切換語言保留控制項與動畫進度。
設定主畫布回歸另外核對共用 viewport／canvas 與主 HUD Label 的文字像素一致性，驗證空白邊緣及內容區的背景點擊／旋轉／平移／縮放隔離、Tab 焦點限制、鍵盤啟用及返回後鏡頭恢復；level_teardown 也涵蓋設定開啟時移除 HUD 的鎖定清理。
開始選單的實際渲染回歸：`godot --path . --script res://tests/menus/main_menu.gd`。檢查 F5 入口、固定模型實例、三種視窗尺寸、相機取景、設定頁與 Home 隔離、語言／抗鋸齒沿用至關卡、選圖／返回／Esc、唯讀地形取景、實際 Level 規模與真正場景切換及第一波手動準備。本局設定另檢查同場景與 viewport、下一步不直接開局、切換前後固定介面位置／尺寸與相機不變、兩欄、兩排內容完整位於原描述區、暫定單選互斥與開關、雙語、三種尺寸、逐步返回並保留值、最後發出一次包含地圖及暫定值的啟動意圖，以及新主畫面恢復預設值。亦取樣各次切換的完整白畫面，驗證過渡期間阻擋 Esc／重複操作、4x 戰鬥暫停後回主畫面、離場按鈕背景的白底像素檢查、舊關卡釋放、再次開始恢復全新進度且保留設定；`level_hud` 另檢查返回主畫面的雙語文字。結果與截圖在 `.godot/test-results/menus/`。

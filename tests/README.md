# 測試

保留可驗證目前行為的功能回歸；一次性效能量測與重複截圖場景已清除，功能測試內的重複計時迴圈也已移除，仍保留機率分布及避讓工作量上限等斷言。同一項的 `.gd`、`.gd.uid` 與 `.tscn` 保持在同一目錄。測試資料與預設值盡量獨立於使用者正在編輯的關卡與塔數值。

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

`navigation/debug_overlay.tscn` 驗證 F1 當波各兵種行程與目前圖的全部 vertex 編號／位置、預設隱藏、關閉隱藏、不逐幀重建，以及戰鬥行程固定時節點仍隨路網更新。實際渲染截圖保存於 `.godot/test-results/navigation/f1_vertices.png`。

`godot --headless --path . --script res://tests/navigation/loop_erasure.gd` 驗證建池去環、節點與連續分段重建、去重後的正負原始評分、嚴格門檻、256 名敵人的配額與 32×32 合成房間網路；地形位於 fixtures/route_loop_fixture.gd，不改正式地圖。效能原始樣本保存在 `.godot/test-results/navigation/loop_erasure_256/`，當次精簡結論見 [去環量測摘要](../reports/loop_erasure_2026-10-22.md)。

`godot --headless --path . --script res://tests/navigation/route_batch.gd` 驗證輕量計畫摘要、按需除錯聯集、256 名批次配額與單筆一致、跨群組一次準備、共用唯讀路線／世界座標、快照與地圖 transform 隔離，以及獨立移動進度。效能對照產物位於 `.godot/test-results/navigation/route_batch_256/`，結論見[當次摘要](../reports/route_batch_2026-10-22.md)。

`godot --headless --path . --script res://tests/navigation/native_candidates.gd` 驗證 C++ 批次候選與 scalar 抽樣加腳本去環參考逐條一致，涵蓋節點／分段／來源順序、共用分段表、正成本轉換、signed 評分、嚴格門檻、Uniform／Softmax 與 256 名配額。`fixtures/candidate_walk_reference.gd` 僅供測試；正式運算位於原生核心。`tests/native/candidate_walk.cpp` 可用 C++17 獨立編譯，輸出放 `.godot/`。

## 手動重現 256 混兵場景

開啟 `tests/enemies/mixed_256.tscn` 後按 F6，或執行 `godot --path . res://tests/enemies/mixed_256.tscn`。這是獨立試驗場，不修改正式入口；載入完成後手動按「開始一局」，不會自動生怪。

本分支已移除與 `feat/outer_game_ui` 重複的顯示預熱及等待遮罩，完成建池後即可手動開波。首次模型／材質使用成本可能仍在首次出兵發生；不要套用舊預熱報告的數字。顯示準備回歸由 `feat/outer_game_ui` 的啟動與轉場測試負責。

場景沿用 Web 報告的 32×32／801 道路格、16 座 Sentry、Soldier 86／Quickfeet 85／Heavy 85，同刻生成。兵種使用測試副本：生命 1,000,000、速度倍率 0.45、波次速度 2.5，其餘跟隨目前 Resource。鏡頭支援原有拖曳旋轉、平移與縮放，F1／F2 可查看路線與威脅，建造輸入鎖定。

「清場並再次開波」移除現有敵人與未完成攻擊，保留地圖、候選快取、renderer 及已載入資源；不必等高血量敵人走完。「重新載入場景」重建場景；Web 的首次頁面載入請重新整理瀏覽器。場景沒有自動計時、P99 收集或報告輸出，不與歷史量測數字混用。

Web 匯出及啟動方式（將 `godot` 換成可用執行檔）：

```powershell
./tools/web/export_test.ps1 -Godot godot -Scene res://tests/enemies/mixed_256.tscn -OutputDirectory .godot/manual_mixed_256_web
python tools/web/serve_web.py --directory .godot/manual_mixed_256_web --port 8993
```

開啟 `http://127.0.0.1:8993/index.html`。此測試匯出保留供手動操作，正式 Web 匯出仍排除 `tests/`。

# 測試

波次編輯器回歸亦會移除 ACT／波次控制項，模擬切分支後新腳本仍搭配舊 dock，驗證子介面重建、未儲存／待切換資料、選取及原生 Undo／Redo 保留。`enemies/solid_material.gd` 同時驗證舊 enemy_walk shader 路徑可載入、相容入口與共用材質的實際像素一致；正式模型仍使用同一份共用材質。

保留可驗證目前行為的功能回歸；一次性效能量測與重複截圖場景已清除，功能測試內的重複計時迴圈也已移除，仍保留機率分布及避讓工作量上限等斷言。同一項的 `.gd`、`.gd.uid` 與 `.tscn` 保持在同一目錄。測試資料與預設值盡量獨立於使用者正在編輯的關卡與塔數值。

`godot --editor --path . -- --test-wave-editor` 在實際波次編輯器驗證 ACT／波次新增與刪除、各 ACT 獨立 checkbox（預設勾選）、原生 Undo／Redo 恢復資料及選取、刪到空白後重建、未儲存追蹤與儲存重載。`levels/act_spawn_expansion.tscn` 使用四個 ACT，檢查勾選／未勾選／再次勾選的混合邊界、下一波仍手動開始，以及最後 ACT 不額外擴張；不修改正式關卡。

自動關卡目錄與 DAG：`godot --headless --path . --script tests/levels/level_catalog.gd`，驗證新增／巢狀／刪除檔案、逐層拓撲順序、跨父節點的 sibling ID 排序、掃描順序無關、菱形 AND 解鎖、重複邊、缺失／重複 ID、環及其後代、4096 節點長鏈、保存重載與壞檔保護。`godot --path . tests/menus/level_selection.tscn` 用兩份新 Level 檔驗證自動選項與前置／後代的 01／02 索引、單一延遲預覽、未解鎖按鈕／內部啟動攔截、雙語、實際通關後解鎖、共用場景選中資料與戰鬥中重新開始不誤記通關。可匯出此場景至 Web；第二次以 `?verify_reload=1` 開啟會額外驗證前次的隔離通關檔已持久保存。測試不覆寫玩家資料；輸出在 `.godot/test-results/levels/catalog/`、`.godot/test-results/menus/level_selection/`。

Level 精簡契約亦由上述回歸驗證：ID／檔名推導標題與描述 key，實際選圖雙語切換；`levels/terrain_endpoints.tscn` 檢查缺失端點必須報錯、巢狀變換、模型及多入口保存重載，`levels/act_spawn_expansion.tscn` 檢查自訂端點高度沿用到新增入口與預覽，實際波次編輯器檢查儲存結果不再包含移除的 Level 欄位。

Web 啟動頁交接回歸：`node tests/menus/web_loading_shell.cjs`，依環境提供 `PLAYWRIGHT_MODULE` 及可選 `BROWSER_EXECUTABLE`。驗證引擎完成／native draw 的兩種先後順序、已知／未知下載進度與失敗訊息保留；加 `--live` 連到正式本機匯出，`--url=...` 可改網址並擷取資源載入、native 載入與主選單畫面。產物在 `.godot/test-results/menus/loading_labels/`。`startup_loading.gd` 另外檢查換場景及主選單首次繪製期間持續保有正確階段 label。

啟動預熱回歸：`godot --path . --script res://tests/menus/startup_loading.gd`。驗證三種正式兵種共用一個 GPU shader 代表、明確保留世界共用材質代表、透明材質不誤合併、共用主 viewport、RNG 隔離、資源保留、關卡不重複預熱及 MSAA 改變後補漏；headless 跳過像素／GPU 驗證。

三種兵 GPU 模型回歸：`godot --path . --script res://tests/enemies/enemy_gpu_models.gd`，比對原動畫與 GPU 的頂點／法線／配色、Quickfeet 3 倍播放、停止姿勢、三批混合容量成長與 slot 回收。`godot --path . --script res://tests/enemies/enemy_gpu_render.gd` 以主 viewport 比對 Quickfeet／Heavy 原模型和 GPU 在三種姿勢的像素，必須使用實際 renderer；JSON 與截圖放 `.godot/test-results/enemies/`。

選圖後載入與預熱回歸：`godot --path . --script res://tests/menus/scene_loading.gd`。使用真實主選單檢查未知階段、工作計數單調遞增、兵種代表實際繪製、背景輸入與開波鎖定、RNG／正式敵群隔離、清理及恢復開波；另以 fixtures/loading_target 驗證準備失敗與取消可回到主畫面，這兩個案例會印出預期的轉場錯誤。截圖在 `.godot/test-results/menus/loading_visuals.png`。一般主選單完整往返仍由 main_menu 回歸驗證。


`fixtures/test_artifacts.gd` 在本機寫入 `.godot/test-results/`；Web 匯出的 res:// 為唯讀，因此測試暫存改用瀏覽器內的 `user://test-results/`。瀏覽器 runner 可另外把 console 結果保存至本機 `.godot/test-results/`。正式匯出排除這些測試。

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
godot --headless --path . res://tests/levels/road_flow_preview.tscn
godot --path . res://tests/levels/road_flow_preview.tscn
godot --headless --path . res://tests/levels/road_flow_continuity.tscn
godot --path . res://tests/levels/road_flow_continuity.tscn
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

`road_flow_preview` 驗證跨群組加總、兵種 Hover／移開、按鈕標題保留入口篩選、雙入口同兵種的實際 GPU 線段／流量資料隔離、篩選動畫相位獨立、分岔／合流／環路／雙向區段、多入口的獨立按鈕／實際配額、零配額入口、任一按鈕實際點擊開波、無有效路線、非選取兵種成本與幾何失效、RNG／正式配額一致性、列表溢出，以及開波、清波、ACT 選入口、暫停、重開和卸載。渲染模式額外送入實際滑鼠事件並比較明暗漸變相位及無中心線畫面，並驗證動畫不改變 mesh、直段／圓角、雙向中央位置與複製重合線形的像素一致性（允許一階 8-bit 輸出量化差異），輸出 `levels/road_flow_*.png`；headless 不宣稱像素通過。人工驗收可在 editor 開啟 `tests/levels/road_flow_playground.tscn` 按 F6：開始下一波按鈕內有三兵種，下方為兩入口環路，hover 篩選、移開恢復，按開始下一波確認中心線收起；F1／F2 暫時讓出玩家中心線。測試地形及波次為獨立實例，不修改 Frontier。

`road_flow_continuity` 使用獨立 viewport，驗證四種朝向的路口解析圓角、原直角區透明、接合無縫、雙向中央重合與獨立行進相位、重合透明度聯集、真正端點圓頭與 48 primitive 滿容量十字接點，四種朝向的 1／16 流量差之細→粗／粗→細線寬實測及接點透明度連續性，以及長短支路匯流後的完整相位、環路重訪同一條有向邊、雙向重疊、70 個抵達時間不截斷、週期邊界及篩選快取。渲染模式在每次行程經過的邊中點與終點直接取樣，確認亮段確實顯示到終點；另取樣軟尾與不應亮起的時刻，並以獨立最小距離計算檢查查表的小數時刻。Web 由瀏覽器保存 console JSON，略過不可寫入 res 的檔案輸出。輸出 `levels/flow_continuity_*.json/png`；headless 不宣稱像素驗證。

`road_flow_preview` 亦涵蓋共用 prepare_for_play 的多入口鎖定／恢復、設定頁隱藏所有入口及中心線、配額／RNG 隔離，以及匯出後兵種清單不與標題重疊。結構計數使用 CPU 幾何與網格長度，避免 Web 浮點紋理讀回截斷與 GPU buffer 讀回；完整場景的紋理複製重合測試限 Windows，Web 的同等聯集像素驗證由 road_flow_continuity 的獨立 fixture 負責，不把截斷過的資料寫回遊戲紋理。

`level_teardown` 驗證不同倍速、按鈕／內部開始入口，以及開場等待、尚未出生與存活敵人的關卡清理。一般渲染模式加 `-- --window-close` 會啟動 2x 手動開波視窗，可手動關閉檢查退出錯誤；加 `--4x`／`--direct` 可切換其他情境。

`enemies/enemy_status` 驗證同類減速取最佳強度與最長剩餘時間合併，涵蓋兩種施加順序、到期、短／長刷新及敵人重用；另使用 fixtures 內的舊版繪製進行像素比較，包含分散與重疊順序、不同圖示、圖集／容量成長、樣式烘焙、移除與重用；headless 會略過像素比較。`cards/card_preview` 與 `combat/combat_preview` 雖名為 preview，仍驗證實際輸入提交及攻擊繪製，供 Web 比對使用。

過去的壓測數字僅保留於 [歷史摘要](../reports/performance_2026-10-20.md)，不代表本次回歸結果。未來若需要新的負載量測，依當時問題建立測試並保存當次方法與樣本。

`godot --path . --script tests/enemies/solid_material.gd` 核對道路／木橋的 surface 合併、塔／三兵種的材質身分、烘焙步態參數、特殊材質排除，以及原 StandardMaterial3D 與共用材質的實際像素差異；結果放 `.godot/test-results/rendering/shared_material/`。Headless 只驗證資料，不能替代像素檢查。工具由測試引用，正式匯出仍排除 tests／tools。

`camera_orbit` 使用實際輸入與獨立 viewport 驗證旋轉速度上限、目前角速度平滑過渡到目標角速度、加速／反向／減速一致、快速多圈不累積及放開後停止、正反向完整畫圓、變動半徑、地面／非卡牌 UI 起拖、中鍵跨過商店卡牌及卡牌上起拖／放開、中心死區、跨 UI 捕捉／放開、卡牌排除、點擊與拖曳分流、暫停選單及地形不變。`camera_limits` 保留方形平移範圍與 0.6x 縮小限制驗證。

`cards/card_drag_placement` 使用獨立 viewport 與實際滑鼠輸入驗證較小的 hover 上提、選中上提與平滑切換、卡面搖動及穩定命中範圍，另驗證手牌拖放、點選後點地圖、有效／無效落點、拖到手牌或商店牌背時取消選取、UI 排除、保留旋轉、鏡頭不被起動，以及 Esc／暫停／開波／離開視窗取消。拖曳預覽截圖與結果寫入 `.godot/test-results/cards/`。

`combat/attack_area` 驗證格子資源儲存重載、Sentry 例圖、四向旋轉、預覽／索敵／威脅一致、非圓形遠角目標、範圍外近敵不搶目標、Resource 修改失效、新道路稀疏影響與圓形備援。預覽截圖與結果寫入 `.godot/test-results/combat/`。原有 combat／towers 的圓形回歸使用獨立範本，避免設計師修改 Sentry 範圍影響測試。

`--test-card-resource-refresh` 透過已啟用的編輯器外掛啟動測試，驗證修改塔範圍 offsets 時的新舊商店卡面、腳本熱更新、部分節點重建與離場通知。測試只修改複製的 Resource，不儲存正式塔資料；結果寫入 `.godot/test-results/editor/`。可使用 headless 編輯器驗證節點生命週期。若正式專案的 GDExtension 被另一個編輯器鎖住，使用預先完成匯入的隔離專案副本（保留 assets、scripts、scenes、addons、測試 fixtures 及本測試，啟用相同編輯器外掛），勿移除正式專案的擴充或關閉使用者的編輯器。

設定頁面回歸併入 pause_menu：文字單選與文字開關、透明背景與遮罩還原、底線動畫、分類、雙語、實際滑鼠、長清單與滾輪輸入隔離、返回及重新開啟；截圖位於 .godot/test-results/settings/。
設定 hover 回歸亦驗證 Light／黑色、移入移開均維持原尺寸且布局寬度不變、文字開關在仍有焦點時收回底線，以及切換語言保留控制項與動畫進度。
設定主畫布回歸另外核對共用 viewport／canvas 與主 HUD Label 的文字像素一致性，驗證空白邊緣及內容區的背景點擊／旋轉／平移／縮放隔離、Tab 焦點限制、鍵盤啟用及返回後鏡頭恢復；level_teardown 也涵蓋設定開啟時移除 HUD 的鎖定清理。
開始選單的實際渲染回歸：`godot --path . --script res://tests/menus/main_menu.gd`。檢查 F5 入口、固定模型實例、三種視窗尺寸、相機取景、設定頁與 Home 隔離、語言／抗鋸齒沿用至關卡、選圖／返回／Esc、唯讀地形取景、實際 Level 規模與真正場景切換及第一波手動準備。本局設定另檢查同場景與 viewport、下一步不直接開局、切換前後固定介面位置／尺寸與相機不變、兩欄、兩排內容完整位於原描述區、暫定單選互斥與開關、雙語、三種尺寸、逐步返回並保留值、滑鼠返回保持焦點與底線持續展開、Esc 回退後焦點不留在隱藏選項、最後發出一次包含地圖及暫定值的啟動意圖，以及新主畫面恢復預設值。亦取樣各次切換的完整白畫面，驗證過渡期間阻擋 Esc／重複操作、4x 戰鬥暫停後回主畫面、離場按鈕背景的白底像素檢查、舊關卡釋放、再次開始恢復全新進度且保留設定；`level_hud` 另檢查返回主畫面的雙語文字。結果與截圖在 `.godot/test-results/menus/`。

`navigation/debug_overlay.tscn` 驗證 F1 當波各兵種行程與目前圖的全部 vertex 編號／位置、預設隱藏、關閉隱藏、不逐幀重建，以及戰鬥行程固定時節點仍隨路網更新。實際渲染截圖保存於 `.godot/test-results/navigation/f1_vertices.png`。

`godot --headless --path . --script res://tests/navigation/loop_erasure.gd` 驗證建池去環、節點與連續分段重建、去重後的正負原始評分、嚴格門檻、256 名敵人的配額與 32×32 合成房間網路；地形位於 fixtures/route_loop_fixture.gd，不改正式地圖。效能原始樣本保存在 `.godot/test-results/navigation/loop_erasure_256/`，當次精簡結論見 [去環量測摘要](../reports/loop_erasure_2026-10-22.md)。

`godot --headless --path . --script res://tests/navigation/route_batch.gd` 驗證輕量計畫摘要、按需除錯聯集、256 名批次配額與單筆一致、跨群組一次準備、共用唯讀路線／世界座標、快照與地圖 transform 隔離，以及獨立移動進度。效能對照產物位於 `.godot/test-results/navigation/route_batch_256/`，結論見[當次摘要](../reports/route_batch_2026-10-22.md)。

`godot --headless --path . --script res://tests/navigation/native_candidates.gd` 驗證 C++ 批次候選與 scalar 抽樣加腳本去環參考逐條一致，涵蓋節點／分段／來源順序、共用分段表、正成本轉換、signed 評分、嚴格門檻、Uniform／Softmax 與 256 名配額。`fixtures/candidate_walk_reference.gd` 僅供測試；正式運算位於原生核心。`tests/native/candidate_walk.cpp` 可用 C++17 獨立編譯，輸出放 `.godot/`。

## 手動重現 256 混兵場景

開啟 `tests/enemies/mixed_256.tscn` 後按 F6，或執行 `godot --path . res://tests/enemies/mixed_256.tscn`。這是獨立試驗場，不修改正式入口；載入完成後手動按「開始一局」，不會自動生怪。

本分支已整合 Boot／DisplayWarmup／選單轉場；直接執行此試驗場不經啟動預熱，完成建池後即可手動開波。首次模型／材質使用成本可能仍在首次出兵發生；不要套用歷史預熱或舊 CPU 模型版本的數字。顯示準備回歸由 menus/startup_loading 與 scene_loading 負責。

場景沿用 Web 報告的 32×32／801 道路格、16 座 Sentry、Soldier 86／Quickfeet 85／Heavy 85，同刻生成。兵種使用測試副本：生命 1,000,000、速度倍率 0.45、波次速度 2.5，其餘跟隨目前 Resource。鏡頭支援原有拖曳旋轉、平移與縮放，F1／F2 可查看路線與威脅，建造輸入鎖定。

「清場並再次開波」移除現有敵人與未完成攻擊，保留地圖、候選快取、renderer 及已載入資源；不必等高血量敵人走完。「重新載入場景」重建場景；Web 的首次頁面載入請重新整理瀏覽器。場景沒有自動計時、P99 收集或報告輸出，不與歷史量測數字混用。

Web 匯出及啟動方式（將 `godot` 換成可用執行檔）：

```powershell
./tools/web/export_test.ps1 -Godot godot -Scene res://tests/enemies/mixed_256.tscn -OutputDirectory .godot/manual_mixed_256_web
python tools/web/serve_web.py --directory .godot/manual_mixed_256_web --port 8993
```

開啟 `http://127.0.0.1:8993/index.html`。此測試匯出保留供手動操作，正式 Web 匯出仍排除 `tests/`。

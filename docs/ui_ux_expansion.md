# UI/UX 與入口自由放置

2026-11-19 修正，基於 `1f097a6`。保留原生 Road Graph、候選池、分流、兵種偏好、卡牌與戰鬥規則；本輪不改關卡／兵種／塔的平衡資料，不 commit／push。

## 實際流程

入口擴張仍由 `LevelDefinition.expands_after()` 判斷：`expansion_wave_interval > 0` 時使用全局波數，否則沿用各 ACT checkbox；最終波不擴張。Frontier 目前資料為每五波。清波／在途攻擊結束後，依序處理遺物、玩家入口放置、特殊事件，完成才解鎖準備與開波。擴張期間使用原流程鎖，直接顯示所有允許區域的候選格，不出現方位選擇按鈕。玩家 Hover 預覽入口與道路，點擊合法格才建路與記錄方位；等待、非法點擊與拖曳鏡頭都不會自動放置。無合法方案時略過擴張，繼續原流程。

`SpawnExpansionPlanner` 從與基地連通的道路向外列舉空地入口候選，以目前地圖包圍框分類北／東／南／西四區，不依世界固定座標。只排除上一次成功擴張的區域；沒有其他合法區域才允許同區。區域不永久封鎖。入口與基地至少曼哈頓 8 格、與其他入口至少 6 格；預設搜尋深度 8、外圈帶寬 3，沒有候選才擴至 16 格。

第二關 `frontier.tres` 的 `expansion_blocked_goal_sides=2`：禁止基地東側半平面，不僅按候選區域名稱過濾，因此東北／東南角落也不能放到基地後方。Level 可於 Inspector 勾選不同的禁止側向；其他關卡預設0。列舉候選及最後提交都會驗證。

## 共用建路

`scripts/map/tile/road_construction_search.gd` 只決定建造幾何，供入口擴張及「敵人偵查兵」事件共用。擴張採基地反向的加權 Dijkstra 樹，讓同次所有候選共用搜尋結果；偵查兵使用既有入口並額外允許起點附近合流。

- 每步成本 1；鄰接舊路每鄰格 +8，相隔兩格每方向 +2。
- 獨立方案的中段不走舊路，基地曼哈頓 2 格內允許合流；偵查兵另允許既有入口 2 格內合流。
- 允許區域沒有合理獨立方案才用早合流；舊路成本 2、合流加價 `8 + 距基地格數 × 0.25`。
- 最長路線為 `ceil(入口到基地曼哈頓距離 × 1.75) + 6`，避免極長繞路。每個候選格先嘗試獨立路，必要才早合流；系統不以隨機或分數替玩家挑選區域／落點。
- 偵查兵保留至少新增 4 格、至少 `max(2, 新格數 / 3)` 格不鄰接舊路的條件。搜尋包圍範圍／12,000 格上限仍由事件 catalog 編輯。

提交前以原 `ConstructionLayout`／`RoadGraphSnapshot` 驗證全部舊入口、新入口及基地連通、路徑接口雙向合法，避開塔、特殊地塊、石地、交通設施與兵營駐點。只追加道路，保留原路。提交後沿用 `PortalMap.rebuild()`、地塊外觀通知、原候選與道路流量預測。新路年代在提交前設為下一波。

生成道路的初始接口只保持新路形狀；後續用普通塔牌、事件道路卡或地塊建造銜接時，`ConstructionLayout.open_generated_joins()` 會只開啟本次施工接點所需的雙向接口，預覽與實際提交使用相同結果。未施工的相鄰平行路仍分離，手動配方封閉的出口及障礙仍受保護。`port_overrides` 的 bit4 記錄生成道路來源，低四位才是出口，Snapshot／native只接收實際四向道路遮罩。此修正避免生成接口永久鎖住而使玩家無法把新、舊道路連成支線。

事件波次複製 WaveDefinition 與可變 WaveSpawnGroup，保留不可變 Troop Resource 身分；避免 inline 兵種在預測與開波重新複製時變成不同的統計 key。增援與正常群組仍由同一 WaveSpawnSchedule 計數及真正出生，不修改原關卡資源。

## 資訊與互動

- 敵人頭頂只保留護盾剩餘比例、技能條及效果圖示，一般／受傷／Boss 都不提交生命值條。傷害、護盾、受擊及死亡效果不變。
- 選中敵人死亡時，保存兵種 Resource 與純數值快照、解除 Node 訊號／參照、清除範圍。原底部面板保留 `0 / 最大生命值` 與「已擊殺」；可切換語言／目標或點空白關閉，沒有額外關閉文字。抵達基地、非死亡移除及結算仍清除選取。
- 每入口只常駐一個 `!`，固定 40×44 點擊區；只有字形以中心為軸 ±10° 搖晃。3 秒週期前 1.5 秒平滑來回、後 1.5 秒停頓，使用實際時間，暫停凍結；戰鬥／流程鎖隱藏。
- Hover 顯示本入口最終排程的「本地化兵種 × 數量」直列，沒有敵軍圖示；最多 300×234，過長垂直捲動。按鈕與清單之間的間隙屬同一 Hover 區，清單行仍可篩選原流量預測；只有點 `!` 開波。
- 敵軍情報共用一個含驚嘆號圖示，左上紅 Badge 顯示本局未讀兵種數。實際出生才通知，不自動暫停；點擊開原進度頁後，只將真正顯示詳情的條目標成已讀。全讀完只隱藏 Badge，入口保留，跨局圖鑑保存機制不變。
- 已有遺物列可於 0.18 實際秒收合為圖示＋總件數，含堆疊；寬度隨動畫回收，不改效果。新遺物輕亮且更新數字，不強制展開。窄視窗保留 56px 控制，點擊於標頭下方展開原圖示列，避免壓住中央時間軸。Hover／點擊原效果詳情保留。
- 新字串集中於 `card_names.csv`，包含繁中／英文與現有文本編輯器；新增圖示為專案內 SVG，無外部服務依賴。

## 驗證入口

沿用既有場景及測試方式，輸出仍在忽略的 `.godot/test-results/`：

```powershell
godot --path . --script res://tests/levels/unit_inspection.gd
godot --path . res://tests/enemies/enemy_status.tscn
godot --path . res://tests/ui_slice_a/hud.tscn
godot --path . res://tests/levels/road_flow_preview.tscn
godot --headless --path . res://tests/levels/act_spawn_expansion.tscn
godot --headless --path . res://tests/levels/wave_expansion.tscn
godot --path . res://tests/tutorial/intro.tscn
godot --headless --path . res://tests/events/regression.tscn
godot --headless --path . res://tests/relics/input.tscn
```

實際結果與尚未執行項目以 [HANDOFF](HANDOFF.md) 本次紀錄為準；加速清波流程不代表十五波自然遊玩或平衡驗收通過。

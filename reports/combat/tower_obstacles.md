# 防禦塔基底、哨塔與障礙佔格

2026-10-16，Godot 4.7.2 Compatibility。

## 結構

- `scripts/towers/tower_definition.gd`：全域 TowerDefinition，Resource 描述塔種名稱、模型、footprint、射程與威脅。不同塔種使用不同定義，不修改共用單例。
- `scripts/towers/tower.gd`：全域 DefenseTower，共用實例基底，保留 anchor、放置當下的佔格及可變影響參數。可繼承加入其他行為。
- `scripts/towers/tower_constants.gd`：全域 TowerConstants，共用預設射程 3、威脅 1、一格 footprint 與模型高度偏移，直接呼叫不需 preload。
- `scripts/towers/tower_map.gd`：管理 anchor 與完整佔格兩份索引；驗證成功才提交障礙及影響。TowerMap.tower_scene 是預設塔型，place_tower(cell, custom_scene) 可使用其他場景。
- `assets/data/towers/sentry.tres`、`scenes/towers/sentry.tscn`：木架哨塔實例，沿用共同 tower.tscn 基底。一格佔格，仍維持原本威脅資料用途，未增加射擊／傷害系統。
- `tools/assets/build_tower.gd`：讀取 card-tower-defense/art/towers/skybridge_towers.gd 的 kind=0，離線烘焙共用配色 mesh。正式資源 assets/models/towers/sentry_base_mesh.res 與 sentry_weapon_mesh.res 分別是固定底座與可旋轉弩機，各一個 surface、合計 265 三角形，不依賴原型專案或執行時模型建構器。

塔種定義供放置時使用；改動已放置塔的射程／威脅，使用實例的 setter。變更已放置塔的 footprint 應透過移除／重新放置完成，不能直接修改共用 Resource 繞過驗證。移除經由 TowerMap.remove_tower，確保障礙與影響一併撤銷。

## 放置與移動

1. 計算完整 footprint，拒絕不存在地塊、重疊、起點或終點。
2. 檢查待生成敵人的完整行程及存活敵人的剩餘路段。這些區域不能建塔；包含正在行走的線段兩端，已走過且無其他預約的格子會釋放。
3. 將候選障礙從道路快照排除，按雙向接口執行一次由終點出發的 BFS，確認所有起點仍連通。
4. 驗證成功才登記塔、更新 blocked_cells、合併同幀的入口圖重建及更新局部威脅／鄰塔數。拒絕不改模型、威脅或 revision。
5. 新路線池與區塊內同成本走法都由排除障礙後的圖生成，不能透過自訂 evaluation 走進塔內。移除後恢復通行。地塊 GridMap 不刪除，blocked tile 的 TileRecord 仍保留，但不佔 native cost array 的位置。

右鍵任一佔格可移除整座塔，左上顯示拒絕原因。原始主場景是一格寬橋梁，需先擴建可繞行道路，才可在橋上建塔。沒有新增 Physics 碰撞或每幀尋路；敵人維持出生前選定行程與既有 MultiMesh／步態。

快照及 BFS 每次建塔約 O(V+E)，只在操作時執行；原生縮減圖與路線池同幀合併重建。威脅影響保持局部圓形更新，射程以 anchor 為中心，八鄰域統計不包含 anchor 自格。一般最短路仍是在現有入口圖上評分：寬區的窗口代表點可能增加實體繞行距離，本次未重寫該縮減規則；狹路測試的繞行成本則與逐格最短距離一致。

## 多起點

RoadPortalGraph.build 新增可選 extra_terminals 參數，保留額外起點在窄走廊、寬區及共享窗口內的節點。障礙改變 degree 時，第二起點不會因普通走廊壓縮而消失。既有五參數呼叫保持相容，PortalMap 傳入所有起點。Windows／Web 的 debug／release 四份擴充均重新編譯。

## 驗證

`tests/combat/tower_obstacles.tscn` 在 Windows／Web release 通過，結果一致，152 條抽樣行程皆不穿過任何 footprint。涵蓋原型模型、多格共用基底、重疊拒絕、狹路最佳繞行、寬區繞行、移除恢復、TileRecord identity 保留、兩個起點、最後通道封路拒絕、待生成／存活行程保護、走過格子釋放。結果見 tower_obstacles.json。

`tests/combat/towers.tscn` 保留圓形邊界、八鄰域、自格排除、影響疊加、射程／威脅修改、新增道路繼承、右鍵操作與每次一個通知的檢查。dead_end_edits fixture 改將塔放在獨立死路格，驗證障礙排除後仍保留新增死路略過與重新接通重建。

Windows 通過：towers、tower_obstacles、enemies、debug_overlay、dead_end_edits、tile_costs、multiple_starts、tile_variants、tile_animation。獨立 C++ portal_graph 測試通過，包含新增的窄走廊／寬區額外 terminal 與原有 3,000 個隨機地圖拓撲對照。

Web release／Edge WebGL2：towers、tower_obstacles、enemies、debug_overlay、dead_end_edits 全部與 Windows 結果一致，沒有 script／shader／browser console error。獨立測試專案匯出，不改正式 main_scene 或 export 排除設定。

實際 OpenGL 預覽見 tower_obstacles.png：三座哨塔形成部分屏障，20 隻敵軍沿上下兩側通行，F3 綠線顯示本波已預約行程。未進行 FPS／計時 benchmark。

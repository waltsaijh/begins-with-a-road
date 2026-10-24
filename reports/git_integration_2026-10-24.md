# origin/main → Routing Sandbox 本地整合

核對日期：2026-10-24（Asia/Taipei）。本報告與整合一同收錄於雙親 Merge Commit；該 commit 的兩個 parent 如下。只在 `D:\games\begins-with-a-road-routing` 整合，沒有 push、rebase、force、reset、clean 或修改正式 worktree 的檔案。

## A. 分支與保護

| 項目 | 實際值 |
|---|---|
| fetch 後 origin/main | `a5422c8d8bcadd41d0580c0115c0f8519437092d`，merge 第二親 |
| Sandbox 原 HEAD | `c33d425310acd512459cc4d24bb54b4354b9d798`，merge 第一親 |
| 共同祖先 | `2fe5adc98edbc94de558e95bf40e92a0fe1ff9e6` |
| Sandbox 原 upstream | `origin/experiment/routing-sandbox` 同為 `c33d425` |
| 正式工作目錄的本地 main | `32aea8bee0293d44e95de457d93b55d6250f9178`；未移動此分支 |
| 初始未提交內容 | 42 個 tracked 修改、77 個 untracked 檔案，包含完整 Phase 5 |
| 安全 stash | `d884400fc38ba15e429a5f1f9f2b260eb04948aa`，含 untracked，保留未刪 |
| 原始檔案備份 | `.godot/merge-main-2026-10-24/original-files/`，119 個檔案與 SHA-256 manifest |

開始時沒有進行中的 merge、rebase、cherry-pick 或 revert。Git metadata 位於 linked worktree 共用的正式專案 `.git`；fetch、index 與 commit 的寫入經額外權限執行，沒有因此操作正式工作檔案。正式 worktree 另有自身未提交修改，本次沒有處理它們。

main 在共同祖先後新增兩筆：

- `cd3491d`：Troop icon redesign，Soldier／Quickfeet／Heavy 的圖示與 import UID。
- `a5422c8`：Fix road flow continuity and smooth centered junction rendering，完整行程相位、中央雙向幾何、解析路口圓弧及寬度銜接、回歸與文件。

Sandbox 在共同祖先後有六筆：`0d78db6`（既有 main 同步 merge）、`297d6dd`（交通與五座恢復塔）、`477580c`（疊塔／遺物）、`1e36ee5`（下一波顯示與測試修正）、`2e2de2a`（六種新兵）、`c33d425`（交接文件）。雙向 `git cherry` 的非 merge 提交均為 `+`，沒有 patch-id 等效的重複提交；Phase 1 與舊 main 同步已在共同歷史中。

採正常 `git merge --no-commit --no-ff origin/main`，逐段解衝突、驗證後提交。Phase 5 保持原本未提交狀態：先 stash，再把已解決的 merge 暫存，之後以原檔備份及四份文件的三方合併還原 WIP，不將 WIP 放進 merge index。安全 stash、原始 patch 與檔案備份都仍保留。

## B. 衝突與語意

| 衝突檔案 | 雙方修改與解法 |
|---|---|
| `AGENTS.md` | Sandbox 的菱形 hover／情報規則，與 main 的完整路線動畫／中央雙向線都修改同一段。保留 Sandbox 互動規則，納入 main 的新顯示語意，取代舊側向雙線描述。 |
| `docs/architectures.md` | 相鄰表格列同時編輯。保留 Sandbox 的硬性選路、歷史、交通權重責任，加入 main 的完整行程相位與查表責任。 |
| `scripts/levels/presentation/wave_flow_preview.gd` | main 將 renderer.display 從三參數改為四參數；Sandbox 同處加入 baseline／候選流量差、無效候選提示與 Scout 錯誤提示。使用目前 forecast 的 `animation(profile, selected_origin)`，保留全部 Sandbox 比較及提示，同一 profile 同時用於前後篩選。 |

未提交修改本身也會阻止安全直接 merge，因此先保護。除上述三個文字衝突外，沒有 rename/delete 衝突，沒有 `.tscn`／`.tres` 結構性 merge conflict，也沒有 C++ API 衝突。端點差異中的大量「D」是直接比較 main 與 Sandbox 的不同內容，並非 main 新提交刪除 Sandbox 功能；以共同祖先的三方差異判讀。

實際載入另外發現 main 更新三張 PNG 的 import UID，卻沒有更新 Troop `.tres` 的引用。雖然文字合併成功，Godot 仍發出 invalid UID 警告並回退到文字路徑。本次只更新這三個引用 UID，保留圖示與所有兵種數值。

乾淨副本的 editor import 發現既有 `@tool` 開波提示直接讀取 SubViewport 不存在的 `mouse_exited` 訊號；合併前副本同樣出錯。本次以 `has_signal` 保護連線，正式 Window 與測試自訂 SubViewport 仍照原樣連接。這是載入相容性修正，沒有改遊戲 hover 邏輯。

## C. 實際內容與保留範圍

main 的 22 個變更檔案都已納入。相對 Sandbox 原 HEAD，本次 merge 修改／新增 29 個檔案：

| 類別 | 檔案 |
|---|---|
| 圖示 | `assets/sprites/troops/{soldier,quickfeet,heavy}.png` 及各自 `.png.import`，共 6 檔 |
| UID 修復 | `assets/data/troops/{soldier,quickfeet,heavy}.tres`，共 3 檔，只改引用 |
| 流量 | `assets/shaders/road_flow.gdshader`、`scripts/navigation/routes/road_flow_forecast.gd`、`scripts/navigation/visualization/road_flow_renderer.gd`、新增 `road_flow_phases.gd` 及 `.gd.uid`，共 5 檔 |
| 協調／載入 | `scripts/levels/presentation/{wave_flow_preview,start_wave_callout}.gd`，共 2 檔 |
| 測試 | `tests/levels/road_flow_preview.gd`、新增 `road_flow_continuity.{gd,gd.uid,tscn}`、`tests/traffic/integration.gd`、`tests/cards/card_drag_placement.gd`，共 6 檔 |
| 文件 | `AGENTS.md`、`docs/{architectures,systems}.md`、`tests/README.md`、`reports/README.md`、main 的 `reports/road_flow_continuity_2026-10-24.md`、本報告，共 7 檔 |

交通整合回歸增加五項檢查：候選完整行程相位、入口／兵種篩選、取消後恢復篩選基準、離開篩選恢復全體基準，以及篩選不重建排程。

拖牌測試在合併前副本也無合法落點，因其假設可編輯 Frontier 必有特定卡牌落點。改用既有合成 Level fixture，並比照既有 traffic/relic input fixture 等待視窗初始化、送出 SubViewport mouse-enter。原拖放、點放、旋轉、UI 排除、封頂塔、暫停／Esc／離窗取消等斷言全保留；失敗時若沒有建成塔，立即回報失敗而不繼續對 null 呼叫 upgrade。

Phase 1–5 的正式功能與原 WIP 均保留：流量／三設施、六塔、疊塔、17 專屬＋4 通用遺物、九種普通敵人、群體／最短／最新路線、五 ACT／十五波、防線、Boss、經濟與測試工具。Frontier、六塔數值、Boss 資源、Phase 5 戰鬥／帳本程式皆與開始時備份逐 byte 相同；沒有新功能開發或平衡調整。

四份重疊文件作三方還原；`docs/HANDOFF.md` 額外加入本次同步補註。其餘原有 114 個檔案仍與原始 SHA-256 相同。Phase 5 的 42 tracked 修改及 77 untracked 檔案仍留在工作區，未偷偷納入此 merge。

## D. 本次驗證

原始 log、JSON、截圖、匯出副本與備份集中在 `.godot/merge-main-2026-10-24/`。Phase 5 歷史 reports 沒有重寫，也沒有當成本次結果。

| 項目 | 結果與證據 |
|---|---|
| Git | PASS：工作樹／index `diff --check`、無 unmerged entries、無刪檔；正常雙親歷史。 |
| Scene／Resource 靜態引用 | PASS：236 份 `.tscn`／`.tres`，無重複宣告 ID、缺少 ExtResource／SubResource、遺失引用檔或可核對的 UID 不一致；`resource-audit.json`。 |
| Godot 匯入 | PASS：Godot 4.7.2；工作區及匯出的 merge tree 最終 editor import 均 exit 0、無 error／warning；`import-verified*`、`commit-tree-import-verified*`。 |
| 資料／戰鬥／路線回歸 | PASS：22 個 headless 場景；`headless-final/results.json`。 |
| 實際輸入／渲染回歸 | PASS：10 個場景；`rendered/results.json` 的兩個初輪失敗由 `rendered-final/results.json` 對應最新結果取代，原紀錄保留。 |
| main 的流量修正 | PASS：27 route probes、78 pixel probes、56 線寬取樣、四個朝向、70 抵達相位與 48 primitive 容量，`rendered/levels-road_flow_continuity.log`。 |
| Phase 5 規則 | PASS：64 checks，包含載入價格、五 ACT／十五波、九普通兵＋Boss、四次遺物、勝敗與生命週期；`headless-final/balance-rules.log`。 |
| 正式入口 | PASS：`res://scenes/level.tscn` 直接渲染 180 幀，exit 0、無錯誤／警告；`frontier-smoke*`。 |
| 完整十五波渲染局 | PASS：generalist／seed 11／final，470 出生、470 擊殺、0 漏敵、20 防線、剩 1 Gold；六種塔、10 次建造、13 次升級、四次遺物選擇、勝利後實際點擊重開成功；`full-run/`。 |
| 獨立帳本 | PASS：`tools/balance/analyze.py` 重算本次一局 trace，`INDEPENDENT_LEDGER_PASS 1`；`full-run/independent.json`。單種子回歸不構成新的平衡結論。 |
| 待提交內容獨立運作 | PASS：從 Git index tree 匯出到 `.godot/.../commit-tree/`，不帶 Phase 5 WIP；三項 headless＋兩項 rendered 通過。之後同步唯一的 @tool guard 修復並再次 editor import 通過；沒有建立其他 Git worktree。 |
| Native runtime | PASS：本次程序載入 Phase 4 debug DLL；357 項 synergy routing、47 項 combat 等實際執行專用選路與戰鬥。 |
| Native build | NOT RUN：相較合併前，`native/`、`tools/build/`、`road_graph.gdextension` 與 `project.godot` 沒有變更；沒有聲稱本次重建成功。 |
| Web／release／效能／真人 | NOT RUN。Windows Compatibility 的自動輸入與截圖不代表瀏覽器、release、效能或人工體驗驗收。 |

22 個 headless 場景為：`levels/{road_flow_continuity,road_flow_preview,wave_spawn_groups,terrain_endpoints,level_flow,act_spawn_expansion,level_teardown}`、`navigation/{route_distribution,multiple_starts,waypoint_routes,dead_end_edits}`、`traffic/integration`、`combat/{tower_restoration,attack_area,combat}`、`enemies/enemy_status`、`relics/{stacking,rewards,mechanisms}`、`synergy/{routing,combat}`、`balance/rules`。

10 個 rendered 場景為：`levels/{road_flow_continuity,road_flow_preview,pause_menu}`、`traffic/{integration,input}`、`cards/{card_shop,card_drag_placement}`、`relics/input`、`synergy/input`、`balance/defeat_input`。此外完整局與正式入口 smoke 分別列出，不混入這 32 個功能場景，也不把 assertion 數當場景數。

本次渲染器是 OpenGL 3.3 Compatibility／NVIDIA GeForce RTX 4060 Laptop GPU。已實際檢視完整局的 Boss／結果截圖。SDK pin 為 `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`；所載入 DLL 的 SHA-256 為 `A74CFDF493D17F9E3C995A29A97C71E982FE3E5C505703E56B12039A3C93ACD4`。

初輪問題完整保留：首次背景匯入未完成造成新類別未註冊，改為等待程序結束後解決；沙箱 editor settings-save 錯誤以正常使用者設定／快取權限重新驗證；三個 invalid UID 引用已修正；乾淨匯入先讀尚未生成的字型快取，完成匯入後重跑消失；@tool 訊號相容性已修正。

道路 hover 初期兩輪有間歇斷言失敗，診斷版、原測試的獨立串行重跑、待提交副本與最後回歸均通過。沒有修改正式 hover 邏輯，也不將這種時序現象宣稱已證明根因；原始失敗 log 在 `rendered/`、`rendered-recheck/`，人工互動仍為 NOT RUN。拖牌 fixture 的原始失敗、修復過程與合併前對照在 `before-rendered/`、`rendered-fixed/`，最終原斷言全部通過。

## E. 交付狀態

本次完成正常本地 Merge Commit；`origin/main` 應為其祖先，Sandbox 原 HEAD 是第一親。未推送，未將 Sandbox 合併回 main。工作區仍保留上述 42 個 tracked 修改與 77 個 untracked Phase 5 檔案，另包含 HANDOFF 的本次補註；沒有未解決衝突或進行中的 Git 操作。

可以在目前 Sandbox 工作區繼續開發。此 commit 本身未收錄 Phase 5，因此分享／發布完整 Phase 5 前仍需要使用者另行決定如何提交那批既有 WIP。不要直接 `stash pop`：WIP 已恢復，安全 stash 留作備份而非待套用工作。本次工作到本地同步停止。

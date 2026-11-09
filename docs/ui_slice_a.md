# UI Slice A — Combat HUD & Enemy Codex

2026-11-06；起始 `experiment/routing-sandbox` / `3f692fe`，工作區乾淨。本輪不 commit／push。

## 玩家行為

- 一般商店的開場、波次獎勵與重刷均為四張塔牌；與原重刷牌排成單排。價格、獎勵、售價快照及交易防重入保留。輔助設施資源、獨立抽取 API、手動補牌、放置及效果未刪除；塔池失效時不以輔助池備援。
- 時間線固定長度、五事件視窗，保留 ACT 名稱；事件整列向左滑，黑點固定並微縮放；hover 節點顯示提示。
- 左上遺物列只畫實際持有圖示，堆疊合併顯示數量；hover 提示名稱／效果，點擊詳情，關閉或 Esc 返回。專屬圖示沿用原 icon mask 與塔色，通用保留原色；不新增圖示套件。
- 敵軍首次實際出生時留下側邊 `! 數量` 通知，遊戲繼續且焦點不變。通知不設期限；同一 Troop ID 每局只排一次。點擊後才暫停，依遭遇順序在同一面板閱讀；關閉／Esc 讀完目前頁後前進，最後返回原狀態。新發現頁只列通知佇列，圖鑑頁列完整目錄。
- 暫停選單的「敵軍圖鑑」已併入進度頁的三欄版面；這裡只保留出生通知的逐一閱讀。

## 責任與保存

`card_shop.gd` 是商品權威；`card_shop_view.gd` 只排列四商品與重刷牌。
`wave_timeline.gd` 保留原進度 API／完整標記範本。
`relic_choice.gd` 消費既有 RunRelics，不改效果、抽選或 RNG。

`enemy_intelligence.gd` 接 `EnemyWave.enemy_spawned`，`seen`／`read`／`pending` 為每局呈現紀錄。`enemy_codex_text.gd` 整理文字、`enemy_model_preview.gd` 只建立停用 processing 的模型副本，不建立 Enemy、不生成行程。Troop 的新增／修改方法僅回傳玩家用文字，不更動 evaluation 或能力快照。

詳情頁向 `LevelHUD.begin_inspection/end_inspection` 借用暫停：保存原 HUD 暫停、原 SceneTree 暫停、倍速及焦點，沿用收牌／遮罩，隱藏暫停選單並鎖鏡頭。詳情頁互斥，設定／進度頁／遺物選擇／轉場不接受新詳情。`inspection_panel.gd` 只隔離背景輸入、限制焦點及處理 Esc；不自行改 tree pause。結束時還原原狀態，已有外部暫停也不會被解除。

LevelProgress 繼續使用 `user://level_completion.cfg` 的 v1 `progress` 格式，新增 `codex.encountered` PackedStringArray。舊檔缺少該 section 時視為空；每次保存先載入原檔再更新兩種 ID，保留其他 section。跨局保存解鎖，不保存當局通知／已閱讀狀態、血量或行程。每個新局仍可收到本局第一次遭遇通知。

## 初版驗證（頂列追修前）

Windows Godot 4.7.2 Compatibility；實際渲染為 RTX 4060 Laptop。以下為本輪執行結果，非引用歷史 PASS：

| 入口 | 結果 |
| --- | --- |
| `tests/ui_slice_a/hud.tscn` headless | 78 項，failures 0 |
| 同入口實際渲染 | 81 項，failures 0；正式 Frontier 場景、真實滑鼠通知／時間線／暫停選單入口、Tab／Esc、十種模型與 800×600／1600×900 版面 |
| cards/card_shop | headless／rendered failures 0，四商品、費用、靠攏、連續交易及重刷動畫 |
| cards/cards、cards/card_drag_placement | headless failures 0 |
| traffic/integration | headless 100 項，failures 0；輔助功能保留、一般商店不供應 |
| relics/stacking、rewards、mechanisms | headless failures 0；mechanisms 113 項 |
| relics/input | rendered failures 0；拖牌、獎勵點擊與新圖示收藏 |
| levels/level_flow、level_hud、pause_menu、ui_scene_templates | rendered failures 0；階段／暫停、重新開始及完整時間線像素填色 |
| levels/wave_spawn_groups、enemies/troop_resources | headless failures 0 |
| `--script tests/levels/level_catalog.gd` | failures 0；既有通關保存／目錄回歸 |
| synergy/input | rendered 67 項，failures 0；未解鎖情報與原分流／能力操作 |

新增整合測試覆蓋 v1 舊檔、保存未知 section、通關與圖鑑互不覆寫、重載／新局解鎖、本局遭遇與閱讀分離、重複出生、多種佇列、原本遊玩／HUD 暫停／外部暫停恢復。保存測試使用 `.godot/test-results/ui_slice_a/progress.cfg`，不改玩家存檔。

原始日誌為 `.godot/ui-slice-*.log`，截圖在 `.godot/test-results/ui_slice_a/`：`compact_shop_relics`、`expanded_timeline`、`relic_detail`、`discovery_notice`、`new_enemy_detail`、`codex_known`、`codex_800`、`codex_1600`、`pause_codex_entry`。保留初輪失敗紀錄於交接說明，不把舊固定六張商品／三兵種／立即出生／空艇 NodePath 的斷言當成新規格；對應測試已改為目前契約並重跑。

## 未驗證與環境限制

未做 Web 匯出／瀏覽器、十五波長局、效能量測或真人美術驗收。既有 Web GDExtension WASM 仍缺失。此環境無法寫入預設 `user://`／shader cache，部分舊整合測試因此有保存警告，新增保存回歸改用可寫的隔離測試路徑且通過；不能據此宣稱瀏覽器 IndexedDB 或此機玩家預設目錄寫入已驗收。未調整 Windows 防護。

人工宜再確認高亮雲背景上的通知辨識、實際戰鬥中開關情報的節奏、遠景遺物辨識，以及長英文／較小視窗的閱讀感受。

## 頂列與時間線追修（2026-11-06）

防線圖示／數值、金幣、遺物、時間線節點、敵軍未讀通知與加速／暫停共用 y=53 的資訊基線。頂列依實際可見項目的總寬度置中，順序為防線／金幣／遺物／時間線／通知／操作，項目間隔16px。時間線既有0.18秒展開動畫同步驅動整列位置；左側圖標向左、右側向右平滑讓位，收合時一起回到中央，空遺物／無通知不留空槽。防線以盾牌＋目前數值呈現，完整目前／上限在 hover。所有指定 HUD 資訊與波次／遺物節點均提供 hover；提示共用淡紙色細框與深青字，沿用 Light 字型。

未來波次使用原標記配色的空心圈；進行中／已完成才填色。

WaveTimeline 的 milestone_tooltip／_get_tooltip 依實際波次提供 ACT、當地／全局波次、狀態、敵軍總數及完成金幣，遺物提示其 ACT 與三選一規則。LevelHUD 只將既有 choosing_relic 狀態投影到時間線，未修改 LevelSession／波次流程。未來圈、遺物圖示與 tooltip 共用兩種模式的節點資料。

追修驗證：新增整合 headless 92項／Compatibility rendered 95項，failures 0；rendered level_flow、ui_scene_templates、pause_menu 各 failures 0。涵蓋頂列對齊、圖示生命、各項 tooltip、四個遺物節點、可選最終獎勵、兩種時間線、當前獎勵、真實 hover、三種視窗尺寸與原通知／暫停／保存回歸。log 為 .godot/ui-topbar-*.log；原截圖入口更新為最新頂列，另加 health_tooltip／relic_node_tooltip／relic_milestone_active.png。Web／長局與 user:// 環境限制同上，未重跑初版全部套件。

### 集中置中追修

LevelHUD._layout_status_row 統一計算跨 CanvasLayer 資訊的水平位置，依可見項目寬度保持整組置中；WaveTimeline 只提供目前動畫寬度與可用寬度上限，不再自行指定螢幕分區。resized／visibility_changed 與視窗尺寸更新布局，資料未變則不重設位置；不搬動既有節點，保留引用、點擊／hover與詳情頁介面。

本輪 headless96／Compatibility rendered99，failures0；rendered level_flow、ui_scene_templates亦0。新增檢查緊湊／展開整組置中、兩側圖標相向移動、維持16px間距與原有通知／暫停／存檔。日誌 .godot/ui-centered-*.log；既有compact_shop_relics／expanded_timeline／discovery_notice截圖已更新並檢視。未重跑其他初版套件、Web或長局。

## 2026-11-07 main 整合

保留本頁頂列、通知及靜態模型圖鑑，加入三類進度頁與新版開波圖示操作。遺物使用集中頂列的聚合數量及詳情，同時採用新版 PNG、使用情境、20px 三選一卡距與 Debug 重抽。正式介面不重複顯示 main 的左下圖示列；獨立 relic_inventory 場景及 API 保留。六種更名敵人的舊存檔 ID 於 LevelProgress 載入／查詢時轉成新 ID；兩種情報介面共用持久遭遇紀錄。Tab 切換 1／2／4 倍，Esc 維持各頁返回與檢視暫停擁有權。當次驗證見 HANDOFF，不沿用本頁歷史測試數。

## 2026-11-08 波次與事件節點

目前時間線每波皆為圓點；遺物雙菱形與新增出生點的門形加號各佔獨立節點，排列於對應完成波次之後。第二關 Frontier 的入口事件在第 5、10 波後，遺物仍在第 3、6、9、12 波後，最終第 15 波直接勝利。LevelHUD 投影 choosing_relic／choosing_start；事件位置與準備期進度使用同一份排程。此規格取代歷史的 ACT 分隔線兼作最後一波／遺物位置。

## 2026-11-08 固定五事件左滑視窗（最新）

前節的全展開布局改為 360px、左一個過去事件、當前事件、右三個後續事件（開場左格留空）。波次／遺物／入口共用五格，ACT 標示保留。黑點固定在第二格；開波時事件整列向左滑，黑點輕微縮放，移除累積進度填色。遺物／入口也滑入當前格，暫停凍結。時間軸固定在畫面中央，遺物列增長時向左延伸，操作列向右，避免黑點隨頂列重排偏移。結尾不補虛構事件。

2026-11-08 最新追修：遺物／入口以獨立圖示直接佔軌道上的事件位置，不附加波次圓點；各標記下方顯示簡短名稱。ACT 垂直分隔線恢復於上一 ACT 全部事件結束與下一 ACT 第一波之間，隨滑動裁切，不佔五事件名額。

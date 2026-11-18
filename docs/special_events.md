# Special Events V1

2026-11-17 實作起點為 `6c13318`；2026-11-18 於 `852bd5b` 基底恢復整合，Git 交付紀錄見 [HANDOFF](HANDOFF.md)。正式 LevelSession 自動啟用，不依賴選圖頁仍屬原型的「額外事件」暫定開關。

## 正式流程

每完成 5 波且尚有下一波，處理一次事件；15 波關卡為第 5、10 波，最後第 15 波直接勝利。20、25 波關卡採相同非最終波判斷。三波教學不增加事件。

清場先等在途攻擊，依序處理當次 ACT 遺物、入口擴張、特殊事件，再準備下一波。這三段共用 CardPlacement 的 entry-selection 鎖；事件另有 `choosing_event` 與 EnemyWave.start_allowed 守衛，關店、暫停／恢復或內部開波入口皆不能解除事件鎖。每個事件只有兩個選項；目標效果必須完成選塔才能繼續。付款、套效果與結束之間沒有 await，重入／連點不重複執行。

從至少一個選項可執行的事件等機率抽取，優先抽本輪未見過者；目前可執行事件都見過後才開始新輪。不可用選項顯示原因並停用。空／耗盡的自訂 catalog 有安全復原，正式九事件池始終有可執行的免費分支。

## 編輯入口

- `LevelDefinition.special_event_catalog` 預設引用 `assets/data/events/catalog.tres`。在 Entries 加入新的 SpecialEventDefinition，無須改管理器的九事件清單。
- `assets/data/events/event_01.tres`～`event_09.tres`：二選一的效果列表與數值。type 支援 road、gold、spend、health、upgrade、downgrade、remove、ceasefire、reinforce、card、random_card、relic。reinforce 的 count、troop、per_start、start、interval_ticks 可編輯。
- `assets/data/events/cards/`：五張特殊牌的種類、格子、識別色、圖示、選用模型及放置效果。大寶石 Damage Bonus=0.1、小寶石 Wave Gold=5、碎石 Incomplete Damage Multiplier=0.9。
- `assets/translations/card_names.csv`：`event.*` 的繁中／英文標題、背景、選項與說明，已加入「遊戲文本」編輯器的「特殊事件」分類。事件效果的金幣、人數、傷害百分比與獎勵由 Resource 填入模板。
- `scenes/events/special_event_choice.tscn` 與 `scripts/events/special_event_choice.gd`：面板、兩個並排選項、停用原因、高亮選塔與 hover 資訊。

## 九事件與實際效果

| 事件 | A | B |
|---|---|---|
| 敵人偵查兵 | 驗證並新增獨立道路，成功 +50 Gold | 下波每入口 +10 偵查兵 |
| 臨時補給 | 隨機最多三座合格塔各升一級 | 指定拆塔、保留地面，+50 Gold |
| 雲遊商人 | -70 Gold，黃色藥劑一張 | 下波 +12 鼠群 |
| 王國徵兵令 | 指定塔下波停火，+60 Gold，波後恢復 | 下波每入口 +5 士兵 |
| 暴風將至 | -30 Gold，1×4 道路卡 | 兩張碎石；開波時未全部放置則該波全塔傷害 -10% |
| 古老祭壇 | -5 基地 HP 且保持存活，隨機可取得遺物 | +30 Gold，下波 +6 飛翼獸 |
| 工程師罷工 | -80 Gold，隨機最多兩座合格塔升級 | +20 Gold，隨機一座 Lv.2 以上塔降級 |
| 遺失的軍餉 | +60 Gold，下波 +5 重裝兵 | 正常塔種／地塊抽取一張免費塔卡 |
| 神秘寶石 | 2×2 大寶石，放置後全塔 +10% 傷害 | 三張 1×1 小寶石，全放完後每波 +5 Gold |

## 卡牌、戰鬥與地圖接線

BuildCard 新增 SpecialCardDefinition；使用原 CardHand／CardView／CardPlacement，沒有第二套庫存或商店。道路／特殊地塊保留原旋轉、地圖 hover 預覽、點放／拖放、成功消耗、地面動畫與音效；特殊牌不進正常商店。黃色藥劑選牌後高亮所有可選塔，點塔使用；走同一個成功消耗入口，僅該次 `upgrade(true)` 忽略上限，不改 unlimited_levels。

TowerMap 保存獨立 special_occupied；它與塔占格的聯集才是導航障礙。一般塔、道路、交通設施與特殊地塊都保護這些永久占格。特殊地塊可放於空地或不封路的既有道路，不能蓋塔、端點、石地、兵營駐點或其他特殊地塊。預覽與提交均先驗證所有入口／基地／兵營駐點的連通性。拆塔仍走原 remove_tower，保留地塊與道路。

事件每次取得一批卡牌都有獨立 batch ID；大寶石只有成功放置後生效，小寶石須同批三張全完成，碎石須同批兩張全完成。塔實例以 event_damage_multiplier 刷新真實塔傷害及兵營友軍傷害，與遺物／成長計算相乘，沒有永久改寫 TowerDefinition。重複大寶石的事件傷害加成相加；重複小寶石每完成一批再增加 5 Gold；多批未完成碎石仍只施加一次 0.9 倍，不重複乘算。碎石在開波時鎖定當波懲罰，放完影響後續波次。

停火使用 DefenseTower.is_disabled 的共用戰鬥守衛，包含普通攻擊、遺物及兵營友軍；既有在途攻擊保留。塔體使用原癱瘓圖示／變暗，單位資訊另顯示徵兵狀態。

下一波以來源 WaveDefinition 的深複本追加 WaveSpawnGroup；成功開波才清除 pending，失敗開波可重試，之後波次重建自原始資料。每入口增援產生一個 fixed_start 群組，不參與既有新增入口的平均分配。WaveSpawnSchedule 仍負責原有候選、配額、預覽、行程快照與真正出生；沒有修改路線分流演算法。小寶石金幣加到複本 reward，沿用 CardShop 的每回合一次正常清波發獎。

## 新道路與自行決定的預設值

- 鼠群 12、飛翼獸 6、重裝兵 5；未指定每入口的三項增援預設從入口 1 出發（資料 start=0）。鼠群沿用原兵種的同群共路。其他每入口數量完全依指定。
- 增援預設從第 0 刻度開始，每 2 個四分之一秒刻度出一個（0.5 秒）；鼠群仍遵守原 cohort 排程。以上皆在事件 effect 字典調整。
- 道路搜尋由有效入口嘗試到基地，包圍範圍外擴 8 格，最大 12,000 候選格；兩者在 catalog 可編輯。建造搜尋採四向 A*，步成本 1，鄰接舊路 +18、相隔兩格 +4。起終點曼哈頓距離 2 格內允許合流；中段不走舊路。至少新增 4 格、至少 max(2, 新格數/3) 格不鄰接舊路才接受。
- 提交前以原 ConstructionLayout／Snapshot 驗證雙向接口與全部端點，原道路不移除；新路的明確接口避免相鄰平行路自動變成寬路。成功才 +50 Gold，並更新地圖顯示、route history、原生圖及下一波預測。無合理路徑就停用 A。
- 面板最多約 820 邏輯像素，選項 hover／focus 使用同色系背景與邊框；無外部美術依賴，地塊為 BoxMesh／PrismMesh，圖示為小型 SVG。

## 驗證

入口及完整命令見 `tests/events/README.md`。自動回歸包含九事件兩選項、資料與實效、UI 選項／世界選塔、流程鎖、真實新增入口及 native 分流、實際出兵與擊殺、卡牌預覽與占格、同批放置條件、清波獎勵一次性、5／10 波及最終勝利。完整十五波自然遊玩平衡及所有滑鼠手勢仍須真人驗收；自動加速清場不代表平衡通過。


2026-11-17 最終結果：Windows／Chrome Web 各284檢查全通過；Windows 原 ACT擴張與遺物回歸通過，塔牌旋轉 Windows／Web 各1148檢查通過。繁中／英文兩種尺寸畫面已檢視。FAIL：無未修正的功能測試失敗。NOT RUN：十五波自然完整遊玩與平衡、全部真人手勢及正式發行包重匯出。Web 仍有與既有無事件卡牌對照相同類型的 buffer警告（事件94、對照40條），詳見 [HANDOFF](HANDOFF.md)。

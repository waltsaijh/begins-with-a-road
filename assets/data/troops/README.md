# 兵種資源

每個 `.tres` 是一份 `Troop`。Godot 的波次編輯器自動讀取本目錄及子目錄，新增、修改、刪除兵種都不需新增 GDScript 類別。兵種設定由波次共用；實際血量、出發時機、路線與避讓狀態屬於每隻敵人。

## 新增與修改

1. 複製現有 `.tres`，或在 Godot 選 New Resource → Troop，儲存在本目錄。
2. 設定唯一的 **Troop Name**（兵種 ID）、**Name Key**、**Sort Order**、**Icon**、**Debug Color**。Name Key 例如 `troop.soldier.name`，顯示文字放在 `assets/translations/card_names.csv`；留空時顯示 ID。
3. 設定 **Max Health**、**Max Shield**、**Speed Multiplier**。實際速度為波次 Move Speed × Speed Multiplier。
4. 在波次編輯器的兵種選單選取它。選單與時間軸會顯示資源的 icon，時間軸色彩與 F1 路徑使用 Debug Color。

| 資源 | 配額分配 | 每格評分 |
| --- | --- | --- |
| soldier.tres | Uniform | 1 |
| quickfeet.tres | Softmax | threat |
| heavy.tres | Softmax | −threat |

血量、護盾與移速以各 `.tres` 當前值為準；波次共用該資源，不從歷史說明恢復數值。

## 尋路

預設 **Route Rule = COST**，此模式的 **Path Evaluation** 用資料描述評分，不必寫 evaluation 函式：

`Path Base Cost + threat × Threat Weight + num_towers_around × Tower Count Weight + movement_multiplier × Movement Weight + damage_per_second × Damage Weight + cover × Cover Weight`

負權重可用於偏好高威脅等行為。例如 soldier 的 Base Cost = 1、其餘權重 = 0；quickfeet 的 Base Cost = 0、Threat Weight = 1；heavy 的 Base Cost = 0、Threat Weight = −1。權重更新會使尋路快取失效，但不改變已開波敵人的固定行程。

**Route Selection** 可選 Uniform／Softmax，**Route Temperature** 只影響 Softmax；**Score Threshold** 為相對最佳路線的嚴格上限，`inf` 表示不以成本差篩選。Overlap Penalty 與 Search Budget 控制候選搜尋。

## 匯入模型

目前 Soldier 使用 `assets/models/enemies/grunt.tscn`，Quickfeet 使用 `runner.tscn`，Heavy 使用 `brute.tscn`；三者的 Model Scale 為 1。Quickfeet 的 Animation Speed 為 3.0。詳見 [模型說明](../../models/enemies/README.md)。

將 `.glb`／`.gltf` 及貼圖放入專案，等待 Godot 匯入，再把匯入場景拖到 **Model**。也可使用自己建立的 `.tscn`；根節點須為 Node3D 或其子類別。

- **Model Scale**：調整大小；每個分量必須大於 0。
- **Model Offset**：修正腳底高度與中心。
- **Model Rotation Degrees**：修正模型朝向；遊戲前方為 −Z，面向 +Z 的模型可將 Y 設為 180。
- **Walk Animation**：填入 AnimationPlayer 的動畫名稱；留空會尋找名稱含 walk／run 的動畫。沒有此類動畫時保持靜態模型。
- **Animation Speed**：動畫播放倍率。
- **Head Height**：0 依 mesh 範圍估算血條高度，也可手動覆寫。

Soldier 的 `grunt.tscn` 使用 MultiMesh 與 GPU 步態；Quickfeet／Heavy 的場景以實例顯示並保留自己的材質與 AnimationPlayer。不同模型可以出現在同一波。自訂場景各自產生繪製成本，適合保留完整的匯入模型／骨架動畫。

Icon 是獨立 Texture2D，可選取 PNG 或 SVG，不受模型匯入方式影響。

## 刪除

刪除檔案後，兵種選單會移除該項。已引用它的出生群組使用 **Troop Path** 保存檔案路徑，因此關卡仍可開啟；該群組會顯示「未設定／檔案已移除」，請改選其他兵種或刪除群組，再儲存。沒有可用兵種的波次不會開始，不會偷偷換成其他兵種。

若使用獨立地圖，預設選 soldier；移除 soldier 時改用目錄中排序最前的可用資源。目錄完全空白時停用開波。

## 避讓

視覺位移以約 0.8 秒的平滑阻尼過渡，完成後保留側向位置，不在鄰兵離開後歸零。轉彎期間不互相碰撞，並保留現有位移；避讓不修改邏輯位置、行走速度與固定路線。過渡速度可在 `EnemyRenderConstants.VISUAL_OFFSET_SMOOTH_TIME` 調整，目前為 0.35；這是阻尼時間尺度，並非固定總時長。

## 多標籤

Body Size 單選 small／standard／large；Tags 是可複合 StringName 清單，例如 ground、flying、armored、uncontrollable。消費端使用 `has_tag()`；不要把體型塞入 Tags，三個體型的查詢只以 Body Size 為準。未設定資源安全預設 standard＋ground。

Soldier 為 standard＋ground，Quickfeet 為 small＋ground，Heavy 為 large＋ground＋armored。這些資料不修改既有生命、速度、攻擊或固定行程；臨時設施依 required_tags 選擇對象。

## Phase 4 六兵種

新增 rat_swarm、shield_guardian、blood_mage、winged_beast、scout、saboteur；完整數值／Tag／能力與限制見 [Phase 4](../../../docs/phase4.md)。

- **Route Rule**：COST 沿用原候選／評分；SHORTEST 直接使用合法路網的實際最短格距；NEWEST 依本局已提交道路歷史選最新有效批次。後兩者不使用普通 Search Budget／Score Threshold，再套 Uniform／Softmax 及適用設施倍率。
- **Cohort Size／Cohort Interval Ticks**：大於 1 時以整群分配入口／路線，尾群可不足額；個體仍獨立。每 tick 為 0.25 秒；群模式使用群間 interval，取代 Batch Size 的並發規則。
- **Damage Reduction／Taunt**：減傷比例、嘲諷半徑與穩定優先級。
- **Heal**：回復量、間隔、範圍。多來源獨立，不復活或超過上限。
- **Sabotage**：選塔範圍、冷卻、前搖與持續時間。重疊取最大剩餘時間，來源死亡移除。
- **Flight Height**：固定 waypoints 的道路上方高度；flying Tag 決定對空與地面設施資格。
- **Ability Text／Ability Text En**：情報介面的繁中／英文能力說明；改數值時一併更新描述。

以上參數於開波快照，暫停停止能力時鐘，原三兵種的預設值維持既有行為。

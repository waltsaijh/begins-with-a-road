# 塔攻擊與資產結構

## 資產

```text
assets/
├─ data/
│  ├─ cards/
│  └─ towers/
│     ├─ sentry.tres
│     ├─ attacks/       sentry_arrow、sentry_beam、explosive_projectile
│     └─ effects/       slow
├─ materials/
├─ models/
│  ├─ mesh_library.tres
│  ├─ tiles/
│  ├─ towers/
│  ├─ enemies/
│  └─ endpoints/
├─ shaders/
├─ sprites/
│  ├─ cards/
│  └─ towers/          保留原有自製 sentry.png
└─ fonts/             字型及授權
```

場景、資源、產生模型的工具與測試均使用新路徑；原有卡片布局與自製圖示保留。PNG 的 UID 與 `.import` 隨檔案搬移，沒有重畫使用者素材。

## 設定

選取 assets/data/towers/sentry.tres，在 Combat 編輯 max_health、default_damage、attack_interval、attack、aim_pivot_path、muzzle_path（相對模型根節點）。AimPivot 以本地 -Z 對準目標，僅轉動弩機；固定底座不隨瞄準旋轉。ArrowRelease 位於原型箭尖，光束與投射物共用該發射點；未設 marker 的模型才使用 muzzle_offset。attack_radius 是 anchor 格中心到敵人所在格中心的格座標半徑，含邊界與整格，與 threat 覆蓋相同。半徑 3 覆蓋 29 格；視覺推開／地圖縮放不影響射程。每幀持續平滑瞄準最近格（等距取 enemy_id 較小者），冷卻時也轉向。沒有射程內目標時，預瞄射程＋1 格內的最近敵人；只有進入原射程且轉向誤差在 3° 內才開火，避免首次攻擊瞬轉。無目標時維持方向，死亡／離場目標會在下一個戰鬥幀重新選取；沒有視線遮擋判斷。TowerConstants 的 AIM_TURN_SPEED=TAU*2（每秒 720°）、AIM_TOLERANCE=PI/60、AIM_LOOKAHEAD_TILES=1 可調。threat 仍是設計者指定的評分，不從實際傷害自動推算。

當前哨塔預設 HP 200、傷害 20、間隔 1 秒、射程 3 格、威脅 1，attack 指向 attacks/sentry_arrow.tres。每個 DefenseTower 各自保存 health、damage、attack_interval 與一份攻擊設定，修改實例不改變其他塔。

- ArrowAttack：帶短拖尾的高速灰色箭矢；speed=24（世界單位／秒），arrow_length=0.36、arrow_width=0.025、trail_length=0.8、trail_width=0.035。只追蹤原鎖定者，命中才扣血，不爆炸；目標死亡或離場則飛至最後位置後消失，不改打其他敵人。長度與寬度均以世界單位設定。
- BeamAttack：立即單體傷害，灰色軌跡僅是畫面，預設保留 0.12 秒。
- ProjectileAttack：固定落點、飛行後範圍傷害。範例 attacks/explosive_projectile.tres：flight_time=0.6、splash_radius=1.5、附加減速。把塔的 Attack 改成此資源即可使用；不需要新增另一個塔管理器。
- splash_radius=0 代表落點一格。敵人離開落點覆蓋區就不受傷，後來進入者會受傷；投射物不是追蹤彈。
- 效果繼承 HitEffect，覆寫 apply(target, source, damage)。SlowEffect 設定速度倍率與時間，同強度刷新持續時間，不同強度取最慢者，不乘算。效果按幀更新；基本傷害致死時不再套用狀態。

AttackPayload 在開火時保存傷害與效果數值，之後修改／刪除來源塔不影響已發射者。來源塔已刪除時自訂效果的 source 可為 null。DefenseTower.damage_against(target) 可覆寫特殊傷害規則；新發射機制繼承 TowerAttack，覆寫 fire(combat, tower, target)。Attack 留空可作不攻擊的障礙塔。

塔與敵人提供 take_damage(amount)。敵人死亡立即退出 Wave 與 MultiMesh；killed、completed（抵達終點）分開計數，全數被殺也可完成波次。塔死亡會移除 footprint、威脅影響並重建路網；目前沒有實作敵人反擊塔。

## 執行與顯示

CombatSystem 在敵人移動後執行，所有塔共用一份當幀敵人格子索引；半徑對應的覆蓋偏移快取，不為每塔掃描全圖。每座可攻擊塔使用射程＋1 格的索引查詢，最近目標若在原射程內必定優先；同一次查詢供預瞄與攻擊使用。瞄準採固定角速度上限的 quaternion 插值，不依賴幀率，細微目標位移可直接跟上；muzzle_position() 僅讀取發射點。冷卻結束、位於原射程內且對準後每次只射一發，慢幀不補射爆量攻擊。無敵人且無投射物時跳過索引建立，無塔／投射物也跳過。

投射物的飛行／落點資料集中管理；沒有逐發 Node、Timer、RayCast 或 PhysicsBody。AttackVisuals 用一個透明 unshaded mesh 提交所有箭矢／漸淡拖尾、beam、投射物標記與命中環，採 Compatibility／Web 可用功能。飛行弧線純視覺，不進行實體碰撞。

## 驗證

tests/combat/combat.tscn：

- 高速箭矢發射後不立即扣血，移動目標命中、單體傷害、拖尾透明漸變、目標消失後清理。
- 立即命中與攻擊間隔。
- 射程外一格預瞄、冷卻期間追蹤／換目標、首次攻擊等待對準、無目標保持方向、底座固定與轉向幀率一致性。
- 縮放地圖後仍按地塊邊界選目標，與 threat 的 29 格覆蓋一致。
- 敵人死亡立即清理 Wave／MultiMesh，全部擊殺結束波次。
- 塔死亡釋放障礙與影響。
- 飛行期間無提前傷害，落點範圍依當時敵人位置。
- 來源塔刪除後仍命中，傷害／效果快照不受後續修改影響。
- 減速、時間到期與顯示 mesh 回收。

tests/combat/combat_preview.tscn 以真正繪圖裝置顯示兩種攻擊，確認共用單一 surface，保存 combat.png。測試同時驗證各方向／垂直瞄準、旋轉縮放後的箭尖與射線對齊、固定底座不動，以及箭矢、光束、範圍投射物三種攻擊的發射點。Windows／Web 功能比較與畫面驗證工具為 `tools/web/verify_enemy_web.cjs --combat --cards`，輸出 combat.json、combat_render.json、combat_web.png。這是功能驗證，沒有執行效能基準。

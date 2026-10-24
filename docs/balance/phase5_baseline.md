# Phase 5 — audited baseline

Audit: 2026-10-23, branch `experiment/routing-sandbox`, HEAD `c33d425`, clean working tree before this work. Runtime exporter ran **before gameplay edits**, Godot 4.7.2. `phase5_baseline_parameters.json` contains 1,074 resolved fields, including inherited script defaults, subresources, wave groups, growth, relic parameters and scene overrides. It is an immutable pre-change export, not final tuning.

| Tower | Card Gold | Damage | Interval s | Role / delivery |
|---|---:|---:|---:|---|
| Sentry | 3 | 25 | .5 | Directional cells, tracked arrow, aiming delay |
| Ballista | 11 | 15 | 1.4 | Forward cells, immediate single target |
| Broadside | 12 | 8 | 1 | Side cells, immediate single target |
| Crossfire | 13 | 4 | .8 | Radius 2, all eligible targets |
| Mortar | 14 | 8 | 2 | Radius 3, fixed landing point, splash radius 1 |
| Barracks | 15 | 2 × 4 | 1 | Two 40-HP allies, interception, respawn 5 s |

Sources: `assets/data/towers/*.tres`; omitted fields resolve through `tower_definition.gd`, `tower_constants.gd`, `barracks_deployment.gd`. All tower bodies 200 HP. Growth damage ×1.35, interval ×.95 (mortar unchanged interval), friendly HP ×1.30 and damage ×1.35, cap Lv.3. Stacking costs an owned card only. AttackPayload snapshots launch damage/effects; arrows can lose their original target, mortar can miss moving enemies, ALL ignores taunt. Shields absorb before HP after damage reduction. Slow merges strongest strength and longest remaining duration; frost has separate expiring stacks.

| Troop | HP + shield | Speed multiplier (wave base 2.5) | Other relevant settings |
|---|---:|---:|---|
| Soldier | 100 + 0 | 1 | Uniform |
| Quickfeet | 50 + 0 | 1.3 | Softmax, threat +1, threshold 25 |
| Heavy | 100 + 150 | .4 | Softmax, threat −1, threshold 25 |
| Rat swarm | 16 + 0 | 1.15 | 5/cohort, .25 s within cohort |
| Shield guardian | 180 + 0 | .65 | 25% reduction, taunt 3.5 cells |
| Blood mage | 65 + 0 | .85 | 18 HP / 3 s, radius 2.5, Uniform |
| Winged beast | 45 + 0 | 1.65 | Exact shortest, height 1.2, no melee interception |
| Scout | 38 + 0 | 1.3 | Newest eligible route generation |
| Saboteur | 75 + 0 | .9 | Range 3, interval 6, windup 1, disable 2.5 s |

**Economy discrepancy:** Troop has no kill-reward field and EnemyWave death never pays Gold. Actual kill income is **zero for all nine troops**. Starting Gold 0, initial three random free tower cards, each completed wave +10, reroll 1, gold relic +20. No other production income or spending path found (`rg` over coins/reward/acquire). Purchases debit card snapshot price; reroll draws four distinct tower types from a freshly shuffled six-type bag plus two traffic cards. Bag resets per call, not persistent across deals. Each tower's valid presets are separately weighted. All three traffic structures cost 3, last three completed participating waves. Shop unavailable before wave 1. Relic reroll discount can reduce reroll to zero; it is not a source of Gold.

**Progression discrepancy:** Existing Frontier has 3 ACTs ×3 waves, one guardian in W2, otherwise original troops. Every ACT boundary including final completion offers a relic. No base life, defeat, or victory presentation exists. `level_finished` alone is not a complete run. Default `expand_starts_after_act=true` requires user-chosen expansion. Phase 5 will disable this for Frontier, preserving custom-level support. Historical prose saying every card costs 3 is only a default, not actual tower prices.

**RNG discrepancy:** Shop and relics already own RNGs. Spawn cohorts use global `Array.shuffle()`, so an explicit spawn RNG is needed for reproducibility; preview already avoids shuffle. Combat target selection is deterministic.

## Boss forensics

Read-only legacy: `D:/games/card-tower-defense/scripts/combat/final_siege_{definition,encounter}.gd`, `boss_route_selection.gd`, `enemy.gd`, `scripts/presentation/enemy_3d.gd`, `art/enemies/skybridge_pawns.gd` and its kit/palette dependencies. Siege Behemoth: 1600 HP, speed 18 legacy pixels/s (48 px/cell), melee 45/.8 s, 0 Gold, base damage 5, radius 144 px, every 10 s charges .6 s then disables up to 2 towers for 7 s. Legacy excludes Barracks; chooses a route from tower exposure, injects escorts dynamically and depends on old WaveManager/EnemyManager/Card/Path APIs. Model is a four-foot armored ram with horns, authored in primitive meshes, purple charge ring.

Selected for adaptation: distinctive ram model and telegraphed two-tower disable. Do not port exposure routing, dynamic spawn insertion, spell exceptions or old managers. Current Troop/EnemyWave fixed-path lifecycle and current disable-source cleanup can support this mechanic with small additions. Boss leak must fail the final encounter; hunting already excludes `boss`. Rebalance timing and HP through actual combat, do not copy 1600 as an assumed correct value.

## Infrastructure

`C:/tools/Godot.exe` reports 4.7.2. Native SDK commit `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`; phase4 Windows debug/release DLLs present. Existing native tools support SCons/MSVC and Emscripten, no native change is initially required. Windows verification does not establish Web compatibility. Legacy and production projects are read-only. No Git mutation is authorized.

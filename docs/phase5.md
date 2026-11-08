# Phase 5 — first complete run

The formal `scenes/level.tscn` now runs five ACTs of three waves. Preparation remains unlimited and manually started, with the existing 1.5-second opening transition. Relics are chosen exactly after Waves 3, 6, 9 and 12; the last ACT finishes without a fifth choice. Frontier does not add entrances between ACTs. Custom levels retain the existing explicit expansion option.

## Runtime responsibilities

`LevelDefinition` owns starting Gold, opening-shop availability, base integrity and whether a custom level rewards its final ACT. `LevelSession` owns integrity, terminal state and the existing projectile-settling/relic transition. Ordinary leaks cost one integrity; Frontier begins with 20. A boss leak immediately loses the run. Defeat cancels pending spawns and active enemies before cleanup callbacks can award a wave reward. Both terminal states lock construction, shop and start input. The shared `scenes/levels/run_status.tscn` provides integrity, boss health/charge indication, result and restart. Restart reloads the current level at 1x, unpaused, with fresh run state. There is no save or meta-progression system.

The opening hand still contains three random tower cards. Frontier now has an opening shop and 9 Gold. Rewards are paid once on completion, including a wave with moderate leaks if integrity survives; no reward is paid on defeat or starting a wave. All enemies, including the boss, have zero kill Gold. Card purchases pay the rolled snapshot price. A later stack consumes that card and does not debit Gold again. Traffic still costs 3 and lasts three participating completed waves; reroll is 1 before the existing relic discount.

Tower tuning changes damage and price, and Barracks friendly damage. Geometry, targeting, projectile timing, tower health, level cap and growth curves are preserved. The nine ordinary troop resources preserve their combat stats and identities; composition, overlap and wave speed supply progression. Exact loaded values and all fifteen explicit spawn tables are in the final parameter export and balance report.

## Siege Behemoth

One final encounter adapts the legacy armored ram model and two-tower suppression mechanic. `tools/assets/build_ravager.gd` reads the legacy art sources and bakes a self-contained scene into this project. The game has no legacy-project dependency. The builder's default legacy input is read-only; inspect the generated model before rerunning to preserve hand edits.

The boss is a normal `Troop`/`Enemy` with large, ground, armored and boss tags: 1,200 HP; speed multiplier .4; melee 28 every 1 s; after an 8 s cooldown starts a 1.2 s windup, then disables at most two legal towers within three cells for three seconds. It uses the current fixed route allocation, current health/shield/status pipeline and source-specific disable cleanup. Slow, frost, knockback and Barracks interception retain their ordinary rules. Hunting explicitly excludes bosses. The charge ring, links, skill bar, disabled-tower lightning and top health label expose the encounter state. Death counts normally; remaining escorts/projectiles must resolve before victory.

The boss reuses SabotageAbility with `targets = 2` (ordinary Saboteurs use one); `base_damage` (ordinary troops default to one) is frozen in the wave-start combat snapshot. No old manager, dynamic escort insertion, exposure-based boss routing or spell system was migrated. The adapted boss can affect Barracks as current sabotage does; the legacy exclusion was intentionally not imported.

## Balance laboratory

`BalanceTrace` is off by default. Tests opt in to JSONL lifecycle, damage, heal, Gold, purchases, builds, upgrades, projectiles, interception, disables, routes, relics and terminal events. It records a configuration hash and separate RNG seeds. Normal gameplay makes no log files. The full-run policy driver uses real shop/CardPlacement/EnemyWave/CombatSystem instances and legal placement validation. It advances production systems at 1/60 s; it is not a second damage or routing simulator.

Reference arenas diagnose geometry and levels; encounter factorials reconstruct the same scene/budget with ability and traffic toggles; full-run policies allow compounding divergence. Rendered runs use real viewport mouse events for all starts, four reward cards and restart. Their construction policy still uses the normal authoritative placement API, so they do not replace human playtesting or the existing drag/shop input regressions. Independent Python analysis imports no game code and reconstructs accounting from raw events.

See `balance/phase5_baseline.md`, `phase5_methodology.md`, `phase5_iterations.md`, `phase5_final.md`, `phase5_reproduction.md` and `phase5_human_playtest.md` for evidence and limits. Windows Compatibility evidence does not establish Web export, release, performance or human enjoyment.

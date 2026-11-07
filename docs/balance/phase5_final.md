# Phase 5 — final evidence and acceptance

2026-10-24, Asia/Taipei. Sandbox `experiment/routing-sandbox`, experiment starting HEAD `c33d425` plus Phase 5 changes. The subsequent local Git update packages this work after existing integration HEAD `3fbad09`; only `balance/rules` was rerun during that packaging, and the original experiment provenance is preserved. This is a complete playable first pass with measured limitations, ready for human acceptance. It is not a claim of finished balance.

## A. Implementation summary

F5 now plays five ACTs and fifteen authored waves using all nine existing ordinary enemy types. Preparation remains manual and unlimited; Frontier adds no automatic entrances. The run begins with three free tower cards, 9 Gold and an available shop. Integrity starts at 20; ordinary leaks cost one, a boss leak loses immediately. Defeat cancels pending spawns without completion income. Victory waits for the final enemies and projectiles. Both results lock trading/building/start, and restart restores fresh state at 1x. Four ordinary three-choice relic rewards occur after W3/6/9/12; there is no fifth reward.

The legacy Siege Behemoth contributes its armored ram model and telegraphed two-tower suppression idea. It uses current Troop/Enemy, fixed routes, damage, status, interception and source-specific cleanup. Old managers, exposure-based routing, dynamic escort insertion and spells were not imported. The baked model is self-contained. Six tower prices/damage were adjusted; ordinary troop combat stats, special-route rules, tower geometry, growth and the 17 specialty relics are preserved. Details: [implementation](../phase5.md), [baseline forensics](phase5_baseline.md).

## B. Primary findings

1. **The old imbalance began with price as well as damage.** A 3-Gold Sentry competed with 11–15-Gold alternatives. The first normalization attempt silently retained 3 because its Resource property preceded `script`. Actual purchase events caught this. Loaded-price checks now protect the final 9/8/8/10/9/8 vector.
2. **Fixed completion income supports recovery without swarm farming.** Kill income was already zero. Keeping it zero removes kill-count income inflation; lowering total completion rewards from the initial proposal's 220 to 168 limits repeated upgrades. All final training runs spent nearly all available Gold, but still recovered from moderate leaks. This does not establish an optimal reward curve.
3. **Geometry and timing matter as much as headline DPS.** Wrong-facing directional guns cannot be rescued by multiplying damage. Mortar misses moving targets at landing; Barracks adds interception even where damage is modest. Broadside remains weakly used in actual runs, so six equally convincing purchasing roles are not established.
4. **Traffic has conditional combat value.** The matched grouped-rat cases prevent 2 and 6 leaks. Guardian mixtures improve by 4 and 0. Healing, Scout and flying cases do not consistently benefit. These results support some load redistribution, not a universal claim that traffic breaks enemy cooperation or outperforms another tower purchase.
5. **Multiple policies complete the run, with uneven margins.** Fourteen training runs and four frozen holdouts all win. The held-out Core/307 case leaks 15; price normalization, +20% HP or +20% speed can lose on the harder training seed. Broad success in these bounded policies does not establish a human win rate.
6. **The difficulty curve remains uneven.** Higher late overlap increases active enemies, but several later waves cause no leaks in all training runs. W12 produces an eleven-leak spike for Heavy/11. Human acceptance should focus on whether late decisions remain necessary and whether that spike is readable.

## C. Evidence

### Scope and accounting

[Independent results](../../reports/phase5/independent_results.json) contain **675 validated trace records**: 432 reference encounters across original/diagnostic/final configurations, 144 baseline replay audits, 56 ability/traffic encounters, and 43 full runs across pilots, training, holdouts, sensitivities and render/replay checks. These are not 675 independent seeds. The baseline replays and full-run repetitions are labeled separately and do not enlarge the training sample.

The independent Python validator reconstructs every Gold transaction, HP/shield damage and healing, deaths, spawns, completed waves and available terminal aggregates; it also checks expected file/event counts. A valid trace may describe defeat. It imports no gameplay code. Raw file hashes are in [raw manifest](../../reports/phase5/raw_manifest.json); selected original traces/logs are in `.godot/phase5/raw_evidence.zip`. This archive includes superseded failed regression attempts as historical evidence. Recompute with [exact commands](phase5_reproduction.md).

Original 72-case baseline replay matches five aggregates in every case when using its original global spawn RNG. Changing to the new dedicated stream changes five Mortar damage results. Therefore original-versus-final Mortar comparisons are descriptive, not perfectly paired; final level and encounter comparisons share streams. See [replay audit](../../reports/phase5/replay_audit.json). Early traces predate automatic hashes; their baseline export and logs are retained. On-disk hashes plus metadata/command arguments describe later in-memory overrides.

### Hypotheses and limits

| Hypothesis | Conditions / sample | Observed result | Interpretation and uncertainty | Reproduce |
|---|---|---|---|---|
| H1 price distorts selection | Generalist seeds11/23; candidate1→2; final seed23 price probes | Actual 3→9 Sentry reduces cheap expansion; all9 final probe loses to boss; price ×.8/1.2 both win | Price matters, but purchase/relic/placement divergence prevents single-cause attribution of every later event. No optimal-price claim | `refinement.json`, sensitivity manifests, pilot traces |
| H2 kill bounties inflate swarm income | Same 470 authored enemies; three analytic schedules plus final ledgers | Potential A/B/C income 470/406/494 vs fixed168; all training income177 including initial9 | Existing economy had no farming. Alternatives are transparent illustrative bounties, not simulated optimal candidates; equal-budget cumulative columns isolate schedule shape | `report.py`, `wave_design_and_economy.csv` |
| H3 geometry/timing explain weakness | Six towers ×3 lanes ×4 matchups, 72 cases/config; final Lv1/Lv3 | Wrong-facing zeros persist; Mortar11 empty landings/58; Barracks intercepts ground but not flying | One seed per reference matrix, geometry-specific. Barracks repeats the legal orientation in all three labels; not independent orientation evidence | `laboratory.tscn`, `tower_geometry.png` |
| H4 separation reduces cooperation | Seven mechanics ×2 enabled states ×2 traffic states ×2 seeds=56 | Rat traffic gain2/6 leaks; guardian4/0; healing0/−1; Scout/flying0 | Conditional support. Guardian improvement remains with taunt off, so no demonstrated taunt-specific synergy break. Control retains6 Gold rather than investing it elsewhere | `counterfactual.tscn`, paired CSV |
| H5 four relics support builds | Seven policies ×2 seeds, then four frozen holdouts | All18 win; exactly four choices each; Core23 succeeds without Protagonist | Policies share fallback Sentry/support behavior; distinct priorities are not seven pure archetypes. No human enjoyment or population success inference | training/holdout manifests |
| H6 boss fits current combat | Full-run final encounters, two paired boss arenas, rules, rendered full run | Boss dies in all18 selected/held-out runs; ability suppresses towers; slow/frost and no Hunting execution verified | Fixed weak arena loadout leaks the boss even with ability off. Full runs do not prove the pulse is sufficiently threatening or the telegraph clear to humans | `counterfactual.tscn`, `rules.tscn`, rendered-final |

### Complete-run distributions

The table gives total leaks at seeds11/23. Each policy has **n=2**, both wins; no confidence intervals are warranted. Training mean2.29, median1, range0–11, ending Gold0–7. Simulation combat/transition duration is approximately329–452 seconds (median350), **excluding player preparation time**, not predicted human session length.

| Policy | Leaks11 /23 | Ending Gold11 /23 | Build evidence / limitation |
|---|---:|---:|---|
| Generalist | 0 /4 | 1 /0 | Buys all six tower types; seed23 has little economic margin |
| Damage-first | 0 /1 | 7 /1 | Sentry/Ballista with Broadside; seed11 naturally reaches Sentry Lv7 with Protagonist |
| Route manager | 0 /1 | 0 /3 | Purchases one versus five traffic cards; most spending still combat towers |
| Swarm specialist | 0 /3 | 7 /0 | Six Mortars and eight Crossfire purchases each; supports actual artillery builds |
| Heavy specialist | 11 /1 | 2 /5 | Ten/eleven Ballistas; seed11 vulnerable to W12 mixture |
| Barracks controller | 0 /1 | 6 /7 | Two Barracks purchases plus eight/nine Sentries and support; not a pure melee win |
| Single core | 4 /6 | 1 /1 | Repeated Sentry upgrades with support; seed23 has no Protagonist |

The four prespecified holdouts were not used for tuning: Generalist101/Frontier wins0 leaks, Core307/Frontier wins15, Swarm101/alternate unequal loop wins0, Barracks307/alternate loop wins4. Four cases cannot establish broad map/seed robustness. [Progression plot](../../reports/phase5/progression.png) retains the large Core/307 margin loss.

Final normal-Resource replay at seed23 matches the candidate3 Generalist's Gold0, kills466, leaks4, damage33,463.605 and simulation duration452.433 s. The rendered seed11 run wins with no leaks and Gold1; it clicks fifteen starts, four rewards and restart through the viewport, verifies fresh state, and records screenshots. Its build policy uses authoritative placement APIs; it does not impersonate a human dragging every purchased card. A separate normal-frame rendered defeat fixture verifies lethal arrival, no reward, cancellation and restart at1x.

### Economy and opportunities

Training receives9 initial+168 completion Gold, no kill income; no selected training economic relic adds Gold. Purchase spending ranges170–177 including traffic; Swarm/23 additionally spends1 on a reroll. Runs buy18–22 cards, **including traffic**, in addition to the three free opening cards. Spending on later upgrades is already included in card purchase costs; stacking has no second fee. Unspent0–7 Gold is below any tower's base price, so low remaining cash reflects scarcity, not a large late hoard. A budget of177 is19.67 nominal nine-Gold cards before traffic/rerolls; this equivalent is not an actual allocation guarantee.

[Per-wave ledger](../../reports/phase5/gold_ledger.csv) records opening balance, realized income, spending and closing balance. [Independent results](../../reports/phase5/independent_results.json) retain purchase types, final tower levels, relics, builds and builds; unused cards are recorded in raw terminal events. Low income cannot compound through missed kills because completion rewards are fixed; surviving moderate leakage still buys the next answer. This removes one poverty feedback path, not every loss spiral from bad placement or unavailable cards.

Only one of14 training runs uses a paid reroll. The additional seed23 probe forces one before each preparation: fifteen Gold in rerolls,158 in purchases, ending4, victory with3 leaks versus baseline4. This single divergent build neither proves rerolls dominant nor useless. Failed/unaffordable opportunities are not exhaustively logged as player intent; the policy's stopping and purchase rules bound this analysis.

Analytic A pays1/enemy; B pays1 for Soldier/Quickfeet/Mage/Wing/Scout/Saboteur,3 for Heavy/Guardian,0 for rats/boss; C adds half-rounded completion income to B. A/B/C totals470/406/494 are **potential**, assume every enemy killed, exclude initial Gold, and include last-wave money with no subsequent purchasing value. B's zero rat bounty is an illustrative normalization with a usability cost, not a recommended reward rule. CSV also supplies80%-kill scenarios and equal-total-budget cumulative curves; fractional rescaling is analytical only. Retaining explicit fixed rewards is the simplest tested recovery rule. No new currency or hidden bounty formula was introduced.

### Combat, levels and routing

| Tower | Original Lv1 mean applied damage | Final Lv1 | Final Lv3 | Final Lv1 / price | Observed role / caution |
|---|---:|---:|---:|---:|---|
| Sentry | 468.3 | 249.0 | 450.0 | 27.67 | Strong forward coverage; still heavily favored by common policy fallback |
| Ballista | 76.2 | 142.0 | 246.2 | 17.75 | High single-target shot and piercing relic; facing can yield zero opportunity |
| Broadside | 47.3 | 94.7 | 173.1 | 11.84 | Side geometry and cruise/salvo hooks; actual-run value remains under-supported |
| Crossfire | 81.0 | 162.0 | 273.2 | 16.20 | All-target crowd damage bypasses taunt ordering; timing can lower kill count despite more damage |
| Mortar | 46.7 | 132.7 | 187.5 | 14.74 | Strong grouped-hit role, fixed landing; no ordinary flying targets |
| Barracks | 106.5 | 120.5 | 148.2 | 15.06 | Interception plus support; friendly HP/engagement matter beyond applied damage |

Means use12 encounters/tower (3 lanes×4 matchups) and are not DPS. Lv3 consumes three cards, so its comparison must include three-card opportunity cost; it is not automatically more damage/Gold. Original-vs-final Mortar also has the RNG caveat above. Final Mortar has58 landings,11 empty (19%): Soldier10 empty/21, Heavy1/25, rats0/12; flying has no shots. Barracks cumulative interception per geometry is54 enemy-seconds against Heavy,16 Soldier,12 rats,0 flying; simultaneous engagements sum unit-seconds. Lv3 Crossfire rat kills fall21→19 in this timing fixture despite higher damage. Overkill/hit/idle details remain in encounter JSON, not discarded to improve rankings.

Across the14 training runs, Broadside applies only about5.6k damage versus Sentry171.9k and Crossfire153.9k. Different purchase counts prevent an efficiency ranking from those totals. Broadside accumulates about1,481 no-target tower-seconds versus261 with a target; Ballista6,441/1,245. These counters sample combat periods with enemies present, not whole-run uptime. Placement geometry, opportunity and availability remain plausible explanations; more damage alone is not justified.

Traffic factorial leaks without→with traffic at seeds11/23: grouped rats7→5 and7→1; guardian13→9 and10→10; healing8→8 and8→9; disable11→8 and11→11; Scout17→17 and16→16; flying22→22 in both. Healing totals fall250→190 and184→166 while leaks fail to improve: reducing a cooperation metric alone is not a win condition. With guardian taunt off, traffic still gains4/0 leaks. Flying is immune to ground traffic, and hard-route eligibility limits Scout alternatives. The fixed four-tower boss fixture leaks4/3 total enemies with or without traffic; boss disable is active (two tower applications) and lowers applied damage. These are diagnostic failures, not successful boss defenses.

## D. Final numbers

All resolved fields and sources: [runtime parameter JSON](phase5_parameters.json). All explicit start ticks, group intervals, counts, batches and rewards: [wave JSON](phase5_wave_proposal.json), authored in `assets/data/levels/frontier.tres`. Each tick is0.25 s; cohort spacing preserves the existing five-member floor. Preview and actual spawning share WaveSpawnSchedule.

| Tower | Gold | Base damage | Attack interval | Nominal damage/s before aim/availability | Growth per level |
|---|---:|---:|---:|---:|---|
| Sentry | 9 | 12 | .5 s | 24 | damage×1.35, interval×.95 |
| Ballista | 8 | 30 | 1.4 s | 21.43 | same |
| Broadside | 8 | 16 | 1 s | 16 | same; normal right-side restriction retained |
| Crossfire | 10 | 8 per target | .8 s | 10 per target | same |
| Mortar | 9 | 24 per landed target | 2 s | 12 per target | damage×1.35, unchanged interval |
| Barracks | 8 | 6 per friendly | 1 s each | 12 with both engaged | friendly HP×1.30, damage×1.35; two slots |

All tower bodies200 HP; existing attack-area Resources, projectile speeds and aiming rules remain authoritative. Barracks friendlies40 HP, respawn5 s; capLv3 except Sentry Protagonist. Traffic3 Gold/three completed participating waves; reroll1 before relic discount; Gold relic20. Starting integrity20, initial9 Gold and three free cards. Rewards by wave: **9,9,9,11,11,11,12,12,12,14,14,14,15,15,0**, total168. No kill Gold.

| Enemy | HP + shield | Speed multiplier | Reduction | Defining rule / ability |
|---|---:|---:|---:|---|
| Soldier | 100+0 | 1 | 0 | Cost/Uniform |
| Quickfeet | 50+0 | 1.3 | 0 | Cost/Softmax, low threat |
| Heavy | 100+150 | .4 | 0 | Cost/Softmax, high threat |
| Rat swarm | 16+0 | 1.15 | 0 | Cost/Uniform;5/cohort, within spacing.25 s |
| Shield guardian | 180+0 | .65 | 25% | Cost/Uniform; legal-target taunt radius3.5 |
| Blood mage | 65+0 | .85 | 0 | Cost/Uniform; heal18 every3 s, radius2.5 |
| Winged beast | 45+0 | 1.65 | 0 | SHORTEST, altitude1.2, flying; no ground-traffic effect |
| Scout | 38+0 | 1.3 | 0 | NEWEST eligible complete route |
| Saboteur | 75+0 | .9 | 0 | Cost/Uniform; range3, cooldown6 s, windup1 s, one tower disabled2.5 s |
| Siege Behemoth | 1200+0 | .4 | 0 | Cost/Uniform; range3, cooldown8 s, windup1.2 s, max two towers disabled3 s |

Actual speed is wave speed×troop multiplier before status. Boss melee28/1 s; ordinary melee remains in the export (Soldier5/1, Quickfeet3/.8, Heavy9/1.2, rats3/1, guardian10/1, mage3/1, flying0, scout4/1, bomber5/1). Cooldowns restart after cast completion/cancellation, so boss pulse-to-pulse minimum is9.2 s, not8. Boss leak is fatal; Hunting cannot execute it. Slow/frost/knockback/interception retain normal rules.

| Wave | Composition | Count | HP+shield | Static EHP | Last spawn(s) | Completion Gold |
|---|---|---:|---:|---:|---:|---:|
| 1 | Soldier5, Quickfeet3 | 8 | 650.0 | 650.0 | 11.0 | 9 |
| 2 | Soldier6, Rats10, Guardian1 | 17 | 940.0 | 1000.0 | 7.5 | 9 |
| 3 | Rats15, Guardian2, Heavy2 | 19 | 1100.0 | 1220.0 | 9.0 | 9 |
| 4 | Soldier10, Heavy3, Mage2 | 15 | 1880.0 | 1880.0 | 13.5 | 11 |
| 5 | Rats25, Guardian3, Mage2 | 30 | 1070.0 | 1250.0 | 11.0 | 11 |
| 6 | Heavy5, Guardian3, Mage2, Saboteur1 | 11 | 1995.0 | 2175.0 | 14.0 | 11 |
| 7 | Scout8, Soldier12, Quickfeet6 | 26 | 1804.0 | 1804.0 | 14.75 | 12 |
| 8 | Wing10, Heavy6 | 16 | 1950.0 | 1950.0 | 18.75 | 12 |
| 9 | Scout10, Wing8, Guardian4, Rats25 | 47 | 1860.0 | 2100.0 | 18.25 | 12 |
| 10 | Rats35, Guardian5, Saboteur3 | 43 | 1685.0 | 1985.0 | 9.5 | 14 |
| 11 | Heavy8, Mage4, Wing12 | 24 | 2800.0 | 2800.0 | 14.25 | 14 |
| 12 | Guardian5, Mage3, Saboteur3, Scout12, Rats30 | 53 | 2256.0 | 2556.0 | 14.25 | 14 |
| 13 | Rats40, Guardian6, Mage4, Heavy8 | 58 | 3980.0 | 4340.0 | 12.5 | 15 |
| 14 | Wing16, Scout14, Saboteur4, Quickfeet12 | 46 | 2152.0 | 2152.0 | 17.25 | 15 |
| 15 | Guardian4, Rats25, Mage3, Boss1, Heavy6, Scout8, Wing8, Saboteur2 | 57 | 4829.0 | 5069.0 | 27.25 | 0 |

HP includes shields. Static EHP divides each troop's HP+shield by(1−reduction); it excludes healing, targeting protection, disables and interception. Last-spawn time is not arrival time. [Per-run wave outcomes](../../reports/phase5/wave_outcomes.csv) give actual duration, peak alive, kills/leaks and surviving tower counts. Base wave speeds by ACT are1.25/1.35/1.45/1.50/1.55. W10–15 intervals are half the initial proposal, rounded to quarter-seconds, with cohort floor preserved.

Decision sequence: W1 forward/basic coverage; W2 early crowd answer and legal taunt; W3 group/armor tradeoff; W4 healing access; W5 healing with taunt/cohorts; W6 protect coverage from sabotage; W7 inspect newest-route exposure; W8 retain air coverage; W9 reconcile hard-route and crowd pressure; W10 overlap/capacity under disable; W11 air plus durable healed ground units; W12 mixed build weakness; W13 sustained AOE and armor; W14 fast hard-route/air targets plus sabotage; W15 staged escorts and boss pulse. These are authored intentions; zero-leak late results show they are not all consistently demanding yet.

## E. Negative findings

The full [iteration history](phase5_iterations.md) preserves the invalid price assumption, rejected candidates, broken initial output IDs and corrected test fixtures. Selected sensitivity probes use only Generalist seed23; baseline final is victory with4 leaks. Each row is **n=1** and measures a compounded run, not a causal coefficient.

| One-variable intervention | Outcome / completed waves | Total leaks | Ending Gold |
|---|---|---:|---:|
| Price×.8 | victory /15 | 2 | 4 |
| Price×1.2 | victory /15 | 5 | 0 |
| All tower prices9 | defeat on boss /14 | 1 | 6 |
| Original price vector | victory /15 | 4 | 2 |
| Enemy HP×1.2 | defeat inW13 /12 | 20 | 5 |
| Speed×1.2 | defeat on boss /14 | 11 | 0 |
| Rewards×.8 | victory /15 | 11 | 7 |
| Rewards×1.2 | victory /15 | 3 | 2 |
| All intervals×.75 | victory /15 | 6 | 0 |
| Healing×1.5 | victory /15 | 11 | 0 |
| Disable duration×1.5 | victory /15 | 4 | 0 |
| Growth increment×.7 | victory /15 | 9 | 0 |

The original price vector's win does not validate its fairness. Unchanged results for longer disables do not prove disables irrelevant in other geometry/seeds. Boss-death versus boss-leak outcomes are binary and can hide a narrow margin. Reward-only candidate2/23 loses; candidate3/23 wins after increased late overlap, but altered friendly-fire losses and later purchases confound that nonmonotonic outcome. No hidden compensation or altered success criterion was added.

Training leaks concentrate at W1(total10), W2(1), W4(8), W7(1), W12(11), W13(1); the other waves have zero in these14 runs. This is evidence against claiming a uniformly rising challenge. Broadside usefulness and universal traffic value remain unresolved. Human readable telegraphs, exciting boss pacing and meaningful every-wave spending decisions are not validated by automation.

## F. Remaining risks

Windows debug Compatibility is the executed platform. Release export, Web build/browser, performance/memory benchmark, Phase5 wave-editor interaction and human playtesting are **NOT RUN**. No native code changed or rebuilt. Native SDK pin and setup are in [reproduction](phase5_reproduction.md). Render logs include an inability to create the sandbox shader cache; screenshots/input succeeded, and logs retain that diagnostic. Editor import settings-save errors are not editor acceptance.

Policies optimize simple exposure/coverage and share fallback behavior. They can use geometry more consistently than a new player and do not model indecision, misclicks, readability, or emotional pacing. Route Manager preparation is slow because it evaluates candidate forecasts; its headless wall time is not game FPS. Small seed samples, generated alternate topology, three repeated Barracks geometry labels, RNG migration, relic/offer divergence, and fixed-step versus rendered timing limit generalization. There is no save system.

## G. Final acceptance status

| Outcome | Status |
|---|---|
| Five ACTs, nine ordinary enemies, four choices, compatible boss, terminal states/restart | Implemented; exercised by rules, actual combat and rendered input |
| Final training14 and frozen holdouts4 | Completed, all win; small-sample observations, not population probabilities |
| Independent raw Gold/damage/lifecycle accounting |675 records validate; replay audit72/72 on five metrics |
| Relevant current regression/visual-input checks |29 Current PASS, listed with exact logs in [verification](../../reports/phase5/verification.json); no unresolved Current FAIL in this set |
| Earlier Phase1–4 suites not rerun here |Historical PASS only; see their original acceptance documents |
| Economic recovery, build variety, route value |Partially supported; detailed counterexamples above |
| Six strong purchase identities / smooth late challenge / fun |Not established; Broadside and late pacing require human review |
| Release / Web / performance / human play / Phase5 wave editor |NOT RUN |

The subsequent user request “GIT更新” authorizes a local commit of these sandbox changes after integration HEAD `3fbad09`. This packaging performs no merge, push, reset or clean; legacy and production remain read-only. The next gate is the [human playtest protocol](phase5_human_playtest.md), recording the actual working-tree version and raw trace rather than assuming automated wins prove enjoyment. Stop here for final human acceptance.

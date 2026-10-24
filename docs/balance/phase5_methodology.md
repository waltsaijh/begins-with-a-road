# Phase 5 — preregistered method

Written after the raw audit and **before combat/economy tuning**. Numbers below are diagnostic comparisons, not universal targets. Use the actual Enemy, CombatSystem, BarracksSystem, WaveSpawnSchedule, TowerMap and shop. A fixed 1/60 s simulation step drives these systems in the laboratory; rendered transition tests separately exercise normal scene processing and input.

## Balance dimensions and hypotheses

| Hypothesis | Comparison and controls | Metrics | Rejection / confounders |
|---|---|---|---|
| H1 price/firepower distorts choice | Original versus six prices 9, then focused individual candidates; same map, offer seed, budget and policy | buys, upgrades, leaks, unused Gold, damage/Gold | reject if relative choices/outcomes do not change; geometry and availability can dominate DPS |
| H2 swarm kill rewards inflate income | A=1 per kill, B=type-normalized bounty, C=wave-only/mixed fixed rewards; same waves and realized kill fractions | potential and realized income, card equivalents, early/late wealth | baseline has zero bounties, so reject claim of existing inflation; recovery is better under fixed wave income |
| H3 geometry explains tower weaknesses | six single-tower reference lanes, parallel/crossing approach, normal Frontier placements | applied HP+shield damage, overkill, shots, misses, idle, interceptions | reject if weakness persists in favorable geometry; raw DPS not sufficient for Barracks or mortar |
| H4 separation reduces cooperation | paired two-lane state, equal budget (unspent traffic cost in control), traffic off/on × taunt/heal on/off | leaks, surviving enemy HP, healing, route quotas | reject for tested case if no improvement; integer quota rounding, transit time and shared coverage are confounders |
| H5 four choices support identities | seven explicit purchase policies with normal shop/relic seeds; forced relic cases labeled diagnostic | owned cards/levels, four chosen rewards, waves cleared, unused Gold | reject broad support if only one policy succeeds; no claims about human skill/enjoyment |
| H6 boss fits existing combat | same boss against generalist, single core, artillery/Barracks; disable off/on and hunting | damage, casts, intercepted time, death/leak, victory | reject if immune, trivially executed, stuck or lifecycle incorrect |

Healthy economy means useful affordable decisions across the run, with visible resource scarcity and recovery from moderate leaks. Tower usefulness means at least one credible role, not equal DPS. Diversity means multiple viable policies under recorded availability, not equal win rates. Difficulty must be assessed with per-wave leaks, unresolved HP and active pressure, not count alone. Routing value requires a measured combat return; buying traffic cards alone is not evidence.

## Policies

All policies see only current inventory, offers, Gold, map and next-wave preview, plus held relics. No future offers/seeds or enemy outcomes. Place legally through TowerMap/CardPlacement; select orientation by current road coverage, then score against the visible next-wave routes. Prefer upgrades when high coverage already exists; log unplaceable cards. Equal placements are sorted by coordinates. Reroll only if affordable and no preferred available purchase, with a per-preparation cap. Unspent Gold remains in the ledger.

| Policy | Buy priority | Upgrades / relic preference | Traffic / fallback |
|---|---|---|---|
| Basic Generalist | fill absent shooting roles, then coverage | supported specialty or damage generic | no forced traffic; buy best affordable legal alternative |
| Damage-First | sentry, ballista, broadside | upgrade covered firing towers; damage | minimal traffic; alternatives if unavailable |
| Route Manager | mixed shooting plus compatible traffic | frost/support, then owned specialty | use forecast to move load toward coverage; decline no-change placements |
| Swarm Specialist | crossfire, mortar, support | AOE relics, upgrade AOE | fallback shooting against visible flying |
| Heavy Specialist | ballista, sentry, broadside | single-target / hunting | fallback cheapest useful shooting |
| Barracks Controller | barracks with ranged support | friendly buffs, frost | never pure melee against flying |
| Single-Core Builder | sentry then repeated same cards | upgrades before sprawl, protagonist if offered | no assumed protagonist; fallback support after cap |

Exact executable scoring and caps live in the lab script, with manifests in raw output. These are bounded behavioral models. A placement heuristic cannot demonstrate human optimal play.

## Experiment/analysis rules

Pilot first: at least two seeds to check variance/runtime. Expand only questions with nontrivial variance or disagreement. Keep shop, relic and spawn streams separate; match seed offsets in pairs. Different policy RNG consumption is recorded and prevents a claim of perfect stochastic equivalence. Encounter pairs reconstruct identical initial scenes; full-run comparisons allow compounded divergence.

Use count, mean/median, min/max or quantiles and paired differences. Bootstrap only with adequate independent seeds; deterministic samples get no fabricated precision/CI. Reserve holdout seeds and alternate map orientation before selecting final candidate. Holdouts diagnose generalization; failed holdouts remain reported. Sensitivity probes change one variable: prices, HP, speed, wave interval, reward, healing, disable duration, growth. Record candidate, expectation, observed result, decision, side effects. No mass simultaneous stat scaling.

Raw JSONL includes run/config hash/seed/stream, ACT/wave, simulation time, entity, event and payload. Summary mode aggregates expensive per-frame counters; detailed mode records damage and individual lifecycle/transactions. Independent Python analysis reconstructs Gold from transactions and kills/damage/waves from events; compares terminal state, validates sample counts, regenerates tables/plots. Instrumentation defaults off.

Evidence levels: rule regression; repeated quantitative experiments; independent raw-data reconstruction; human playtest **NOT RUN until actual participants play**. Windows debug/release/Web are separate statuses.

## Frozen final evaluation plan

Training uses seeds 11 and 23, seven policies (14 runs). The two-seed pilot exposed a large acquisition/geometry difference and a boss loss after reducing income. This motivates repeating every policy on both seeds; it does not justify a confidence interval or a population win-rate claim. Runtime is several minutes per full run, with traffic preview evaluation materially slower. Report the two individual observations and their range, not precision to many decimals.

Holdout seeds **101 and 307** are reserved before final selection and not reused to tune. Four cases are fixed: Generalist/101/Frontier, Core/307/Frontier, Swarm/101/holdout, Barracks/307/holdout. `tests/balance/holdout.gd` freezes a previously unused unequal loop (upper z=0, lower z=4, connectors x=3 and 19, goal 22,2). It is different from both Frontier and the diagnostic x=2..16/z=0..6 traffic arena. Failures remain failures; no changing the holdout or selecting a favorable replacement seed.

Final sensitivity probes use the harder training seed 23, Generalist, one variable at a time: price ×.8/1.2; flat9/original price ordering; HP ×1.2; speed ×1.2; rewards ×.8/1.2; all spawn intervals ×.75; healing ×1.5; disable duration ×1.5; growth increment ×.7. These are local directional probes, not a complete response surface. Traffic factorial repeats on 11 and 23. Tower diagnostics compare all six towers at Lv.1 and Lv.3, 3 geometries ×4 matchups (72 each). Same initial 50 Gold in traffic arms includes 6 unspent Gold in the no-traffic arm; this is a direct tactical comparison, not proof that two traffic cards beat every alternative purchase.

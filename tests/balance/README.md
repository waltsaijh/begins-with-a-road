# Phase 5 balance laboratory

These fixtures execute production systems. They are excluded from exports and do not add F5 debug controls.

- `laboratory.tscn`: six towers × three legal geometries × four matchups; `--level=1|3`, `--damage=...`. Its spawn stream is fixed at 91573 across current reference pairs (the `--seed` labels the global diagnostic seed). `--stats=baseline` loads original stats into duplicated resources and restores the historical global spawn shuffle for reproduction. This is a damage/opportunity diagnostic, not six full-run win rates.
- `counterfactual.tscn`: seven mechanic toggles × ability on/off × traffic on/off = 28; 50 Gold initial budget, forced four-tower diagnostic loadout. Control retains the 6 Gold that traffic spends. `--seed=11|23` separates departure order; no arbitrary future wave knowledge.
- `full_run.tscn`: seven player-visible policies or `--policy=name`; `--seed`, `--config`, `--output`. Purchases debit the real shop; cards place and upgrade through authoritative validation. `--rendered` uses Compatibility rendering, actual start/relic/restart mouse events and screenshots. It still places through the legal API; existing input suites verify hand dragging and shop clicks.
- `rules.tscn`: final loaded values, all fifteen transitions/four rewards, single-commit choices, loss with pending groups, boss statuses, no post-loss reward and cleanup.
- `defeat_input.tscn`: real normal-frame movement, 4x clicks, start, defeat and restart, using an explicit 1-integrity fixture. Production Frontier is 20.
- `holdout.gd`: frozen distinct topology; do not tune it after seeing outcomes.
- `config/candidate2_frontier.tres`: pre-refinement 220-Gold/longer-interval wave snapshot. Candidate3 manifests explicitly scale this to the selected 168-Gold/faster-late-spawn configuration. It is not an alternate shipped level.

Exact commands and experiment manifests: [reproduction](../../docs/balance/phase5_reproduction.md). Raw results/logs/screenshots stay in `.godot/phase5/`; summaries and charts in `reports/phase5/`. Use a new output directory to avoid overwriting evidence. A process exit without the completed sample matrix and independent accounting does not count as PASS. Detailed mode is required for independent damage reconstruction; the optional interactive summary mode deliberately omits per-hit records.

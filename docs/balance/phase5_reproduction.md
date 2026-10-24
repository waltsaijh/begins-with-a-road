# Phase 5 — reproduction

Workspace: `D:\games\begins-with-a-road-routing`, branch `experiment/routing-sandbox`, experimental starting HEAD `c33d425` plus Phase 5 work, subsequently packaged in a local commit after existing integration HEAD `3fbad09`. Original results retain their recorded configuration provenance; only the core `balance/rules` fixture was rerun for that Git packaging. Legacy and production remain read-only. Godot 4.7.2 Compatibility loads the existing `road_graph.editguard.phase4` Windows debug GDExtension. No native change or rebuild is required for this work; setup/build commands remain in `native/README.md`. The SDK pin is `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`. `cl`, `scons`, `emcc` and `clang++` were not exposed in the task shell PATH at final audit; this is not proof that their installations are absent.

## Environment and dependencies

Use PowerShell from the workspace. `python` below must be a working Python 3 executable, not the Windows Store alias. The verified runtime is `C:\Users\USER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe` (3.12). Accounting uses only its standard library. Plotting uses Matplotlib 3.11.2, installed locally in ignored `.godot/phase5/python`:

```powershell
$py='C:\Users\USER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py -m pip install --target .godot/phase5/python -r tools/balance/requirements.txt
```

The render logs identify OpenGL 3.3 Compatibility on RTX 4060 Laptop GPU. Sandbox runs emitted `Can't create shader cache folder`; screenshots and actual input completed. The test runner retains this diagnostic while excluding that one cache message from application-error classification. Editor import also emitted settings-save errors in the sandbox; these are not counted as a successful editor validation. No Web, release export or performance claim follows from these runs.

## Execute without relying on GUI process detachment

Windows GUI `Godot.exe` must be awaited with `Start-Process`. Example final seeded run:

```powershell
$engine='C:\tools\Godot.exe'
$root=(Get-Location).Path
$log=Join-Path $root '.godot/phase5/reproduce-final.log'
$process=Start-Process -FilePath $engine -WindowStyle Hidden -PassThru -ArgumentList @('--headless','--path',$root,'res://tests/balance/full_run.tscn','--log-file',$log,'--','--output=res://.godot/phase5/reproduce-final','--policy=generalist','--seed=23','--config=final')
$process.WaitForExit()
$process.ExitCode
Get-Content $log -Tail 3
& $py tools/balance/analyze.py .godot/phase5/reproduce-final
```

The final candidate is authored directly in Frontier. This command does not apply a second reward or interval scale. The historical candidate3 manifests use the saved candidate2 level and apply reward ×.75 and late interval ×.5; `full_run.gd` routes `--config=candidate3` to that snapshot when no other resource is explicitly selected. Sensitivity manifests explicitly name the same snapshot. Integer rounding uses Godot `roundi` (positive .5 rounds upward), and rats retain the cohort-spacing floor.

## Principal matrices

```powershell
& tools/balance/run_experiments.ps1 -Manifest tools/balance/training-0.json
& tools/balance/run_experiments.ps1 -Manifest tools/balance/training-1.json
& tools/balance/run_experiments.ps1 -Manifest tools/balance/training-2.json
& tools/balance/run_experiments.ps1 -Manifest tools/balance/holdout.json
& tools/balance/run_experiments.ps1 -Manifest tools/balance/sensitivity-0.json
& tools/balance/run_experiments.ps1 -Manifest tools/balance/sensitivity-1.json
```

Use fresh output IDs in a copied manifest if preserving this session's raw outputs. Each job saves arguments, exit/status and its log. Runner timeout is 30 minutes per policy; failures are not converted to victories. Shop seed=run seed+1000, spawn=+2000, relic=+3000. Combat selection is deterministic. Different purchases consume different shop draws, so full runs are not perfectly matched stochastic encounter snapshots.

For the reference matrix, substitute `res://tests/balance/laboratory.tscn` in the awaited command and pass `--output=res://.godot/phase5/tower-final --config=final-combat --level=1`; repeat at level 3 into `tower-lv3`. For the traffic factorial use `res://tests/balance/counterfactual.tscn`, `--seed=11 --output=res://.godot/phase5/counterfactual-v2`, then seed 23 into `counterfactual23`. Each must finish with 72 or 28 records, zero failures, no script error, and independently valid JSONL.

Historical reference baselines retain raw outputs and the immutable pre-change parameter export. To regenerate them, run `laboratory.tscn` with `--stats=baseline --damage=1 --config=baseline-replay` and a fresh output; repeat damage factors 2 and 3 for those interventions. This duplicates definitions in memory, loads original damage/price/deployment values from the baseline export and uses the original global spawn shuffle seeded with 11. It does not edit final Resources. The final reference matrix uses the dedicated spawn stream (91573). Replaying old stats with that new stream changed five Mortar outcomes; restoring the old stream matched all 72 cases on damage, kills, leaks, overkill and healing. These are reproducibility checks, not additional independent balance trials. `python tools/balance/replay_audit.py` recomputes the comparison.

Early traces contain a configuration name but predate automatic hashes; their provenance is the baseline parameter export and preserved logs. Later records include resource/script hashes, and newer records also include the driver hash. Instrumentation-only changes during the session can change hashes without changing combat parameters. Resource hashes identify the on-disk inputs; metadata and the saved command arguments identify in-memory experimental overrides.

`refinement.json` explicitly uses `tests/balance/config/candidate2_frontier.tres` for the historical reward-only and speed-only comparisons. The later reroll probe uses the final full-run command with `--seed=23 --policy=generalist --config=reroll-first --reroll-first`; it buys one reroll before shopping in every preparation. This is an additional diagnostic, not a change to the frozen training/holdout plan.

## Rendering, rules and regressions

```powershell
& tools/balance/run_checks.ps1 -Output .godot/phase5/reproduce-rules
& tools/balance/run_checks.ps1 -Rendered -Output .godot/phase5/reproduce-rendering
& tools/balance/run_checks.ps1 -Only 'balance/rules' -Output .godot/phase5/reproduce-phase5
& tools/balance/run_checks.ps1 -Rendered -Only 'balance/defeat_input' -Output .godot/phase5/reproduce-defeat
```

For a complete rendered run, use the awaited full-run command above **without `--headless`**, and add `--rendered --config=final`; use seed 11 and a fresh output. Expected evidence: fifteen start clicks, four reward clicks, final victory, `rendered.json` with `restart_verified=true`, preparation/relic/boss/result/restart screenshots. The loss fixture advances normal engine frames rather than the fixed-step driver. Existing Phase 1–4 rendered suites cover hand/shop/relic/intelligence/pause inputs.

Interactive recording during ordinary play: launch formal `res://scenes/level.tscn` with `-- --balance-trace=res://.godot/phase5/human.jsonl --balance-seed=23`. A restart preserves existing files by appending a unique suffix. `--balance-summary` reduces detail but cannot independently reconstruct damage. Human results remain NOT RUN until someone actually plays and records them.

## Recompute evidence independently

```powershell
& $py tools/balance/analyze.py .godot/phase5/rendered-final
& $py tools/balance/report.py --manifest tools/balance/evidence.json --archive
& $py tools/balance/replay_audit.py
```

The report reads raw JSONL, reconstructs each Gold transaction and HP/shield/healing sequence, checks deaths and complete-wave counts, compares terminal Gold/kills/damage when available, verifies recorded event/sample counts, then regenerates tables and four plots. It imports no gameplay code. `raw_manifest.json` contains file SHA-256 values. The selected raw traces and logs are bundled in ignored `.godot/phase5/raw_evidence.zip`; unpack it at the workspace root to restore expected paths. The tracked `reports/phase5` directory contains only aggregate data, manifests, charts and status summaries.

Final runtime parameter export: await Godot with `--headless --path <root> --script res://tools/balance/export_parameters.gd`; destination defaults to `docs/balance/phase5_parameters.json`. The generated authoring proposal is reproducible with `python tools/balance/author_candidate.py --candidate final --output <a-new-path.tres>`; the default output is ignored and does not overwrite the authored level. Boss model generation is optional, read-only against the legacy source, and is not required to run the game.

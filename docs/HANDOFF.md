# Routing Sandbox — Phase 5 交接

## 最新同步補註：2026-10-24

已完成 `origin/main`（`a5422c8`）→ `experiment/routing-sandbox` 的本地正常 merge，新 HEAD 為 `3fbad09d78085c9d646174cc9f4177fa46eba333`；原 Sandbox HEAD 為 `c33d425`，共同祖先為 `2fe5adc`。未 push，未移動本地 main 或修改正式 worktree。完整差異、衝突、修復與本次證據見 [Git 整合報告](../reports/git_integration_2026-10-24.md)。

Phase 5 原有 42 個 tracked 修改與 77 個 untracked 檔案已還原並保留未提交；安全 stash `d884400fc38ba15e429a5f1f9f2b260eb04948aa` 與 `.godot/merge-main-2026-10-24/original-files/` 仍保留。WIP 已在工作區，不要再次直接套用 stash。合併後 32 個代表性功能場景最終通過，另有正式入口 smoke、完整十五波渲染局／四次遺物／Boss／重開、獨立帳本及待提交樹的獨立驗證。Native runtime 已執行，Native build／Web／release／效能／真人未執行；初輪失敗與限制見整合報告。

以下是同步前的 Phase 5 實作交接與歷史量測；其中 `c33d425`、未進行 merge、29 項驗證等只描述該階段，不代表本次最新 Git 狀態或測試集合。

核對日期：2026-10-24（Asia/Taipei）。本文件描述本次實作與量測，後續仍須先核對實際 Git 狀態。完整 A–G 報告見 [Phase 5 最終證據](balance/phase5_final.md)，操作見 [README](../README.md)，共識見 [AGENTS](../AGENTS.md)。

## 1. 目前版本與範圍

| 項目 | 核對結果 |
|---|---|
| 工作目錄 | `D:\games\begins-with-a-road-routing` |
| 分支／HEAD | `experiment/routing-sandbox`；實驗起點 `c33d425`，本次 Phase 5 提交前 HEAD `3fbad09` |
| 開始狀態 | 乾淨；實際 HEAD 已不是需求中的舊快照 `2e2de2a` |
| 正式／舊專案 | `D:\games\begins-with-a-road`／`D:\games\card-tower-defense`，唯讀，未修改 |
| Git 操作 | 使用者後續「GIT更新」授權將 Phase 5 成果提交本機；本次未 push、reset、clean 或丟棄既有成果 |
| 引擎／原生 | Godot 4.7.2、Compatibility；沿用 phase4 Windows debug GDExtension，未改 C++／未重建 |
| SDK | `native/godot-cpp`：`e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77` |

上一版交接屬於 Phase 1–4 文件整理；其「三 ACT／只有盾衛試配／勝敗未完成／本次只改文件」已被本次功能工作取代。舊版本可在 `c33d425` 的 `docs/HANDOFF.md` 查閱，不把歷史測試當成這次已重跑。

## 2. 正式玩法

F5 → `scenes/level.tscn` → `assets/data/levels/frontier.tres`，五 ACT／十五波、九種既有普通兵與一隻最終攻城巨獸。不限時準備、手動開波、原 1.5 秒開場。第 3／6／9／12 波後各三選一，不發第五件遺物，不自動加入口。

防線生命 20，普通漏敵扣 1、巨獸漏敵敗北。敗北清除待出生／存活敵人且不發該波獎勵；勝利須等敵人及在途攻擊結束。兩種結果均鎖建造／交易／開波，結果按鈕重載場景恢復 1x、未暫停與全新狀態。沒有存檔、局外成長或新貨幣。

初始三張免費塔牌、9 Gold、開場商店。擊殺收入仍為 0，波次獎勵依序 9/9/9、11/11/11、12/12/12、14/14/14、15/15/0，共 168。塔價 sentry/ballista/broadside/crossfire/mortar/barracks=9/8/8/10/9/8；傷害 12/30/16/8/24，兵營友軍6。間隔、幾何、成長、Lv.3 上限及原有 17 專屬遺物不變。

巨獸適配舊裝甲撞槌模型與雙塔癱瘓，1200 HP、速度倍率 .4、8 秒冷卻＋1.2 秒前搖、3 格內最多兩塔癱瘓 3 秒。模型在本專案內自足；不帶入舊管理器、動態插怪或威脅選路。沿固定行程，保留減速／冰霜／擊退／兵營攔截，狩獵不處決 boss。

## 3. 系統與關鍵入口

| 責任 | 位置 |
|---|---|
| 波次與正式數值 | `assets/data/levels/frontier.tres`、`assets/data/towers/`、`assets/data/troops/siege_behemoth.tres` |
| 生命／勝敗／四次獎勵 | `scripts/levels/level_session.gd`、`scripts/levels/definitions/level_definition.gd` |
| 結果、生命及 Boss UI | `scenes/levels/run_status.tscn`、`scripts/levels/presentation/run_status.gd` |
| Boss 能力快照／多目標 | `scripts/enemies/troops/troop.gd`、`scripts/combat/enemy_abilities.gd` |
| 出兵與終止／RNG | `scripts/enemies/spawning/{enemy_wave,wave_spawn_schedule}.gd` |
| 開場商店／帳本事件 | `scripts/cards/shop/card_shop.gd`；原卡面價格快照與交易權威保留 |
| 可選事件記錄 | `scripts/combat/balance_trace.gd`；各正式系統僅在啟用時發事件 |
| 實際戰鬥實驗 | `tests/balance/{laboratory,full_run,counterfactual,rules,defeat_input}.tscn` |
| 策略／預留地圖 | `tests/balance/{policy,holdout}.gd`；保留七策略與原先凍結的地圖 |
| 獨立分析／重現 | `tools/balance/{analyze,report,replay_audit,verification}.py`、JSON manifests、PowerShell runners |
| 模型離線生成 | `tools/assets/build_siege_behemoth.gd`，已烘焙模型不需重新生成即可執行 |

原 Phase 1–4 架構仍見 [architectures](architectures.md)、[systems](systems.md)、[Phase 3](phase3.md)、[Phase 4](phase4.md)。未更改有限 Cost 候選、硬性 SHORTEST／NEWEST 資格、整群配額、預覽不消耗 RNG 或固定行程規則。

## 4. 證據與重現

- [基準稽核](balance/phase5_baseline.md)：原始 1074 個載入參數、原始價格／Gold／Boss 依賴。
- [方法](balance/phase5_methodology.md)：事先假設、七策略、凍結 holdout、敏感度及限制。
- [迭代](balance/phase5_iterations.md)：包含無效價格假設、失敗候選、重現差異及否決理由。
- [最終報告](balance/phase5_final.md)：參數、十五波、每項主張的條件／樣本／結果／不確定性。
- [重現指令](balance/phase5_reproduction.md)：Godot 等待方式、參數、seed、Python 與 Matplotlib 依賴。
- [真人驗收](balance/phase5_human_playtest.md)：尚未執行，不能把自動操作當真人結果。

`reports/phase5/independent_results.json` 有 675 筆原始 trace 的獨立重算：432 參考遭遇、144 基準重播、56 能力／交通遭遇、43 完整跑局。重播不是額外獨立樣本。原始 JSONL、log、截圖留在 `.godot/phase5/`，選定 trace/log 壓縮包為 `.godot/phase5/raw_evidence.zip`。`tools/balance/evidence.json` 是選取清單，`raw_manifest.json` 有 SHA-256；追蹤中的 reports 僅保留彙整與四張診斷圖。

主驗證為七策略×兩 seed 的 14 局，加事先保留的四局，均完成；training 漏敵範圍 0–11，holdout Core/307 漏敵15。675 筆帳本／傷害／生命週期可重算，不代表 675 個種子或平衡通過率。原始 72 案例用原 RNG 重播後五項指標全吻合；新 RNG 造成五個迫擊砲結果不同，已標記。

正式遊玩可加 `-- --balance-trace=res://.godot/phase5/human.jsonl --balance-seed=23`。詳細記錄可獨立核算；summary 模式不能完整重算傷害。重開保留舊檔並用新後綴。平常預設不記錄。

## 5. 驗證分類

以 [verification.json](../reports/phase5/verification.json) 的場景、模式及 log 為準，不能把 assertion 數和測試場景數混加。

| 分類 | 本次證據 |
|---|---|
| Current PASS | 29 項目前場景／模式檢查：21 headless、6 既有 rendered 輸入回歸、1 rendered 完整長局、1 rendered 敗北／重開 |
| Current PASS | 獨立帳本675 trace、基準重播72/72；屬資料驗證，不灌入上述29項 |
| Current FAIL | 上述最終回歸集合無未解失敗；敏感度敗北是有效量測結果，仍完整保留 |
| Historical PASS only | 早期 Phase 1–4 未於本次重跑的 suite／release 結果；查原 acceptance 文件，不列本次 PASS |
| NOT RUN | Windows release export、Web wasm／瀏覽器、效能／記憶體、真人、Phase5 波次編輯器互動 |

初輪回歸有六個舊數值／手動步進 fixture 失敗，原 log 保留；實際修正 fixture 後重跑通過，最後重要九項再驗證。沒有為了舊斷言改回正式資源。Phase5 規則有64檢查，包含15波、四次遺物、終局鎖定、敗北排程、Boss 狀態及清理。

Rendered 完整局以真實 viewport 點擊15次開波、四次遺物與重新開始；建造策略仍走 API，不代表逐張拖牌的人類遊玩。敗北 fixture 用正常引擎幀與真實輸入驗證。Compatibility 在 RTX4060 Laptop 執行；sandbox shader-cache 建目錄警告保留，不影響已觀察的截圖／點擊。Editor import 的設定存檔錯誤不能算 editor 驗收。

## 6. 已知限制與下一步

六塔購買角色與後期難度仍只有部分支持。Broadside 全局使用率／有目標時間低；交通對鼠群有收益，但對血法師／硬性選路不保證有利；部分後期波次在14個訓練局都零漏敵，W12 Heavy/11 卻漏11。HP或速度增加20%、全塔同價9的單 seed 探針可敗北，不能稱已找到穩健最優解。普通兵種資源未改，壓力來自編成／重疊／波次速度。

目前停在最終人工接受。請依真人驗收表觀察首波購買可理解性、分流回報、Boss 前搖辨識、W12尖峰與後期是否仍需決策。若修改數值，先記錄工作樹與新配置，不覆寫這次原始證據，不拿 holdout 反覆調到通關後仍稱保留驗證。Phase 5 成果依後續 Git 更新指令提交本機，尚未整合到正式專案。

## 7. 本機 Git 更新核對

使用者後續要求「GIT更新」。當時分支 HEAD 已為 `3fbad09`，包含既有 `origin/main` 合併、流量呈現與兵種圖示更新；這些既有提交不由本次重做。Phase 5 原始實驗仍按原紀錄解讀，不把舊樣本換標為新 HEAD 重測。本次另於整合後工作樹重跑 `balance/rules`，結果 Current PASS，log 在 `.godot/phase5/git-update-checks/balance-rules.log`；`git diff --check` 通過。提交包含 Phase 5 程式、資源、實驗工具、彙整證據及文件，原始大型輸出仍保留在忽略的 `.godot/phase5/`。

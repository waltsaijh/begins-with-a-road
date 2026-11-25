# Begins With a Road 穩定性調查與架構審查

2026-11-25，台灣時間（UTC+8）。調查標的是使用 Godot 執行時的兩件事故。本文的行號以本機 checkpoint `1363b5d28153c10c6ba3640c1cd9a447a1bbb210` 為準。

## 三個先回答的問題

1. **能確認到哪一層？** 16:22 有本專案 Godot 行程在 NVIDIA OpenGL 模組內發生讀取存取違規的三方紀錄。玩家回憶下午四點左右在一般戰鬥中必須強制關掉遊戲，此案是時間與執行方式最吻合的候選。另一次在擊敗首領、結算畫面已出現後，畫面和滑鼠一起凍結；附近時段有處理器已修正的硬體錯誤及非正常重開。後者缺乏當下的核心堆疊。**無法證實兩起事故有共同根因。**
2. **最優先三項。** 第一，整機凍結期間的處理器錯誤值得帶著紀錄做主機層排查，重複進行實機壓測會有再次中斷的代價。第二，戰鬥程序崩潰已能定位到確切原生模組與位移，值得優先做離線符號化。第三，遊戲自身已有可獨立重現的離場缺陷：渲染批次移除敵人時會讀取已離樹的防禦塔。這是修復範圍明確的專案問題。另有一條會放大群殺幀成本的商店刷新路徑，見下文量測。
3. **下次最值得留下什麼？** 若再次整機凍結，優先保存「同一次重開對應的系統傾印」（若 Windows 有寫出）。記下到分鐘的本機時間、畫面、聲音、滑鼠和恢復方式，重開後先對照 System 1001 的 dump 路徑及有無同時段 LiveKernelReports，再啟動 Godot。若僅遊戲卡住、Windows 仍能操作，最有價值的是關閉前該 Godot 遊戲行程的 hang dump，可用工作管理員「詳細資料」建立記憶體傾印；若已崩潰，保留 CrashDumps、Report.wer 及玩家 log。傾印可能含記憶體中的私人內容，均留本機。

## 版本與證據保全

- 已先讀實際 AGENTS.md。分支 `experiment/routing-sandbox` 與本機追蹤的 `origin/experiment/routing-sandbox` 原同指 `bc668e861bc00d43f71771f13b585f39202b2d21`，index 原無 staged 內容。95 個已追蹤檔有差異，另有 96 個未追蹤檔。辨認新增的 Blender 原始檔、GLB、烘焙 Resource、腳本與 UID，最大新檔 heavy.glb 為 101,860 bytes。
- 先用 `git status -sb`、`git rev-parse HEAD '@{u}'`、`git diff --cached --stat`、`git diff --stat`、`git diff -- project.godot`、`git ls-files --others --exclude-standard`、`git check-ignore .godot bin build export_credentials.cfg` 核對。執行 `git add -A -- AGENTS.md README.md project.godot assets docs scenes scripts tests tools` 及 `git commit -m "Checkpoint current game, art, UI, and test progress before stability review"`。共 191 檔、4,649 行新增、387 行移除，含工作樹的敵人資源、美術來源、部署／法術／事件／結算相關遊戲進度、設定、文件和測試。提交後工作樹乾淨，對本機上游 ahead 1。沒有 fetch、push、merge 或操作 stash、其他 worktree。
- 調查次序為 checkpoint → 複製玩家日誌、既有測試紀錄及可讀事故證據 → 新的隔離 headless 實驗。原始證據索引在本機 `.godot/stability-20261125/preserved.csv`，含原始路徑、複本、大小、UTC 修改時間、SHA-256。`manifest.csv` 補列引擎與 native DLL。較早渲染測試與更新後的測試輸出仍分檔保留。System 和 Application 篩選 XML 分別存為 `System.events.txt`（29 筆）及 `Application.events.txt`（13 筆），事件的 SystemTime 使用 UTC。本機忽略目錄會隨手動清除 .godot 而消失，保留事故資料時應一起備份到私人位置。
- 玩家資料源為 `%APPDATA%/Godot/app_userdata/BEGINS WITH A ROAD/logs`，另有使用者的 `AppData/Local/CrashDumps`、Windows WER ReportArchive、System/Application 記錄。名稱含 `arrival-*`、`drag-hand-*`、`list-input*` 的 .godot 紀錄來自先前合成測試，並非事故當次日誌。
- Report.wer 記載引擎為 `C:/tools/Godot.exe`，載入此工作目錄的 `bin/road_graph.candidates.windows.template_debug.x86_64.dll`。玩家 log 是 Godot 4.7.2.stable.official，commit `ed1daf0bf001b61586d9930840f2f1394092c079`，OpenGL 3.3 Compatibility，RTX 4060 Laptop GPU 610.62。實際啟動記錄比 project.godot:57–59 同時出現的 Windows driver 與 rendering method 設定更能辨識這次後端。測試引擎與現存 C:/tools/Godot.exe 的 SHA-256 均為 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`。現存 debug DLL 為 `1795E58C4FEFBAB7995B94993A619C2767A26AA433B98FA11B91B2172694E0E9`，由 road_graph.gdextension:7 選用。Git 忽略 bin，重建時需核對二進位檔；目前雜湊不能倒推事故記憶體逐位元一致。

## 事故 A　戰鬥中關閉遊戲

**原始證據已確認；事故未在本輪重演。** 玩家記得一般戰鬥中強制關閉遊戲。2026-11-25 16:22:45.682，WER EventTime 與 Application Error 1000（record 21403）對上 Godot.exe；16:22:54 Windows Error Reporting 1001（21404）記錄報告。玩家日誌 `player-logs/godot2026-11-25T16.23.32.log:6–19` 含 signal 11、兩層 nvoglv64.dll 及後續引擎幀；輪替檔名時間晚於 WER 數秒。

本機擷取 `Godot.exe.2736.dmp`（45,661,413 bytes，SHA-256 `BCAA9F72DFBBBE0FCA644F0DF344E2B2C036E720C1B8308BDC5ADBD785C85090`）。直接讀取 MDMP ExceptionStream 與 ModuleListStream：執行緒 28504、例外 0xC0000005、讀取位址 0x162、指令位址 0x7FFE9DC20DC7，落在 nvoglv64.dll + 0x670DC7。Report.wer 同為 0x670DC7、模組版本 32.0.16.1062；Godot 自身回溯為相鄰的 +0x670DC6。三者都指向同一區域。11/20 也曾有載入本專案 DLL 的 Godot／nvoglv64.dll APPCRASH，但位移不同，沒有當次玩家操作資料。

可信度高的是**失敗指令與例外類型**。現有資料分不出驅動內部缺陷、引擎向 OpenGL 提交的狀態異常、先前的記憶體破壞或平台不穩。堆疊未符號化，引擎沒有留下當下的 GDScript、塔種、shader 或繪製命令。也未找到可區分強制關閉與例外先後的使用者輸入紀錄。即使新程式碼調整了卡頓或離場錯誤，也要獨立比對這個例外簽章。最小下一步是對已保存的使用者 dump，以匹配 Godot build 的符號在本機 WinDbg 執行 `.ecxr`、`kv`、`lmvm nvoglv64`，辨識最靠近驅動的引擎呼叫端。當次查找未取得可用本機 WinDbg/CDB 及相符 PDB；沒有安裝工具或上傳傾印。

## 事故 B　首領死亡後整機凍結

**玩家目擊及非正常重開各有依據；共同原因待驗。** 玩家已看到結算畫面，隨後畫面固定且滑鼠無法移動。這個順序將單純「未進入結算」排到後面。11/25 16:26:10 至 16:32:02，有 11 筆 WHEA-Logger 19（records 87441–87451）；Windows 對 87451 的原文為「已修正的硬體錯誤」「處理器核心」「Corrected Machine Check」「Internal parity error」「APIC 識別碼 1」。當日 15:22 等較早時間也出現相同欄位。系統曾自行修正這些通報，單一事件或 APIC 編號都不足以判定 CPU 損壞。

16:35:41 有 Kernel-Power 41（87487），BugcheckCode=0；16:36:03 有 EventLog 6008（87458）及 6005。6008 的內文引用前次非正常關機為 16:31:21，與另一筆 16:32:02 硬體通報的表面順序並不一致，不能拿來重建精確的凍結秒數。找不到這次重開對應的新 bugcheck 1001 與可讀核心傾印，也無法從紀錄證實玩家的實際重開方式。11/24 23:07 的 0x1A bugcheck 和 112426-33187-01.dmp 是前一晚的獨立事件。核心 WER／先前系統 dump 的讀取受 Windows ACL 限制，已記錄，不變更權限。

可信度高的是「該時段有平台層更正錯誤，且發生非正常重開」。**目前沒有證據把首領碎石、勝利音樂、某個 GPU 資源或特定硬體元件定為整機凍結的肇因。** 在反覆渲染前，宜把這段時間窗與事件內容交給主機維護者確認平台穩定性。戰鬥 A 的 fault module 不能代替 B 的 kernel dump。

## 正式生命週期與同幀行為

| 階段 | 實際入口、責任與可觀察的結果 |
|---|---|
| 進入、準備、建造 | project.godot:14 → scripts/menus/boot.gd:44 → scripts/menus/main_menu.gd:102 → scenes/level.tscn:3 繼承 main。scripts/levels/level_session.gd:41、109 在子節點 ready 前套用地形，:171 起準備導航及顯示。scripts/cards/card_placement.gd:305–356 → TowerMap 提交成功才消耗卡。地圖與 CombatRegistry 管合法性，TileVisuals 管呈現。 |
| 開波與生成 | level_session.gd:241–259、278–292 先取得階段鎖並收店，再提交排程；scripts/enemies/spawning/enemy_wave.gd:89–121 計算路線、預留顯示容量，:216–257 依時生成並連事件。首領與同波普通兵可以有不同入場方式。 |
| 最後擊殺 | scripts/enemies/enemy.gd:73–88 先設 finished，同步發 died，之後 queue_free 並發 damaged。enemy_wave.gd:306 → enemy_killed → level_session.gd:166–169 入帳 1 金；enemy_wave.gd:322–333 以 living.erase 防止 tree_exiting 重扣，在 pending 空、alive=0 時先清 active 和首領臨時地面，再發 wave_finished。商店 scripts/cards/shop/card_shop.gd:90–98 以輪次防重，清波獎勵另算。 |
| 在途攻擊與結算 | level_session.gd:294–313 有 finished、HUD 在樹及 settling 守衛；若 projectile 仍在陣列，等待其清空。scripts/combat/combat_system.gd:57–73 的命中回呼可在移除該發射物前同步發生。最後一波到 level_session.gd:338–340、418–445。finished 先設定，保存通關再顯示畫面；其他同一死亡 signal 的視覺訂閱仍可能在此後才跑（enemy_multimesh.gd:139–150）。不能假設結果畫面顯示後已無死亡特效提交。 |
| 致命漏敵 | enemy_wave.gd:301–304 先發 enemy_leaked，level_session.gd:411–433 扣血／首領漏敵結束，abort_wave 先關 active、清 pending、停敵人與清投射物。返回原呼叫棧時，release 的 active 條件避免將敗北當清波。 |
| 結算留場 | _end_run 只停 LevelSession 的 process。戰鬥主循環無目標即早退；兵營仍有復位／掃描路徑（scripts/combat/barracks_system.gd:55–92），HUD 仍會排版與詢問時間軸（scripts/levels/presentation/level_hud.gd:130–163）。勝利呼叫 RunStatus.finish 的 _presented 守衛、一次碎紙（24 片、約 1.4 秒）與勝利音樂。還會同步保存進度及搜尋下一張圖（level_progress.gd:41–71、run_status.gd:47–59、133–140、level_catalog.gd:11–22，目前三張關卡資源）。會產生同步工作；沒有測到這些工作造成死鎖。 |
| 離場、重玩 | run_status.gd:103–126，重玩重載關卡，下一張／回選單走 ScreenTransition；scripts/interface/screen_transition.gd:79–113 在 scene_changed 後等待準備。暖機含 await 與離樹檢查；可另外測試切場取消與完成回呼競合。結果已顯示、玩家還沒選重玩時，不能直接套用「拆除整個 scene」的錯誤。 |

## 可重現的離場缺陷

**已重現，高可信。** 爆破手前搖持有有效的塔實例，但塔已離開場景樹；移除另一敵人時渲染器把末槽交換過來，立刻更新其姿勢。enemy_multimesh.gd:83–100、169 檢查了敵人與 renderer；enemy_action_visual.gd:50、62 讀取目標的 global_position 前只看實例有效性。這會觸發引擎 `!is_inside_tree()` 並回傳預設 transform。玩家可能看到錯位或在離場得到引擎錯誤。

歷史渲染測試 `list-input-out.log:4–12` 由 tests/synergy/playground.gd:75 移除場景，觸發上述堆疊，但 54 項功能斷言通過。新實驗 `action-probe/first-observation.log:3–14` 以同一行程的真實 MultiMesh／敵人／姿態程式比較；唯一變因是從樹移出仍有效的目標。A 零錯，B 一次相同堆疊，兩者剩餘槽位皆正確且程序正常退出。手動建立前搖，未重演整場戰鬥。建議修復時將「移除／搬移槽資料」與「提交下一幀姿態」分開，離場時只清理；讀取目標前驗證仍在樹上。驗收要同看槽位結果和引擎錯誤數。

## 資源與幀耗風險清單

下列是從資源擁有者追到釋放點的靜態證據。除另列對照外，沒有把程式配置次數當作實測 RAM、VRAM 或事故因果。

| 系統與原始碼 | 何時建立、保留與釋放 | 可區分風險的量測 |
|---|---|---|
| 敵人批次及施法模型。enemy_wave.gd:103–111、scripts/enemies/rendering/enemy_mesh_batch.gd:19–60、enemy_action_visual.gd:25–62、89–94 | 開波依模型預留整波容量，超量可倍增；敵人死亡減 visible count，容量保持到場景卸載。部分敵人首次施法實例化 GLB，動作後隱藏，移除時 dispose。 | 固定敵人數，觀察 capacity、visible_count、活體數及首次施法幀；同等容量重用與每波單調增長分別記錄。 |
| 道路與開場。scripts/map/tile/appearance/tile_visuals.gd:97–129、166–204、230–250；road_surface.gd:101–152 | sync 會掃全圖；形狀加鄰居狀態作 MeshLibrary 鍵，舊形狀可留至場景卸載。開場在同一次 sync 建立各格臨時 Node3D 和 MeshInstance，再依順序顯示。動畫結束回靜態批次。 | 同地形、同修改循環，量 cache.size、活動 jobs、節點與 sync 時間；A→B→A 再重複可區分首輪暖機和持續增長。 |
| 敵方首領、法術、投射物。enemy_wave.gd:251–300、scenes/enemies/boss_impact.tscn:11、scripts/cards/definitions/commander_spell.gd:36–66、scripts/combat/rendering/attack_visuals.gd:47–79 | 同一首領空地依格去重，最多一格接道加九格平台／單一落點，借用 Mesh，清波或 abort 時釋放。落地 48 粒、0.6 秒後 finished 釋放。光束與延遲彈有期限，援軍於波後清理。有投射物時每幀替換 ImmediateMesh，可能反覆提交渲染資源。 | 分別計數釋放後空地、粒子、援軍、殘餘彈，按命中數觀察幀時間。首領落地與首領死亡後結算是兩個不同時刻。 |
| 戰鬥特效與聲音。scripts/combat/rendering/restored_bursts.gd:5–43、scripts/audio/game_audio.gd:80–131 | 短時 burst 有 72 上限及壽命，死亡及命中另有固定粒子池。Audio Autoload 持有跨局播放器與 BGM，勝利轉場另有一次性播放。場景切換後仍有播放器是設計預期。 | 按持有者計活躍量與總池量；每局返回相同選單之後再取樣。舊 MP3 退出訊息不代表現行 OGG 洩漏。 |
| 原生導航與預測。scripts/navigation/portal_map.gd:105–113、172–190；scripts/navigation/routes/reduced_routes.gd:21–25；native/src/reduced_routes.cpp:56–87、110–116；scripts/navigation/visualization/road_flow_renderer.gd:179–243 | deferred 重建仍在主執行緒，最低分路線遇到許多同分連接時會重建搜尋；地形／成本變動使快取失效。準備期流量顯示建立查詢紋理。 | 固定小地圖只改平分候選數，記錄候選、plan_us 與幀時間。預測限準備期；現有玩家 fault 指令不在原生導航 DLL。 |

### 戰鬥中集中擊殺的成本

**已重現，同步入帳是可量測的卡頓風險。** level_session.gd:169 → scripts/cards/shop/card_shop.gd:293–304 → scripts/cards/presentation/card_shop_view.gd:113–135。四個隱藏商品各設 price_override、can_afford；card_view.gd:12–19 的兩個 setter 值相同仍進 _refresh，:247 刷新配方，card_tile_diagram.gd:22–71 清空再建道路線點。每次入帳至少八次卡面刷新，32 筆至少 256 次。金幣圖示的視覺聚合發生在不同路徑。

第一輪暖機後，在同一 Frontier 場景、seed 17391、1×、起手三張、固定四商品與商店關閉守衛，逐輪重設餘額 9，交替做同額的兩種入帳方式。單筆 32 金幣三輪為 **2.175、4.432、7.467 ms**；同一呼叫時段內 32 筆各 1 金幣為 **188.143、143.358、164.871 ms**。最終皆為 41 金幣；兩種訊號各發 1 或 32 次。中位數之比 37.2。原始輸出 `shop-probe/observation-20261125-165217-829.log:3–12`。計時涵蓋完整入帳及同步 listeners，使用 headless、直接 grant，不含實際殺敵、GPU 或金幣圖示，尚未單獨量出 UI 所占比例。玩家可能感到一幀長停頓，164.871 ms 不能解釋需重開機的持續凍結。

最小修復候選是保留每筆交易與 HUD 正確餘額，在商店關閉時記下待刷新狀態；只在顯示前重建商品外觀。驗收應重跑相同探針，另確認重新開店後售罄、價格、購買力與 HUD 都正確。這項優化不需要先重寫經濟系統。

## 文件、腳本與測試債

| 原句或案例 | 現行證據與判斷 | 後續該保護的行為 |
|---|---|---|
| README.md:20「擊殺不額外給錢」 | level_session.gd:169 每擊殺入帳 1，docs/systems.md:469 有記載，新結算探針實測 +1。文字過時。 | 區分逐敵收益及清波／遺物收益。 |
| docs/systems.md:48「手牌平行排列」；AGENTS.md 的 11/08 歷史敘述「士兵／首領多路分流」 | card_hand.gd:258–259 現為 4° 扇形、弧高 8；boss_approach.gd:5 與 wave_spawn_schedule.gd:36 另選密集防線。AGENTS.md 頁首已有新共識。docs/HANDOFF.md:3、23、27 有日期，保留其歷史性。 | 系統總覽改指現行入口；交接另加本次版本及仍失敗的測試。 |
| tests/balance/rules.gd:56–58 固定六塔售價 9/8/8/10/9/8 | 實際 sentry:30、ballista:32、broadside:32、crossfire:29、mortar:29、barracks:24（均為 assets/data/towers/ 的同名 .tres 行號）分別 30/40/40/50/50/35。舊 `arrival-rules.log:160` 記六項價格斷言失敗。 | 從所抽 BuildCard 核對實付金額和餘額；若要鎖平衡值，另維護經確認的基準。 |
| 同測試 :37、39–42、63–75 停掉場景自行推進，僅完成遺物選擇 | 正式 :358–365 的特殊事件可鎖開波，:242 會拒絕，tests/events/regression.gd:280 另有覆蓋。後繼多項勝利／商店斷言共享失敗的前置流程；不能算成多起獨立產品故障。:90–94 把延後群組加給即將被 level_session.gd:250、383 與 special_event_manager.gd:224–226 重建的波次複本。 | 從正式開波讀取的原始關卡資源設定 fixture，走完入口與事件選擇，驗證最後一敵和在途攻擊完成才贏，敗北清除 pending。tests/levels/result_actions.gd:33、40、47 直接呼叫 _end_run，只能覆蓋結果介面。 |
| tests/cards/card_drag_placement.gd:89、111、123–125 的回位斷言 | 同時測根節點位置和卡面旋轉；:272 摘要布林固定為 true，必須另看 failures 與錯誤行。舊渲染紀錄 `arrival-verified-card_drag_placement-out.log:4` 失敗，先前非固定步進的 headless 通過。新時間對照見下表。 | 分開記位置、旋轉與焦點；用實際時鐘等待動畫停止，設有界 deadline。保留真實視窗焦點案例。 |
| scenes/levels/wave_timeline_act.tscn（UID wox18nlloehr） | 查名稱、UID、資源引用、外掛、project.godot Autoload、export_presets.cfg:7 與工具文件；正式 wave_timeline.gd:10 使用 components/ 下另一個場景。舊路徑出現在匯出排除表。尚無法排除人工入口，僅列候選。 | 確認維護者是否仍用舊場景手動預覽，之後才考慮刪除。反例是 scenes/main.tscn 仍被 scenes/level.tscn:3 繼承；relic_inventory.tscn 與 tower_hover.gd 仍有工具用途，tower_map.gd:46 實例化後者。 |

## 實驗設計與復驗

所有新引擎實驗均使用同一版本 Windows 引擎、單一 headless 程序、隔離 APPDATA、每個程序至多 30 秒與有限幀數；下一個案例在上一個程序退出後才開始。沒有新增渲染、匯入、長跑或改寫遊戲腳本。本機原始結果位於上文的個案目錄，診斷來源及重播啟動器與 checkpoint 分開。報告與探針保留為工作樹新增檔。

| 假設與單一變因 | 觀察值／停止條件 | 結果及限制 |
|---|---|---|
| 最後一敵為士兵或首領會不會改變結算次數 | 同一正式 LevelSession、合成一 ACT 一波、空起手、9 金、seed 17391、1×。同一開始命令、出生後 60 幀一次致死傷害，後看 90 幀再清理 6 幀。最多 650 幀，未出生或不符條件即停止。 | `final-soldier.log`、`final-ravager.log` 均 pass；兩者各一次 wave_finished／run_finished、kill=1、alive=0、gold +1、victory、結果可見與通關 ID 可讀。saved 檢查讀 LevelProgress.snapshot，本探針沒有重啟程序驗證存檔。未涵蓋第 15 波整場累積、投射物擊殺路徑、真 GPU、音效裝置或玩家當時配置。 |
| 搬移末槽時目標還在樹內／剛離樹 | 同一 renderer、soldier 和投擲前搖的 bomber，目標物件仍有效，只改在樹狀態；90 幀上限。 | A 正常，B 穩定出一次 global_transform 錯誤；可重播啟動器另外驗證一次。引擎退出 0。 |
| 固定總入帳，改單筆／32 筆 | 四個商品、同樣初始餘額與商店狀態、暖機一次，交替三輪；上限 120 幀，異常即停。 | 見上文毫秒數；未拆成個別 listener，也沒有測量 RAM 或 VRAM。 |
| 相同手牌操作，改一般時鐘／--fixed-fps 60 | 保留原測試至回位斷言，僅加入量測與提前結束；同一地形、原三張起手、seed 17391。觀察實際經過微秒、根節點、旋轉、選中／hover 與 sway；600 幀上限。 | `hand-probe/real.log` 約 264.73 ms，位置相同、旋轉 0、sway 0、failures=0。固定步進 `fixed.log` 僅 21.179 ms，根節點仍正確、hover=-1、selected=-1、旋轉約 0.00002292 rad、sway=0.06428；選牌搖動和回位共兩處失敗。card_view.gd:134–137 按實際時鐘、每幀上限 0.08 秒，測試等待場景 Timer。**已證明固定步進可製造假失敗**；沒有當次渲染失敗的分項值，仍不能排除該次焦點或產品問題。 |

### 在另一份 checkout 重跑

需要此 checkpoint、可正常執行的 Godot 4.7.2 專案與相容 native DLL，以及與報告同交付的 [重播目錄](stability_2026-11-25_replay/)。將目錄維持在 reports/ 下。來源目錄有 .gdignore，啟動器把指定探針複製到 .godot 的個案位置，log 按時間戳另存。使用本機引擎的實際路徑，每次只選一案。

```powershell
$engine = 'C:/tools/Godot.exe'
& ./reports/stability_2026-11-25_replay/run.ps1 -EnginePath $engine -Case ravager
```

可選 soldier、ravager、detach、shop、hand-real、hand-fixed。detach 以「A 零錯、B 一次指定堆疊」為重現標記；hand-fixed 可能回傳失敗，應查看實際經過時間及個別輸出。本次另外實際跑過交付版的 -Case detach。相同毫秒數並非跨機器驗收標準。

### 證據查詢與尚未執行項目

- 實際取證使用 Get-ChildItem、Copy-Item、Get-FileHash、Get-WinEvent。時間窗從本機 2026-11-23 零時到本次擷取。System 過濾 41、6008、1001、4101、17、18、19、46、161、2004、6005、14、153 再依 provider 縮小。Application 過濾 1000、1001、1002 並選 Godot／BlueScreen／LiveKernelEvent 等字樣。用 ToXml 保存欄位；對 87451 另讀 Message。只需複查凍結窗可執行下列唯讀命令。
- WER 用 Report.wer 的 EventTime、Sig、AppPath 和 LoadedModule 核對。PowerShell 以 BitConverter 讀本機 dump 的 exception stream（型別 6）和 module list（4），用 exception address 減涵蓋它的模組基址求 RVA，與原始 WER 及 Godot backtrace 交叉驗證。System 41 的 BugcheckCode 與 Application 1000 的 exception code 是不同欄位。
- 靜態查核使用 `rg -n 'enemy_killed|wave_finished|_end_run|run_finished|abort_wave' scripts`、`rg -n 'await|queue_free|tree_exiting' scripts/enemies scripts/levels scripts/interface`、`rg -n 'card_price|Future batch|Correct preparation' tests/balance/rules.gd assets/data/towers`、`rg -n 'uid://wox18nlloehr|wave_timeline_act|relic_inventory\.tscn' .` 等檢索後讀取函式及場景原文。事故與 headless 測試各用不同的 user:// 和 log。
- 未執行 GPU A/B、壓力測試、驅動或登錄檔變更、整機傾印配置、跨局成長實驗。現有資料沒有逐輪 RAM／VRAM 序列，不能下洩漏結論。若另獲授權且平台狀態允許，先選**單次、可在另一台機器執行**的最小渲染測試：固定 checkpoint／引擎／設定／種子，沿用首領探針的地形、開波及致死時間另製經授權的渲染案例，保留交付版的 headless 守衛；實驗變因只有是否啟用 Compatibility 實際渲染，觀察越過擊殺到結果的第一個原生錯誤。最多 30 秒，不重試；遇到顯示驅動恢復、畫面／輸入異常、WHEA 新事件即停。此對照只能區分進入實際渲染路徑是否為必要條件，不能驗證故障機硬體。若專查跨局成長，另行授權後先暖機，再逐輪於同一選單、同一等待時間採樣程序私有位元組、VRAM、物件、節點與 MeshLibrary 項目；分開標示波峰與卸載後基線。
- 提案順序為保存與離線分析原生堆疊、處理可獨立重現的離場錯誤、分離金幣入帳與隱藏商品重畫，再修正診斷與文件。原始失敗仍保留，未刪腳本、未改測試預期、未建立修復提交。

```powershell
Get-WinEvent -FilterHashtable @{
    LogName='System'
    StartTime=[datetime]'2026-11-25 16:20'
    EndTime=[datetime]'2026-11-25 16:37'
    Id=19,41,6005,6008,1001,4101
} | Select-Object TimeCreated,Id,ProviderName,RecordId,Message
```
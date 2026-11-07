# Routing Sandbox — Phase 5 交接

## 2026-11-07 背景音樂與音量設定

Git 更新：使用者以「git更新」授權將本節累積成果提交於 experiment/routing-sandbox（提交前 HEAD e5088df），不 push。本節下方各次實作的「未 commit／push」為當時快照，本次一併納入提交；其測試結果沿用已完成的實測，提交整理只重查差異及 git diff --check，不宣稱重新執行整套測試。

最新 BGM 格式替換：使用 Downloads 指定的 bgm_default.ogg／bgm_battle.ogg，複製至 assets/audio/music/ 並更新 GameAudio 引用，移除舊 MP3 副本及其 .import。原生 loop=false，保留 BGM 基礎增益、設定滑桿、號角與所有淡化時序。OGG 匯入無錯誤，Compatibility 實際 game_audio failures=0（包含兩曲 OggVorbis 類型、解碼、循環重疊與開波／結束切換）；未 commit／push。

新增哨塔攻擊聲：程序合成 `assets/audio/towers/sentry_shot.wav`（0.22 秒弓弦／破風），重建腳本 `tools/assets/build_sentry_shot.gd`；integrated/sentry.tscn 指定匯出的 shot_sound，沿用真實射擊事件與 Combat 音量。Godot 4.7.2 Compatibility 實際 tower_integration：84 次配置／旋轉、所有塔事件及哨塔開火時的音檔／bus 斷言通過，failures=[]、stderr 空白。未修改原攻速／傷害，未 commit／push；Web 與真人主觀混音未測。

新增 hover 音效：assets/audio/ui/hover.mp3（按鈕）與 card_hover.mp3（手牌、展開商店、遺物卡），播放增益均為 click 的 25%，走 Master。音訊專項 headless 與實際 card_drag_placement 回歸均 failures=0，涵蓋種類分流、低增益、停用按鈕靜音與同卡移動不重播。快速關閉仍可能出現前述 mixer Resource 清理警告，非斷言失敗。


本次追加（依使用者澄清修正）：全部 BGM 播放基礎增益 50%、滑桿預設恢復 50%、號角增益 50%，回平時音樂為 4 秒 smoothstep 交叉淡化。新增 Downloads 指定的 click／placement／wrong_placement 原檔副本，按鈕由 BaseButton.pressed 統一觸發、放置依提交結果觸發；非法放置只短亮紅色格面 0.4 秒。新增回歸斷言驗證預設音量、4 秒包絡、按鈕聲、成功／失敗放置聲、拒絕不消耗卡與紅色閃亮恢復。game_audio headless、card_drag_placement 實際 Compatibility 均 failures=0；已檢視 invalid_ground_before／flash 截圖，地塊區域 812 像素有明顯變化（RGB 差值總和 >10），效果不擴散至其他格色。首次新增音檔匯入前 preload 暫時報錯，素材匯入完成後測試可載入；Web 與主觀混音尚未驗證。


本輪使用使用者指定的三份原型音檔，在 assets/audio/music/ 保存獨立副本；新增 GameAudio Autoload、正式開波／收尾／離場接線、射擊 Combat bus 及共用設定頁三個百分比滑桿。開波號角一次、戰鬥結束不播號角；音樂淡化與雙 player 循環銜接以實際時間執行，跨場景保留音樂與音量。音量設定不跨次啟動保存。完整行為與測試入口見 systems.md「設定頁面」。沒有 commit／push。

本輪 Godot 4.7.2：隔離 APPDATA／LOCALAPPDATA 的 headless editor import 無錯誤；game_audio headless 與 Compatibility 實際渲染均 failures=0；既有 level_flow headless、pause_menu 實際渲染均 failures=0。音效設定截圖 .godot/audio-settings.png 已檢視，三滑桿及百分比沒有重疊。level_flow 快速關閉時有音訊播放 Resource 的清理警告；音訊專項在刪除播放器後等待 mixer 收尾，及 pause_menu 正常重玩／結束皆無此警告。主觀混音平衡、Web 匯出與瀏覽器使用者手勢音訊解鎖未測。原型專案未修改。


## 2026-11-07 本次 main → routing-sandbox 整合

以 Sandbox `d85f60b` 為基礎完成既有 `origin/main`／`MERGE_HEAD=6141d51` 合併。授權包含 Merge Commit，不 push。以下為本次紀錄；後續兩個分支的歷史紀錄不代表現況或本次重測結果。

合併前以 `git merge-tree` 重建同一對父提交，再逐檔比對 index 與工作目錄：兩者完全一致，沒有額外本地未提交差異。使用者確認可能沒有建立新 stash；清單只有 11 月 3 日 `60a9224`（此前已恢復）及 10 月 24 日 `d884400`。本次不重新 apply 舊 stash，兩份均保留，沒有把 stash 內容加入 Merge Commit。

衝突處理（實際 14 檔）：

- `AGENTS.md`、`README.md`、`docs/HANDOFF.md`、`docs/phase4.md`、`docs/systems.md`：整合兩邊有效設計與分支歷史，修正目前入口、圖鑑／進度頁、遺物列、倍速及測試敘述。
- `scenes/enemies/components/enemy_intelligence.tscn`、`scripts/enemies/presentation/enemy_intelligence.gd`：保留 Sandbox 較完整的通知、持久解鎖、閱讀佇列及靜態模型預覽；恢復原 `.gd.uid` 與 LevelSession 初始化，採 main 的新版圖示色。
- `scenes/relics/relic_choice.tscn`、`scripts/relics/relic_choice.gd`：頂列聚合份數與詳情保留，納入 main 的新版卡片、圖示／使用情境、全畫面 Backdrop、20px 間距及 Debug 重抽。左下獨立 inventory 元件保留給工具，正式關卡不顯示重複兩列。
- `scripts/levels/presentation/level_hud.gd`：保留集中頂列、緊湊時間線及檢視暫停擁有權；增加進度頁與 Tab／Esc，維持 Sandbox 1／2／4 倍。進度、設定及圖鑑／遺物詳情互斥，暫停選單共六項。
- `tests/levels/level_flow.gd`、`tests/levels/pause_menu.gd`、`tests/relics/input.gd`、`tests/synergy/input.gd`：依整合後介面保留兩邊階段鎖定、實際輸入、tooltip、遺物數量與手牌獨立性斷言。

跨檔案補強：六種敵人新 ID 加上 v1 codex 舊 ID 映射，圖鑑文字改用新 ID；進度頁敵人與原圖鑑共用遭遇解鎖規則。教學三波／前置關卡、五 ACT Frontier、四塔商店、交通 API、戰鬥、道路及 main 的新版素材／左右鍵鏡頭／載入預熱修改保留。資源引用掃描未發現執行期遺失檔案；列出的其他路徑是測試生成檔及離線工具輸出。

本次 Godot 4.7.2、Windows Compatibility 驗證（隔離 APPDATA／LOCALAPPDATA，不改玩家存檔）：

- Headless editor import：無錯誤，CSV 翻譯重匯入後二進位內容與合併來源一致。
- Headless：UI Slice A 104 項（當時版本）、tutorial/intro、progress_page、level_flow、relics/rewards、level_catalog、card_names、troop_resources、relics/mechanisms 114 項、traffic/integration 100 項、synergy/routing 357 項，全部通過。
- 實際渲染：最終 UI Slice A 108 項、level_hud、pause_menu（含重新開始）、pause_navigation（含血條像素）、camera_orbit、relics/input、synergy/input 67 項、tutorial/intro、main_menu，全部通過。頂列、圖鑑／遺物代表截圖已檢視。
- 初輪 UI 時間線測試在 deferred hover 啟動 tween 前取樣，補 GUI frame 同步後通過；pause_navigation 原有立即出生假設造成空陣列，改成獨立 Resource 的 start_tick=0 fixture 後通過。沒有修改正式波次或刪除功能來通過測試。

日誌與比對證據在 `.godot/merge-2026-11-07/`，截圖在 `.godot/test-results/`。未執行完整十五波平衡、Web 匯出／瀏覽器、release、效能或真人驗收，不以此次 Windows 回歸推論這些結果。

## Sandbox 歷史紀錄（合併前）

## 最新 Git 更新授權：2026-11-06

使用者要求「git更新並push到雲端」，授權提交本輪 UI Slice A、頂列／時間線與集中置中成果、資源、相關測試及文件，正常推送 origin/experiment/routing-sandbox。開始 HEAD 3f692fe，fetch 後本分支與遠端同步；origin/main 的新增提交未合併。本次沿用剛完成的 headless96／rendered99 及相關流程／時間線回歸，不另重跑遊戲測試；提交前核對 staged diff --check。測試log／截圖仍留在忽略的 .godot/。下方未commit／push為本次授權前的階段快照。不改main worktree、不做merge／rebase／reset／clean或強制推送。

## 最新 UI 布局：集中置中與同步位移，2026-11-06

沿用未提交成果，整組資訊依可見項目置中，固定16px間距；時間線展開／收合的0.18秒動畫同步帶動兩側圖標移動，不再貼齊畫面兩端，空遺物／無通知不保留固定槽。保留所有節點引用、tooltip、通知與暫停行為。headless整合96／rendered99、rendered level_flow／ui_scene_templates均failures0；日誌 .godot/ui-centered-*.log，截圖原目錄已更新並檢視。未commit／push，Web／長局未測。
## 最新 UI 追修：頂列與時間線，2026-11-06

沿用下節全部未提交成果。防線改盾牌圖示＋數值，與金幣／遺物／時間線／敵軍未讀通知／加速及暫停放在同一頂列；補上各項 hover 資訊。緊湊未來波次改空心圈、移除其底部細進度條；兩模式依 ACT 加雙菱形遺物節點（Frontier四次，自訂最終獎勵旗標保留）。未改戰鬥、導航或十五波流程。

本輪 headless整合92／Compatibility rendered95，failures0；rendered level_flow／ui_scene_templates／pause_menu亦各0。實際頂列、空心圈、兩模式遺物及hover截圖已檢視，日誌 .godot/ui-topbar-*.log，截圖仍在 .godot/test-results/ui_slice_a/（覆蓋為最新版本，新增health_tooltip／relic_node_tooltip／relic_milestone_active）。Web／完整15波／真人未測，user://環境限制同下節。未commit／push。細節見 [UI Slice A](ui_slice_a.md)。
## 最新 UI：Slice A，2026-11-06

起始 branch experiment/routing-sandbox／HEAD 3f692fe，工作區乾淨；本輪未 commit／push。完成四塔商品的單排商店（輔助設施保留但暫不販售）、hover／點擊展開的緊湊時間線、持有遺物圖示列，以及實際出生後的未讀通知／共用敵軍圖鑑。詳情向 LevelHUD 借用暫停並還原原狀態；通關 v1 保存加入 codex section，舊檔相容。沒有修改原生／導航、戰鬥／波次 Resource 或模型。

本輪 PASS：新整合 headless 78／rendered 81；商店 headless／rendered、cards、拖牌、traffic100、relic stacking／rewards／mechanisms113／rendered input、rendered level_flow／HUD／pause_menu／timeline templates、wave_spawn_groups、troop_resources、level_catalog、synergy rendered input67，failures皆0。初輪舊測試固定6張商品、3兵種、立即出生與舊空艇節點路徑已更新為目前契約；初輪解析／取樣問題已修正重跑。實際 Frontier UI 及800×600／1600×900截圖已檢視。日誌 .godot/ui-slice-*.log，截圖 .godot/test-results/ui_slice_a/。git diff --check 另於交付前核對。

預設user://／shader cache受環境寫入權限限制，部分既有整合測試留下保存警告；新增跨局／舊檔保存回歸使用隔離的可寫路徑且通過。未跑Web（仍缺路網WASM）、完整15波、效能或真人驗收。完整責任／入口／限制見 [UI Slice A](ui_slice_a.md)。下方為歷史階段紀錄。

## main 歷史紀錄（合併前；移除圖鑑及遺物詳情的決策由本次整合取代）

2026-11-07 進度頁：移除遊戲內敵軍情報按鈕／面板與「新 N」提示，主畫面與暫停選單新增「進度」，列出六塔、全部敵人與 21 件遺物的名稱、描述及數值／特性；遺物名稱下方以對應塔色小字標示使用情境，三選一卡片相同；開波提示的兵種圖示改為暫停並開到該敵人。新增 tests/menus/progress_page.gd（中英文無漏 key）。實際 main_menu、synergy/input、tutorial/intro、headless level_flow、road_flow_preview 通過；pause_menu 的 Restart fixture 失敗與 pause_navigation 的敵人準備錯誤在修改前提交版相同，未修。

2026-11-07 開場改為全白品牌畫面：Web shell 只顯示左 Godot（深色無框）右 team_icon；Boot 同畫面加細長進度條與小字；主選單就緒後 logo 淡出、白底再淡出。Logo 開場淡入 0.8 秒（Web 用 CSS、桌面用 Boot）。選圖進關卡維持白底，雲海載入版本已依使用者要求撤回。Web 實測 shell、Boot、轉場 logo 位置一致，無 console error。發現隱藏 IntroLogos 在 Web 尺寸為 0（Windows 不會發生），以 refresh() 修正並在 startup_loading 加回歸。實際 menus/startup_loading、main_menu（--resolution 1600x900）、level_selection 與 headless tutorial/intro 通過。menus/scene_loading 有 2 項失敗，修改前提交版相同（第一關為教學時 start_allowed 為 false）。main_menu、scene_loading 含滑鼠輸入，需獨佔視窗焦點，與瀏覽器同跑會假失敗。tests/menus/web_loading_shell.cjs 已更新但未執行（本機無 Playwright）。

2026-11-07 教學改用新版卡牌：starting_01～03、升級牌與新商品改引用基礎版配置（直線、L型、旁直線路、直路），全部走 imported_tower_visual；移除教學專用 bridge.tres（tile_presets/bridge.tres 仍供其他用途）。迫擊砲 2×2 在此地形只有 turns 0／2 合法，指定為 (5,0,1)、turns 2 坐進轉角，文案改為不寫死角度。Godot 4.7.2 headless 與實際 tutorial/intro、headless level_flow、level_catalog、cards、card_names、tower_integration 通過。放第三張牌的 0.5 秒停頓來自道路流量筆觸：教學在此之前隱藏，road_flow shader 首次繪製編譯 5 個 program；RoadFlow 改在載入時以相機下次像素常駐物件編譯。

2026-11-06 Shader 收斂：依使用者要求將 3D 純色材質收斂為 SolidMaterials 的不透明／半透明兩組旗標（28 個場景／資源檔、151 個材質），移除 hologram 深度預通道及之前加的常駐圓環。Web tutorial 進關卡前 program 121→77（scene StandardMaterial3D 約 60→16），主選單前 84→61。放第一座塔原本是下一步舊 model hologram 首次繪製深度預通道材質，凍結 4.4–5.2 秒，現為約 0.4–0.6 秒的首次編譯；波次中 0 link、最長單幀 35ms。視覺差異：舊 model hologram 改為原色不透明，爆散碎片與落地圓環改無光照。headless mechanisms（114）、tower_restoration、tower_integration、combat_bursts、card_drag_placement、cards、tutorial/intro、level_flow、balance/rules 及實際 combat_bursts、tutorial/intro、tower_restoration 通過。cards/card_preview 在修改前的提交版 headless 即逾時，未查原因。未驗 Frontier 全程及其他 GPU／瀏覽器；瀏覽器 shader 快取對冷啟動的影響未隔離。

2026-11-06 迫擊砲落地卡頓：Web 每發落地約凍結 1 秒。攔截 WebGL 呼叫確認每次落地重新連結 5 個 program，burst 結束又全部刪除；原因是 mortar_impact 複製出全專案唯一的發光＋半透明材質，釋放後 shader 隨之刪除。RestoredBursts 改由掛在相機下的次像素常駐圓環持有該變體，於載入遮罩下編譯。同次另發現第一次擊殺編譯 death_burst 的 10 個 program，造成約 4 秒凍結；BurstEmitter 改在載入時預放一個次像素特效。Web release（Frontier 同佈局前兩波、窗格顯示中）修正後 63 秒內 linkProgram／deleteProgram 皆 0，載入期 link 26→41，最長單幀 62ms；headless mechanisms（114）、tower_restoration、combat_bursts、level_flow 及實際 combat_bursts 通過。窗格隱藏時 rAF 會節流，當時約 1 秒的尖峰不可當效能數據。未驗證其他 GPU／瀏覽器或完整 15 波。

2026-11-06 合併 origin/main：依使用者「merge with main」指令，將 origin/main `f72420b` 合併至 feat/ui_suggestions（原 HEAD `af3e9e5`）。保留教學、鏡頭左右鍵、1x／2x／3x、遺物圖示列與開波對話框，並納入 Phase 5 五 ACT／生命／勝敗、Tower Tile Editor、道路凹槽與 Art Slice D–F。Frontier 要求 tutorial 前置；tutorial.tres 設定 reward_final_act，維持第 3 波遺物選完才記通關。本節以下的舊 HEAD 與「未提交」敘述均為當時快照。

本次合併驗證：重建 `road_graph.candidates.*` 的 Windows／Web debug 與 release，重新匯入翻譯。Godot 4.7.2 headless level_catalog、level_flow、tutorial/intro、balance/rules（67）、road_refinement/rules（744）、camera_orbit 及 Compatibility 實際 tutorial/intro、camera_orbit、menus/level_selection 通過；輸出在 `.godot/merge-main-2026-11-06/`。未跑完整回歸、Frontier 全 15 波、真人遊玩或合併後的 Web 匯出／瀏覽器。

2026-11-05 鏡頭左右鍵對調（HEAD `6a58b02` 後）：左鍵由卡牌以外起拖平移，右鍵可由地面、卡牌或其他 UI 起拖繞中心旋轉；保留 4px 點擊／拖曳分流、左鍵卡牌拖放、單擊右鍵旋轉卡牌及原旋轉速度／平滑、暫停與設定 navigation lock。平移捕捉後可跨卡牌，左鍵直接按在卡牌（含停用牌／商品／牌背）則保留原操作。教學中英文、README、驗收提示及操作共識同步更新，取代下方歷史記錄的右鍵平移／左鍵旋轉。

本次 headless camera_orbit、pause_navigation、tutorial/intro 通過；Godot 4.7.2 Compatibility 實際 camera_orbit、pause_navigation、pause_menu、card_drag_placement、tutorial/intro 全通過，涵蓋角速度／完整畫圓、左右鍵點擊分流、跨商店平移、卡牌上右鍵旋轉、卡牌拖放不動鏡頭、暫停血條投影／設定阻擋及完整三波教學。翻譯匯入與 `git diff --check` 通過。證據在 `.godot/left-pan-right-orbit-2026-11-05/`；未跑完整回歸、Web 瀏覽器或長局平衡。

2026-11-05 教學改為首關與三波：此版取代下方五步教學初版的「買牌即通關／獨立可選」設計。tutorial 為 1 ACT、3 波（4／6／8 名步兵，獎勵 20／10／10）；Frontier 直接要求 tutorial，Bridge 直接要求 tutorial 與 frontier，依既有 DAG 排為 tutorial → frontier → bridge，舊的後續關卡完成紀錄也不能略過教學。首波後維持五步商店／升級引導，買到新塔只解除教學規則並轉為自由實戰，繼續第 2、3 波；第 3 波與普通最後 ACT 遺物獎勵完成才保存通關及解鎖。

初始牌改為 intro.tres 的 Starting Cards 引用三個獨立 starting_01～03.tres，可改 Tower／Tile Preset 及順序；文案讀實際塔名、升級 hologram 搜尋同種塔，升級牌不再限定第一個卡位。修改入口與資料限制見 assets/data/tutorial/README.md。Godot 4.7.2 headless tutorial/intro、level_catalog 及 Compatibility 實際 intro、main_menu 全通過，涵蓋三波、購買後仍未通關、自由放新塔、ACT 獎勵、第一關預選／後續解鎖及舊紀錄守衛、修改初始牌順序與升級目標、重玩重置；`git diff --check` 通過。證據在 `.godot/tutorial-three-waves-2026-11-05/`；教學測試仍以工具清敵，未驗長局平衡、完整回歸或 Web 瀏覽器。

2026-11-05 五步教學：在 `feat/ui_suggestions`、HEAD `7c1dfcf` 上新增可由選圖頁選擇的「第一條防線」（tutorial.tres），共用 level.tscn，地形與起終點保存在獨立 GridMap 場景。固定哨塔／迫擊砲／弩砲跨橋牌，前兩張依 hologram 在橫／縱道路以 0／90° 放置形成繞道，第三張自由合法放置。開波後四名步兵；清波與砲彈結束接保證哨塔購買／原塔升級，之後才允許付費刷新並保證交叉火力。最後購買才保存 tutorial ID，不走該教學的 ACT 遺物／擴張；Frontier 不新增前置條件。可選 TutorialDefinition／Director 與放置、商店 policy 預設不作用於一般關卡，原始 Frontier、兵種與塔平衡 Resource 未修改。

本次 Godot 4.7.2 Compatibility 實際 tutorial/intro 以相機、卡牌、R 旋轉、地圖／開波／購買／刷新點擊完成五步，含拒絕錯誤操作、金幣、暫停隱藏、重新進入重置與中英文 1280×800／800×600 代表畫面，通過；headless intro、card_shop、level_flow、level_catalog 及實際 menus/level_selection、main_menu 通過，`git diff --check` 通過。兩個既有測試的舊假設同步修正：level_flow 允許已明訂的快捷鍵／兵種名／遺物 tooltip，level_selection 完成最後 ACT 後先選遺物才檢查通關解鎖。證據在 `.godot/tutorial-2026-11-05/`；教學測試以工具清敵，不代表長局戰鬥／平衡、完整測試集合或 Web 瀏覽器已驗收。

2026-11-05 鏡頭平移改為右鍵拖曳：相機在 GUI 前捕捉右鍵，移動達共用 4px 門檻才平移；未達門檻於放開後遞送原點擊，保留單擊右鍵旋轉卡牌及試驗場工具。中鍵不再平移，右鍵可由卡牌起拖、跨商店持續、放開停止，離窗／失焦／設定鎖定清除捕捉。更新手牌與放置的右鍵組合保護。Godot 4.7.2 headless camera_orbit、camera_limits、pause_navigation 通過；Compatibility 實際 camera_orbit、pause_navigation、pause_menu、card_drag_placement 通過，包含右鍵點擊／拖曳分流、中鍵不平移、商店不誤觸、取消手勢、暫停投影及設定阻擋。camera_orbit 原本只搜尋正式單行地圖上的可放塔格而失敗，改用既有獨立 road_flow_fixture 並排除被 UI 遮住的測試落點，未修改正式地圖。`git diff --check` 通過，證據在 `.godot/right-pan-2026-11-05/`；未跑 Web 或完整回歸。

2026-11-05 遺物 Debug 重抽：三選一卡列下方新增中英文「重新隨機抽選（Debug）」按鈕，只在 debug 版本顯示；release 守衛同時保護方法。重抽沿用原 options 規則與遺物 RNG，不改持有、金幣或階段；未進選擇、暫停、提交後均拒絕，空候選保留原畫面。Godot 4.7.2 headless rewards 驗證候選合法／唯一、通用槽、持有與金幣不變、暫停／選定／耗盡守衛通過；Compatibility 實際 relics/input 點擊重抽、暫停及選取均通過，`git diff --check` 通過。證據在 `.godot/relic-reroll-2026-11-05/`，未跑 release 匯出、Web 或完整回歸。

2026-11-05 遺物文案：沿用使用者已改寫前十件的簡短效果提示，從 protagonist 至 reroll_discount 重寫其餘 11 件中英文說明，修正 protagonist 英文未完成文字；保留前十件文案及所有名稱、ID、效果參數。重新匯入 CSV 與兩語 `.translation`，Godot headless 驗證 CSV 欄位／key 唯一及全部 21 件中英文說明與匯入結果一致，`git diff --check` 通過；證據在 `.godot/relic-copy-2026-11-05/`。本次僅文字更新，未重跑畫面／戰鬥回歸。

2026-11-05 遺物選擇版面：將原 260×330px 選項縮為 184×272px 卡牌、間距 20px，圖示區 64px、名稱 18px、說明 14px，整組含 24px 標題對完整畫面置中。原本 Modal 的 80px 頂部留白改為獨立 Blocker 的點擊留白；Backdrop 覆蓋全畫面並忽略滑鼠，頂部暫停仍可操作。Godot 4.7.2 Compatibility 實際渲染檢查全部 21 件遺物、中英文、800×600／1280×800，卡牌尺寸、文字邊界、遮罩上下像素一致全部通過；relics/input 實際點擊頂部暫停及選取遺物通過，`git diff --check` 通過。記錄及截圖在 `.godot/relic-choice-2026-11-05/`；未跑 Web 或完整回歸。

2026-11-05 遺物圖示對應：在 `feat/ui_suggestions`、HEAD `7c1dfcf` 上，將 17 件專屬遺物 Resource 的 icon 改為 `assets/sprites/relics/<id>.png`，4 件通用維持 SVG；保留專屬的 alpha mask／塔色與既有機制參數。Godot 4.7.2 headless 匯入完成，逐項實際載入確認 21 件圖示路徑及非空圖片（17 PNG／4 SVG）通過，`git diff --check` 通過；記錄在 `.godot/relic-mapping-2026-11-05/`。本次未重跑畫面或戰鬥回歸。

2026-11-03 快捷鍵更新：遊戲速度改為 1x／2x／3x，Tab 與頂部倍速按鈕循環切換；Esc 優先於卡牌／商店取消操作，切換暫停／繼續。按住不重複觸發；暫停中的 Tab 保留選單導覽，設定頁維持 Tab 焦點／Esc 返回。headless level_hud、pause_navigation 與實際渲染的 level_hud、pause_menu、card_drag_placement 全部通過，涵蓋快捷鍵循環、重複按鍵、暫停鎖定、設定頁與拖牌時 Esc。記錄在 `.godot/shortcuts-2026-11-03/`；未跑 Web 瀏覽器或完整測試集合。

2026-11-03 持有遺物介面：移除左側本局遺物按鈕／收藏面板，改為獨立於手牌的固定螢幕橫列，28px 圖示由左至右依取得順序新增，hover 提供名稱及說明；Screen Margin 預設左距 16px、底距 216px，不跟隨卡牌移動／收合／動畫，暫停與三選一時隱藏。原先跟隨手牌向上堆疊的版本已依使用者修正取代。最終版本的實際 relics/input 驗證取得份數、左右順序、固定留白、移動手牌根節點及收牌後位置不變，通過；前一版另通過 rewards 與 synergy/input（67 項）。Godot 4.7.2 Compatibility、RTX 3050 Laptop；最終版證據在 `.godot/relic-row-2026-11-03/`，前一版在 `.godot/relic-icons-2026-11-03/`，未跑 Web 瀏覽器或完整測試集合。

2026-10-30 狀態顯示修正：相機平移／縮放後，MultiMesh buffer 的新位置沒有刷新 canvas 繪製命令快取的裁切範圍，狀態最初落在畫面外預留區時會持續漏畫。enemy_status_batch 的非空提交改為同步 queue_redraw，保持共用批次。新增四個畫面邊緣移回中央的實際像素回歸，修正前四案皆缺少全部狀態、修正後全數通過；既有 2,048,000 像素對照、圖集／容量／重用／樣式烘焙與 pause_navigation 暫停鏡頭回歸通過。Godot 4.7.2 Compatibility、RTX 3050 Laptop；本次證據位於 `.godot/status-2026-10-30/`，未執行 Web 瀏覽器或完整測試集合。

2026-10-29 UI 更新：每個入口在準備期常駐顯示置中開波文字與橫排兵種圖示，hover 單個圖示拓寬邊框並顯示該入口數量；標題開整波、圖示開敵軍情報，沿用流量篩選、配額與階段鎖定。塔名／等級提示改為 24px 白字黑框的螢幕 Label，不隨鏡頭縮放。Godot 4.7.2 Compatibility 實際渲染的 road_flow_preview、level_hud 與 synergy/input（67 項）通過；另通過 headless 流量回歸及中英文各 0／1／9 兵種版面檢查。12 兵種橫向捲動、入口分配、hover 不重建排程、開波／ACT／重開與暫停恢復均由流量回歸覆蓋。本次記錄在 `.godot/wave-icons-2026-10-29/`，未執行 Web 瀏覽器驗收或完整測試集合。

核對日期：2026-10-23（Asia/Taipei）。本文件是新工作階段的起點；玩法共識看 [AGENTS](../AGENTS.md)，細節看 [systems](systems.md)、[Phase 3](phase3.md)、[Phase 4](phase4.md)。測試結果只對下述版本及環境成立。

## 最新 Git 更新授權：2026-11-05

使用者在 Art Slice F 完成後要求「git更新 並 push到遠端」，本次提交累積的 Modeling Skill、Blender 建模來源／腳本／預覽、Godot 資產、Art Slice E 正式接入及 F 配色與測試文件。成果提交為0776f4b。開始核對 HEAD 為9b9a7f9，首次fetch時同步；推送前遠端新增兩筆提交至df4e224，因分岔被拒。使用者以「好」明確授權合併遠端後正常push；本次merge無衝突，遠端與原基準無檔案差異，合併後僅補記授權文件。目標仍為 origin/experiment/routing-sandbox。可重建 ZIP 及 Blender 自動備份加入忽略，保留本機檔案；未操作 main worktree、rebase／reset／clean 或強制推送。以下各階段「未commit／push」為當時快照。本次 Git 更新沿用剛完成的 F 測試，未重跑遊戲測試；提交前執行 staged diff --check。

## 最新配色：Art Slice F，2026-11-05

六塔保留暖灰白主體，在功能區加入低彩度塔種識別色。正式／預覽預設B；assets/data/rendering/tower_color_identity.tres的Variant可切A回到原色，F6 tests/combat/tower_color_identity.tscn以A/B及1/2/3切換六塔、192塔與最遠距離。管線只替換31個共享Mesh的COLOR，不改幾何／動畫／材質／玩法；GLB與A基準保留。完整交付與重建方式見 [Art Slice F](art_slice_f.md)。

本輪PASS：Godot4.7.2匯入、A與B各84配置／旋轉及實際事件動畫、既有tower_restoration／card_drag_placement、三組Compatibility GPU A/B截圖（塔外背景與UI差異0）、非COLOR資料／法線完全一致、深色機械不變、重建31個B hash不變／50個A與GLB基準檔不變。初輪headless Dummy音效退出殘留已定位，測試關閉該音效並清理場景；正式音效未改。未做本輪Web、完整十五波、真人辨識或新效能測試。保留前輪未提交工作，沒有commit／push。

## 最新接入：Art Slice E，2026-11-05

六塔已接入正式TowerDefinition.visual_model與TowerBodyVisual；來源GLB不重製，舊model保留fallback／音效。新wrapper／GLB純色衍生批次在assets/models/towers/integrated/，共31個網格實例，動畫與砲口獨立；新增imported_tower_visual負責事件、方向、間隔調速與閒置停止。正式／預覽共用外觀factory，預覽保留配色與格面紅綠提示。完整說明見 [Art Slice E](art_slice_e.md)。

本次PASS：84組配置／旋轉實際放置與預覽比對；CombatSystem射擊事件、兵營首次部署／重生、四向／雙舷獨立與同時播放、快速重觸發／缺失動畫；tower_restoration、towers、tower_obstacles(464路線)、cards、card_drag_placement、mechanisms(113項)、stacking、traffic/integration(104項)、construction/placement(34項)。正式Frontier六塔GPU截圖與192活動視覺短測完成（RTX4060 Laptop，平均5.46ms／幀，非通用效能保證）。

Web實際匯出失敗：缺少既有bin/road_graph.candidates.web.template_release.wasm32.nothreads.wasm，未執行瀏覽器測試；project.godot／export_presets已還原。未做真人操作、完整十五波或長時間測試。Lv2/3保留數值與標籤，使用本輪Lv1造型，沒有新增升級零件。沒有commit／push。

## 最新視覺資產：Art Slice D，2026-11-05

完成 [六塔統一配色與功能動畫](../tools/assets/blender/art_slice_d/model-spec.md)：沿用既有模型，兵營只新增雙門；六塔共10個獨立一次性動畫，來源、Python、GLB、APNG與關鍵影格保存在工具側。新遊戲資產準備在 `assets/models/towers/art_slice_d/`，包含GLB／.import、僅限本批的EditorScenePostImport、共用solid_color烘焙網格及獨立`*_visual.tscn`，尚未被TowerDefinition使用，沒有改寫戰鬥或放置。

11-04 Godot4.7.2原始GLB與烘焙後場景均通過10片段播放、末幀復位、尺寸／朝向／砲口／獨立方向與Airship移動層級檢查；Compatibility GPU產生實際近景／18.5尺度圖。11-05續做兩次建置數量與規格一致、原六塔來源SHA不變，雙門73幀與入口／彼此無表面交叉。APNG為12fps真實渲染取樣。未做正式TowerBodyVisual掛載、事件時序、Lv2/3、hologram、Web或效能驗收；巨弓約3秒片段不能直接改寫既有1.4秒攻擊間隔。完整NodePath與待接入清單見成果文件。

## 最新美術建模：五塔家族，2026-11-04

完成 [tower_family](../tools/assets/blender/tower_family/model-spec.md)：哨塔、兵營、迫擊砲、十字火力、飛行艇，各自獨立 .blend／Python入口／GLB／兩視角與遊戲尺度圖；另有既有巨弓C＋五塔四向比較與最遠縮放。風格沿用暖灰白＋功能深色，量體依1×1／2×2／1×2區分。無攻擊動畫，無Godot接入或遊戲系統修改。

本次驗證：五塔footprint越界0、非流形邊0、退化／同mesh重複三角形0；GLB無動畫／貼圖／外部依賴，重新匯入AABB最大誤差小於1.2e-7。重跑後幾何與 owned 數量相同，巨弓來源hash不變。Blender 5.2.3寫含集合實例的scene library曾崩潰（MCP WinError10054），改隔離背景程序保存正常工作檔並完成渲染。迫擊砲不同preset角落錨點須後續依規格平移外觀，未做自動掛載；未跑Godot／Web／效能驗證。可編輯網格尚未做正式靜態合批。

## 最新美術驗證：Great Ballista C 上色與攻擊，2026-11-04

使用者指定以C / Detailed繼續第二輪，仍僅Blender視覺驗證。成果位於 [great_ballista_round2](../tools/assets/blender/great_ballista_round2/model-spec.md)：保留46 mesh／1352三角形與L形占格，暖灰白＋少量功能深色，增加純pivot／物件關鍵影格的3秒攻擊循環。交付兩個靜態視角、白模配色對照、近景與1280×800／18.5實際尺度APNG、六格姿態及可重跑腳本／.blend。

Current PASS：MCP建置／姿態檢視、重跑數量一致且原物件變換與第一輪來源保留、72幀非飛行構件footprint越界0／非流形0／非正行列式0／首尾矩陣差0、PNG真渲染、兩份APNG各36幀的CRC／時序／patch邊界及六取樣幀無損重建。箭補回為預覽用的可見性切換，無上膛人物／音效／新特效。未修改戰鬥、正式資料或地形；未建立本輪GLB、未跑Godot／Web／效能／正式整合。詳細限制與重跑命令見成果文件。

## 最新美術探索：Great Ballista A/B/C，2026-11-04

使用者授權第一輪 Blender Art Slice，明確不接入 Godot／不改遊戲邏輯／不做攻擊動畫。來源、三版獨立 .blend／GLB、統一正交預覽及完整比較說明位於 [great_ballista_slice](../tools/assets/blender/great_ballista_slice/model-spec.md)。沿用右後裝填格的 L 形 `(0,0),(0,1),(1,1)`，錨點0、Godot −Z正面；兩格主武器＋一格箭架，暖灰白主色。A/B/C為276／548／1352三角形，共同比例、材質及鏡頭。

Current PASS：MCP程序建模與camera檢視、三版獨立圖／並排圖／四方位比較／初始與最遠遊戲距離PNG、重跑數量一致、逐mesh非流形／footprint越界／負行列式均0、GLB僅目標節點與兩材質且無貼圖／相機／動畫、四份 .blend 重新開啟及主檔渲染。保留原 Blender Cube／Camera／Light；輸出檔不帶入。父目錄 tools/assets/blender/.gdignore 隔離原始檔與Art Slice GLB。未修改任何正式遊戲邏輯、資料或資產；未跑Godot／Web／效能／正式接入驗收。視覺建議以B作後續基準，C近景改善在遊戲遠景收益有限，待使用者比較。

## 最新文件工作：3D Modeling Skill，2026-11-03

起始核對分支 `experiment/routing-sandbox`、HEAD `9b9a7f9`、工作樹乾淨。新增 [.agents/skills/bwar-modeling](../.agents/skills/bwar-modeling/SKILL.md)，包含美術原則／檢查清單、專案場景契約及 Blender MCP→GLB→Godot 流程；同步 AGENTS 與架構索引。來源文件規定 `.blend`／Python 留在工具側，GLB 入 assets；標明多格 TowerBodyVisual 不會因只換 TowerDefinition.model 而全面套用，以及共用 shader 所需自訂通道。

本次僅文件與 Skill；未修改 Blender 場景、未製作模型、未修改遊戲邏輯／資料或既有資產，未執行遊戲／Web 測試與 GLB 接入驗收。Current PASS：基本 frontmatter／命名／必要欄位／未完成標記檢查、三份 Skill 文件相對連結與三處入口連結、git diff --check。內建 quick_validate.py 因本機 Python 缺少 PyYAML 無法完成；以不安裝套件的基本結構檢查補充，未宣稱完整 YAML 驗證。下方遊戲 PASS 均為先前工作結果。

## 本次 Git 更新授權：2026-11-03

使用者於道路、橋頭、寬路流線及雙向路肩接觸暗部完成後再次要求「git更新並push到遠端」，授權提交目前全部相依修改並正常推送 origin/experiment/routing-sandbox。已 fetch 核對遠端；保留本輪實作與驗證，提交前核對 diff --check。下方各階段「未提交／不 push」是此次授權前的歷史狀態，不再限制本次提交與推送。未操作 main worktree，未執行 merge／rebase／reset／clean 或強制推送。

最新路肩補強：路面內側加入0.06格寬、0.46強度的漸淡接觸暗部，受光側也能讀出凹槽。雙向固定光源渲染163項通過，兩側根部亮度約為鄰近路面的0.76；補強後 depth_flow 真渲染5128項亦重跑通過。原始結果在 `.godot/test-results/bank_contact/`／`road_depth_flow/`，忽略的測試產物不納入提交。

## 最新工作：道路凹槽、橋頭與寬路流線，2026-11-03

起始仍為 `experiment/routing-sandbox`／HEAD `4b0d2fe`，沿用上一輪全部未提交成果；本輪不 commit／merge／rebase／reset／clean／push，不操作 main worktree。僅新增道路高度／接合及流量視覺修改；塔模型、戰鬥、商店、敵軍與原生選路未再更動。

RoadSurface 同一網格以路面0／路肩0.065／斜面寬0.045形成凹槽，塔／石地基礎仍為0。木橋不再當作完整實心相鄰地面；開放橋保留橋台與同網格接合面，側邊已有地面則用連續石路；索引及向上面向亦經覆蓋驗證。新增 WideRoadFlow 以全雙向道路臂／共用交會區投影完整配額行程，窄轉寬共用真實入口，反向時鐘各自保存，內部換道保留原時間為停留；建造預覽多傳候選快照，未改排程或RNG。

Current PASS：新 depth_flow rendered5128／headless5111（4650覆蓋、17像素、120名真正三兵種配額，五組0備援）；原流量連續性含78像素／56線寬、流量預覽含Hover／配額／RNG；放置744、Construction placement34／regression54／rendered input32、裁切input13、編輯器rendered input48、地塊動畫／變種；PortalGraph／native_candidates286／route_batch／多入口／dead_end_edits／traffic104／synergy routing357；Frontier180幀渲染啟動。C++本輪未改，未再build。下方1722／458等是前輪結果，沒有在本輪重跑。

人工 F6 `tests/road_refinement/depth_flow.tscn`，1–9／0選案例、R改格子旋轉、Space短筆觸動畫；26張截圖與JSON在 `.godot/test-results/road_depth_flow/`，logs `.godot/road-depth-*.log`。細節、根因、檔案及當次證據見 [道路修正](road_visual_and_placement_refinement.md)。所驗配置未見缺面／格線／額外支線，極端不規則交會仍有安全保留原位置的備援；Web／release遊玩／效能／15波／真人未測，等待人工驗收。

## 前輪工作：道路視覺與建造裁切，2026-11-03

起始核對 `experiment/routing-sandbox`／HEAD `4b0d2fed64731ad5bb5c9452d66a0f4b10022441`，工作區乾淨。本輪依新任務不 commit／merge／rebase／reset／clean／push、不改 main worktree；下方 Git 授權是上一輪已完成的操作。

已完成道路遇既有塔全 footprint 裁切、預覽／提交同源、雙向接口寬路聯集、塔旁終止邊界、移除塔下重複基板，以及原生 block-cut 完整合法路線灰化。沒有改20＋1資源、戰鬥數值、經濟／商店／遺物或波次。主要檔案、設計與限制見 [road_visual_and_placement_refinement](road_visual_and_placement_refinement.md)。

Current PASS：新增規則744、rendered裁切input13；20＋1 rules1722／combat104／rendered input118；編輯器rules458／rendered input48／組合29；Construction placement34／regression54／geometry51／rendered input32；cards／tile_presets／rendered拖牌；combat／tower_restoration／stacking；traffic104、synergy routing357、RoadPortalGraph／native_candidates286／route_batch／多入口／dead_end_edits／road_flow_preview；tile_animation／tile_variants。Windows native debug／release重建，C++ edit_guard3584編輯oracle通過。Frontier正式level180幀渲染啟動通過。原始資料在 `.godot/road-refinement-*.log` 及 `.godot/test-results/`，初輪失敗／短timeout保留，最終結果見詳細文件。

人工入口：F6 `tests/road_refinement/gallery.tscn`，A全覽、1–9／0聚焦；實際放牌用原 `tests/tower_tile_editor/playground.tscn`，文件附原基礎版迫擊砲L型＋哨塔直線的重現座標。新增14張真實道路／點牌／拖牌／提交截圖在 `.godot/test-results/road_refinement/`；六塔12張等級圖亦已重產。已由agent檢視，未宣稱人類美術驗收。

NOT RUN：Web native／匯出／瀏覽器、Windows release遊玩、效能、Frontier全15波及真人。舊wasm無route_cells時保留中性色並警告，Web上線前需重建；沒有修改Windows防護。選圖頁無腳本預覽與手工主選單橋景仍使用原素材。完成後等待人工驗收。

## Git 更新授權：2026-11-03

使用者在塔體／射程／預覽工作完成後要求「git更新並push到遠端」，授權將目前相依的施工原型、Tower Tile Editor、使用者保存的地塊／Frontier 配置及20＋1更新一併提交，推送至 origin/experiment/routing-sandbox。已 fetch 核對遠端，更新前本地領先14個提交、落後0個；不改 main worktree，不做 merge／rebase／reset／clean 或強制推送。下方「未提交／不 push」敘述是本次授權前的歷史快照。程式未再修改，沿用本輪已完成的驗證，提交前另核對 git diff --check；測試原始輸出仍留在忽略的 .godot/。

## 最新工作：20＋1 塔體／射程／預覽，2026-11-03

核對 `experiment/routing-sandbox`／HEAD `e87f8288cb97b85d71c4b38dcb7dc7a67754bb63`，在既有未提交成果上繼續；沒有 commit／merge／rebase／reset／clean／push，未操作 main worktree。下方整合與 stash 紀錄是先前工作，本節才是本輪測試。

已把保存的「基礎版」二十份配置與既有兵營接入正式抽牌，組合標記 variant_group=base；資源／名稱／權重仍同源。新增 footprint 幾何與低面數完整組件模型，Lv1–3 外觀及哨塔 Lv3 視覺封頂；迫擊砲／交叉火力的整體中心、弩砲主軸、側舷雙側各2×3與巡航／右舷同步。放置預覽區分塔體、道路與連續範圍，不畫道路接口與射程內部格線。傷害／攻速／價格／成長保持原數值。主要入口與完整映射見 [tower_visuals_and_preview](tower_visuals_and_preview.md)。

本輪 Current PASS：新 tower_visuals/rules 1722、combat 104、真渲染 input 118（全部21份 selector／補牌／旋轉／放置、六塔疊級、開波）；原 tower_tile_editor rules 458、rendered input 48（兩波）、combinations_input 29、card_drag_placement；headless cards／tile_presets、combat／tower_restoration、relics stacking／mechanisms 113／rewards、construction geometry 51／regression 54、traffic integration 104、balance rules 67。Frontier 正式 level 180幀渲染啟動通過；Gallery 六塔12張等級／範圍圖與六塔實際預覽已產生並檢視。數字為各 suite 自己的斷言數，不混稱遊玩場次。

輸出在 `.godot/test-results/tower_visuals/` 及 `.godot/tower-visual-*.log`。初輪的舊單格／方塊／候選身份斷言與新兵營輸入 fixture 的單通道不足均已修正重跑；失敗 log 保留，不算最終 PASS。最後 editor import 無腳本／資源解析錯誤，但有 Godot 使用者設定路徑無寫入權限；rendered 另有 user:// shader cache 目錄警告。未解除或修改 Windows 防護，未宣稱完整 Editor 互動驗收。

人工入口：`tests/tower_tile_editor/playground.tscn` 選「基礎版」；`tests/tower_visuals/gallery.tscn` 用1–6／R／A看塔種、四向與射程。兵營需先有可繞行道路。造型採共用程式組件／快取，極端自訂 footprint 仍需美術驗收；兵營原模型保留。未跑 Web、release、效能、真人或Frontier全十五波，未改／重建 C++。本輪完成後停止，等待人工驗收。

## 先前整合：2026-11-03

本次由 experiment/routing-sandbox `4440da4` 合併 origin/main `d36a866`，保留五 ACT／十五波、生命、勝敗、經濟與 Boss，整合 Boot／選單、選圖／解鎖、通關 ID、逐 ACT 擴張、預熱與原生候選優化。勝利才記通關，重新開始保留所選 Level。下列量測均為歷史證據；本次驗證與 stash 恢復結果另見 `.godot/merge-2026-11-03/`。使用者授權本次 Merge Commit；stash 恢復的本地修改保持未提交、原 stash 保留，不 push。

本次合併樹驗證：Godot 4.7.2 headless editor import 無腳本／資源錯誤；Windows debug／release 原生擴充建置通過。headless 通過 balance/rules（含勝利保存與敗北不保存）、level_catalog、level_flow、act_spawn_expansion、terrain_endpoints、relics/rewards、traffic/integration、synergy/routing、native_candidates、route_batch。rendered 通過 level_selection（含結果畫面重開）、startup_loading、scene_loading 及 main_menu；main_menu 需以 --resolution 1600x900 啟動以涵蓋最大測試 viewport，預設較小視窗的初輪滑鼠輸入失敗仍保留。scene_loading 的 Invalid data／Unavailable 為預期失敗恢復案例。未執行 Web 建置／瀏覽器、完整長局或效能重測；stash 恢復後的驗證另記，不混同本次 Merge Commit 的成果。

## stash 恢復與本次驗證：2026-11-03

Merge Commit 為 `e87f8288cb97b85d71c4b38dcb7dc7a67754bb63`（父提交 `4440da4`、`d36a866`）。其後使用 `git stash apply` 恢復 `60a92248d2e091dfede9ffefdaf3ee6e6ba28826`，保留原 stash；恢復的 tracked／untracked 修改均不另行提交。Frontier 保留 stash 的編成與資源改動（目前首波僅 Quickfeet），並遷移至 ID／逐 ACT 擴張設定。施工開波先原子確認草稿，保留載入鎖定與失敗恢復商店。獨立施工／塔牌編輯器的舊座標欄位已遷移為同位置的地形端點，不更改路網或波次。

恢復後 Current PASS：headless editor import；cards、tile_presets；construction shapes／placement／regression／geometry；tower_tile_editor rules（458）；balance/rules；level_flow；traffic/integration；rendered construction input（32）、tower_tile_editor input（48）與 combinations_input（29）。翻譯 142 列的兩種語言逐項與 CSV 相符；Frontier 15 波、穩定 ID、關閉入口擴張及自建 catalog 的資源引用驗證通過。日誌／JSON 位於 `.godot/merge-2026-11-03/`。套用前額外產生的 tower_tiles 備份位於該目錄的 `pre-stash-tower-tiles/`；其兩份新增配置亦保留於原目錄，沒有刪除使用者資源。Web、真人、效能與完整十五波實戰未重測。

## 已恢復的本地工作（以下為歷史驗證）

## 最新修改：測試組合與高塔身，2026-10-26

在現有未提交成果與使用者已編輯的 Frontier／塔資源／自建配置上增加：內建排除／清單隱藏、可命名的跨塔種配置組合、套用／切換後重開獨立測試，以及一格高的額外塔身與一致預覽。組合約束實際商店、補牌與 TowerMap 放置／升級，空池不回退；資料保存在既有 catalog 原生資源，舊索引可直接讀取。未改寫使用者資料、未 commit／merge／push，未改 C++ 或 Windows 安全設定。

本次新 `combinations_input.tscn` 真渲染 29 項 PASS，原編輯器 input 48／rules 458、Construction regression 54、cards／tile_presets 重跑 PASS。GPU 畫面已檢視，修正初輪對話框自動換行導致過高的版面；最終操作按鈕都在畫面內。保留已知 shader cache 權限訊息，無最終腳本錯誤。詳細使用與測試檔見 [tower_tile_editor.md](tower_tile_editor.md)。真人、Web、release 與完整長局未重測。下節為初版歷史驗證，不當作本次全數重跑。

## 初版工作：Tower Tile Editor，2026-10-25

核對分支 `experiment/routing-sandbox`、HEAD `4440da42402df2343d586265c55a3050e08c7c2d`。在上次 Construction Prototype 的全部未提交成果上繼續，未 commit／merge／push／reset／clean，未改正式／舊 worktree、六塔數值或 C++ DLL。

已交付獨立 `tests/tower_tile_editor/editor.tscn`／`playground.tscn`：可自由畫每份配置自己的連通多格塔體、道路、手動接口、原點／錨點與方向；具存取、複製、改名、權重、預設、安全封存及立即補牌。共用 TowerMap 真正阻擋全體格子，仍只建立一座塔，任何占格可升級；自訂兵營駐點經完整路網檢查。既有牌與塔保存幾何快照。獨立測試維持單卡立即提交、60 Gold／免費補牌／無敗北，沿用正式商店及混兵戰鬥；不安裝批次或幾何加成。

新責任位於 `scripts/tower_tile_editor/`，原生使用者資源首次儲存才建立於 `assets/data/tower_tiles/user/`。詳細欄位、存取／封存、A–E 人工情境及操作見 [tower_tile_editor.md](tower_tile_editor.md)。Preview 的隔離排程只在候選改變時計算，不寫歷史或消耗 RNG。編輯模式凍結世界並停用關卡輸入，修正鏡頭攔截畫筆拖曳。

本次規則 **458 項 PASS**，實際 Compatibility／RTX 4060 Laptop 渲染與滑鼠鍵盤 **48 項 PASS**，包含連續兩波、重開、原點／錨點、手動接口、取消捨棄、真實拖放及十字五格單塔。相關舊牌／建造／疊塔／交通／硬性選路／Phase 5 規則、波次／卸載、combat、真渲染拖牌／暫停回歸亦通過；Frontier 完成 120 幀渲染啟動 smoke，不代表全長局。原始輸出在 `.godot/test-results/tower_tile_editor/`，詳見工具文件。初輪實際輸入暴露的畫筆／鏡頭衝突已修正並重跑；初輪測試腳本的下拉索引、排程等待及 CombatSystem 取址錯誤已修正，不將帶 SCRIPT ERROR 的執行列為 PASS。

Godot Editor 的 SAC `~road_graph…dll` 封鎖未修改也未宣稱解除；這次使用直接 runtime 入口，可依工具文件的 PowerShell 命令啟動。渲染另記錄 `user://` shader cache 目錄權限訊息，但畫面、截圖與測試完成。未進行真人、Web、release、效能或正式十五波驗收；目前等待人工接受。下節是上一個 Construction Prototype 的歷史交接。

## 前次工作：Construction Prototype，2026-10-25

本次實際分支 `experiment/routing-sandbox`、HEAD `4440da42402df2343d586265c55a3050e08c7c2d`（Phase 5 已提交）。Oct 24 開始乾淨，Oct 25 從用量中斷留下的修改續作；新增建造原型全部保留未提交，沒有 commit／merge／push／reset／clean。正式／舊 worktree 未修改。以下 Oct 24 merge 補註是歷史，不能用其 HEAD 或未提交數量判定目前狀態。

已完成五複合形狀、明確接口及塔偏移、批次預擺／移動／旋轉／排序／撤銷／原子確認、唯讀下一波預測、兩種可撤回幾何獎勵及 A／B／C 可玩 Playground。開 [tests/construction/playground.tscn](../tests/construction/playground.tscn) 按 F6；F5 仍為 Frontier。正式塔／兵種／Frontier 資源未修改，C++ 未改也未重建。

當次證據和限制以 [construction_prototype.md](construction_prototype.md) 為準，原始 JSON／log／GPU 截圖在 `.godot/test-results/construction/`。五形狀、放置、批次／排程、幾何、真輸入與九組對照通過；相關舊牌、疊塔、交通、硬性選路、Phase 5 規則、波次、拖牌、暫停、流量預覽與 Frontier 啟動回歸亦通過。先前 Phase 5 全長局／Web／效能的歷史數字不算本次執行。Editor import 有環境權限／系統封鎖訊息，翻譯已匯入並由遊戲畫面驗證，未宣稱 Editor 互動驗收。

目前停在人工接受前；真人、Web、release、效能與正式十五波未重測。四 U 明顯擴張路網但仍讓同塔覆蓋多分支；兩 L 反向逐次放置亦能成功，不能把批次描述成唯一可達終局。下一步由使用者玩兩波比較操作負擔與輪廓，再決定是否進入正式規則；不要自行整合 main。

使用者後續回報 Editor 的 `~road_graph...dll`／`0xc0e90002` 對話框。已確認為 Application Control policy block（4551），本機 SAC 啟用、DLL 未簽章；直接 runtime 重跑 54 項 construction regression 通過，但 Editor 問題尚未解除。診斷及直接執行入口見 [native/README](../native/README.md#windows-編輯器載入封鎖2026-10-25)。未關閉防護、未重建／替換 DLL，不能宣稱 F6 已驗收。

## 歷史同步補註：2026-10-24

已完成 `origin/main`（`a5422c8`）→ `experiment/routing-sandbox` 的本地正常 merge，新 HEAD 為 `3fbad09d78085c9d646174cc9f4177fa46eba333`；原 Sandbox HEAD 為 `c33d425`，共同祖先為 `2fe5adc`。未 push，未移動本地 main 或修改正式 worktree。完整差異、衝突、修復與本次證據見 [Git 整合報告](../reports/git_integration_2026-10-24.md)。

### main 的歷史同步紀錄（2026-10-26）

2026-10-26 整合註記：本次依使用者指令，從 main `eb618c6` 合併 experiment/optimize_graph `cd6da3b`，工作目錄為 `D:\Windows\Desktop\begins-with-a-road`。以下分支、路徑、F5 入口及測試為 2026-10-23 歷史快照，不代表目前狀態。正式入口已改為 Boot → 主選單 → 選圖／本局設定 → Level；保留 Phase 2–4、C++ 候選／批次配額、GPU 模型與設定／解鎖流程。新增整合回歸核對交通倍率與硬性選路的批次／單筆一致性、群體狀態獨立及飛行高度；本次測試記錄位於 `.godot/merge-checks-2026-10-26/`，不沿用以下歷史結果。

本次整合驗證（2026-10-26）：Godot 4.7.2、Compatibility、RTX 3050 Laptop；29 項 runtime 回歸＋1 項真實波次編輯器檢查通過，涵蓋路線／批次配額／去環、九兵種、交通、六塔、遺物、ACT／卸載、選單／設定及實際載入預熱。Windows 與單執行緒 Web 的 debug／release 擴充建置成功；未跑現版 Web 瀏覽器、完整長局與效能對照。scene_loading 以故意失敗的目標驗證恢復流程，預期產生 Invalid data／Unavailable 診斷，無非預期引擎或腳本錯誤。詳細結果見上述目錄的 summary.json 及各項 log。

2026-10-26 UI 分支整合：依使用者指令，將 main `d36a866` 合併至 feat/ui_suggestions（原 HEAD `8155007`）。保留該分支的塔圖示、時間線場景、28px／零列間距與面板標題定位；情報清單的 anchors／offsets 集中在宿主場景，避免繼承重複。被刪除但仍受既有測試場景引用的 road_flow_preview 腳本及原 UID 採 main 版本，保留空 hover 回歸。先前 reset 留下的 129 份未追蹤檔案均與 main 完全相同，已備份至忽略的 `.godot/merge-ui-2026-10-26/untracked-backup/`。

UI 分支本次驗證：8 種中英文版面、批次路線、關卡流程、實際道路預測、67 項敵軍情報輸入、HUD 與主選單檢查通過。ui_scene_templates 有兩個時間線圓點像素斷言失敗；在獨立 main `d36a866` 副本重現相同兩項失敗，確認為既有問題，本次不改動時間線邏輯。原始 log 與 main 對照保存在 `.godot/merge-ui-2026-10-26/`。前述 29＋1 全通過記錄屬 main 合併時選定的測試集合，不代表本次這個額外像素測試通過。

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
| 波次與正式數值 | `assets/data/levels/frontier.tres`、`assets/data/towers/`、`assets/data/troops/ravager.tres` |
| 生命／勝敗／四次獎勵 | `scripts/levels/level_session.gd`、`scripts/levels/definitions/level_definition.gd` |
| 結果、生命及 Boss UI | `scenes/levels/run_status.tscn`、`scripts/levels/presentation/run_status.gd` |
| Boss 能力快照／多目標 | `scripts/enemies/troops/troop.gd`、`scripts/combat/enemy_abilities.gd` |
| 出兵與終止／RNG | `scripts/enemies/spawning/{enemy_wave,wave_spawn_schedule}.gd` |
| 開場商店／帳本事件 | `scripts/cards/shop/card_shop.gd`；原卡面價格快照與交易權威保留 |
| 可選事件記錄 | `scripts/combat/balance_trace.gd`；各正式系統僅在啟用時發事件 |
| 實際戰鬥實驗 | `tests/balance/{laboratory,full_run,counterfactual,rules,defeat_input}.tscn` |
| 策略／預留地圖 | `tests/balance/{policy,holdout}.gd`；保留七策略與原先凍結的地圖 |
| 獨立分析／重現 | `tools/balance/{analyze,report,replay_audit,verification}.py`、JSON manifests、PowerShell runners |
| 模型離線生成 | `tools/assets/build_ravager.gd`，已烘焙模型不需重新生成即可執行 |

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

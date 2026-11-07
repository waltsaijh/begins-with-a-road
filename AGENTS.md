# Agent 工作共識

- 2026-11-08 最新 Git 授權：使用者要求「git更新並push到遠端」，授權提交本輪完整塔體中心旋轉、異種塔重疊預覽／升級過濾、相關測試與文件，並正常推送 origin/experiment/routing-sandbox，包含先前本機音訊提交 6163ba8。開始 HEAD 6163ba8；fetch 後本分支領先追蹤分支 1 筆、沒有落後。origin/main 有更新但本次不合併。下方未 commit／push 為本次授權前快照；不操作其他 worktree、不 merge／rebase／reset／clean、不強制推送、不動 stash。

- 2026-11-08 異種塔重疊：只有所持卡牌的 TowerDefinition 與既有塔相同，才採用升級預覽／升級命中補償／權威升級。不同塔種繼續顯示所持塔牌的模型、地塊與射程，使用一般重疊驗證並標紅；放置失敗保留卡片、原塔等級與地圖。同種塔即使已滿級，仍沿用既有升級錯誤顯示。本輪與前項旋轉修改一併維持未 commit／push。

- 2026-11-08 放置旋轉：正式選牌／拖牌的 R 與單擊右鍵，改繞完整塔體占格包圍框中心轉向，道路跟隨同組補償；迫擊砲／交叉火力等 2×2 正方塔四方向維持同一組占格。以選牌起始朝向作絕對基準，不逐次累加位移；長寬奇偶不同的矩形在半格差異時取最近整格，轉滿一圈回原位。BuildCard 的資料座標、place_selected 等原點 API 及教學 hologram 仍使用配方原點，由 CardPlacement.pick_card_cell 統一把游標轉成補償後的原點供預覽／點放／拖放；升級優先命中游標下的同種既有塔。單格塔與交通設施行為保留，獨立批次試驗場的既有預擺項目旋轉未改。本輪未 commit／push。

- 2026-11-07 最新 Git 授權：使用者要求「git更新」，授權提交本輪 OGG BGM／號角與淡化、三類音量設定、點擊／hover／放置音效、非法放置紅格回饋、哨塔合成射擊音效，以及相關測試、重建工具與文件；本次不 push。開始 branch 為 experiment/routing-sandbox、HEAD e5088df，現有差異均為本次聊天累積成果。下列音訊階段的未 commit／push 為本次授權前快照；不操作其他 worktree、不 merge／rebase／reset／clean、不動 stash。

- 2026-11-07 哨塔攻擊音效：assets/audio/towers/sentry_shot.wav 為本專案程序合成的 0.22 秒弓弦彈放／箭矢破風聲，來源工具 tools/assets/build_sentry_shot.gd；integrated/sentry.tscn 指定匯出 shot_sound，沿用真實 fire_event 與 Combat 六聲道射擊池，不在預覽播放、不改攻擊數值。實際 tower_integration 84 次配置／旋轉與開火音效接線驗證通過；未 commit／push。

- 2026-11-07 音訊：使用本專案 assets/audio/music/ 內的平時／戰鬥 OGG 與開波號角 WAV（BGM 使用 Downloads 指定新版，號角來自先前指定原型路徑；各為本專案副本，不建立執行依賴）。GameAudio Autoload 跨場景播放平時 BGM，正式關卡開波等待開始時淡出平時音樂、播一次號角後淡入戰鬥 BGM；波次及在途攻擊收尾後、勝敗、重玩或離場淡回平時，不播結束號角。全部 BGM 的播放基礎增益為 50%，滑桿預設維持 50%，號角基礎增益 50%；一般開始／切換 1.5 實際秒淡化，戰鬥結束／離場回平時延長至 4 秒，皆用 smoothstep 平滑包絡，循環尾端提前 2 秒交叉接回開頭；不受倍速或暫停影響。共用音效設定保留靜音，增加整體／BGM／戰鬥音效 0–100% 滑桿，號角、射擊與放置音效走 Combat bus，所有 BaseButton 的 pressed 播 click（走 Master）；placement／wrong_placement 分別在權威放置成功／拒絕時播放，非法放置讓原紅色格面短亮並於 0.4 實際秒復原，不改導航或消耗卡牌。新音效副本位於 assets/audio/ui/ 與 assets/audio/placement/；按鈕 hover.mp3／卡片 card_hover.mp3 走 Master，基礎增益皆為 click 的 25%，單聲道避免疊音；手牌與展開商店使用穩定的 hover index 變更觸發，遺物卡採卡片聲，停留同卡及停用項目不重播；設定跨場景保留，本次執行結束不保存。本輪不 commit／push。

- 2026-11-07 本次授權：完成 origin/main → experiment/routing-sandbox 的既有 Merge、驗證與 Merge Commit；不 push。已比對目前 index／工作目錄與原始合併樹完全一致，沒有本次未提交修改或新 stash；保留兩份歷史 stash，不重複套用。
- 本次介面整合沿用 Sandbox 的集中頂列、聚合遺物數量／點擊詳情、緊湊時間線、出生通知與持久圖鑑；加入 main 教學、三類進度頁、開波對話框、Tab／Esc、左右鍵鏡頭與新版素材。進度頁的敵人沿用遭遇解鎖，舊六種敵人 ID 載入時映射新 ID。倍速保留 Sandbox 1／2／4，Tab 與點擊使用相同循環。獨立 relic_inventory 場景保留供工具使用，正式關卡使用頂列，不重複顯示兩列。

- 2026-11-06 最新 Git 授權：使用者要求「git更新並push到雲端」，授權提交本輪 UI Slice A、頂列／時間線及集中置中修正、資源、相關測試與文件，並正常推送 origin/experiment/routing-sandbox。開始 HEAD 為3f692fe，fetch後本分支與追蹤分支同步；未合併 origin/main 的其他更新。下方 UI 階段的未 commit／push 為此次授權前的歷史；不操作 main worktree，不自行 merge／rebase／reset／clean 或強制推送。
- 2026-11-05 前次 Git 授權：使用者在 Art Slice F 完成後要求「git更新 並 push到遠端」，授權提交目前累積的 Modeling Skill、建模來源、Art Slice D／E／F 資產與整合、測試及文件，並正常推送 origin/experiment/routing-sandbox；首次推送遇遠端新增兩筆提交而分岔，使用者再以「好」明確授權本次合併遠端分支後正常 push。此為本次 merge 的例外授權；各實作階段的不 commit／push 註記為此次授權前的歷史。可重建 ZIP 與 Blender 自動備份留本機並忽略。仍不改 main worktree、不擅自進行其他 merge／rebase／reset／clean 或強制推送。

本文件供接手本專案的 agents 閱讀，彙整截至目前已記錄的遊戲設計、實作決策與工作約定。新討論產生或修改共識時，更新對應段落；被取代的決策應明確修正，避免同時保留互相矛盾的規則。這不是逐字聊天紀錄，也不把尚未確認的想法寫成既定需求。

## 文件分工與判讀

- `AGENTS.md`：供 agents 使用，集中保存目前為止的討論結果、設計限制、工作方式與必要背景。
- [README.md](README.md)：供人類閱讀，說明核心遊戲體驗、目標、目前進度及基本操作。
- [docs/architectures.md](docs/architectures.md)：說明專案結構與系統責任，維持目錄／模組層級，不列逐檔清單。
- [docs/systems.md](docs/systems.md)：上述共識的詳細補充，保存演算法、UI 行為、參數語意及驗證入口。修改相關系統前一併閱讀對應章節。
- [docs/HANDOFF.md](docs/HANDOFF.md)：階段交接入口，保存核對日期／HEAD、完成範圍、重要檔案、已知限制及本次／歷史／未執行的測試。新工作階段先核對實際 Git 狀態，不把快照當永久現況。
- `reports/` 是歷史證據，不是目前設定或本次測試結果。遊戲數值以目前 Resource、場景覆寫及程式為準，不從舊報告恢復平衡值。
- 區分正式關卡與獨立試驗場景。舊試驗場景的自動生怪、右鍵單塔工具或起點切換，不代表正式關卡操作。
- `card-tower-defense` 是部分素材的原型來源，並非本專案執行依賴；不要將該專案的路線分配、階段規則或其他約定直接套用到這裡。

## 遊戲方向與現況

- Begins With a Road 是從雲海上的一條道路開始，以建造卡同時擴建道路與防禦塔的 3D 塔防。決策核心是卡牌、道路形狀、塔位、火力與兵種路線偏好的組合。
- 玩家目標是防守終點、應對所有 ACT 的波次；路網必須連通，不能完全封死入口到終點。Phase 5 已有防線生命、勝敗與重新開始；保存通關 ID 與敵軍圖鑑解鎖 ID，沒有進行中存檔。
- F5 正式入口為 `scenes/menus/boot.tscn`，共用顯示預熱完成後進入 `scenes/menus/main_menu.tscn`；選「開始遊戲」進入選圖頁，先選第一關「第一條防線」（完成後解鎖邊境前哨）、按「下一步」調整本局設定，再按「開始作戰」進入 `scenes/level.tscn`，載入所選 Level Resource。教學為 1 ACT、3 波，第 3 波遺物選完才記通關；Frontier 為五個 ACT、每個三波；第 3／6／9／12 波後各選一次遺物，第 15 波敵人與在途攻擊結束後勝利，不發第五件遺物。
- 開始選單參考原型的左側標題／操作與右側雲海折線橋景；所有標題、徽記、按鈕、58 段橋、柱子、端點、相機及雲層均明確保存於 `.tscn`，動畫保存於 AnimationPlayer，不在執行時程序生成選單或地形。選單只持有呈現與設定宿主，不初始化波次、商店或導航。開始遊戲先開啟地圖選擇頁；關卡來自 assets/data/levels/ 及子目錄的 LevelDefinition，新增 .tres 即自動列入；超過一張啟用左右箭頭，草稿與未解鎖關卡可瀏覽但不可開始，不把獨立試驗場景自動列為正式關卡。選圖頁沿用無面板文字、僅變黑、不縮放的 hover、底線及雲海，中央為正交的唯讀地形預覽，長軸在畫面中保持水平，預覽 Zoom 為 1.0（較原 1.25 縮小 20%），Bottom Clearance 為 280px，地圖名稱／資訊區整體上移 60px；下方為名稱、由 Level 讀取的 ACT／波次數及返回／下一步；同一個 MapSelection 場景內接續本局設定，再按開始作戰切換關卡，不建立 dialog 或更換選圖場景。步驟標示保留選圖／本局設定／開始；按下一步僅把地圖名稱下方的固定描述區替換為兩欄、兩排的選項區，左上難度、右上起始手牌、左下額外事件、右下暫定提示；欄間距 64px、排間距 24px，選項字級 18px、最小高度 32px；每欄把整組內容置中，欄內各列與提示維持左對齊，同欄標籤使用依語言計算的共用寬度，讓選項起點一致；保留標籤左側 12px 透明內距，中央有僅於選項步驟顯示的 1px 淡青垂直分隔線，返回反向還原；地圖、相機位置／倍率、頁面標題、地圖名稱／箭頭與底部按鈕的位置及尺寸皆維持不變，不重新排版整頁或改變取景留白。暫定難度（輕鬆／標準／挑戰）、起始手牌（隨機／固定）與額外事件文字開關只供流程預覽，頁面明示目前不影響戰局；值由獨立字典隨 launch_requested 發出，不套用引擎設定或改寫 Level Resource。返回／Esc 逐步回退，滑鼠返回保留被點擊按鈕的焦點與底線展開，不強制搶回下一步；只有焦點已隨選項隱藏或不存在時才回到下一步。回選圖保留暫定值，再返回才回主畫面；新主畫面實例恢復預設值。地形預覽直接引用正式地形，不初始化模擬、商店或導航；預覽改為單一共用場景，選中時才實例化 Level.terrain，切換時釋放舊地形，停用腳本樹回呼、處理與碰撞；不用逐地圖建立選單資料、預覽或遊戲場景。較長的 Z 軸地圖以展示相機轉 90° 維持水平，介面位置與樣式不變。所有 Level 共用 level.tscn，一次性交接所選 Resource；重新開始仍保留選中 Level。第一波維持手動開始；無存檔時不顯示繼續遊戲。主畫面使用共用設定頁，語言／抗鋸齒／靜音於本次執行跨場景保留；設定關閉返回開始選單，Web 隱藏離開。主場景與橋景分別是 `scenes/menus/main_menu.tscn`、`scenes/menus/components/menu_stage.tscn`。
- `main`、`9x9`、`11x11big` 保留作為共用場景／獨立試驗入口。正式地形由關卡引用，起終點與道路一起在地形場景中編輯。
- 採用 Godot 4.7.2、Compatibility 渲染器與 C++17 GDExtension，目標包含 Windows 與單執行緒 Web。新增顯示功能需維持此平台方向。

## 關卡、波次與輸入

- Level 的 Level Id 是穩定的解鎖／通關 key，空白時使用 levels/ 內相對檔名；Required To Complete Levels 為前置 ID 清單，必須全部完成。用字典與鄰接清單、Kahn 一次 O(V+E) 檢查 DAG 並逐層產生拓撲列表，同層 sibling 按 ID 字典序排列，完整建立含排序為 O(V log V + E)，不再手動設定順序；前置一定先於後代，通關不改變索引。重複邊去重，重複 ID、缺失前置、循環及依賴錯誤分支的關卡保持鎖定，留在正常 DAG 之後按 ID／資源路徑排列，不影響正常分支。選單顯示「未解鎖」與尚未完成的前置名稱，封鎖下一步及內部啟動。只在目錄重載／通關事件更新狀態，不逐幀搜尋依賴。完成最後一波保存 ID 至 user://level_completion.cfg，跨啟動保留；中途返回、重新開始或關閉不記通關，無進行中存檔。新增與 ID 規格見 [關卡說明](assets/data/levels/README.md)。

- LevelDefinition 保存穩定 ID、前置 ID、Terrain、ACT、可選的 Tutorial 引用，以及 Phase 5 的 base_health／starting_gold／opening_shop／reward_final_act；移除獨立 Title、Title Key／Description Key，由 ID 推導 ui.maps.title.<id>／ui.maps.description.<id>。起終點完全由 TerrainEndpoint 讀取，不保留 Starts／Goal、Use Terrain Endpoints 或 Marker Height。端點的 Height Offset 控制模型相對格子表面的垂直偏移（預設 0.0305），ACT 新增入口及其預覽沿用第一個地形入口在 GridMap 局部座標中的高度偏移。

- 開場採全白品牌畫面：左無框 Godot 機器人（assets/godot_mark.svg）、右同尺寸 assets/team_icon.png，兩者以 75% 不透明度在白底上呈深灰色（Row 的 modulate 與 shell 的 opacity 須一致），版面由 IntroLogos 定義。Web HTML shell 在引擎尚未能畫時只顯示兩個 logo，沒有文字與進度條，失敗才顯示訊息，必須同時收到引擎啟動完成與首個 native draw 通知才移除；shell 以 canvas_items 同比例（1152×648）重現位置，兩張 logo 是 base64 內嵌副本；改尺寸、間距或素材時須同步 shell，否則換手會跳動。Boot 維持相同畫面，下方加更寬更細的進度條與小字（LoadingDisplay.compact）；沒有確切工作數時隱藏進度條。交接主選單時 ScreenTransition 以 intro 模式接續不透明白底，主選單首次繪製後 logo 先淡出，白底再淡出到主畫面。隱藏的 IntroLogos 會錯過 Web 畫布首次改尺寸，顯示時必須呼叫 refresh()；此問題只在 Web 出現。Logo 開場淡入 0.8 秒：Web 由 shell 的 CSS 動畫播放（主執行緒阻塞時仍能動），Boot 不重播；桌面由 Boot 淡入。選圖進關卡的讀條與一般選單切換維持白底，雲海載入畫面試過後已撤回。桌面關閉引擎預設 splash。

- 共用顯示預熱在啟動場景、主選單出現前完成：明確配置相機、與關卡共用的 Environment、同設定方向光、原 renderer 及白色載入介面，不初始化敵群、導航、商店或關卡。DisplayWarmup 依材質設定、網格格式、一般／MultiMesh 繪製、蒙皮／blend shape 與陰影挑代表，不按兵種名稱硬編；原三種兵共用 GPU shader 與頂點格式，只需 Soldier 一個兵種代表；新六種兵帶有獨立模型腳本，保守地各自預熱。啟動場景另明確繪製塔底座的純顯示網格，涵蓋世界共用色盤材質；移除舊 CPU 模型後不能把其原本附帶涵蓋的編譯延後到進關卡。未知腳本或非變換動畫軌採保守場景區分。代表在主 viewport 實際繪製後清理或隱藏；服務保留代表 Resource、世界材質網格與完成紀錄，切場景後重用 shader／材質。快取包含 viewport、MSAA、Environment 與可見光源／陰影組合；條件改變或新組合由關卡補漏，不用單一布林值永久跳過。
- 地圖選擇確認作戰後，白色轉場中顯示極簡載入介面，完成關卡準備才淡入遊戲。場景載入尚無確切工作量時只顯示狀態；已知階段按「入口圖就緒＋第一波各兵種／入口候選池＋尚未準備的顯示代表」推進細進度條；Frontier 第一波以目前 Resource 為準（恢復的本地編成目前只有 Quickfeet）；候選池依兵種／入口各準備一次，顯示工作量依尚未預熱的代表動態計算，包含 Phase 5 Boss。啟動與轉場共用 LoadingDisplay，不當成剩餘時間或 shader 編譯百分比。ScreenTransition 透過可選準備方法及進度回呼協調，不直接引用敵人或導航。準備不加入敵群、不分配配額、不消耗 RNG，不增加移動階段工作。準備期間停用關卡 processing、攔截輸入並拒絕開波，完成後恢復原模式，第一波仍手動開始。失敗或目標中途離場時恢復來源場景並清掉遮罩；啟動預熱失敗仍進選單，由關卡重試未完成組合。Headless 略過 GPU 預熱；直接執行 level 的偵錯入口保留原行為，直接開主選單會在進關卡補漏。單項同步編譯仍可能暫停載入畫面，未涵蓋的新特效仍可能首次停頓。

- Level → ACT → Wave → SpawnGroup 以 Resource 編輯；波次編輯器分別選擇 ACT 與其波次，可新增／刪除 ACT、波次及編輯各 ACT 的「結束後新增出生點」checkbox（預設勾選）。新 ACT 附一個波次，新波次附獨立的預設兵種群組；可刪到空白再新增，無效資料不可儲存。結構、選項與群組編輯皆支援原生 Undo／Redo、儲存重載與未儲存追蹤，刪除後復原保留原資料及選取；群組拖曳吸附與預覽保留。
- 出生時間使用整數刻度，每格 0.25 秒。群組可重疊或留空檔；還有未來群組時不能因場上無敵人而結束波次。正式排程慢幀會補上到期批次。
- 每波準備期無時間限制，包含第一波都必須由玩家手動開始，不倒數或自動進攻。點擊「開始下一波」後有 1.5 秒開場等待：時間線在前 1 秒以 ease-in-out 推進到下一節點，再停 0.5 秒。
- 開波不給額外金幣，只保留各波完成時的獎勵；Level Resource 不再提供準備倒數、自動開第一波或提早開始獎勵設定。
- 進入開場等待立即取消選牌與預覽、收起手牌、停止建造與商店交易；戰鬥保持鎖定，波次完成後恢復。關閉商店不能解除階段鎖定。
- 每個 ActDefinition 各自保存 add_start_after_completion（預設 true），不再使用 Level 的全局擴張開關。完成該 ACT 且還有下一個 ACT 時，勾選才先選擴張方向與新增入口，期間禁止放塔與開波；完成後或未勾選時進入不限時、手動開始的下一波準備。最後 ACT 直接完成關卡，不額外新增入口。
- 地形必須帶有至少一個入口、恰好一個終點；端點不可重疊、必須位於可連通道路。多入口依場景樹順序編號；缺失端點回報設定錯誤，沒有關卡座標備援。
- Phase 5 Frontier 的五個 ACT 均關閉新增入口，保留十五波的既有設計。
- 倍速為 1x／2x／4x，Tab 或頂部倍速按鈕依序循環，按住不連續切換。遊戲中的 Esc 在 GUI／卡牌取消操作之前切換暫停／繼續；設定頁中 Esc 仍只返回暫停選單。暫停中的 Tab 保留選單焦點導覽，不切換速度。按下暫停立即停止模擬並鎖住遊戲輸入，不經過減速過渡；暫停仍可平移縮放鏡頭，但頂部倍速與暫停按鈕立即停用且不回應 hover；透過右下繼續遊戲或 Esc 恢復。手牌與商店以實際 0.35 秒收至畫面下方，並同步淡入由場景設定透明度的白色遮罩；恢復時反向還原，接續原進度、選牌及商店展開狀態。
- 鏡頭採左鍵平移、右鍵繞畫面中心旋轉；兩者都在 GUI 前捕捉，移動達 Orbit Drag Threshold（預設 4px）才視為拖曳，未達門檻則在放開後遞送原按下／放開事件，保留左鍵放塔／UI 點擊及單擊右鍵旋轉卡牌。左鍵只從卡牌以外起拖，手牌、商品、牌背與重刷牌（含停用牌）的實際命中範圍保留卡牌操作；捕捉後可跨過卡牌／價格／其他 UI 持續平移，放開即停止。右鍵可由地面、天空、卡牌或其他 UI 起拖，依滑鼠繞中心的角差旋轉；捕捉後跨 UI 仍持續，不觸發卡牌或商店。未超過最高轉速時，畫一圈對應同向一整圈，只改方位，不改仰角、距離、縮放及地形；中心 Orbit Dead Zone 預設 16px 忽略角差。Maximum Orbit Speed 預設 360°/s，依實際時間限速，不受倍速／暫停影響。角速度以同一指數響應加速、反向及減速，Orbit Smoothing Seconds 預設 0.15 實際秒消除 99% 速度差；每幀取用後丟棄輸入，不累積待轉圈數，停下／放開後目標速度歸零並沿原響應停止。新鏡頭手勢、離窗、失焦或 navigation lock 清除捕捉與角速度，須重新按下才開始；中鍵不控制鏡頭。暫停時仍可操作，滾輪縮放及方形平移中心限制保留。
- 暫停選單包含繼續遊戲、重新開始、設定與回到主畫面。各項右對齊，hover 時以實際 0.2 秒二次 ease-in-out 左移 12px，文字變黑但不縮放，移開反向還原，不使用 hover／focus 橫線。固定外層保留原命中區；共用範本位於 levels/components/pause_menu_item.tscn。重新開始重載目前場景，重置進度、手牌、敵人、金幣與 1x 未暫停狀態；回到主畫面會結束目前關卡，舊關卡保持暫停直到白色過渡遮住並移除，再次開始建立全新進度，語言與顯示設定仍保留。設定頁面以獨立 Control 場景與暫停選單共用主 viewport／CanvasLayer，避免子視窗取樣模糊：左側分類清單，中間左 key／右 value 的可捲動選項，最右側垂直捲軸。設定頁面透明無白色面板，進入時以實際 0.2 秒加強原有白色遮罩（LevelHUD 的 Settings Veil Alpha 預設 0.82），返回還原場景原值。頁面內分類、返回及選項共用透明文字按鈕：hover 僅將文字變黑，維持 Light 字重、原尺寸與命中範圍；移開恢復原字色，不縮放。Noto Sans TC Light 的字型匯入 oversampling 維持 0.0，依 viewport 自動取樣；固定 4 倍取樣因一般文字過細與邊緣破碎已撤回，不以全域字型匯入變更處理局部 hover。設定／主選單與暫停按鈕均啟用隨 scale 取樣，保留原字重與布局。此共用行為也套用開始選單；開始／設定／離開與選圖的返回／下一步／開始作戰共用相同字色規則，不為個別操作單獨覆寫金色；失焦回到一般青灰色。一般按鈕 focus 底線以實際 0.2 秒由中央漸展、失焦反向收回；分類、radio 與 checkbox 的底線只表示選中值，取消時即使保有焦點也收回。radio 不畫圓點，checkbox 為純文字開關，不畫方框或勾。切換語言以翻譯 key 原地更新文字，不重建控制項，保留焦點與底線動畫進度。優先使用文字 radio，舊 dropdown 資料也呈現為 radio；目前提供語言、抗鋸齒、靜音及整體／BGM／戰鬥音效音量，立即生效但不跨次啟動保存。返回／Esc 回到暫停選單，保持遊戲暫停。頁面以資料與 signal 介面隔離實際設定套用，不依賴關卡，由主畫面與暫停共用；開啟期間由全畫面透明 Control 阻擋背景點擊並限制鍵盤焦點；LevelHUD 依頁面可見性使用鏡頭的通用 navigation lock，停止已有手勢與角速度，防止背景平移／旋轉／縮放及延後點擊。返回或移除 HUD 時解除鎖定，設定元件不引用關卡或鏡頭。
- 主畫面、地圖選擇與遊戲之間共用約 0.5 實際秒的白色過渡：0.25 秒變白，完整白畫面下切換，再用 0.25 秒淡出；載入期間保持白色。獨立 ScreenTransition Autoload 場景只負責遮罩、過渡與輸入攔截，不決定關卡規則；過渡不受暫停或倍速影響，期間阻擋滑鼠、鍵盤、鏡頭與重複切換；離場鎖定由過渡層與宿主狀態守衛處理，不把文字按鈕改為 disabled，避免字色或動畫突然變化。暫停文字 Theme 的 disabled 樣式也保持透明，不回退到引擎預設灰底。主畫面「離開」仍為關閉遊戲。
- 關閉視窗／移除關卡時，敵人 `tree_exiting` 也可能觸發波次完成；關卡已排程刪除或 HUD 已離開場景樹時，不再推進下一波。HUD 的準備期更新與世界投影須忽略離場後的呼叫，避免在清理期間讀取空 viewport。

## 五步教學關卡

- 「第一條防線」（assets/data/levels/tutorial.tres）為第一關，1 ACT、3 波；Frontier 的 Required To Complete Levels 包含 tutorial，Bridge 包含 tutorial 與 frontier，透過既有 DAG 自然排序為 tutorial → frontier → bridge。後續新增關卡也須直接包含 tutorial 前置，舊的後續關卡通關紀錄不會繞過教學。沿用共用 level.tscn，地形與端點明確保存在 scenes/maps/tutorial.tscn。
- 依序教左鍵平移／滾輪縮放／右鍵繞中心旋轉；預設三張初始牌為哨塔、迫擊砲、弩砲，引用 assets/data/tower_tiles/user/ 的基礎版配置（直線、L型、旁直線路），新商品交叉火力用直路，全部走新模型。前兩張依 hologram 放置：哨塔在橫路原向，迫擊砲在轉角轉 180°坐進內角，各形成繞過塔占格的道路；第三張可任意合法放置。2×2 塔在此地形沒有 90° 合法解，教學文案不寫死角度。
- 初始牌由 assets/data/tutorial/intro.tres 的 Starting Cards 編輯，三張卡獨立為 starting_01～03.tres，可更換 Tower／Tile Preset 與重排。教學文案依實際塔名顯示，升級 hologram 尋找實際建好的同種塔，不假設升級目標必為第一張。Upgrade Card 的塔須存在初始牌任一位置，New Card 的塔不得存在初始牌；指定格／方向需配合修改後的配置，詳見該目錄 README。
- 三張放完才開放手動首波，沿用 1.5 秒等待與戰鬥鎖定。首波四名步兵結束並等待砲彈後，保證商店的升級牌（預設哨塔），要求購買並疊到同種塔；升級後才允許付費刷新並保證新塔（預設交叉火力）。買下只完成操作引導，不記通關；清掉指定建造／商品／重刷限制，進入自由實戰，繼續手動第 2、3 波。
- 教學三波預設 4／6／8 名步兵，獎勵 20／10／10。第三波由 reward_final_act 沿用最後 ACT 遺物選擇，選完才保存 tutorial 通關 ID 並解鎖後續關卡；不在購買新牌時結束。提示在暫停、設定、載入及遺物選擇期間隱藏。中途返回／重新開始重置本局，不保存中途步驟。
- TutorialDefinition 保存卡組與目標，TutorialDirector 監聽真實動作，透過可選放置與交易規則限制引導期；不代玩家建造／交易，也不修改共用 BFS、升級、價格與商店動畫。一般關卡不配置 Tutorial，不受引導限制。驗證及人工入口在 tests/tutorial/README.md。

## 進度頁

- 「進度」取代遊戲內左側敵軍情報按鈕與面板，主畫面與暫停選單都可開啟，繼承 settings_page 的外殼、捲動、Esc 與焦點，左側分「我方防禦塔／敵軍／遺物」。塔清單在 ProgressCatalog.TOWERS 明確定義，須與 card_shop.tscn 的 catalog 同內容同順序（回歸檢查）；敵人沿用 TroopCatalog 自動發現與 sort_order。ProgressCatalog 從 TowerDefinition／Troop 讀名稱、圖示與數值：塔描述與特性在翻譯 key tower.<id>.description／tower.<id>.traits（特性以 | 分隔），敵人描述沿用 ability_text／ability_text_en，特性由 tags、減傷與硬性選路產生。遺物直接讀 assets/data/relics/catalog.tres 的順序，名稱下方以 RelicDefinition.usage_text()／icon_color() 用對應色小字標示塔名或「通用」，三選一卡片共用同一標示（12px，塔色加深 45%）；可重複者列持有上限；專屬圖示套塔色，通用保留原色。全部條目直接顯示，沒有解鎖或遇敵紀錄。塔與敵人圖示都無底板，以 ui_icon_mask 套 accent_color 加深 45%，與手牌／商店一致。敵人圖示一律是 assets/sprites/enemies/<troop_name>.png 的 64×64 白色遮罩，顏色由 Troop.accent_color 分配且各不相同，開波提示共用 Troop.icon_color()，波次編輯器直接以 accent_color 調色；不再使用 SVG 或 sprites/troops/。

## 卡牌、商店與放置

- BuildCard 可組合 TowerDefinition 與 TilePreset，或單獨引用 TrafficStructureDefinition；兩者互斥。初始手牌預設三張；可指定固定卡牌，否則先抽塔，再按該塔自己的地塊候選權重抽配置。
- 地塊是獨立 `.tres`，名稱為人工設定。塔可共用配置並使用不同權重；權重為零、失效檔案與空項目不參與抽取，沒有有效候選的塔不參與抽牌。
- 塔占格與地塊道路一起旋轉，使用 90 度順時針步數與同一 anchor。成功放置才消耗卡片，失敗保留。
- 手牌同時支援點選後點地圖，以及按住卡牌拖到地圖放開放置。手牌起拖超過 8px（Hand 的 Drag Threshold）才進入拖放；單純點按保留同卡切換選取。拖曳沿用 hologram、R／右鍵旋轉及權威放置檢查，拖已選中的牌保留旋轉。有效落點只提交一次；拖到任意可見卡牌（自己、其他手牌、商品或牌背，包含停用牌）上放開會取消目前選牌與預覽，保留卡片，不觸發落點卡牌；無效地塊或其他 UI 上放開則保留選取，也不觸發 UI。Esc／取消選牌、暫停、開波、商店／ACT 鎖定、離開視窗或失焦均取消拖曳並吞掉剩餘放開事件。手牌捕捉按下與放開，滑鼠移動仍交給 GUI 更新 hover；不啟動鏡頭平移或旋轉。
- 候選快照必須包含整組新增道路及塔障礙，再以 BFS 驗證所有入口到終點連通。不可用修改前道路判斷跨橋卡是否封路。
- 道路可合併既有道路並保留參數；新道路遇到已建塔的完整 footprint 時自動裁切，不新增該格或接口，預覽／驗證／提交共用 card_ground。新塔體重疊仍拒絕，石地／端點／設施／兵營駐點保護保留。所有塔牌經 construction_plan，裁切後驗證所有入口與固定行程；塔完整 footprint 排除於導航快照之外，底下的歷史地塊紀錄保留。拆塔刷新鄰格接口，升級不重鋪道路。
- 預覽不是提交權威；點擊時重新驗證，並保護待生成／存活敵人的剩餘固定行程。失敗不可留下部分地塊、塔、威脅或 revision 變更。
- 放置卡牌時同時顯示綠／紅 hologram、獨立塔體／道路格面與淡金色連續攻擊色面，圓形畫圓盤、格形只畫聯集外輪廓，包含空地上的完整範圍，遊戲預覽不畫道路接口線；共用可編輯範本為 scenes/cards/components/card_preview.tscn 的 Ground／AttackArea 節點，填色與邊框顏色可在 Preview Inspector 設定。只在換格、旋轉或失效時重建，不因停留計時每幀重建。
- 批次地塊一次提交並刷新相鄰接口、塔影響與導航。預覽在換格、旋轉或失效時更新；不可每幀重建路線池。
- 商店每波完成後發一次獎勵，一般商店只抽四張防禦塔，單排右端保留原重刷牌；輔助設施暫停供應但資源／抽取工具／放置效果保留；開關不重抽，購買不能重複扣款，全部候選失效時不扣重刷費。
- 塔種抽取使用洗牌袋，地塊依各塔權重獨立抽取；商店 RNG 與敵人選路分開。卡牌保存抽出時售價，重刷不改已入手卡片。
- 商品買走後向右靠攏，手牌保留原卡面實例。快速購買／收合接續現有動畫；動畫中的點擊與商品索引需防止錯購。

## 道路、尋路與兵種

- 地圖使用整數格座標與四向接口；模型 1×1 格，石地與斜角不連通。道路保留雙向、平行分支及環。
- GDScript 管理資料、失效與協調；C++ 管理入口圖、寬區局部搜尋、候選探索、批次逐格展開／去環／資料重建、去重評分、機率表與批次配額索引，以及編輯檢查。GDScript 保留 Resource evaluation、快取生命週期、波次排程與畫面協調；不逐候選跨原生邊界。BFS 放置檢查不決定敵人路線。
- 一般 Cost 兵種使用有限候選池（Phase 4 硬性規則另見下節）。先共用中性幾何候選，再以兵種正成本探索補充；每條節點路線只取有限個局部同成本代表。建立候選池時對完整逐格行程以堆疊與格子索引表做 O(L) 去環，保證同一路線不重踩格子或實體邊；同步重建路長、實際經過的 vertex、分段與格子索引，再按去環結果去重、以原始 evaluation 評分及建立 Uniform／Softmax 配額。去環只在建池執行並快取，出生與敵人移動不做去環，也不改已固定的當波行程；原生節點路線仍是探索來源，最終分段 ID 依保留的逐格走法識別，不假借被剪接前的 native edge ID。
- 原始 evaluation 可正、零或負；搜尋時平移成正成本，最後以原始分數加總評分。起始格不計費；拒絕 NaN／無限地塊分數。
- 僅保留 `score - min_score < threshold`；等號排除，INF 停用門檻，0 不保留候選。最佳分數是池內最佳，不保證全圖最優或列出所有同分走法。
- Dijkstra 加道路重用懲罰探索不同候選，正反向共用實體道路計數。search_budget 是搜尋次數，不是保留路線數。連續停滯後的一輪中繼補路也不保證完整覆蓋。
- 不使用全域 DAG、ZDD 或 Yen；局部最短路 DAG 僅壓縮同分走法。候選方向聯集可能有環，不得讓敵人在聯集中任意選邊。
- Soldier 預設 Uniform；Quickfeet／Heavy 預設 Softmax，分別偏好低／高威脅。路線模式由 Troop Resource 設定，不恢復舊下拉選單。
- Uniform 對保留候選提供等基礎權重；臨時設施再修正權重。Softmax 使用穩定的 `exp(-(score-min_score)/temperature)` 權重。每波以 `index / total` 對應累積機率區間，固定配額後打亂出發順序，並非每隻獨立隨機抽選。
- 同兵種、同入口的出生群組共用整波配額；各起點持有獨立計畫與機率表。開波依每個兵種／入口批次準備一次計畫及全部配額，不逐隻重新查詢與複製計畫摘要。相同候選的路線資料與世界座標在該次波次建立中共用唯讀 packed buffers，敵人的路線字典、數值與移動進度仍各自保存；世界座標快取不跨次建立沿用，保留當波快照且避免地圖變換失效。預覽不能消耗實際出發順序的隨機數。
- 正式 plan_for 只回傳輕量計畫摘要；最終候選的 nodes／edges／steps／directions 聯集與統計由 debug_summary_for 明確請求後才建立並快取，不在一般建池或批次分配時掃描全部路線建立除錯資料。
- 開波時固定全部待出生敵人的行程、血量及速度。之後修改地圖／評分只影響未來波次，不改寫既有快照；敵人移動期間不尋路。
- RoadEditGuard 透過 Tarjan／block-cut 與並查集延後不影響有效路網的死路新增重建；新增死路仍立即擁有地塊資料。刪除、任意改接口或移動端點需明確完整重建。
- 每格一份 TileParameters，每張地圖一份 store；store 管理座標、成本快取與失效，不負責尋路。成本變更與道路幾何變更分別失效。
- 新增兵種使用 `assets/data/troops/` 的 Troop `.tres`，由 TroopCatalog 自動發現，不為每個兵種新增腳本子類別或硬編目錄。缺失的兵種不能偷偷替換後開波。

## Routing Sandbox Phase 2：臨時交通設施

- Troop 使用互斥的 body_size（small／standard／large）及可複合 tags；has_tag 統一查詢，tags 中的體型字串不覆蓋 body_size。舊資源預設 standard＋ground；Soldier／Quickfeet／Heavy 分別 standard／small／large，皆 ground，Heavy 另有 armored。不變更原生命、移速或戰鬥資料。
- TrafficStructureDefinition 獨立於 TowerDefinition；旗幟在鄰路空格，模型附一格石地與支柱，預覽／正式模型共用且隨設施移除；四向相鄰影響 ground ×1.5；拒馬／窄口覆蓋既有道路，Phase 4 起分別影響 small＋ground／large＋ground ×0.5，預設售價 3、壽命 3 波。範圍、標籤、倍率、壽命、模型及雙向共存群組由資源設定。預設設施互斥，不占用導航格、不修改道路 Tile；塔、兵營駐點、端點、道路新增及 ACT 延伸均保護設施占位。
- 每座設施對一條完整候選路線最多作用一次，跨設施乘法疊加。保留原候選搜尋、嚴格 threshold 與成本；在 Uniform／Softmax 基礎權重上使用 log 倍率後穩定正規化，再用原 index／total 配額。倍率非有限或負值無效，全零權重沿用無可用路線處理。有限候選及 threshold 限制保留：不重引入被排除路線；預覽無實際流量改變時明示限制，不畫假箭頭。
- TrafficStructures 由 TowerMap 持有；放置時快照效果及初始壽命，開波記錄參與實例，完整波次結束才減一。第三波結束清除實例、占位及權重；跨 ACT 保留剩餘壽命，最後一波仍扣除，提前刪除與卸載亦清理。準備期 Hover 已建設施顯示剩餘波數。所有現有固定行程保持不變。
- UI Slice A 起一般商店只使用塔池洗牌袋，商品索引 0–3；輔助池 API 與資源保留供工具使用，不作無有效塔候選時的備援。初始手牌仍抽塔；重刷四張只扣原費用，保留牌背、翻面、插牌、靠攏及旋轉動畫。
- 候選效果透過 CardPlacement 訊號傳給既有 WaveFlowPreview，使用 WaveSpawnSchedule 的唯讀 modifiers 覆寫建立不洗牌配額；不改正式 effects，不消耗 RNG，不重建候選搜尋。換格、旋轉、revision 或設施變更才重算。取消、非法位置、UI、失焦、暫停或開波恢復正式預測／隱藏預覽。
- 保留 Phase 1 流動筆觸；新增的 ↑／↓ 只表示配額相對增減。僅在雙向接口驗證後度數至少 3 的岔路出口，依實際有向流量差及 minimum_quota_change（預設 1）顯示。入口／兵種篩選同步套用前後流量，標記為固定螢幕向上／向下，不表示敵人方向。增量箭頭以實際時間輕微上浮、減量箭頭下沉，循環接縫柔和淡出／淡入；Float Distance／Float Period 可調（預設 5px／2 秒）。外觀範本在 scenes/traffic/components/。
- 驗證與人工場景見 tests/traffic/README.md；不要把舊回歸對可編輯 main 地形／Quickfeet 數值的固定假設還原到正式資源。

## Routing Sandbox Phase 3：疊塔與本局遺物

- 同種 TowerDefinition 卡牌拖放或點選到已建塔任一占格時升一級，忽略 TilePreset，不加道路、不改方向／占格／固定行程／導航 revision；只消耗一張牌，不額外扣錢。一般 Lv.3 封頂，只有「成為主角」解除哨塔上限。保留冷卻、接戰、復活計時與塔／友軍血量比例。
- Hover 已建塔與升級短暫回饋共用一份螢幕對話框，塔名靠左、等級 Lv.n 靠右；兩者與「開始下一波」統一使用 Noto Sans TC Light、16px 青灰色文字（Color(0.2,0.36,0.38)），不加描邊，間距 12px。框體與下一波提示共用 scenes/interface/components/speech_bubble_frame.tscn 的淡色底、青灰邊框、切角與下方置中尖角；塔提示不設固定最小寬，依名稱與等級所需寬度貼合，左右內距 12px、上下內距 8px。尖角投影至塔上方，字體與框體不隨鏡頭縮放改變；只共用一個臨時實例，不為每座塔增加標籤，所有控制項不攔截滑鼠。使用獨立 CanvasLayer 7，高於開波提示所在的 LevelHUD Layer 6；重疊時塔提示顯示於上層。提示處理在暫停時仍可執行隱藏，遊戲暫停或宿主停用時不顯示，避免蓋住暫停／載入介面。
- TowerGrowth 獨立 Resource 保存每級倍率：一般射擊塔傷害 ×1.35、間隔 ×0.95；迫擊砲只增加傷害；兵營友軍生命 ×1.30、傷害 ×1.35，不增加人數；塔本體生命預設不成長。Lv.4 以上同曲線，溢位原子拒絕、不偷偷衰減；既有每塔每幀一次普通攻擊的更新上限保留。
- TowerMap 持有每局 RunRelics；catalog 為 17 件唯一專屬與 4 件通用，參數、名稱／描述／圖示與重複上限資料化。重開／卸載清除當局狀態，不修改共用塔／兵種設定。既有與新塔共享同一效果管線，不複製塔腳本。
- 遺物中英文說明採簡短、直覺、略帶個性的效果提示，沿用前幾件文案的語氣，不在玩家說明中羅列完整倍率、疊加上限或程式內部規則；詳細機制仍記錄於 Resource 與 docs/phase3.md。
- 遺物圖示由 Resource 明確引用：17 件專屬使用 `assets/sprites/relics/<id>.png`，4 件通用保留同目錄的 SVG。三選一卡面、邊框及圖示共用主色：專屬沿用塔的 accent_color 與手牌 icon mask／加深比例；通用保留 SVG 原色，以 RelicDefinition.accent_color 對應圖示灰綠主色。hover／pressed／選中停用回饋保持各自色系，逐卡複製 StyleBox，文字維持深色可讀。
- 遺物三選一為置中的三張 184×272px 卡牌，間距 20px，略大於 144×208px 手牌；圖示區 64px、名稱 18px、說明 14px，外部標題 24px。變暗遮罩覆蓋完整 viewport，包含頂部；視覺遮罩不攔截滑鼠，另由下方 80px 起的 Blocker 攔截背景點擊，讓頂部暫停仍可操作，不能藉由裁掉遮罩保留點擊區。
- Debug 版本的遺物三選一卡列下方提供「重新隨機抽選（Debug）」按鈕，release 隱藏且拒絕呼叫；只在等待選擇且未暫停時可重抽，選中回饋期間禁止。沿用 RunRelics.options 的三槽／唯一性／持有上限規則與獨立 RNG，只更新候選，不扣錢、不直接取得或解除階段鎖定；可與前次部分重複，候選池耗盡時保留原畫面。
- ACT 結束先等待飛行中砲彈全部落地；非最後 ACT 再三選一，之後才進入下一準備期或自訂關卡的入口擴張。最後 ACT 直接結算，只有 Level.reward_final_act 可另外要求最終獎勵（教學第 3 波使用此設定）。選擇及等待期間鎖住建造／交易／開波。通用、弱關聯、全池隨機各一槽；同次不重複，已持有專屬排除。弱關聯預設每件權重 1+0.25√塔數，空池回退全池；RNG 獨立。
- 機制共用 AttackPayload／CombatSystem：冰霜各層獨立 2 秒到期、強度 0.18 且遞減至最高 60% 減速；不改原 SlowEffect 合併語意。燃料依錨點幾何距離 5 格、每來源 +15% 加法，不支援自己。small／flying／boss 以 Troop.has_tag 判斷。
- 迫擊砲不提前瞄準、不追蹤；落地依實際三維距離結算一次傷害及爆炸，原目標／來源死亡不取消。每三發特殊彈半徑 ×1.8 且可傷友塔；塔死亡保留地塊和既有行程。大砲傷害 ×3、間隔 ×1.5、速度 ×0.5，確實加倍飛行時間。
- 空艇模型分為 FixedBase 固定底座與 Airship 艇身；六支砲管、砲口與後座組件都在艇身上。「出發」只移動 Airship，底座、建造錨點及朝向保持固定；索敵原點與右舷判斷取自移動艇身，移除遺物只讓艇身復位。預覽／威脅取巡航可達射程聯集，不每幀改導航；一般射擊及 6 秒一次的三連齊射都服從本體右舷限制。哨塔處決每 8 秒優先 large 普通敵人、排除 boss，沒有合法對象不消耗；支援攻擊將有效範圍乘 3，格形／圓形各自同比放大。
- 弩砲穿透使用實際直線幾何及每發命中 ID 去重；擊退沿原 waypoints 逐段倒退 0.3 格，接戰先雙方釋放。孤立傷害 ×2 的 3 格鄰塔檢查包含兵營、不含交通設施。兵營增援提供完整第三槽位；神射手讓所有未接戰友軍保留近戰並可遠攻 3 格。
- 17 件明細、通用倍率與限制見 docs/phase3.md。tests/relics 提供分階段回歸與獨立人工驗收場景；F7／B／F9 和右上可收合的「自由增添／移除遺物」面板僅在測試場景。補牌用 B 或面板的「補齊缺少的塔牌」按鈕，只依目前手牌的 TowerDefinition 補六塔中缺少的種類、每種一張，忽略 TilePreset 差異，保留原牌及重複牌，齊全不加牌，禁止綁 F8（Godot 停止執行），按住不連續觸發、暫停不補牌。面板內清單顯示全部 21 項，可捲動選取，支援逐份增減、說明、持有數／上限與結果，沿用正式唯一性／通用上限，暫停禁止增減。移除同步撤回持續效果、巡航、齊射及第三友軍並釋放其接戰；保留既有等級、已發放金幣、既有命中效果及在途攻擊快照。不要新增本次未討論的專屬遺物或把 UI 名稱當成機制完成。

- 已持有遺物使用集中頂列的 RelicBar，依種類排列並顯示疊加份數；hover 提示名稱／效果、點擊開啟詳情與使用情境。詳情向 HUD 借用暫停，與圖鑑、設定、進度頁互斥，關閉恢復原狀態。圖示不跟隨手牌位置或收合；專屬沿用遮罩與塔色，通用保留原色。三選一／一般暫停期間隱藏頂列，重開／卸載清除；不改效果、上限或 RNG。main 的獨立 relic_inventory 場景保留供工具使用，正式關卡不重複顯示。

## Routing Sandbox Phase 4：敵軍協同與硬性選路

- 沿用 Troop／TroopCatalog，新增鼠群（small ground swarm）、盾衛兵（large ground armored guardian）、血法師（standard ground support）、飛翼獸（standard flying）、偵查兵（small ground scout）、爆破手（standard ground saboteur）。能力、模型、圖示、體型、Tags、Route Rule 與 Uniform／Softmax 均為 Resource 設定；數值見 docs/phase4.md。Phase 5 已把九種普通兵種編入十五波，普通兵種數值未變，改以人數／時間／波次速度校準；歷史「只有一名盾衛試配」不再是現況。
- 鼠群預設 5 隻一群；每個 WaveSpawnGroup 在尾端可不足額，不跨編輯群組拼群。入口和路線均按群分配，同兵種同入口跨群組共用整波「群」配額；只洗牌整群，尾群保持尾端。每隻仍有獨立生命及完整固定行程。群內 1 刻度（0.25 秒）；群首間隔為 max(interval_ticks, cohort_size × cohort_interval_ticks)，鼠群模式不使用 batch_size 分拆群。一般兵種原刻度／batch_size 語意不變。預覽、列表與正式出兵共用 WaveSpawnSchedule，顯示總個體數。
- Route Rule COST 保留有限候選、原始評分、strict threshold、Uniform／Softmax。SHORTEST／NEWEST 使用獨立硬性候選，優先於 Cost／threshold；合格候選以等基礎分數進入同一配額及交通倍率流程。新六兵基準 Uniform，盾衛不使用追友或威脅尋路；血法師與爆破手不追友。飛翼獸對所有地面交通倍率免疫。
- 飛翼獸由原生格子 BFS 找真正最短距離，每條最短 DAG 有向邊提供一條代表完整路線，去重後分流，不受普通 search_budget／Cost 候選限制。仍沿四向合法道路，以 1.2 格高度的固定 waypoints 飛行；不被兵營近戰攔截。普通迫擊砲索敵與爆炸都排除 flying；空中打擊解鎖三維球形命中。其他射擊塔與神射手可對空。
- 偵查兵身份是入口／終點＋完整物理格序列，不使用 RoadPortalGraph 節點／候選索引。每局 PortalMap 保存已提交雙向接口快照及 Wave；初圖出生 0，準備第 N 波的編輯記 N，同波多次提交同齡。誕生取第一份容納完整行程的歷史快照；快取、成本、預覽或重搜不新增歷史。失效路徑排除，重新接回已存在行程仍沿用首次出生。
- 原生新路搜尋對當前道路每條邊用容量 1 的頂點最大流尋找簡單入口至終點完整通路，排除死路／單接點環。對當前邊呈單調增長的歷史，這保證最新有效批次不被普通候選池漏掉；同齡路線提供有限代表，不列舉全部組合。反覆刪除／重接造成非單調歷史時，使用最多 200,000 次展開的完整行程查證；不能完成證明就明示錯誤並停止開波，不偷偷回退舊路。沒有新有效批次才回退較舊有效批次。原生改動需重建並重啟 Godot；目前載入 bin/road_graph.candidates.*。
- 盾衛嘲諷只在符合原攻擊射程／方向／對空條件的候選中比較，依 taunt_priority、塔至盾衛距離、enemy_id 決定；全目標交叉火力不受限制。一般射擊、齊射、狩獵及兵營單體攻擊共用優先規則。減傷不修改共享資料，狩獵仍能處決非 boss。
- 血法師每個實例獨立治療時計，治療附近仍活著的受傷友軍（含自己）、不超上限；每幀最多一次脈衝，慢幀不累積爆發。綠色擴散環提供提示。爆破手選最近合法塔、同距以格座標穩定排序；橘色前搖環／連線／技能條完成後施加癱瘓，塔頂顯示閃電。重疊取最長剩餘時間，不相加；每個來源獨立到期，來源死亡／離場或波次結束立即清除。停止塔普通／遺物攻擊及兵營友軍攻擊，釋放接戰；既有飛行攻擊快照繼續。等級、定義、地塊、道路和行程不變；暫停不走能力時計。
- 下一波兵種圖示保留 hover 兵種／入口篩選，hover 時展開顯示該入口的個體數；點擊圖示暫停並開啟進度頁的該敵人，不開波。
- tests/synergy/playground.tscn 是獨立 A–D 可玩驗收：可切換重置場景、套用分流、B 補缺牌、D 按 N 同波新增雙路與切換空中打擊、F9 清波。不要將測試工具或合成波次加到正式 Frontier；詳見 tests/synergy/README.md。

## Routing Sandbox Phase 5：完整長局與平衡證據

- Frontier 五 ACT／十五波，沒有自動新增入口。防線 20，普通漏敵扣 1，攻城巨獸漏敵立即敗北；敗北取消後續排程與場上敵人，不發過波獎勵。勝敗均鎖定建造／交易／開波；結果頁重新開始重載場景、恢復 1x 與未暫停狀態。base_health=0 保留舊獨立測試不敗北的語意。
- 初始三張免費塔牌、9 Gold、第一波前可買商店。擊殺 Gold 全為 0；完成波次依序給 9／9／9、11／11／11、12／12／12、14／14／14、15／15／0，共 168。重刷原價 1、設施 3／三波、金幣遺物 20 不變。疊塔不重複收費。
- 塔價依 sentry／ballista／broadside／crossfire／mortar／barracks 為 9／8／8／10／9／8；單發傷害為 12／30／16／8／24，兵營每名友軍 6。原攻擊間隔、範圍、生命、Lv.3 上限及成長倍率保留。Resource 的 script 必須先於自訂屬性，驗證 Inspector 載入值，不只讀文字。
- 最終一隻攻城巨獸適配舊專案裝甲撞槌模型與雙塔癱瘓：1200 HP、速度 ×0.4、冷卻 8 秒後蓄力 1.2 秒，再癱瘓 3 格內最多兩塔 3 秒。沿目前固定道路，狩獵不處決 boss，減速／冰霜／攔截仍適用。模型已烘焙到本專案；不能引入舊路線、管理器、法術或動態插怪依賴。
- BalanceTrace 預設關閉；實驗明確啟用，shop／relic／spawn 三條 RNG 分離，預覽不消耗出兵亂數。實際遊戲可用 --balance-trace=res://.godot/phase5/play.jsonl 與 --balance-seed=23；--balance-summary 只供概況，完整獨立傷害重算需詳細模式。
- tests/balance 驅動正式戰鬥與交易，保留基準、否決候選、七策略、能力／交通因子對照、敏感度與預留驗證。tools/balance/analyze.py 從 JSONL 獨立重算帳本。原始輸出與壓縮包留在 .godot/phase5，reports/phase5 只放彙整與診斷圖。人類遊玩、Web、release 與效能驗證不可由 Windows 自動測試推論，詳見 docs/balance/phase5_final.md。

## 戰鬥與顯示

- 敵人頭頂狀態維持共用 MultiMeshInstance2D 批次。每次非空 buffer 提交後須 queue_redraw，刷新 canvas 命令的裁切範圍，避免相機平移／縮放後沿用畫面外的舊範圍而漏畫血條、護盾、技能與效果圖示；不可只依賴 MultiMesh.buffer 更新。四邊離屏後移回的實際像素回歸在 tests/enemies/enemy_status.tscn，暫停鏡頭投影另由 pause_navigation 驗證。

- 道路、木橋、塔、端點的非發光零件及正式三兵種共用 `assets/materials/solid_color.tres`，不依顏色／兵種複製材質。顏色烘焙進 COLOR，粗糙度／反光保存在 CUSTOM1；GPU 四肢支點沿用 UV／UV2，擺幅／起伏／側擺／取樣間隔保存在 CUSTOM0，靜態模型 w=0 跳過動畫。相位及移動 blend 仍使用原 MultiMesh custom data，不增加移動階段提交成本。一般道路／木橋各 1 個 surface；有柱道路另保留柱底特殊 surface。雲、柱底漸變／生長、端點發光、透明特效、2D UI 及任意外部匯入模型保留特殊材質。離線轉換只讀取目前本地模型，不重生原型或重設地圖；規格與重建入口見 [材質說明](assets/materials/README.md)。材質共用不保證引擎 program 數或所有載入時間下降，需實測。
- Routing Sandbox 已恢復迫擊砲、弩砲、空艇舷炮、交叉火力與兵營，Sentry 保留現版設定。五塔資料來源與差異見 assets/data/towers/README.md；新版塔生命／威脅預設不是舊版平衡值。catalog 明確列在 card_shop.tscn，維持新版塔種等權洗牌袋；每塔獨立地塊候選，原四種道路變體等權，兵營空道路配置仍需覆蓋既有道路。舊塔 VolleyAttack 保留出生順序優先、精確圓形距離或方向格範圍；迫擊砲改為固定實際落點的拋物線飛行，落地才對當下球形範圍內敵人結算；Phase 5 傷害 24／爆炸半徑 1，交叉火力命中範圍內全體。
- 兵營部署兩名友軍，駐點為前方道路並防止後續塔覆蓋；接戰只暫停敵人固定行程，不改 route／waypoints、不增加導航障礙。原生命 40、5 秒重生、局部道路移動及敵人反擊由資料與實例分開保存；現有三兵種反擊沿用原 grunt／runner／brute 值，新兵種未設定時傷害為 0。暫停、目標／友軍死亡、塔移除、波次結束與卸載須釋放接戰。舊模型、後座、視覺爆散與射擊音在 Sandbox 自足；不依賴舊專案執行，也不帶回舊法術、Boss 或商店架構。

- 塔的攻擊範圍由 TowerDefinition.attack_area 引用獨立 TowerAttackArea `.tres`，以 anchor 相對 Vector2i 格子清單定義，與卡牌 90 度順時針同步旋轉；空引用才回退到包含邊界的 attack_radius 圓形。預覽、實際索敵與威脅必須共用同一範圍；自訂範圍不受 attack_radius 再裁切，不能讓範圍外較近的敵人搶走目標。威脅相加，鄰塔數仍為八鄰格、不含本格。Sentry 使用 ranges/sentry_forward.tres，實際形狀以目前 offsets 為準，允許直接在 Inspector 修改；局部 -Z 為前方。最初的 3×5 格設計圖僅作為獨立回歸範例，不用來覆寫設計師的資源。威脅評分與實際傷害分開。
- 戰鬥系統在敵人移動後建立共用格子索引；塔查詢覆蓋格，不逐塔掃全圖。瞄準持續平滑更新，對準後才發射；預瞄不擴大實際射程。
- 箭矢追蹤原目標、抵達才扣血；光束立即結算；拋射物飛向固定落點、落地時對範圍內仍在場的敵人結算。發射時快照傷害與效果，塔消失不取消已發射攻擊。
- 護盾先於生命扣除。一般同類 effects 不疊加（Phase 3 冰霜是獨立可堆疊種類），只保存一份「最佳強度＋最長剩餘時間」的合併狀態；新效果時長與既有剩餘時間取最大，不相加。減速取最低速度倍率，即使較弱效果提供較長時間，最強減速也維持到合併時間結束，不退回弱效果；圖示跟隨最強效果。不同效果種類可各自存在。死亡退出波次及顯示；擊殺與抵達分開統計，接戰敵人可反擊兵營友軍。
- 共用 Resource 保存設定，即時血量、位置與冷卻屬於實例；可變攻擊資料需實例獨立。技能條由 Phase 4 爆破手用於施法前搖；能力計時與癱瘓來源仍屬於實例。
- 正式 Soldier／Quickfeet／Heavy 使用專案內 grunt／runner／brute 外觀，各有單一 surface 網格與獨立 MultiMesh，三者共用 `solid_color.gdshader`。Troop 的 GPU Model 引用離線網格與步態 Resource；Quickfeet／Heavy 直接烘焙目前保存的來源場景，不重建原型，保留配色、武器、支點與原 Walk 的 17 個線性插值關鍵影格。Soldier 維持依距離推進、停止回中立；Quickfeet／Heavy 維持依模擬時間推進、停止凍結姿勢，Quickfeet 保留 3 倍播放。正式敵群不建立逐隻模型或 AnimationPlayer；各模型獨立緊密 slot 與容量，全敵群頭頂狀態另有獨立順序，開波依模型合計人口預留。任意匯入模型未提供相符 GPU Model 時仍保留原材質／骨架／動畫。修改來源後需重新烘焙，入口與限制見 `assets/models/enemies/README.md`。視覺避讓使用固定工作量，不改邏輯位置、速度或路線；轉彎時忽略接觸並保留偏移。
- 頭頂血量／護盾／技能／效果採共用 overlay 中的單一 MultiMeshInstance2D，依原繪製順序以共用材質及圖集合批，一次提交可重用 buffer。外觀仍取自可編輯 Appearance；矩形邊框由 shader 保持清晰，其他樣式一次烘焙。敵人清空時清除可見 instance 與圖示快取；暫停移動鏡頭時仍重新投影，不能停在原畫面位置。
- 地塊連接與外觀分開。柱子與木橋保留合法舊配置，固定 seed 與修改順序可重現；不能為外觀變種更改導航或兵種成本。
- 3D 純色材質只允許兩組 StandardMaterial3D 功能旗標，以 SolidMaterials 為準：不透明為頂點色＋emission_enabled（預設黑），半透明為 Alpha＋無光照＋雙面＋頂點色；場景與 .tres 只能改顏色與數值。每多一種組合約多編譯 5–6 個 WebGL program，會造成數秒凍結或拉長載入。材質釋放時若是該組合最後使用者，shader 會刪除，下次重新連結。BurstEmitter 於載入時預放一個次像素特效留在回收池，同時讓半透明組合常駐。舊 model 沒有 set_preview 時，hologram 保留原色，只關陰影，不換材質。
- 地圖先提交，浮起動畫在獨立顯示層處理。只更新差異格，保留未變模型與連續動畫進度；完成後回到靜態合批。
- 雲海與柱底漸變使用 Compatibility 可用的近似，不依賴體積霧或 Forward+。死亡／AOE 特效可編輯且回收，不影響傷害與波次結算。

## UI、命名與素材

- 2026-11-05 [Art Slice F塔種識別色](docs/art_slice_f.md)：暖灰白建築主體保留，只在功能區使用青綠／鋼藍／赭金／磚紅／灰紫／青藍。可重建設定在 assets/data/rendering/tower_color_identity.tres，Variant預設B，A為原暖灰白回退；不改卡牌accent_color。離線build_integrated_towers的--identity僅建立color_identity/b/共享網格，與A只有COLOR不同，沿用solid_color材質與原動畫。正式／Ghost同factory套用，沒有新增遊戲UI。A/B各84放置／旋轉及事件動畫、三組GPU比較、網格資料與重跑hash檢查通過；本輪未測Web／真人辨識。GLB更換時先重建integrated A，再重建B。

- 2026-11-05 [Art Slice E正式接入](docs/art_slice_e.md)：六塔TowerDefinition.visual_model引用assets/models/towers/integrated/的獨立wrapper；TowerBodyVisual依實際body適配，舊model保留不相容形狀fallback與音效。GLB衍生純色網格離線合併，同組六塔共31個mesh instance。imported_tower_visual由真正攻擊／部署事件播放一次性動畫；十字按實際ALL命中方向、空艇按左右舷分開；巨弓拉弦不延遲權威傷害或更改冷卻。新預覽與正式模型同源，保留原色與既有格面紅綠提示。Lv2/3維持數值／標籤，本輪使用相同Lv1幾何。桌面整合／既有回歸已通過；Web匯出受缺失路網WASM阻擋，未通過Web驗收。

- 2026-11-05 [Art Slice D](tools/assets/blender/art_slice_d/model-spec.md) 完成六塔第一版功能配色、10個一次性動畫與Godot資產準備。新資產限於 assets/models/towers/art_slice_d/，含GLB、.import、獨立外觀場景及共用solid_color離線烘焙網格；尚未替換正式模型／TowerDefinition。十字四向與空艇左右舷動畫保持獨立；專屬匯入腳本清除Godot補入的不相關方向固定軌道。正式接入仍需TowerBodyVisual、砲口／瞄準NodePath、事件與冷卻時序、升級／預覽適配，不將巨弓約3秒視覺片段視為新的攻擊間隔。Blender來源與預覽仍在工具側。

- 2026-11-04 [防禦塔家族純建模](tools/assets/blender/tower_family/model-spec.md)：以巨弓C為風格基準完成哨塔、兵營、迫擊砲、十字火力、飛行艇的Blender／Python／GLB及比較圖，均為工具側Art Slice，無動畫或正式接入。實際占格分別1×1、1×1、2×2、2×2、1×2；迫擊砲不同preset的角落錨點不同，未來外觀掛載須依規格調整，不移動邏輯錨點。巨弓未重製；空艇固定支座與Airship分離，六砲位於艇身。仍未完成Godot材質烘焙與TowerBodyVisual掛載。
- 2026-11-04 [Great Ballista 第二輪](tools/assets/blender/great_ballista_round2/model-spec.md) 依使用者指定以C / Detailed驗證兩色與攻擊動態，仍為工具側Blender Art Slice：暖灰白＋少量功能深色，3秒簡單pivot循環；本輪不改正式戰鬥、不強行接入Godot。C作為這次實驗基底不等於已選為正式遊戲模型，後續採用仍依使用者指示。

- 2026-11-03 新增專案 [3D Modeling Skill](.agents/skills/bwar-modeling/SKILL.md)：後續 Blender MCP 建築製作先讀該 Skill；美術以「遠看迷宮、中看戰術符號、近看微縮結構」、單主色與功能幾何為準，沿用格子、朝向、TowerBodyVisual 與純色材質契約。Blender 原始檔／Python 存於 tools/assets/blender/，正式接入的 GLB 存於 assets/models/ 對應分類，Godot 外觀以 .tscn 包裝。Skill 初建當次僅文件；2026-11-04 的 [Great Ballista A/B/C](tools/assets/blender/great_ballista_slice/model-spec.md) 為獨立 Art Slice，GLB 暫存在工具側 exports/，沒有接入 Godot；三版只是細節密度實驗，尚未選定正式版本。

- 保持畫面簡潔：透明頂部時間線、金幣、倍速與暫停；商店直接展開在遊戲畫面，不加全畫面遮罩。一般遊戲不常駐顯示除錯統計；tooltip 僅用於已明確定義的快捷鍵、兵種名稱與持有遺物說明。
- 手牌與商店共用鏡像弧形排版；hover 上提 6 原始 px，手牌選中時上提 24 原始 px（Hand 的 Selected Lift），選中／hover／還原從當前位置平滑過渡，選取切換預設 0.22 實際秒（Selection Seconds）。選中卡面以 ±0.6°、3.6 秒週期緩慢搖動，取消選中在 0.22 秒內淡出搖動；參數在 card_view.tscn 的 Selection Motion。搖動只作用於 Visuals 子節點，外層 Button 命中區穩定，不放大或置頂；上提的命中延伸跟隨實際上提動畫，保留原下緣位置。
- 時間線由關卡資料生成；UI Slice A 預設以目前 ACT／波次、接下來兩個波次及沿途遺物節點顯示（未來波次空心圈、遺物雙菱形，不另畫底部進度條），hover 展開全部 ACT，點擊可固定展開／收合，0.18 實際秒平滑過渡。中心錨點固定，ACT 最後一波用分隔線，進度從左至右裁切填色，戰鬥停在當波節點。
- 每個入口的開波提示在準備期常駐顯示：上方水平置中的「開始下一波」／「Start next wave」，下方將該入口實際出發的兵種圖示由左至右排列。點上方文字開始整波；每個圖示有獨立邊框，平時只顯示圖示，hover 時以 0.15 秒向旁展開為「圖示 ×數量」，離開收回。圖示點擊暫停並開啟進度頁的該敵人，不觸發開波。標題／空白 hover 限於該入口全部，圖示 hover 再限縮至該兵種；離開整組提示恢復全體，暫停／失焦／離窗清除 hover。固定螢幕尺寸隨入口投影定位，不因鏡頭縮放或 hover 放大；部分出界由視窗裁切，完全離畫面才隱藏。
- 整個開波標題與橫排圖示包在先前淡色底、青灰描邊、切角及下方置中尖角的對話框內，準備期常駐顯示；不使用菱形驚嘆號或垂直兵種列表。對話框左右內距 12px、上下內距 8px、尖角高 8px，依內容調整寬度。標題 16px，下方圖示框 34×34px、圖示 24×24px、框間距 6px，橫排整組置中；只有當前 hover 的框顯示 14px 數量。數量依入口跨群組加總，不顯示全波總量；零配額入口顯示 ×0。超過 480px 的橫排可水平捲動，保持單列。
- F1 顯示當波各兵種實際完整行程與目前入口圖的全部 vertex，節點以深色圓點及 V 編號標示，編號對應 graph.nodes 的 id；準備期用同配額預覽。節點隨 graph_changed 更新，不改動已固定的當波行程；關閉 F1 一併隱藏節點。F2 顯示威脅及地塊資料。預設關閉、各自切換，F3 已移除。
- Routing Sandbox 第一階段：正式關卡準備期在每個起點上方顯示置中的開波標題與橫排兵種圖示，hover 圖示時才展開該入口跨群組加總數量。預設預測全體；hover 標題／空白時限於該入口，圖示再限縮該兵種，離開整組提示恢復所有入口。動畫相位取自篩選後的完整配額行程：保留每條有向邊及實際轉彎的所有抵達步數，不再以區段聯集的 BFS 首次抵達時間代替，長短支路匯流與環路重訪均須接續至終點。相同行程及相同抵達間距去重，最近相位查表只在資料失效或首次使用篩選時建立，shader 固定工作量查詢，不逐行程迭代或增加敵人移動成本。道路中心線統計現有 WaveSpawnSchedule 不洗牌排程的完整配額行程，按兵種／入口／有向格子區段累加，不修改搜尋或消耗出發 RNG；資料失效才重算，hover 不重算排程。中心線以共用 mesh／shader 顯示相對流量，流量越高筆觸越粗、越清楚；進出流量不同時，線寬及透明度在轉彎／直行接點平滑銜接，不以整段較小流量造成突然變寬；雙向路段重疊於道路中央，仍分別保存有向流量與動畫相位；直段筆直，所有實際 90 度轉向（包含匯流／分岔）皆為局部圓角，只有一小段前後漸淡的米白筆觸沿路滑行，移除永久底線，筆觸顏色及長度可調；接點以實際轉向的相位及中央圓弧接合，內部使用互補裁切且不畫圓頭端帽，只有完整行程起終點保留圓頭；每個四分之一圓弧由一個解析 primitive 表示；單格 primitive 上限為 48，涵蓋四向轉向及起終點，仍只繪製一份格子 quad。岔路以線形聯集一次計算透明度，不因重合加深，不使用箭頭、虛線或發光；開場等待、戰鬥、ACT 選入口、暫停及完成時隱藏。F1／F2 開啟時暫時隱藏玩家中心線，原除錯用途不變。
- 塔名與地塊前綴分開保存翻譯 key，完整卡名依語言組合；支援英文及繁體中文，缺少語言時回退 zh_TW。不要硬存完整卡名。
- 卡面、價格、端點、時間線及特效的共用範本放各功能 `components/`；外觀優先由可編輯場景／資源提供。詳細字級、動畫與素材規格見系統文件與各目錄 README。
- `@tool` 卡面接收 Resource.changed 時，編輯器更新需合併延後並確認必要子節點已完成重建；離場實例忽略通知。卡面相容已開啟場景的舊根節點 artwork 與新版 Visuals，不為熱更新直接修改編輯中的場景樹。
- 波次編輯器的 tool 腳本熱重載不代表既有 dock 的節點樹已更新。缺少 ACT／波次控制項時，從目前保存的場景重建該 dock 的子介面，保留根節點、關卡 Resource、選取、待切換資料、dirty 簽章及 Undo／Redo 目標；重新登記 unique owner 並連接新控制項，離場通知不存取 UI。舊 `enemy_walk.gdshader` 路徑只作編輯器分頁相容入口，與正式 solid_color shader 共用同一份 include 實作，不新增執行期材質。
- 共用常數使用 `class_name XxxConstants`、`extends RefCounted` 及大寫 const，不為常數建立 Autoload 或逐實例 Resource。場景 export 覆寫優先於預設。
- 原型素材透過離線工具產生；遊戲不能依賴另一專案路徑。重建素材前檢查手動修改，更新 tile library 不等於重設地圖；`--demo` 會覆寫示範地形。

## Construction Prototype：獨立建造實驗

- `tests/construction/playground.tscn` 用 F6 執行，A 舊版即時、B 複合即時、C 複合批次；切換重開。F5 Frontier 維持原規則／候選／數值。六張卡、60 Gold、B 補缺牌、換形與無敗北都是明示測試補助，六波混兵仍走原商店、手動開波及戰鬥。
- 沿用 BuildCard／TilePreset；複合配置新增穩定 ID、完整占格、塔偏移、允許旋轉與逐格四向接口。五模板在 `assets/data/construction/presets/`；空接口字典保留舊相鄰規則。道路同格合併允許接口，不同相鄰格只有雙向同意才連通；外觀和導航共用最終 layout。此版占格只含道路與塔基座，不支持額外裝飾地形。
- ConstructionBatch 只保存手牌索引／引用及草稿幾何；可選、移、轉、排序、撤銷。中間可以斷路，不能非法重疊；預擺不耗牌、不改地形、歷史或 RNG。確認與開波前重驗完整聯集、所有入口及原 WaveSpawnSchedule，失敗維持可編輯狀態，成功同步提交並一次耗牌；無草稿亦可開波。同種牌升級已建塔不新增道路，草稿塔需先確認才可升級。交通設施仍單獨即時放置，有草稿先處理草稿。
- 預擺排程使用隔離的原生圖、成本與歷史副本，流量標示為預測；正式敵軍維持固定行程。一次確認只記錄最終拓樸，同波誕生規則與 Scout／Winged 硬性選路保留。失敗開波恢復原商品，不重抽或給獎勵。
- 幾何獎勵僅 B／C 安裝管理器後啟用：弩砲前方連續 5 道路格延伸前緣射程 1 格；交叉火力 2 格內有真實度數 ≥3 的路口，傷害加成 +10%。以雙向接口計算、每塔不重複疊加、幾何失效撤回，保留升級／遺物並共用預覽／射程／威脅。不改共用 TowerDefinition。
- 詳細限制、九組 A／B／C 對照與當次證據見 [construction_prototype](docs/construction_prototype.md)。較大路網不代表獨立防守區；兩 L 反向即時放置亦可完成，批次的已驗證收益是順序容錯。已做 Windows 邏輯／真渲染輸入與相關回歸，真人、Web、release、效能及完整十五波未重測，停在人工接受前，不自行整合 main。

## Tower Tile Editor：獨立多格塔編輯與即時測試

- 路肩受光面也要有深度提示：RoadSurface在實際路肩根部的路面內側，以頂點色產生0.06格寬、0.46強度的漸淡接觸暗部，坡面亦使用逐頂點漸層；不只加深背光面，不沿內部格界描線。雙向相機驗證場景為 tests/road_refinement/bank_contact.tscn，世界光源固定，確保兩側均有對比。

- 2026-11-03 後續視覺修正：道路行走面Y=0、路肩Y=0.065，外界0.045格斜面形成凹槽；塔／石地基礎保持0。開放木橋與實心鄰格分開計算邊界，橋頭接合面在同一網格內，側面已有地面則使用連續石路，正常鏤空保留。WideRoadFlow依完整雙向道路臂及共用交會區，把原完整行程投影到寬路中央，反向及所有到達相位獨立，換道保留原時間作停留，候選預覽傳原proposal.snapshot；不改導航、戰鬥、模型或數值。十案例、四向橋頭／凹角、GPU像素及真實三兵種配額驗證見 [道路修正](docs/road_visual_and_placement_refinement.md)。


- 2026-11-03 道路修正：TileVisuals 以獨立顯示 MeshLibrary 繪製同層雙向接口的連續路面，四格角落只在四邊皆連通時補滿；外側倒角、柱子／合法窄木橋與浮起動畫保留，塔體方向沒有出口。塔下逐格重複木板與兵營補塊已移除，原武器基座保留並貼地。RoadEditGuard 的 block-cut 聯集新增 route_cells 作結構性灰化，僅基地至啟用入口的完整 simple paths 有效，不以候選池／配額判色；死路新增即使不重建導航亦刷新。詳細規則、人工場景、Windows native重建與本輪測試見 [道路與放置修正](docs/road_visual_and_placement_refinement.md)。本輪依新任務明確不 commit／merge／push；之前 Git 授權只屬已完成的上一輪。

- 2026-10-26：內建可獨立排除測試資格／隱藏清單，均保存於 catalog；具名組合保存塔種＋配置 ID 白名單、內建排除選項與目前選擇，不複製幾何或權重。只有成員可實際抽取、補牌、放置及用作升級卡；TowerMap 提交亦驗證，空池不能回退內建。切換／套用組合或改變內建參與會重開獨立測試關卡，清除上一組塔、手牌及商品；編輯器內操作於返回時重開。交通設施保留獨立原池。新配置須明確勾入既有組合。
- 2026-11-03：五塔正式採用原「基礎版」二十份 preset，加既有兵營一份；catalog 組合以 variant_group=base 標記，TowerDefinition.preset_group=base 的抽牌讀同一組合的成員與最新權重，切換獨立測試組合不改正式來源。新外觀依 footprint 組裝完整弩架／船身／砲座，Lv1–3 切換組件，不再用額外一格高方塊填塔身；哨塔 Lv4 以上保持 Lv3 外觀。全部占格仍屬同一座塔。詳見 [塔體與預覽](docs/tower_visuals_and_preview.md)。

- 入口為 `tests/tower_tile_editor/editor.tscn`／`playground.tscn`，是 Godot 獨立可執行 Scene，不是 Editor Dock。準備期開啟編輯器會凍結世界並隔離關卡輸入，關閉時還原；不可讓鏡頭攔截繪圖拖曳。一次一張、合法即提交，不安裝批次控制或幾何加成；舊 Construction Playground 繼續獨立保留。
- TilePreset 的非空 `tower_footprint` 以放置原點保存完整塔體，覆蓋該卡的 TowerDefinition footprint；空值保留舊規則。同一 TowerDefinition 可配多種連通形狀，不複製塔種／戰鬥設定。塔錨點須在塔體內，`facing_steps` 與地塊旋轉疊加；`default_rotation` 須在 allowed_rotations。model_offset 是塔自身朝向下的視覺位移。新多格迫擊砲／十字火力以整體塔體中心作攻擊原點與圓形範圍，側舷砲雙側各 2×3 隨朝向旋轉，弩砲以最長縱列的前緣作射線方向；實例、預覽與威脅共用 TowerBodyGeometry，位移不改幾何中心。自訂兵營 home_offset 也以放置原點保存，須在可通行路網，不能在塔體內。
- 一次放置只建立一座 DefenseTower。occupied 的每個格子回查同一實例；升級任何占格不新增地形，死亡清理全部占位。實例與已取得卡牌保留配置快照，新存檔不能改寫既有占位／行程。
- 編輯器支援拖畫、原點／錨點、接口、旋轉檢視、Undo／Redo、存取、複製、改名、預設及權重。manual_ports 可明確保存零道路的手動模式；內部接口須雙向一致，未使用的向外接口保留但不當作有效路線。
- 自建 `.tres` 與 catalog.tres 存於 `assets/data/tower_tiles/user/`，首次儲存才建立。內建檔不覆寫；複製新 ID，改名保留 ID。刪除是經確認的候選封存，保留原資源以保護引用。候選權重立即套用獨立 Playground 真正的商店抽取；預設僅控制選單，不調整權重。基礎版成員亦正式接入 Frontier 候選，六塔傷害／攻速／價格／升級曲線保留。
- Playground 明示 60 Gold、免費補牌／重抽、空手牌、無敗北、六波手動混兵；同塔不同配置可並存。只在預覽改變時計算隔離的未提交完整排程，不能改路線歷史或消耗 RNG；取消、非法位置、暫停／開波時恢復正式預測或隱藏。金色新增道路、淡青合併道路、青色塔體、橙紅被阻擋道路須與最後一份完整候選一致。
- 使用、驗證與限制見 [tower_tile_editor](docs/tower_tile_editor.md)。Windows 直接 runtime 已驗證，Editor 的 SAC DLL 封鎖仍屬已知環境限制；未修改系統安全設定。待人工驗收，未 commit／merge／push，也未執行 Web／release／效能／Frontier 全長局驗收。

## 維護、建置與驗證

- 結構責任見 [architectures](docs/architectures.md)。依功能放置腳本、場景、測試及報告；詳細索引保留在各目錄，不塞入架構導覽。
- `scripts/` 的功能根目錄保留主要協調器；關卡／卡牌 Resource 型別放各自 `definitions/`，出生排程與敵群放 `enemies/spawning/`，地形端點放 `map/terrain/`，地塊資料集合放 `map/tile/`，候選與配額放 `navigation/routes/`。敵人的螢幕 UI 使用 `presentation/`，3D 模型與避讓使用 `rendering/`；小型功能保留平面結構。目錄與協作細節見架構文件的 scripts 章節。
- 搬移腳本保留 `.gd.uid`，搬移場景保留 UID；同步修正場景、資源、外掛、測試、工具及文件引用，不能只靠舊 UID 兜底。
- 工具搬移要檢查根目錄推導、C++ include 與動態報告路徑；測試／工具變更要檢查匯出排除設定。
- `native/godot-cpp/` 是固定版本依賴，不當成遊戲內容修改。建置輸出為 `bin/road_graph.candidates.*`，擴充不可熱重載，更新後重啟 Godot。版本與命令見 [native/README.md](native/README.md)。
- Web 使用對應版本、支援 GDExtension 的匯出樣板與 wasm；維持單執行緒及 Extensions Support。服務與部署需符合現有 COOP／COEP 設定。
- 依變更執行相關回歸；純資料／排程可 headless，滑鼠、像素與動畫檢查需實際渲染，波次編輯器需實際 editor。命令見 [tests/README.md](tests/README.md)。
- 功能回歸依系統分類保留；一次性壓測、重複純預覽與歷史原始輸出已清除。測試 JSON／截圖使用 `tests/fixtures/test_artifacts.gd` 寫入 `.godot/test-results/<功能>/`，log 與其他暫存也放 `.godot/`；不重新累積到 `reports/`。需要長期保存的結論才整理成精簡摘要。不可將歷史通過結果當成本次執行，未跑的檢查需明說。
- 只修改文件時檢查文件分工、連結與描述一致性，不必為此重跑整套遊戲測試。新決策同步寫入本文件，並更新受影響的詳細說明。

## 效能測試共識

- `experiment/optimize_graph` 合併 main、尚未合併 outer_game_ui 時的歷史量測見 [2026-10-24 Windows／Web](reports/merged_graph_performance_2026-10-24.md)：32×32／801 道路格／16 塔／256 混兵，各三輪、每輪首次與再次開波。Windows RTX 的兩波平均約 12.29／12.27 ms，Web AMD 約 20.86／20.28 ms；冷建池約 33.62／37.39 ms。Web 首次出兵至首個繪製幀約 4.87 s，再次約 0.13 s，該次版本無顯示預熱。這是獨立試驗場的現況，未做版本 A/B，未量測準備期中心線；不同 GPU／建置與歷史版本不能直接相減。Web 原生擴充須重建至包含批次候選 API 的版本，不可沿用其他分支的舊 wasm。

- `experiment/optimize_graph` 已整合 `feat/outer_game_ui`：保留 C++ 去環、候選建池、批次配額與共用移動資料；顯示預熱僅由 DisplayWarmup／Boot／ScreenTransition 與 LevelSession 準備契約處理，不恢復舊 EnemyWave 自動預熱或 LoadingOverlay。正式入口先預熱再進主選單，直接執行試驗場則不經啟動預熱。

- 完整行程相位修正（接點裁切前版本）的 Web 對照見 [2026-10-24 流量亮段](reports/road_flow_continuity_2026-10-24.md)：25×21、255 道路格、雙入口、256 人下一波配額，量測準備期預覽而非 256 名存活敵人。相位表使用 RGBA8 雙 16-bit 距離，避免 Web 浮點紋理讀回截斷；Windows／Web 均保留應亮起與應透明的像素驗證。平均／P99 與同步重建成本分開記錄，不據此宣稱戰鬥或載入效能改善。
- 不透明純色模型共用材質的 Web 對照見 [2026-10-23 共用材質](reports/shared_material_2026-10-23.md)，原始資料在 `.godot/test-results/rendering/shared_material/`。AMD／Edge、新舊交錯各三輪、809 格／256 混兵，啟動中位數 31.68→20.11 s，啟動 shader stage 編譯提交 130→110；首／次波平均 17.08→15.67／18.60→16.06 ms，P99 幾乎不變，首次仍約 0.29 s 尖峰，選圖至關卡 2.01→2.24 s。此為材質共用與道路 surface 合併的合計效果，不宣稱所有載入階段或硬體全面改善。

- 三種兵各自 MultiMesh／共用 GPU 動畫的本次 Web 對照見 [2026-10-23 GPU 混兵](reports/enemy_gpu_batches_2026-10-23.md)，原始樣本在 `.godot/test-results/enemies/gpu_batches/`。本次為 809 道路格的 32×32 合成地形，與舊 801 格配方不同。三輪中位數第一／二波穩態平均 22.39→18.00／21.93→18.83 ms；載入未縮短，首次既有非敵人 program 尖峰仍存在，且保留一輪明顯變慢的結果，不能宣稱全面改善或尖峰已消失。

- 主選單前共用顯示預熱見 [2026-10-23 啟動預熱](reports/startup_warmup_2026-10-23.md)，原始資料 `.godot/test-results/menus/startup_web/`。正常 Frontier 四名 Soldier，舊選圖後預熱對照一輪、新啟動預熱兩輪；進關卡約 11.56 秒改為 1.65–2.22 秒，首次出兵兩種流程均無秒級停頓。新流程到主選單約 31.61–34.24 秒，包含 Godot／WASM 與選單自身首次繪製，不宣稱總啟動或 FPS 改善；未重跑 256 人負載。

- 正式 Frontier 的載入分項診斷補在 [2026-10-23 載入整合](reports/loading_transition_2026-10-23.md)，原始資料 `.godot/test-results/menus/normal_loading/`。預熱每兵種僅一個代表，包含全部 ACT 的兵種；不可把合成 256 人負載的 8–9 秒當正常關卡基準，或把全兵種預熱時間直接與第一波 Soldier 出場停頓相比。該次控制樣本有異常長幀而未用於改善幅度比較。
- 同報告的 WebGL 呼叫補測已定位首次顯示的秒級阻塞：Soldier／Quickfeet 材質的一般與 USE_INSTANCING 程式共四次 LINK_STATUS 等待約 8.95 秒，全部 program 查詢約 9.79 秒；原始資料 `.godot/test-results/menus/webgl_diagnosis/`。這是特定 Edge／AMD 的單次編譯／連結路徑證據，未細分 ANGLE 與驅動，不宣稱模型本身必須預熱固定秒數。

- 選單轉場的顯示預熱整合及相同 Web 負載複測見 [2026-10-23 載入整合](reports/loading_transition_2026-10-23.md)，原始資料在 `.godot/test-results/menus/loading_256/`。預熱將一次性成本移至等待，仍有約 0.33–0.50 秒遊戲尖峰；不把少量樣本的穩態平均差異宣稱為 FPS 改善。

- `feat/outer_game_ui` 從真實主選單、選圖與本局設定進入正式 level 的 32×32／256 混兵 Web 結果見 [2026-10-23 選單路徑量測](reports/menu_performance_2026-10-23.md)，原始樣本在 `.godot/test-results/menus/mixed_256/`。此分支該次尚無 reduced_graph 的候選優化及敵人預熱，不能把跨分支差異歸因於選單；該次一次性工具用完清除，只保留摘要及原始資料。

- 已完成的一次性極端負載、狀態 A/B 與複雜路網 256 混兵場景及專用 benchmark 工具已清除，仍有價值的數字見 [2026-10-20 歷史摘要](reports/performance_2026-10-20.md)。該摘要不是目前版本的執行證據，也不再提供已移除的重現入口。
- 未來量測使用合成地形與獨立實例，不改正式關卡或數值；同時記錄平均、P95／P99、一次性規劃／生成停頓及當次原始樣本。headless Windows 不用來推估渲染幀率，Web 的 rAF 上限、實際 GPU 及建置模式需明列。
- benchmark 程式、舊版對照副本與功能回歸中夾帶的重複計時迴圈已移除；保留功能斷言及必要的工作量上限驗證。新的一次性量測工具用完即清除，只保留當次原始資料與精簡結論。
- 使用者要求保留可操作的 `tests/enemies/mixed_256.tscn` 重現相同負載，屬於獨立手動試驗場，不含自動計時／採樣。手動開波、清場重開以保留已載入資源，及重新載入場景均不更動正式關卡；對應 Web 測試匯出可保留供使用者操作，操作與匯出見 tests/README.md。
- Web 的 32×32／256 混兵量測見 [2026-10-22 Web 摘要](reports/web_performance_2026-10-22.md)，原始資料在 `.godot/test-results/navigation/web_current_256/`。場外視窗曾停止推進，正式數字改用可見視窗；固定模擬 delta 不代表實際 FPS 上限。冷啟動／首次生成須與暖機後幀時間分開記錄。
- 遠景必須確認相機 near／far 與實際地形／模型均在取景內，不能只看頭頂 overlay 的可見座標。
- 2026-10-20 歷史量測記錄 Godot 使用 RTX 3050、Edge 使用 AMD 內顯；2026-10-23 本次 Windows 渲染 log 為 RTX 4060 Laptop。每次比較以當次 log 確認實際 GPU，不沿用舊機器描述；可透過瀏覽器啟動參數作獨顯對照，不修改系統設定。
- 狀態已採單一 2D MultiMesh；投影、buffer 填寫與模型更新仍有 CPU 成本，不能從節點數推論所有成本已消失。大型多入口規劃仍有同步停頓；不據短測宣稱通用敵人上限或長時間無記憶體洩漏。

- 去環的 32×32 合成地形、256 混兵與 16 塔量測見 [2026-10-22 摘要](reports/loop_erasure_2026-10-22.md)；當次原始樣本位於 `.godot/test-results/navigation/loop_erasure_256/`，不能將該短測推論成通用敵人上限。候選池去環增加一次性建池工作，移動階段不執行去環。

- 摘要延後、批次配額與波次內共用世界座標的後續 A/B 見 [2026-10-22 摘要](reports/route_batch_2026-10-22.md)。該次冷建池與排程中位數下降，但實際渲染未測得穩態 FPS 或整批模型生成改善；勿把 headless CPU 排程收益等同於渲染收益。

- 候選運算移至 C++ 的對照見 [2026-10-22 摘要](reports/native_candidates_2026-10-22.md)：本輪冷建池中位數降低約 62%，完整路線與配額一致；排程與實際渲染未測得改善，渲染尾端較高，勿把建池收益宣稱為每幀收益。

- 後續 [P99 判因](reports/p99_investigation_2026-10-22.md) 確認測試期間 CPU 有效執行速度波動，沒有發現候選 C++ 搬移增加每幀工作。比較尾端時固定模擬步數並核對戰況／工作計數，以直接逐幀探針分段；Performance.TIME_PROCESS／TIME_PHYSICS_PROCESS 是定期更新監視值，不當作每一幀的分段時間。保留慢樣本，同時記錄 CPU 校準或硬體效能計數，不能因三輪 P99 不同便推論演算法回退。

## 交接與後續範圍

- 交接快照與啟動檢查集中在 docs/HANDOFF.md；文件修正不代表功能變更。測試須區分本次 PASS、歷史 PASS 未重跑、FAIL 與 NOT RUN，不能沿用舊報告當新證據。
- 目前仍是 Routing Sandbox，尚未整合到正式專案／main。Phase 5 已依後續明確指令實作五 ACT、經濟、Boss 與量測；平衡是第一輪候選，不是人類樂趣或正式發布驗收。特殊事件不在本次範圍。
- Phase 1–4 的 Offboarding 原為文件與非破壞性驗證；本次使用者另授權 Phase 5 實作與平衡工作，現停在人工接受。2026-11-03 使用者已授權完成 origin/main 合併、Merge Commit 與 stash apply；恢復的本地修改保持未提交，保留 stash、不 push，不修改正式或舊專案。後續工作依新的使用者指令界定範圍。

- 2026-11-03 後續使用者要求「git更新並push到遠端」，授權提交目前相依的施工／塔牌編輯器／基礎版資源與20＋1更新，並正常推送 origin/experiment/routing-sandbox；先前未提交／不 push 註記屬於授權前歷史。仍不修改 main worktree，不進行 merge／rebase／reset／clean 或強制推送。

## UI Slice A：Combat HUD 與 Enemy Codex（2026-11-06）

- 遺物收藏入口改為實際持有的圖示列，重複遺物共用圖示與數量；hover 顯示名稱／效果，點擊開詳情。空持有不顯示空槽；獎勵／效果／RNG 不變。
- 取代 Phase 4 的常駐敵軍情報入口與準備期發現：只接 EnemyWave.enemy_spawned，按 Troop.troop_name 每局第一次實際出生記遭遇並排未讀通知，不暫停、不搶焦點。已遭遇與已閱讀分開；點通知後才暫停，同一面板依序閱讀，關閉／Esc 讀完目前頁再前進，最後恢復原狀態。每局只通知一次，跨局只保存圖鑑解鎖。
- 暫停選單新增敵軍圖鑑，未解鎖列顯示問號；下一波圖示開啟進度頁，同樣尊重解鎖，不提前揭露／標記遭遇。詳細頁共用實際模型的獨立靜態 SubViewport、Resource HP、在地化類型與玩家語言的路線描述，不展示 Softmax／內部權重。
- LevelHUD.begin_inspection/end_inspection 為單一詳情頁的暫停擁有權，沿用收牌與遮罩，鎖住鏡頭並保存原 HUD／外部暫停、倍速及焦點，拒絕詳情頁重疊。共用 inspection_panel 只管輸入焦點／Esc，不管理戰鬥。
- LevelProgress 沿用 user://level_completion.cfg 的 v1 progress 格式，另存 codex.encountered（PackedStringArray）；舊檔缺少 codex 時為空，儲存保留通關及其他 section。不保存當局通知、血量或進度。細節／測試見 docs/ui_slice_a.md。

- 2026-11-06 UI Slice A 頂列追修：防線改盾牌＋目前數值，與金幣／遺物／時間線／通知／速度及暫停同高；整列依可見項目置中，項目間距16px，兩側圖標跟隨時間線展開／收合平滑移動；空遺物／無通知不留固定槽。防線、金幣、操作與時間線波次／遺物節點均有淡紙色 hover 資訊；遺物標記依 ACT 及 reward_final_act 產生，正式四個，沒有第五件。見 docs/ui_slice_a.md。

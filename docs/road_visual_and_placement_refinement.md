# 道路視覺與建造裁切

## 本輪：凹槽、橋頭與寬路流線（2026-11-03）

開始時核對 HEAD 仍為 `4b0d2fe`／分支 `experiment/routing-sandbox`，保留上一輪全部未提交修改。本輪沒有 commit／merge／rebase／reset／clean／push，未操作 main worktree。Git diff 中的塔模型與 C++ 改動屬於上一輪；本輪只修改地表顯示、流量顯示與預覽幾何交接，不改導航、戰鬥、兵種、商店或波次數值。

### 道路高度與外緣

RoadSurface 不再「完整平面上覆一層路色」。同一份網格改以連續高度場生成地表：路面 Y=0、路肩 Y=0.065，路界外 0.045 格形成斜面，並以原共用材質的頂點色稍微加深坡腳。內部共享相同座標／高度，不生成格線、重複路緣或內部側壁；原厚度與外側倒角保留。道路實際行走平面只從前輪的 0.012 回到 0，角色／友軍原來的 0.025 高度與塔錨點均保留，無需改移動或戰鬥。

後續人工回饋要求側邊陰影更明顯：`BANK_SHADOW_STRENGTH` 由原0.10調至0.34，強化路面與路肩接觸處的暗部；路面主色、路肩高度及幾何保留。以同一真渲染驗收場景重拍核對。

第二次回饋指出受光側仍缺乏深度：單純加深斜面不足，現改為坡面逐頂點漸層，並在真正路肩根部的路面內側加入0.06格寬、強度0.46的接觸暗部。依相鄰高地的高度場計算，不依格子邊界畫線，因此寬路內部保持乾淨；同一份網格／共用材質，沒有額外覆蓋Mesh或全局光照變更。固定世界光源、相反兩個相機的實際像素顯示：兩側根部亮度約為旁邊路面的0.76，受光側也能辨識高度差。

新增 `tests/road_refinement/bank_contact.tscn`，加 `-- --verify` 執行雙視角檢查；163項（含四個兩側對比測量）PASS。截圖與JSON在 `.godot/test-results/bank_contact/view_a.png`／`view_b.png`／`rendered.json`，log為 `.godot/bank-contact-both-views.log`。這次補強是本輪既有真渲染驗收之上的針對性修正。

塔體地面與石地仍為 Y=0，鄰格高度場在交界處降回相同高度，避免基座浮空或接縫。木橋原甲板頂約 Y=0.051，橋頭連接 0 與 0.051；流量面仍為 Y=0.075，保持在路面、路肩及橋板上方。本輪沒有再修改塔模型。

### 橋頭缺口的根因

重現了「橋側新增地面後，合法地面出現深色開口」：前輪讓木橋直接替換整個 1×1 顯示地塊，但木橋原素材只有約 0.63 格寬的木板、梁與護欄；周圍石地卻仍把它視為完整實心鄰格，省略了接合邊界。這是橋／實心地面的分類與接合錯誤，並非道路裁切或路網消失。

現在先在同層實際地面上判斷開放橋段：兩側仍為天空才使用原木橋；若橋側已有地面，該格改用同一套連續石地生成器。石地與真正開放橋相鄰時保留橋台側壁，橋本身的兩端亦加入與甲板相接的結構過渡面，仍屬原本那一份 Mesh，不額外放遮蓋物。橋下與護欄外的正常天空空隙保持開放。

修正接合網格的迭代中，覆蓋測試另抓到 SurfaceTool.append_from 保留來源索引、使後續新增接合頂點未被引用的問題；現在先 deindex 再組裝接合面，並核對向上的面向。這是本輪新增接合面時修掉的組裝問題，不混稱為原版已存在的索引錯誤。

### 寬路流量置中及分組

`wide_road_flow.gd` 讀取完整雙向接口，找出可連續通行的最大矩形道路臂與共用交會區。2／3 格以上直路投影到橫截面中央；L／T 的重疊區共用一個交會點；窄路入口沿真正的較窄接口過渡到寬路中央。缺少雙向接口、空地或塔體均不被視為可跨越的連續路面。

來源仍是 RoadFlowForecast／WaveSpawnSchedule 的完整已分配行程。相同方向的平行路段合併位置及到達相位集合，強度由真實有向流量累計、以全體配額作同一基準。反向仍保留相反的端點順序、各自時鐘與來源，不改造成一股方向。狹窄道路沿用原本解析圓角；寬路的交會使用連續圓滑過渡與強度漸變。

內部換道投影後可能成為同一個位置，該段時間以停留顯示保留，沒有刪掉原行程的一秒或把亮段跳到後段。Shader 的停留片段會在原到達時間區間保持可見；一般片段仍按原完整行程相位前進。每個覆蓋格只畫一次 quad，片段透明度取 max 聯集，避免重合加深。窄路仍最多48片段，寬路依實際投影片段數配置紋理與 shader 迴圈，不截斷流量或相位。

Hover 兵種／入口篩選、交通設施增減提示、Scout／Winged Beast 排程仍使用原資料。建造預覽與批次試驗只多傳遞既有 proposal.snapshot，讓未提交道路的寬度也能正確投影；不重新選路或消耗 RNG。

### 主要檔案

| 檔案 | 本輪責任 |
|---|---|
| `scripts/map/tile/appearance/road_surface.gd` | 凹槽高度場、路肩與邊界、木橋分類及橋台／橋頭接合 |
| `scripts/navigation/visualization/wide_road_flow.gd` | 道路臂／交會區及完整行程的顯示投影 |
| `road_flow_renderer.gd`、`road_flow_phases.gd` | 寬路片段合批及保留原始完整行程；上述檔案均在 navigation/visualization |
| `assets/shaders/road_flow.gdshader` | 動態寬路片段與完整時間的停留片段；保留 max 聯集 |
| `wave_flow_preview.gd`、`candidate_preview.gd`、`construction_batch.gd` | 傳遞候選快照；不變更原排程 |
| `tests/road_refinement/depth_flow.tscn`／`.gd` | 十種實際渲染、四向地形旋轉、覆蓋／像素及真實排程驗證 |

### 本輪驗證與截圖

本輪 Current PASS：

- 新 depth_flow 真渲染 **5128** 項、Headless **5111** 項；含 **4650** 個地表覆蓋探針、**17** 個 GPU 像素檢查及原生排程產生的 **120** 名 Soldier／Scout／Winged Beast 行程。十種配置均實際渲染；橋頭與凹角額外修改格子／接口資料旋轉三次，不只是轉相機。
- 實際 WaveSpawnSchedule 的2格、3格、L、T及窄轉寬五個案例均為 **0 次退回原格子中心**。檢查完整配額、導航 revision 與出生 RNG 不因顯示而改變。
- 原 road_flow_continuity 真渲染通過：78 像素、56 線寬取樣、四向路口、反向獨立時鐘、70到達相位及週期接縫；road_flow_preview Headless／真渲染均通過入口／兵種 Hover、配額、RNG、生命週期與交疊像素。
- 放置規則744、Construction placement34／regression54、rendered input32；實際裁切 input13；Tower Tile Editor rendered input48；tile_animation／tile_variants通過。
- RoadPortalGraph、native_candidates286、route_batch、多入口、dead_end_edits、Traffic integration104、Synergy routing357通過；Frontier正式場景180幀渲染啟動通過。

上述都是本輪重跑。前輪1722／458等完整套件沒有在本輪重跑，不將下方歷史表格當作當次證據。本輪未改 C++，使用前輪已建置的 Windows DLL，沒有再執行 native 建置。

26張真實 viewport 截圖與 JSON 在 `.godot/test-results/road_depth_flow/`：

| 檔案 | 內容 |
|---|---|
| `narrow.png`、`wide2.png`、`wide3.png` | 窄路與2／3格寬的凹槽、單一中央流線 |
| `wide_L.png`、`wide_T.png`、`narrow_to_wide.png` | 轉彎、分岔及寬度過渡 |
| `bridge_heads.png`、`bridge_heads_rot1.png`–`rot3.png` | 開放橋、橋台、側邊實心地面與四個旋轉 |
| `tower_edge.png`、`rotated_concave.png`及其rot1–3 | 塔旁地表、正常天空洞口、不規則凹角 |
| `opposite_flows.png`、`*_origin0_phase075.png`、`*_origin1_phase075.png` | 同一置中位置上的反向時鐘；單獨入口亮段位置不同 |
| `wide2_lane_change_dwell.png` | 換道被置中後仍保留原時間 |
| `scheduled_wide2.png`／`wide3`／`wide_L`／`wide_T`／`narrow_to_wide` | 由真正 WaveSpawnSchedule 產生的五組各24人配額 |

結果：`rendered.json`／`headless.json`；最終執行 log 為 `.godot/road-depth-rendered-final.log`／`road-depth-headless-final.log`，其他回歸為 `.godot/road-depth-*.log`。初輪解析錯誤、接合面覆蓋與停留相位的失敗log保留於first／coverage等檔案。實際候選換道的額外支線由agent檢視畫面發現，改以共用道路臂及新增斷言重跑，不將早期自動PASS當作美術PASS。

### 人工驗收與限制

F6 開啟 `tests/road_refinement/depth_flow.tscn`：1–9／0切換十例、R真正旋轉格子與接口、Space切換短筆觸動畫。初始長筆觸定格供比較輪廓，不是一般遊戲的常駐底線。直接命令：

```powershell
& C:\tools\Godot.exe --path D:\games\begins-with-a-road-routing res://tests/road_refinement/depth_flow.tscn
# 自動檢查並重產全部截圖
& C:\tools\Godot.exe --path D:\games\begins-with-a-road-routing res://tests/road_refinement/depth_flow.tscn -- --verify
```

可玩驗收仍用 Tower Tile Editor Playground 或F5進Frontier。這十種配置及五組原生配額的截圖未見缺面、內部格線或額外換道支線；這是 agent 畫面檢查，仍待真人驗收。極端不規則交會若無法得到完全位於路面的連續投影，會保留原行程位置；本輪五組真實排程未觸發此備援。不是任意形狀的完整 medial-axis 解算器。

NOT RUN：Web／Windows release遊玩、效能／大量路網量測、完整Frontier15波、真人美術驗收。本機既有 user:// shader cache 寫入警告仍保留；不改 Windows 安全設定。寬路的 shader 片段數與投影成本依圖形／行程而異，不據本輪功能檢查宣稱效能改善。

## 前輪：道路合併與放置裁切的紀錄

核對：2026-11-03，`experiment/routing-sandbox`，起始 HEAD `4b0d2fed64731ad5bb5c9452d66a0f4b10022441`，起始工作區乾淨。本輪修改未 commit／merge／rebase／reset／clean／push，未操作 main worktree。

## 放置規則

`TowerMap.card_ground()` 是裁切入口。新卡的道路格若落在既有塔完整 `occupied` footprint，且不是新卡自己的塔體，就從新地塊地面清單移除。新卡的塔體重疊仍拒絕；端點、石地、交通設施、兵營駐點及已固定敵軍行程的原有保護繼續生效。同種卡點到現有塔時仍是原本的升級操作。

所有塔牌（包含舊單格配置）都經 `construction_plan()`／`commit_construction()`。裁掉的格子不加入 ground、road 或 requested ports；既有塔及其底下的歷史地塊不被覆寫。`ConstructionLayout` 計算雙向接口、清除通向完整塔體的可通行出口，快照排除所有塔體，BFS 檢查每個入口、基地及兵營駐點。失敗發生於地形、塔、威脅、revision、牌與 Gold 變更之前。

正式提交重新驗證最新狀態，成功只建立一座新塔並消耗一張卡；不加批次確認、不另收 Gold。舊批次試驗仍保留自己的流程與草稿間衝突規則，本輪裁切只適用於**已建塔**。塔拆除時刷新本體與鄰格接口；升級不重新鋪路。

`CardPreview` 直接使用 `card_ground()`，點選與拖放均不畫出被裁掉的道路格。射程面、模型、旋轉與升級預覽仍沿用既有管線。預覽不取得提交許可；世界狀態變動後重新驗證的守衛仍保留。

## 連續路面與塔旁邊界

`map/tile/appearance/road_surface.gd` 只產生顯示資料，由原 `TileVisuals` 的顯示 GridMap 批次繪製。原 TileMap 仍是地形資料權威；不合併導航節點，保留候選池、配額、Scout、Winged Beast、RouteHistory 與流量時間資料；流量幾何已由本輪改為寬路置中。

- 從同層、排除塔體的快照判斷雙向接口。中央路面寬 0.68 格；合法出口延伸到共享邊。
- 四格共享角只有在周圍四條邊都雙向連通時才填滿。因此 2×N、3×N、L／T 與不規則寬路可形成連續面，不把沒有側接口的兩條平行道路畫成廣場。
- 道路聯集仍由最多九個互不重疊矩形定義；本輪地表在共享採樣點生成凹槽與路肩。內部不產生路緣、線條、直立面或路口圓弧；格子仍各自存在於資料中。
- 本輪路面及塔體／石地基礎為 Y=0、路肩 Y=0.065，以0.045格斜面銜接；整片地面外側保留倒角及到 Y=-0.37 的側面。塔體下保留同高、連續的地面，塔旁道路則明確終止。
- 使用原共用純色材質與頂點格式，按接口、角、外緣、灰化、木橋／柱子狀態快取 MeshLibrary 項目。顯示 ID 不再等於邏輯地塊 ID；動畫測試核對顯示映射。
- 窄路的合法木橋及石柱保留；寬路／岔口採連續石路。新格浮起、塔模型跟隨、柱子生長仍沿用原動畫，不每幀重建路面。

## 塔與地面

移除 `TowerBodyVisual` 為每格額外疊出的木塊與薄甲板，以及自訂兵營的舊 `FootprintBody` 補塊。弩架、輪子、八角砲座、船身、FixedBase、砲管、Lv2／Lv3 組件保留。

迫擊砲與交叉火力的既有機械組件局部下降 0.20，讓原本落在重複板上的底面重新貼地；弩砲側邊箭匣亦重新貼地。沒有降低塔節點、改 footprint、射程中心、數值、索敵或命中規則。砲口跟隨可見武器的位置，攻擊快照與四向戰鬥回歸仍通過。既有自訂 `model_offset` 保留，不擅自修正作者指定的偏移。

## 灰化判定

原生 `RoadEditGuard.prepare()` 新增 `route_cells`，直接輸出原本迭代 Tarjan／block-cut 分析中的格子聯集，再限制於基地所在連通分量、有可達入口的完整路線。單點附著的旁支環路不屬於 simple path；兩端接回主路的合法迴路則整段保留。所有啟用入口的合法路線取聯集，不依目前兵種、候選 budget／threshold、Scout 最新路或當波配額判色。

顯示層使用獨立 guard，不動控制器的增量 guard。依完整快照／端點變更快取；`graph_changed`、地塊新增與外觀刷新觸發同步。即使新增死路沒有重建導航，也會正確灰化；接回第二個有效出口後恢復米色。沒有每幀建圖或路線枚舉。正式算法及記憶體為 O(V+E)；窮舉只存在於小型測試。

必須重新建置 native DLL／wasm 才能取得分類。舊 binary 無此欄位時保留中性色並記錄一次警告，不將全部合法道路誤染成灰色。本輪已重建 Windows debug／release；Web wasm／瀏覽器未執行。

## 人工驗收

1. 開啟 `tests/road_refinement/gallery.tscn` 按 F6：A 全覽，1–9／0 聚焦十個案例。包含窄路、2×4、3×4、L、T、不規則聯集、兩種多格塔、裁切後輪廓及有效路／死路／旁支環。這是唯讀幾何對照場，使用正式 RoadSurface 與塔模型。
2. 可玩入口仍是 `tests/tower_tile_editor/playground.tscn`，選「基礎版」。先補迫擊砲「L型」，不旋轉放在格 `(8,1)`；再補哨塔「直線」，不旋轉放在 `(8,3)`。哨塔牌的兩格道路落在既有迫擊砲上，應被裁掉；右側一格正常新增。可用 F2 查看格子座標。此組卡牌直接引用原本保存的正式資源。
3. 改用拖放重現，檢查預覽和結果；把新塔體壓到原塔非錨點應被拒絕（同種塔的既有升級操作除外）。同種牌升級時道路應完全不動。開始波次觀察實際行程。
4. 在寬路周圍旋轉／縮放鏡頭，確認無內部井字線、塔旁端口、破洞及明顯深度閃爍。美術品質仍由人類驗收，不以自動測試代替。

可直接執行，不依賴 Editor 的 DLL 暫存副本：

```powershell
& C:\tools\Godot.exe --path D:\games\begins-with-a-road-routing res://tests/road_refinement/gallery.tscn
& C:\tools\Godot.exe --path D:\games\begins-with-a-road-routing res://tests/tower_tile_editor/playground.tscn
```

真實 Compatibility／RTX 4060 Laptop 截圖位於 `.godot/test-results/road_refinement/`：

| 檔案 | 內容 |
|---|---|
| `overview.png`、`case_01.png`–`case_10.png` | 十種正式網格渲染結果；7／8 為塔旁、10 為死路及旁支環 |
| `click_preview.png`、`drag_preview.png` | 實際關卡點牌／拖牌的裁切預覽 |
| `committed_level.png` | 實際提交後的塔、道路、灰化及原關卡 UI |

可用 `gallery.tscn -- --capture` 重產 11 張圖；`input.tscn` 重產三張關卡圖。六塔各 Lv1–3 的附加對照已由 `tests/tower_visuals/gallery.tscn` 重產到 `.godot/test-results/tower_visuals/`。所有圖片皆 Godot viewport 輸出，非示意圖。

## 前輪驗證

| 狀態 | 本輪執行 |
|---|---|
| PASS | 新 `road_refinement/rules` 744 項：512 occupancy＋128 隨機雙向接口對照窮舉 simple paths、動態灰化／恢復、單／多格裁切、接口、預覽、原子失敗、Gold／牌、疊塔與三兵種排程 |
| PASS | 新真渲染 `road_refinement/input` 13 項：實際點牌、拖牌、裁切、消耗、保留原塔與手動開波 |
| PASS | `tower_visuals/rules` 1722、`combat` 104、rendered `input` 118（全21份及六塔升級）；Gallery12圖 |
| PASS | Tower Tile Editor rules458、rendered input48（含兩波）、combinations_input29 |
| PASS | Construction placement34／regression54／geometry51、rendered input32 |
| PASS | cards、tile_presets、rendered card_drag_placement；relics stacking |
| PASS | combat、tower_restoration；traffic integration104；synergy routing357（含 RouteHistory／硬性選路） |
| PASS | RoadPortalGraph、native_candidates286、route_batch、multiple_starts、dead_end_edits、road_flow_preview |
| PASS | tile_animation、tile_variants；Frontier 正式 level 180幀渲染啟動 |
| PASS | Windows native debug／release 建置；C++ road_edit_guard3584 次編輯 oracle，另核對完整路線格子聯集 |
| PASS | 最後 headless editor import 無腳本／資源解析錯誤；git diff --check 無內容錯誤 |
| NOT RUN | Web native／匯出／瀏覽器、Windows release 遊玩、效能量測、Frontier全15波、人類操作與美術驗收 |

測試 JSON 在 `.godot/test-results/` 各功能子目錄，logs 在 `.godot/road-refinement-*.log`。規則最終為 `road-refinement-rules-final.log`；Portal 最終為 `road-refinement-portal-final.log`；大型套件為 `road-refinement-tower-rules-final.log`／`road-refinement-editor-rules-final.log`。初輪有測試型別／API 欄位錯誤、短 timeout，以及舊測試對可編輯 main 地形、舊預測 ports、顯示 ID 和已延後建立的 debug DAG 的假設；均保留初輪 FAIL／中止證據，修正 fixture／斷言後重跑，不以歷史 PASS 代替。本輪沒有修改使用者 main 地形來滿足測試。

## 限制

- 路面採格子聯集的直線邊界及淺倒角，不是自由曲線道路；目前保留寬度與色系，轉角仍需人類檢視。
- 這是單層 Y=0 遊戲地圖；同高度才共享外緣，不支援坡道／跨層導航。
- 選圖頁的無腳本地形預覽、手工主選單橋景仍使用原本保存的素材；本輪連續道路及灰化在遊戲 TileVisuals 中生效。
- 單點附著環路會灰化，即使從入口可以走進再原路折返；正式行程不重踩格子，因此它不屬完整合法行程。
- 本機 shader cache 的 user:// 寫入警告仍存在；editor import 另有使用者設定目錄／settings 儲存權限訊息，未出現腳本或資源解析錯誤。本輪未更改 Windows 防護設定。實際遊戲渲染與輸入測試通過，不代表完整 Editor 互動驗收。
- 沒有新增地塊／兵種／事件，沒有變更 Gold、商店、遺物、傷害、攻速、波次或20＋1資源。完成後等待人工驗收。

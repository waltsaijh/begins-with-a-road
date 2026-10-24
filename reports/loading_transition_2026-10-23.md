# 2026-10-23 選圖到關卡的載入與預熱

## 實作

`feat/outer_game_ui` 在選圖確認「開始作戰」後，先變白並顯示載入介面，再建立正式關卡、準備路線與顯示，完成後淡入遊戲。轉場只處理呈現、輸入隔離及通用準備契約；LevelSession 決定工作，獨立的 enemy_render_warmup 使用既有 renderer 繪製兵種代表、動畫與頭頂狀態。

場景讀取階段無可靠工作總量，只顯示「載入戰場」；準備階段按入口圖、第一波各兵種／入口候選池、全部 ACT 兵種代表的實際完成數顯示細進度條。正式關卡目前 5 項，本次混兵負載 7 項。它是已完成工作比例，不是時間或 shader 編譯百分比，單項同步工作仍可能暫停畫面。

預熱不建立正式敵群、不分配配額、不消耗 RNG，沒有增加正常移動迴圈的工作。準備中鎖住輸入、停用關卡 processing 並拒絕開波；完成後恢復原模式，第一波仍手動開始。準備失敗或目標離場會恢復來源場景及解除遮罩。Headless 跳過 GPU 預熱；直接執行 level 保留偵錯入口。

## 實際 Web 驗證

沿用[整合前的選單路徑測試](menu_performance_2026-10-23.md)：實際點擊 menu → 選圖 → 本局設定 → 開始作戰，進入正式 level，再點擊正式開波按鈕。僅在測試執行時於記憶體替換 32×32、801 道路格、91 節點／19 寬區、16 塔、Soldier 86／Quickfeet 85／Heavy 85 的負載。生命 1,000,000、速度倍率 0.45、波次速度 2.5、Quickfeet path_base_cost 0.25；不改正式數值。

兩次獨立可見 Edge 155.0.4283.62 工作階段，1280×800、DPR 1，實際 AMD Radeon Graphics／ANGLE D3D11；同一單執行緒 Compatibility release，使用本分支原生擴充。沒有更動系統設定、沒有清除驅動快取，也沒有併入 reduced_graph 的 C++ 候選池優化。

| 指標 | 整合前（三輪） | 載入預熱第一輪 | 載入預熱第二輪 |
| --- | --- | ---: | ---: |
| 變白後至負載準備完成 | 8.55–9.40 s | 13.51 s | 14.76 s |
| 首次開波完整觀察窗最大間隔 | 5.30–6.53 s | 500.07 ms | 333.26 ms |
| 點擊至生成後兩次 rAF 確認的最大間隔 | 前兩輪未單獨標記；第三輪 6533.17 ms | 133.36 ms | 83.32 ms |
| 穩態平均（最後 300 幀） | 第一波 21.83–22.00 ms | 20.61 ms | 20.33 ms |
| 穩態 P95 | 33.44–33.46 ms | 33.42 ms | 33.41 ms |
| 穩態 P99 | 33.50–33.72 ms | 33.58 ms | 33.51 ms |

兩輪均到 7／7、代表可見數清零後才淡出，均正確生成 256 人，觀察窗結尾仍存活 256 人，沒有 pageerror／Godot ERROR。完整觀察窗從開波點擊前開始，到生成後至少 16 秒；最後 300 個 rAF 間隔為穩態，共 600 個。rAF 代表瀏覽器畫面節奏，並非純 CPU／GPU 計時。

5–6 秒的大停頓已提前到載入階段；整段遊戲觀察仍有 0.33–0.50 秒尖峰，尚未消除所有首次使用成本，也未分離剩餘特效、建立及同步成本。兩輪不是嚴格固定 CPU 時脈／戰況的效能 A/B，因此不將平均幀時間的小幅差異宣稱為穩態 FPS 改善。

## 正式 Frontier 的分項診斷（補測）

上述 8.55–9.40 秒包含合成地形、塔與候選池，不能當成一般 Frontier 的載入基準，也不能直接解釋玩家看到的約 11 秒。本次另外從選單進入未修改的 Frontier，第一波維持原本 4 名 Soldier；仍採同版 Edge／AMD／Compatibility release，排除啟動 Godot Web 到主選單的時間。

單次完成樣本 `serial-1`，從進入關卡的 covered 到 finished 為 17.153 秒，其中開始顯示預熱前約 1.322 秒，三個代表依序耗時如下：

| 代表 | 從開始準備至完成清理 | renderer.add_enemy 呼叫 |
| --- | ---: | ---: |
| Soldier | 6.879 s | 1.455 ms |
| Quickfeet | 8.614 s | 1.935 ms |
| Heavy | 0.055 s | 0.765 ms |

這是實際繪製／等待幀／清理的整段時間，不是獨立 shader 編譯計時。程式只建立每個兵種一個代表；主要耗時發生於加入之後的首次繪製等待，並非建立 256 個敵人。後續才出現的 Quickfeet 也被提前準備，所以現在的載入範圍比第一波 Soldier 的首次出場更廣；不能宣稱只是把同一段 5–6 秒原樣搬到前面。Heavy 是否共用前兩者已準備的顯示程式仍是推測。本輪秒數與玩家的 11 秒不同，不視為固定耗時。

關閉顯示預熱、保留場景與導航的控制版雖成功進入關卡，首次出場觀察卻出現約 1001 秒異常 rAF 間隔，並在截圖時逾時，因此拒絕用它計算首次出場改善幅度。兩份紀錄均有 WebGL buffer INVALID_OPERATION 警告，未判明來源；不能宣稱這輪顯示完全無錯。沒有從此診斷推出全敵人數量或跨 GPU 的通用結論，也沒有變更預熱策略。

原始資料在 `.godot/test-results/menus/normal_loading/`：`serial-1.json`／截圖為完成樣本，`control-1.json` 是上述不可作效能比較的控制樣本。一次性量測程式及匯出包用完移除，正式關卡、波次、專案設定與預熱程式恢復原狀；本次未重跑整套功能回歸。

## WebGL 呼叫層診斷（後續補測）

直接使用既有 `build/web`，從真實主選單依序點擊選圖／下一步／開始作戰；沒有修改或重新匯出遊戲。仍為可見 Edge 155.0.4283.62、1280×800、AMD Radeon Graphics／ANGLE D3D11。一次性瀏覽器包裝器量測原有 WebGL 呼叫，不主動增加 shader 編譯或 LINK_STATUS 查詢；只在同一 WebGL context 查一次 GPU 名稱。

載入階段的 `getProgramParameter` 累計阻塞 9788.715 ms，四次最大呼叫均查詢 LINK_STATUS（35714），如下。依編譯時序與緊鄰提交的 shader 原始碼辨識：前兩份包含 Soldier 的 `leg_swing`，後兩份為 Quickfeet 的 StandardMaterial；每對中第二份定義 USE_INSTANCING。這些是另一輪量測，不可與前次 6.879／8.614 秒逐項拼接。

| 材質程式 | LINK_STATUS 呼叫阻塞 |
| --- | ---: |
| Soldier，一般版本 | 2251.925 ms |
| Soldier，實例版本 | 2682.035 ms |
| Quickfeet，一般版本 | 1995.435 ms |
| Quickfeet，實例版本 | 2021.865 ms |

四次共 8951.260 ms，約占載入階段 program 查詢阻塞的 91%。Godot 提交的每份上述程式含約 34k 字元 vertex 與 90k 字元 fragment 原始碼，包含引擎光照等通用程式；不是模型的網格頂點數。USE_INSTANCING 是捕獲原始碼中的差異，不表示已證明目前顯示一定需要兩份都同步準備。其餘深度／特化版本也有編譯，但沒有同等秒級阻塞。

`compileShader`／`linkProgram` 的提交呼叫很短；阻塞落在後續取得連結狀態時。這符合 [MDN WebGL best practices](https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/WebGL_best_practices) 對 shader／program 查詢可能等待編譯及跨程序往返的說明。已定位到瀏覽器編譯／連結同步等待；仍未將 ANGLE 轉譯、GPU 程序排程與 AMD 驅動編譯細分，不能宣稱特定驅動 bug 或這是不可降低的必要時間。沒有改動 renderer、shader 或載入策略。

原始呼叫、提交的 shader、console 與來源雜湊在 `.godot/test-results/menus/webgl_diagnosis/`。計數 stage 在淡入後仍維持 level_loading，所以日常 draw／buffer 的累計數包含閒置觀察，不能作純載入總量或穩態效能指標；上述四次 LINK_STATUS 則都有獨立起訖時間。遊戲成功淡入、第一波仍手動，但後續同樣出現 WebGL buffer INVALID_OPERATION，未將它當作本次秒級編譯等待的原因。一次性腳本用完移除，未跑功能回歸。

## 功能回歸與產物

- Windows／RTX 3050 Compatibility 實際渲染：`tests/menus/scene_loading.gd` 通過，驗證未知／已知進度、單調工作計數、三個代表模型、RNG／正式敵群隔離、恢復開波與 processing、移除代表、準備失敗及取消後回到選單。兩個故意失敗的 fixtures 會印出預期的 Invalid data／Unavailable 轉場錯誤，測試 failures 為 0。
- 原有 `tests/menus/main_menu.gd` 實際渲染通過，包含響應式布局、雙語、設定、9 次白色轉場、暫停返回與全新開局。
- `level_flow`、`level_teardown` headless 通過，後者 48 種清理情境。沒有以 headless 估算渲染效能，未重跑全部專案測試。
- 原始 JSON、逐幀樣本、進度紀錄、截圖、log 與來源雜湊位於 `.godot/test-results/menus/loading_256/`。Windows 載入畫面為 `.godot/test-results/menus/loading_visuals.png`。
- 效能匯出完成後只補上準備契約的非法參數／狀態守衛與功能斷言，正常準備路徑未變；最終 Windows 回歸另驗證這些收尾。來源雜湊記錄當前來源，PCK 雜湊識別實際量測匯出包。
- 一次性 Web 計時程式、臨時 Autoload 及測試匯出包用完移除，正式設定與資源恢復原狀；只保留功能回歸及量測證據。

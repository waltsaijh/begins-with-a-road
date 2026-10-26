# 單執行緒 Web：32×32／256 混兵（2026-10-22）

本次測試目前工作目錄中的 C++ 候選運算版本，分支 `experiment/reduced_graph`、基底 HEAD `27f4ddc`，包含尚未提交的修改。這是目前版本的 Web 實測，沒有與搬移前的 Web 版本做 A/B。

後續依使用者要求保留可操作的 `tests/enemies/mixed_256.tscn`，可手動開始及清場後再次開波，操作見 [測試說明](../tests/README.md)。它沒有採樣器，與下文當次已移除的自動量測工具分開；以下數字仍只代表當時的首次開波，沒有因此補測第二波。

使用者後續手動觀察：只有首次出發明顯卡頓，同一頁面內重新載入場景及再次開波均無明顯卡頓。這不是帶時間戳的追加量測，但支持程序內首次使用的初始化／快取因素，不能將首次約 5 秒外推為每波固定成本。程式檢查顯示 TroopCatalog 已在準備時載入兵種及其模型 Resource，步態 shader 也已 preload；Quickfeet／Heavy 的模型實例與動畫則在 add_enemy → enemy_model._init 時才建立。資源讀入不代表已完成 GPU 首次繪製準備，因此優先懷疑首次實例化、材質／shader 編譯與上傳等工作；尚未逐項隔離，不把 shader 當成已證實的唯一原因。

Godot 的 [Compatibility 首次 shader 停頓說明](https://docs.godotengine.org/en/latest/tutorials/rendering/jitter_stutter.html) 建議在載入時，讓相關模型／效果在鏡頭內實際繪製至少一幀，可用不透明 2D 載入遮罩遮住畫面。僅 preload 或把模型 hide／放到鏡頭外，並不等同完成此類暖機。本輪尚未加入這項預熱行為，也沒有宣稱已修正首次出發停頓。

## 方法與環境

- Godot 4.7.2、Compatibility、Web release、GDExtension／Emscripten 4.0.20、`threads=no`。重新確認原生 release 建置為最新，重新匯出；HTML 的 `GODOT_THREADS_ENABLED=false`，載入 `road_graph.editguard.web.template_release.wasm32.nothreads.wasm`。未使用舊 `build/web/` 匯出。
- Windows／Ryzen 5 4600H 筆電，Edge 155.0.4283.62、WebGL 2／ANGLE D3D11，1280×800、DPR=1。分別使用預設 AMD Radeon Graphics 及以瀏覽器啟動參數指定的 RTX 3050 Laptop GPU；每輪讀取 WebGL 的實際 renderer 核實，未改系統 GPU 或電源設定。
- 本機 HTTP 伺服器、COOP／COEP，`crossOriginIsolated=true`。每輪重新開啟獨立瀏覽器，冷啟動數字包含當次首次使用的資源及材質等初始化；不是正式網路下載時間，也不是保留瀏覽器快取的回訪結果。
- 與前次相同的合成 32×32／801 道路格、16 塔、91 vertex／19 region。Soldier 86、Quickfeet 85、Heavy 85，同刻出生；測試副本生命 1,000,000、速度倍率 0.45，波次速度 2.5，Quickfeet `path_base_cost=0.25`。不改正式 Resource。相機完整取景、near=0.1／far=150，截圖已確認地形及模型均可見，F1／F2 關閉。
- `--fixed-fps 60` 固定每幀模擬 delta 為 1/60，並非把實際 Web 幀率強制設成 60。每輪暖機 180 幀、取樣 600 幀，以直接時間戳記錄 wall 幀間隔，另記錄瀏覽器 rAF 間隔及實際 draw 次數。未把 `Performance.TIME_PROCESS` 當成逐幀資料。
- 正式樣本使用可見視窗及相同的背景節流停用參數／焦點模擬，次序 AMD1、RTX1、RTX2、AMD2、AMD3、RTX3。場外視窗探索曾遇到暖機停止推進及瀏覽器關閉，探索樣本與中止輪次不列入正式統計。

## 結果

各 GPU 三輪、每輪獨立統計；下表取各輪統計的中位數，不把 1,800 幀混成單一分布。FPS 為 1,000／平均幀時間中位數。

| 指標 | AMD 內顯 | RTX 3050 |
| --- | ---: | ---: |
| 平均 wall 幀時間 | 21.27 ms | 19.76 ms |
| 各輪平均幀時間範圍 | 18.92–22.58 ms | 16.66–20.33 ms |
| 換算 FPS | 47.0 | 50.6 |
| P95 | 27.24 ms | 31.58 ms |
| P99 | 32.37 ms | 38.83 ms |
| 各輪最大幀時間範圍 | 34.83–55.34 ms | 46.45–91.85 ms |
| 新地圖場景建立至 16 塔就緒 | 19.18 s | 18.70 s |
| 三兵種完整冷建池 | 34.75 ms | 36.66 ms |
| 快取計畫下的 256 名排程 | 18.34 ms | 24.15 ms |
| 排程至 256 名全部生成，含首幀等待 | 5.33 s | 5.23 s |
| Process 範圍平均實耗 | 10.26 ms | 10.43 ms |
| 模型／避讓等範圍平均實耗 | 6.08 ms | 5.71 ms |
| 戰鬥範圍平均實耗 | 1.10 ms | 1.04 ms |
| 頭頂狀態範圍平均實耗 | 2.53 ms | 2.76 ms |
| draw-submit 平均實耗 | 9.25 ms | 7.76 ms |

這個合成負載下，兩種 GPU 都沒有穩定維持 60 FPS；RTX 平均較快，但尾端反而較高，不能只根據三輪就判定 GPU 升級一定改善 P99。更新範圍裡模型／避讓與頭頂狀態仍占可觀時間，draw-submit 也有成本；不是候選運算搬到 C++ 後，全部每幀工作都消失。

較突出的問題是首次使用的停頓：場景建立約 18–19 秒、首次 256 名全部生成約 5 秒；這些數字沒有藏進暖機後平均幀時間。冷建池只有約 35–37 ms，無法解釋數秒的首次生成。本輪尚未隔離資源、材質／shader、WASM JIT、模型／動畫建立與首幀繪製各自的占比，也未測同一頁面第二次開波，不能將整段停頓直接歸為模型建立或 shader 編譯。

| 輪次 | 平均幀時間 | P95 | P99 | 冷建池 | 全批生成 |
| --- | ---: | ---: | ---: | ---: | ---: |
| AMD1 | 18.92 ms | 26.79 ms | 32.37 ms | 34.75 ms | 5.33 s |
| RTX1 | 16.66 ms | 24.48 ms | 29.13 ms | 36.66 ms | 5.68 s |
| RTX2 | 20.33 ms | 33.27 ms | 40.52 ms | 48.16 ms | 5.23 s |
| AMD2 | 21.27 ms | 27.24 ms | 30.47 ms | 32.03 ms | 4.82 s |
| AMD3 | 22.58 ms | 29.58 ms | 36.32 ms | 39.77 ms | 5.46 s |
| RTX3 | 19.76 ms | 31.58 ms | 38.83 ms | 32.26 ms | 5.18 s |

空白頁對照各 120 個 rAF 間隔，AMD／RTX 的中位數均約 6.9 ms，常態更新間隔約對應 144 Hz，並非固定 60 FPS。RTX 空白頁平均 10.59 ms，含 72.3／368.1 ms 尖峰；AMD 平均 6.94 ms。這也顯示瀏覽器／環境本身可能有停頓，不能將遊戲 P99 的全部差異指派給遊戲邏輯。

六輪皆有 600 次實際 draw、開始與結束維持 256 存活，全部 3,600 個樣本的 delta 均為 1/60，無 console／腳本錯誤。每輪檢查的 1,397 個計畫候選條目皆無重踩格子；數字包含預設 Soldier 計畫及測試兵種副本，並非全圖不同路線總數。完整出發順序與逐格行程的指紋均為 `092c397465b6a09583ed12519592aa6937fdfb666758f67f5c02e1869e9997a7`，與本輪 Windows headless 場景檢查一致；Windows 檢查僅作功能核對，未當作渲染效能對照。

## 判讀限制與產物

場景建立、建池及生成是不同區間：冷建池包含新的 native planner prepare 與三兵種計畫，幾何池依正式流程共用，但不包含先前完成的 Resource evaluation、場景建立、模型或繪製。排程使用已建立的計畫；「排程至全部生成」包含排程與首幀等待，兩者不能相加。

Process／模型／戰鬥／overlay 是場景更新順序中的時間戳跨度，包含當下被排程延後的時間；模型跨度也包含同優先序的攻擊顯示。draw-submit 是 frame_pre_draw 至 frame_post_draw 的實耗，可能包含提交及同步等待，不是獨立 GPU 計時。本輪沒有把 CPU、GPU、材質編譯、WASM JIT 或資源載入各自隔離，不能僅由這些跨度指定唯一瓶頸，也不能據此認定 C++ 搬移使 Web 退化。

原始逐幀／rAF 樣本、階段時間、實際 renderer、長任務記錄、console 及截圖保存在 `.godot/test-results/navigation/web_current_256/`，正式檔案以 `foreground-` 開頭；`summary.json` 為彙整，`raf_baseline.json` 為空白頁 rAF 對照。無前綴的 AMD／RTX 檔案僅為場外視窗探索，不混用。這是短測，不代表通用敵人上限、長時間穩定性或無記憶體洩漏。

本次臨時量測場景、瀏覽器收集工具、測試匯出及相關匯出快取用完即移除；正式入口與匯出排除設定保持原樣。保留原始資料與本摘要，功能回歸入口見 [tests/README.md](../tests/README.md)。

benchmark 清理後重新通過 Windows headless 的 route_distribution、waypoint_routes、enemy_visual_separation、troop_profiles，以及獨立 C++ portal_graph／portal_routes；Web 功能比對工具通過 JavaScript 語法檢查。本輪沒有重跑完整 Windows／Web 功能對照套件。

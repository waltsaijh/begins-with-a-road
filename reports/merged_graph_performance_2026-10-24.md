# 合併 main 後的 Windows／Web 效能（2026-10-24）

版本為 `experiment/optimize_graph` 的 `442a738`，已合併 main `a5422c8`，保留候選去環與 C++ 批次運算。本次是目前版本量測，沒有對修改前版本做 A/B，不能從歷史報告相減推論改善幅度。

## 負載與方法

- 使用獨立的 `tests/enemies/mixed_256.tscn` 合成負載：32×32 範圍、801 道路格、16 座 Sentry、91 vertex／19 region、單入口。Soldier 86、Quickfeet 85、Heavy 85，同刻出生；生命為測試副本 1,000,000、速度倍率 0.45、波次速度 2.5。沒有修改正式 Resource。
- 直接進入試驗場，不經主選單；本分支本來就沒有 `feat/outer_game_ui` 的 Boot／DisplayWarmup。Soldier 使用 GPU MultiMesh，Quickfeet／Heavy 仍使用模型實例與 AnimationPlayer，未包含另一分支的三兵種 GPU 合批或共用純色材質改動。
- Ryzen 5 4600H、Godot 4.7.2、Compatibility、1280×800。Windows 為引擎 runtime／debug GDExtension、RTX 3050 Laptop GPU／NVIDIA 591.86；Web 為單執行緒 release 匯出／release GDExtension、Edge 155.0.4283.62、AMD Radeon 內顯／ANGLE D3D11。GPU 與建置不同，不能把差異當純平台成本。
- 各平台三輪，先完成 Windows 三輪，再完成 Web 三輪；沒有其他壓測同時執行。Web 每輪使用新的瀏覽器實例與頁面，確認頁面 visible、DPR=1、crossOriginIsolated=true；沒有清除驅動 shader 快取，也不是網路下載測試。
- 每輪各測首次與再次開波。CLI／Web HTML args 都使用 `--fixed-fps 60` 固定模擬 delta，這不是實際 FPS 上限；Windows 關閉 VSync、不設 Engine.max_fps。每次全部生成後暖機 180 幀、取樣 600 個實際 wall 幀間隔，確認 600 次 draw、開始／結束皆 256 人存活。第二次先清除敵人、攻擊與效果，保留同一場景、renderer 及快取，重新設定相同 seed。
- 相機完整取景、near=0.1／far=150、size=42；Windows／Web 截圖已確認地形與模型可見。F1／F2 關閉。測試的是敵群、塔攻擊、原有模型／動畫、狀態顯示與視覺避讓；沒有量測準備期中心線重建、hover 或其 shader 成本。

## 三輪中位數

每輪先獨立統計幀時間，再取三輪統計的中位數，不把所有幀合成一個分布。FPS 是 1,000／平均幀時間中位數。

| 指標 | Windows／RTX | Web／AMD |
| --- | ---: | ---: |
| 試驗場 setup 方法至準備完成 | 1.09 s | 18.70 s |
| 三兵種冷建池 | 33.62 ms | 37.39 ms |
| 快取計畫下的 256 人排程 | 7.80 ms | 11.25 ms |
| 首次開波至全部生成 | 74.09 ms | 4,781.49 ms |
| 首次開波至首個繪製幀之後 | 94.79 ms | 4,869.21 ms |
| 再次開波至全部生成 | 103.27 ms | 105.62 ms |
| 再次開波至首個繪製幀之後 | 118.45 ms | 129.91 ms |
| 首次波穩態平均幀時間 | 12.29 ms | 20.86 ms |
| 首次波穩態 FPS | 81.34 | 47.95 |
| 首次波 P95／P99 | 16.72／19.25 ms | 26.91／31.58 ms |
| 再次波穩態平均幀時間 | 12.27 ms | 20.28 ms |
| 再次波穩態 FPS | 81.47 | 49.31 |
| 再次波 P95／P99 | 16.75／21.12 ms | 25.56／27.27 ms |
| 場景總 draw calls（取樣末端） | 1,265 | 1,265 |

setup 計時從測試 setup 方法開始，包含合成場景建立、塔及計畫準備，以及期間實際等待的繪製；不包含此前的 Godot／WASM 啟動與場景 Resource 讀入，不能稱為頁面總載入時間。冷建池是全新 native planner prepare 加三兵種計畫，共用幾何池，排除地圖建圖與 Resource evaluation 輸入計算；每輪一次暖機後測六次。排程只量 WaveSpawnSchedule.build，不洗牌，包含行程快照、配額、座標與出生刻度；一次暖機後測九次。兩項皆在實際 runtime 中量 CPU，不能換算成渲染 FPS。

「至全部生成」從按下試驗場開始動作前計時，包含清場等待一幀、排程及實體建立；「至首個繪製幀之後」再等待 frame_post_draw 與下一個 process_frame，涵蓋首次顯示／提交的停頓，但不是 GPU fence 完成時間。這些區間包含排程，不能相加。首次出兵停頓不藏入暖機後平均幀時間。Windows 沒有一致的「第二次必定更快」現象。

## 各輪結果

| 輪次 | 首次平均／P99 ms | 再次平均／P99 ms | 首次生成 ms |
| --- | ---: | ---: | ---: |
| Windows 1 | 12.29／20.27 | 12.27／21.60 | 109.11 |
| Windows 2 | 12.24／18.30 | 12.55／21.12 | 74.09 |
| Windows 3 | 12.46／19.25 | 11.79／16.23 | 65.88 |
| Web 1 | 22.03／37.43 | 20.24／27.27 | 4,781.49 |
| Web 2 | 20.86／31.58 | 20.28／26.96 | 4,822.37 |
| Web 3 | 20.60／29.93 | 20.78／29.73 | 4,691.25 |

Web 在這個負載下沒有維持 60 FPS，首次顯示仍有約 4.9 秒停頓；冷建池僅約 37 ms，無法解釋數秒的停頓。同頁再次開波約 0.13 秒，支持首次使用／顯示準備因素，但本次沒有逐項隔離 shader 編譯、模型實例、上傳與其他初始化，不能歸給單一原因。本分支沒有顯示預熱，不能套用其他分支的載入時間或改善幅度。

## 一致性、建置與限制

六輪的三兵種候選數皆為 256／425／460，完整排程沒有重踩格子；路線索引、逐格行程、原始分數與選中機率的指紋一致：`8ea1fbfdd84e6c9c805c89bcbc6d4df5c789e5ccfe29e86d5b74eb7ba2bfa4f1`。兩平台各 3,600 個取樣幀，合計 7,200 幀；每次取樣開始與結束皆存活 256 人。這不代表逐幀戰鬥狀態的額外指紋對照，也不是長時間穩定性測試。

第一次 Web 嘗試發現本機 wasm 仍是缺少 search_costs／rank_candidates／allocate_indices 的舊版，因此無法執行；已由目前原始碼重建單執行緒 Web release 擴充，再重新匯出，確認 bin 與匯出 wasm 的 SHA-256 相同。這次失敗沒有完成取樣，另存 invalid-stale-wasm，不列入效能表。

Windows／Web 有既存兵種圖示 UID 失效、依文字路徑載入的 warning。Web 三輪完成量測並輸出結果後，在 get_tree().quit 的引擎清理階段皆另出現 `Pages in use exist at exit in PagedAllocator: N16WorkerThreadPool5GroupE`；保留各輪 errors 與 console，不宣稱全流程零引擎訊息，也沒有為避開它剔除較慢輪次。量測完成前未出現腳本／遊戲錯誤，所有工作量斷言通過；本次沒有修改引擎清理實作。

原始資料、各輪完整幀間隔、摘要、二進位雜湊及截圖存於 `.godot/test-results/navigation/merge_perf/`。一次性量測腳本、場景、瀏覽器工具及測試匯出用完移除；保留既有手動 mixed_256 場景。正式 project.godot 與 export_presets.cfg 匯出後已還原。沒有修改遊戲運算邏輯，也沒有用這次結果宣稱合併改善 FPS 或排除效能回退。

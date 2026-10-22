# Phase 2 驗證與人工驗收

所有地形、波次與測試實例獨立於 Frontier。輸出寫入 `.godot/test-results/traffic/`，不將歷史結果視為本次結果。

## 自動化入口

```powershell
godot --headless --path . --script res://tests/traffic/weights.gd
godot --headless --path . res://tests/traffic/integration.tscn
godot --path . res://tests/traffic/integration.tscn
godot --path . res://tests/traffic/input.tscn
```

- weights：標籤、舊資料預設、互斥體型、適用兵種、單次套用、混合疊加、Uniform／Softmax、整數配額、單一路線、溢位及零權重。
- integration：三設施配置／放置、道路不變、互斥／端點／駐點／塔及 ACT 延伸保護、兩入口各兵種配額、RNG、候選快取／threshold、正式快照、提前移除、跨 ACT 的三波到期、最後一波、雙池抽牌／重刷／價格、岔路門檻及清理。
- input：SubViewport 實際滑鼠拖放、非法落點、點選、旋轉、UI／暫停取消候選、放置前後預測一致、Hover 剩餘波數、戰鬥中卸載與新關卡。必須實際渲染。
- 既有 card_shop 回歸已調整為兩排／七張牌背；仍驗證原卡牌動畫、購買及 hover。其他既有功能回歸保留。

## 人工操作

1. 在 Godot 開啟 `tests/traffic/playground.tscn`，按 F6。三張初始手牌為旗幟／拒馬／窄口，提供 100 金幣與已可開啟的商店；四波跨兩個 ACT，雙入口都有三兵種。
2. 開啟右下牌堆：上排四塔、下排兩設施，原重刷卡在右下。買牌後各排向右靠攏；點重刷一次更新兩排，只扣一次費用。收起商店。
3. 拖拒馬到上方或下方分支；有效位置綠色、衝突紅色。道路顯示候選配額，岔路以 ↑／↓ 顯示相對基準變化。增加箭頭會輕微上浮、減少箭頭會下沉；不要將這些垂直標記視為敵軍方向。
4. 移到 UI、端點、空地或取消選牌，確認恢復基準。旗幟改放鄰路空格，預覽與放置後都應有一格石地及下方支柱；窄口改放另一段道路。R／右鍵旋轉，點選後點地圖也可放置。
5. Hover 起點兵種列檢查入口及兵種篩選；若整數配額或候選限制使流量不變，應看到簡短提示且無假箭頭。
6. 確認放置後，預測與剛才候選相同。Hover 建築顯示剩餘 3 波。手動開波並觀察敵軍，完整波次後剩 2、1，第三波後移除；原道路保留，第四波預測回復。
7. 暫停／繼續、切換 ACT、重新開始；確認候選圖層隱藏／恢復及新關卡沒有殘留設施。最後一波不再開下一波。
8. 正式 F5 入口仍為 scenes/level.tscn，商店照既有規則在波次完成後才出現；初始隨機手牌仍為塔牌。六塔／兵營另以 tests/combat/tower_restoration_playground.tscn 驗收。

## 範圍與已知限制

有限候選及 strict Score Threshold 保留，倍率不新增路線；幾何或整數配額限制會使設施在部分位置沒有可觀察影響。設定全零權重會使正式開波依既有安全規則拒絕；MVP 三設施都是正倍率。模型採本專案木材、石材與布面簡單幾何，平衡值仍需人工調整。

本次驗收結果以 `.godot/test-results/traffic/acceptance.md` 和對應 log／JSON 為準。舊 route_planner 與 tile_placement 測試仍假設 main 為固定直路；troop_profiles 仍要求 Quickfeet 速度 1.5，與可編輯資源不符。不能為讓舊測試通過回退正式地形／數值。

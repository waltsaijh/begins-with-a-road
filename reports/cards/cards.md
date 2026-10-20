# 建造卡驗證

三張遊戲場景均加入同一個 CardPlacement 組件，卡片取自原型的三種哨塔／周圍道路樣式。卡面已改為可編輯的 card_view.tscn：灰階底紙／框線、獨立塔圖示與文字節點，地塊小圖另用 `_draw()`。TowerDefinition.icon／accent_color 為圖示與染色的唯一來源；BuildCard 可指定卡面變種。PNG／SVG 均可替換。手牌成功放置後消耗，選擇、旋轉、取消或放置失敗不修改地圖與庫存；回合商店見 shop.md。

## 結構與提交

- `assets/data/cards/*.tres`：三種 BuildCard 配置，共用 `assets/data/towers/sentry.tres`。
- `scripts/cards/build_card.gd`：純資料 Resource 與旋轉後的地塊配置。
- `scripts/cards/card_placement.gd`：操作、選擇、預覽失效與呼叫提交。
- `scenes/cards/card_view.tscn`：遊戲與編輯器共用卡片場景，144×208，根節點 Inspector 可指定預覽卡片與預設素材。
- `assets/sprites/cards/`、`assets/sprites/towers/`：可自行繪製替換的灰階 SVG，完整說明位於 assets/sprites/README.md。
- `scripts/cards/presentation/`：卡面狀態繫結、獨立地塊示意、卡片列、整組地塊／塔預覽。
- `TowerDefinition.cells_at()`：所有多格塔與卡片共用旋轉佔格。
- `TowerMap`：卡片／舊塔工具共用驗證、原子提交、佔格與威脅更新。
- `TilePlacement.add_cells()`：批次加入、去重、受影響接口刷新、延後通知。
- `RoadGraphSnapshot.capture(map, blocked, additions)`：預先計算批次完成後的真實接口，完全不寫入 GridMap。

放置時先驗證完整配置，再同步寫入全部幾何與障礙，重建一次入口圖，最後才通知新增格。沒有先寫入、檢查失敗再撤回的路徑。起終點、既有塔／石地與敵軍尚未通過的固定路線均受保護。卡片道路可與原路合併，既有 TileParameters 身分與資料不變。

## 檢查

`tests/cards/cards.tscn` 在 Windows 與 Web 驗證：

- 塔圖示／色彩即時繫結、PNG-like ImageTexture 替換、卡框／底紙／圖示 fallback、選中／旋轉／文字狀態與子節點不攔截點擊。
- 無繞路的封路卡整張拒絕，格數、塔數與 revision 不變。
- 補上三格繞路後，同時在原路建立塔；每個新增格通知都能讀到完整地圖與塔佔格。
- 三個新增格通知、一次入口圖 revision；候選接口與實際提交後接口完全相同。
- 新路繼承 threat=1、num_towers_around=1，原地塊保留同一份參數 Resource。
- 抽取 16 次有效路線，都不穿越塔 footprint。
- 四種朝向、負座標、多格塔與點擊非中心佔格移除。
- 重疊、起點覆蓋、不完整 Resource、無效座標及超界 offset 拒絕。
- 預覽後才開始一波敵人，再點擊建造：重新驗證並拒絕，不信任過期預覽。

`tests/cards/card_preview.tscn` 使用真正的 Compatibility 繪製，驗證選卡按鈕、Q/E 鍵事件傳遞、左鍵地圖提交、整組預覽，並保存 Windows／Web 畫面。

Windows 回歸：`tests/maps/tile_placement.gd`、`tile_animation.tscn`、`tower_obstacles.tscn`、`towers.tscn`、`dead_end_edits.tscn`、`enemies.tscn` 全部通過。包含 9x9／11x11big 與多起點的敵人計畫、單隻生成與 O(N) 顯示分離、障礙繞路及既有死路略過行為。

Web 以單執行緒 release、Compatibility 在本機 Edge 驗證，`tools/web/verify_enemy_web.cjs --cards` 比較原生／Web 的 CARD_CHECK、CARD_RENDER_CHECK 結果並保存畫面；機器可讀紀錄在 cards.json／cards_render.json。這是功能與繪製驗證，沒有進行新的效能基準量測。

## 操作

點卡片或 1～9 選擇對應手牌；左鍵整組放置並消耗一張；Q／E 或右鍵旋轉；Esc 或再選同卡取消。未選卡時，原左鍵單格道路／右鍵單塔工具仍可用。自動波次仍沿用原設定，塔不能攔截已選定的敵軍行程；可於本波結束後建造。

卡片建造只影響未來選路，不改變既有敵人的固定行程。手牌與金幣在本次遊戲中保存，尚無存檔；商店交易見 shop.md，塔攻擊與效果見 combat.md。

# 穩定地塊外觀與浮起動畫

2026-10-16，Godot 4.7.2 Compatibility。

## 外觀保留

Layout.select 接收上一份 layout，直接讀取 TileAppearanceConstants 的 seed、柱距與木橋配置常數，起終點優先，其餘柱子仍在入口且符合半徑時保留；補選的新柱子不能排擠合法舊柱。木橋仍在非入口直線格、符合間距及配額時保留，之後只補足空缺。新增候選或地塊數跨過 16 的倍數，都不讓合法舊橋重新抽籤。失效項目移除，其他合法外觀保留。

配置是保留歷史的貪心演算法，修改順序會影響外觀；同一 seed 與同一修改順序可重現。每次仍掃描現有格子與入口，不宣稱為完全增量選點或最大數量解；只向顯示層寫入模型真的改變的格子。

## 動畫

TileVisuals 把資料與動畫分開。原 TileMap 立即更新且保持所有格子與接口，只關閉其繪製；另一張共用 MeshLibrary、無碰撞的 GridMap 顯示已定位格子。新增地塊或外觀變更時先移除舊顯示；新地塊與木橋從設定的深度浮起，目前預設 Y=-0.75，在 0.5 秒內減速定位。柱子新增／移除時改用固定石質頂面、柱身向下伸長／收回的方式；柱子換木橋時，橋面浮起，原柱身同步收回。只在柱身轉場中使用可伸縮的額外支撐 mesh 與單一暫時材質；純接口改變直接更新接合模型，周圍不會整片升降。

快速連續修改會移除舊暫時模型、更新目標並保留動畫進度。首次載入直接定位，不播放全圖動畫。完成後回到 GridMap 合批並釋放暫時節點；沒有動畫時停止逐幀處理。沒有逐格 Tween、沒有每幀建圖、不延後尋路或地塊參數。

共用預設：TileAppearanceConstants.ANIMATE、ANIMATION_DURATION（0.5 秒）、RISE_DEPTH（0.75 格）。TileVisuals Inspector 可逐場景覆寫 animate、duration、rise_depth。雲層及柱底共用噪聲場的流速係數由 0.13 改為 0.195，即原本的 1.5 倍，層數與貼圖取樣數不變。

## 驗證

tests/maps/tile_animation.tscn 驗證合法外觀保留、失效項目的選擇性替換、配額增加、首次載入不動畫、顯示與資料隔離、共用預設與浮起起點／方向／設定時間內完成、柱子頂面固定及支撐伸縮、快速修改舊模型立即移除、六種正反向與混合替換、動畫完成後清理及停止處理、導航 ports／原生規劃器保持正確。

Windows：本次常數整理後重新通過 tile_animation、tile_variants、tile_placement；dead_end_edits、debug_overlay、towers、enemies 為先前回歸結果。tile_animation_start.png／middle.png／end.png 為先前 Y=-4 版本在起始、途中、定位後的畫面，拍攝時暫時放慢以便比較。

先前的 tile_animation 測試已在 Web release／Edge WebGL2 通過，沒有 script／shader／browser console error，結果記錄於 tile_animation_web.json。使用獨立測試專案匯出，未改動正式專案的主場景與 export 排除設定；本次常數整理未重新執行 Web 測試。未進行 FPS benchmark。

## 新建塔隨地塊浮起

卡片在空格新增地塊與塔時，塔的 Visual 模型直接跟隨腳下地塊相同的浮起進度、深度與時間；邏輯位置、占格與影響資料立即提交。放在已定位地塊上的塔保持原位。快速更新地塊模型會保留塔的跟隨關係，動畫完成或 finish() 後還原模型原始位置並釋放關係。停用 TileVisuals.animate 時塔也立即定位。

`tests/maps/tile_animation.tscn` 同時驗證同步高度、即時邏輯位置、快速修改、完成清理與停用動畫。

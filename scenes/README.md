# 場景目錄

可直接開啟的遊戲入口／功能組合放在各分類根目錄；供其他場景複用或動態實例化的範本，放在原分類的 `components/`。腳本仍放在 `scripts/`，模型與材質仍放在 `assets/`。

| 分類 | 主要場景 | 共用範本 |
| --- | --- | --- |
| 根目錄 | `level.tscn` 正式關卡（由開始選單進入，亦可直接執行）、`main.tscn` 共用遊戲場景、`9x9.tscn`／`11x11big.tscn` 測試地圖 | 各功能分類管理自己的範本 |
| `menus/` | `main_menu.tscn`，F5 開始入口；`map_selection.tscn` 同場景選圖與本局設定介面 | `components/`：可編輯固定橋景、唯讀正式地形預覽、徽記；按鈕與設定頁沿用 settings 範本 |
| `interface/` | `screen_transition.tscn`，跨場景保留的白色過渡 Autoload | 過渡遮罩與時長由場景編輯 |
| `cards/` | 放置系統、手牌、商店與商店整體畫面 | `components/`：卡面、牌背、標題、價格、地塊格、商品槽與旋轉提示 |
| `levels/` | HUD、時間線整體與 ACT 新入口選擇 | `components/`：時間線軌道／節點／ACT 標題、開波對話框、獎勵文字、新入口模型 |
| `maps/` | `tile_map.tscn`，道路與初始起終點 | `components/`：`start_point.tscn`、`goal_point.tscn` |
| `enemies/` | 敵人實體與波次生成器 | `components/`：狀態外觀、批次狀態顯示層、獨立開波控制 |
| `effects/` | 攻擊顯示、死亡／AOE 回收池 | `components/`：死亡與 AOE 爆散範本 |
| `towers/` | `sentry.tscn` 等具體塔種 | `components/tower.tscn`：塔共用基底 |
| `environment/`、`navigation/` | 雲層、除錯面板 | 目前無需拆分 |

詳細的介面編輯位置見 [UI 場景索引](UI_README.md)，地形放置方式見 [地圖說明](maps/README.md)，特效參數見 [特效說明](effects/README.md)。波次編輯器的場景與外掛仍在 `addons/wave_editor/`。

# 遊戲 UI 場景索引

固定介面由場景中的節點編輯；數量依資料改變的卡牌、ACT、波次標記及地塊格子，執行時複用／實例化對應的場景範本。程式處理選取、資料、計時、布局與動畫，不再以 `Control.new()` 建立遊戲介面。共用範本集中在各分類自己的 `components/`，整體介面場景維持在分類根目錄。

| 要調整的內容 | 場景 | 編輯位置 |
| --- | --- | --- |
| 頂部金幣、倍速、暫停與暫停選單 | `levels/level_hud.tscn` | `Header`、`PauseBlocker/Menu`；按下即暫停模擬；根節點 `pause_seconds` 僅控制 0.35 秒手牌與商店收合，`pause_menu_fade_seconds` 控制 0.35 秒淡入淡出；文字選單樣式位於 `assets/themes/pause_controls.tres` |
| 暫停選單項目 | `levels/components/pause_menu_item.tscn` | 固定根 Control 與子 Button；Button 的 Hover Shift／Hover Scale／Hover Seconds 控制左移、放大與 ease-in-out 時長；各選項文字與動作由 LevelHUD 指派 |
| 開波對話框 | `levels/components/start_wave_callout.tscn` | `Shape/Background` 的多邊形、`Border`、`Title`；根節點可調 hover 顏色與邊框粗細倍率 |
| ACT 結束後選擇新入口 | `levels/spawn_expansion.tscn` | `Interface/Root/Panel` 的標題、說明、三個方向按鈕與重選按鈕；`World` 的候選格、路徑與入口預覽；根節點可調搜尋距離與候選帶寬 |
| 新入口模型 | `levels/components/expansion_start.tscn` | `Visual` 的起點模型；邏輯根節點固定，只有模型跟地塊浮起 |
| 時間線整體 | `levels/wave_timeline.tscn` | 根節點的 Preview／Appearance；`Progress` 用 `clip_contents` 水平裁切填色 |
| 時間線軌道 | `levels/components/wave_timeline_track.tscn` | `Line` 的線寬與高度、`StartDivider` |
| 波次圓點與 ACT 分隔線 | `levels/components/wave_timeline_marker.tscn` | `Dot/Fill`、`Dot/Outline`、`Divider` |
| ACT 文字 | `levels/components/wave_timeline_act.tscn` | Label 的高度、對齊；目前 ACT 的字型與整體字級／顏色由時間線根節點指定 |
| 放置旋轉提示 | `cards/components/rotation_key_hint.tscn` | `Key` 底框、`Key/Letter`、`ClockwiseArrow/Curve`、`Head`；根節點可調 0.5 秒停留、淡入時間與浮起距離 |
| 手牌容器 | `cards/card_hand.tscn` | `Cards`；根節點 `vertical_offset` 調整手牌高度，扇形布局由 CardFanLayout 計算；暫停時手牌與商店隨 LevelHUD 的 `pause_seconds` 滑出，白色遮罩由 `levels/level_hud.tscn` 的 `PauseBlocker/WhiteVeil` 調整 |
| 正面卡牌 | `cards/components/card_view.tscn` | 背景、外框、捷徑、塔圖示、標題、價格與地塊圖容器 |
| 卡名、價格、牌背 | `cards/components/card_title.tscn`、`cards/components/card_price.tscn`、`cards/components/card_back.tscn` | 各子節點 |
| 地塊圖的一格 | `cards/components/card_diagram_cell.tscn` | 根 ColorRect 是道路顏色；`Tower` 是塔格顏色，`Tower/Accent` 是塔色圓點 |
| 商店與商品槽位 | `cards/card_shop_view.tscn`、`cards/components/shop_slot.tscn` | `Root/Slots` 與商品槽位內的正面／背面 |
| 獨立測試地圖的開始按鈕 | `enemies/components/enemy_wave_controls.tscn` | `Root/Start`；正式關卡使用起點對話框 |
| 敵人血條、護盾、技能條與狀態圖示 | `enemies/components/enemy_status_appearance.tscn` | 根尺寸是整條容量；`Background` 樣式、`Health`／`Shield` 顏色、`Skill` 位置／尺寸／顏色、`Icon` 尺寸／高度與邊框 |
| 敵人狀態顯示層 | `enemies/components/enemy_status_overlay.tscn` | `EnemyStatusOverlay` 的 `icon_gap`；`Appearance` 是外觀範本，遊戲中會隱藏 |
| F1／F2 除錯面板 | `navigation/route_debug_panel.tscn` | 按鈕、圖例、地塊資訊與錯誤訊息 |

敵人狀態由同一個 overlay 的單一 MultiMeshInstance2D 繪製，每批只保留一份外觀範本，不為每隻敵人建立整組 Control。啟動時讀取上表列出的尺寸、顏色與樣式：矩形 StyleBoxFlat 由 shader 繪製，圓角、陰影及其他樣式一次烘焙到共用圖集；靜態效果圖片首次使用時加入圖集，敵人清空後釋放圖示快取。執行期間修改範本需重新建立顯示層；任意新增的節點不會自動繪製到每隻敵人頭頂。`Health`／`Shield` 在範本中的寬度只用來展示外觀，遊戲中的比例由血量與護盾決定。

節點名稱是程式讀取資料的介面，調整位置、尺寸、樣式與素材即可；如要重新命名節點，也需更新對應腳本路徑。動態集合請編輯其 `.tscn` 範本，而不是執行中的 Remote 複本。場景內顏色若由資料覆寫（塔 accent、目前 ACT、時間線進度），可在其根節點的 Inspector 調整相關設定。

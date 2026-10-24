# 關卡與地圖選單

在本目錄（或子目錄）新增 `LevelDefinition .tres`，重開遊戲或重新進入選圖頁後就會自動出現。只需要這一份關卡資料，不需另外建立 MenuMapDefinition、預覽場景或可執行關卡場景，也不需修改主選單。

在 Inspector 設定：

| 欄位 | 用途 |
| --- | --- |
| Level Id | 唯一且穩定的 ID，供前置條件與通關紀錄使用；空白時以本目錄下相對檔名（不含 `.tres`）作為 ID，例如 `frontier`、`chapter2/bridge` |
| Required To Complete Levels | 必須**全部通關**的前置 ID，沒有前置時留空 |
| Terrain | 實際 GridMap `.tscn`，必須包含道路、至少一個 Start 與剛好一個 Goal；選圖預覽與遊戲都使用它 |
| Acts | 既有 ACT／Wave／SpawnGroup 設定 |

每個 ACT 另有 `Add Start After Completion`（預設勾選），決定該 ACT 結束後是否新增一個出生點；沒有下一個 ACT 時直接完成關卡。這個選項不再放在 Level。波次編輯器可新增／刪除 ACT 與波次，並透過「結束後新增出生點」checkbox 編輯，全部支援復原／重做與儲存重載。

標題與描述的翻譯 key 直接由 ID 推導，不另存欄位：`ui.maps.title.<id>`、`ui.maps.description.<id>`。例如 `frontier` 使用 `ui.maps.title.frontier` 與 `ui.maps.description.frontier`；在 `assets/translations/card_names.csv` 填入英語／繁體中文翻譯即可。子目錄衍生的 ID 保留斜線，例如 `chapter2/bridge`。改 ID 時也要同步改前置條件與翻譯 key。

例如：

```ini
# bridge.tres 的 [resource]
level_id = "bridge"
required_to_complete_levels = PackedStringArray("frontier")
```

```ini
# citadel.tres 的 [resource]：兩關都完成才開放
level_id = "citadel"
required_to_complete_levels = PackedStringArray("bridge", "forest")
```

前置關係由 ID 清單表達 DAG；不直接互相引用 Level Resource，避免循環資源載入。列表以 Kahn 拓撲排序自動產生：沒有前置的關卡先列出，之後逐層列出所有前置皆已排入的關卡；同層按 ID 字典序排列。例如 `frontier → bridge` 一定是 Frontier 在前，即使 `bridge` 字母較小。順序不隨通關狀態或檔案掃描順序改變，不需手動設定順序。

重複邊會去重，重複 ID、缺失前置、自我依賴、環及依賴錯誤分支的關卡都會保持鎖定，選圖頁提示設定有誤；這些錯誤項目放在正常 DAG 之後，按 ID／資源路徑排列，仍可查看。其他正常分支仍可遊玩。修改 ID 代表不同關卡；已有通關紀錄的關卡應保留 ID，重新命名／移動檔案時也建議明確填寫原 ID。

未解鎖的地圖仍可左右切換與查看預覽，描述區顯示未完成的前置名稱，「下一步／開始作戰」不可用。缺少 Terrain／ACT 的草稿仍會列出並顯示資料尚未完成。第一次開選圖會優先選可玩地圖，再次進入保留原選擇。

預覽使用共用 `scenes/menus/components/map_preview.tscn`；只在選中時實例化該 Level 的地形，切換時釋放舊地形，不同時建立所有地圖。沿 Z 較長的地形會旋轉展示相機，使長軸水平；維持正交、45° 俯角、Zoom 1.0、Bottom Clearance 280px。節點腳本在進入場景樹前移除，停用處理及碰撞；不載入 LevelSession、波次、導航或商店，不修改原始地形資源。

起終點只在地形場景編輯，Level 不保存 Starts／Goal、端點來源開關或 Marker Height。端點自己的 `Height Offset` 控制模型相對格子表面的高度，預設 0.0305；ACT 新增入口與預覽沿用第一個地形入口在 GridMap 局部座標中的高度偏移。缺少端點會回報設定錯誤，不使用隱含座標備援。

所有地圖都透過共用 `scenes/level.tscn` 執行，選中資料在新場景進樹前一次性交接；不改寫 PackedScene、預設 Frontier 或原始 Resource。重新開始保留所選關卡，回主選單清除待交接資料。

完成最後一波後才保存 Level Id 至 `user://level_completion.cfg`，跨次啟動保留；中途返回、重新開始或關閉視窗不算通關。只保存通關 ID，不保存進行中的局、塔、金幣或手牌。Windows 是 Godot 的專案使用者資料目錄，Web 使用該網站／瀏覽器的本機持久儲存；清除網站資料會清掉紀錄。

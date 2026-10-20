# 翻譯 key 規則

使用點號分隔命名空間，每段都是小寫 snake_case。key 是穩定識別碼，不是顯示文案；修改中英文名稱時只改 CSV 內容，不改 key。

| 用途 | 範例 |
| --- | --- |
| 兵種名 | `troop.soldier.name`、`troop.heavy.name` |
| 塔名 | `tower.sentry.name`、`tower.crossfire.name` |
| 地塊前綴 | `tile_preset.corner`、`tile_preset.blasting` |
| 暫停選單 | `ui.pause.resume`、`ui.pause.exit` |
| 卡名組合格式 | `card.name_format` |
| 未設定卡片 | `card.unassigned` |

Troop 與 TowerDefinition 的 **Name Key** 與 TilePreset 的 **Prefix Key** 填入上述識別碼。實際英文、繁體中文放在 `card_names.csv` 的 `en`／`zh_TW` 欄。例如新增兩個字的地塊 ID 可以使用 `tile_preset.corner_bridge`。

`card.name_format` 的英文值為 `{prefix} {tower}`，中文值為 `{prefix}{tower}`；請保留格式中的兩個 placeholder。卡面本身使用獨立的前綴／塔名節點，套用對應字重與行數。

編輯 CSV 後讓 Godot 重新匯入；產生的 `.translation` 已登錄在專案設定。切換語言使用 `TranslationServer.set_locale("en")` 或 `TranslationServer.set_locale("zh_TW")`。新增 key 時也應補齊兩種語言，避免畫面直接顯示識別碼。

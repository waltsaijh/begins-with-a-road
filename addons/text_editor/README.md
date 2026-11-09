# 遊戲文本編輯器

開啟本專案的 Godot，點上方 **遊戲文本** 分頁。也可從 **專案 → 工具 → 遊戲文本編輯器** 開啟。外掛已在 project.godot 啟用；若原本的編輯器還沒出現新分頁，重新開啟專案，或到「專案設定 → 外掛」啟用「遊戲文本編輯器」。

1. 左上選分類，或搜尋中文、英文、名稱／識別碼。
2. 左側選文字，在右側直接編輯繁體中文與英文。直接按 Enter 換行，不必手動處理 CSV 引號。
3. 下方查看換行與唯讀預覽。遺物會帶入目前資源中的實際數值；其他動態內容以提示字代替。
4. 按 **儲存全部修改**。下一次啟動遊戲就會使用新文字。

修改中的詞條前有圓點，底部顯示未儲存筆數。Ctrl+Z／Ctrl+Shift+Z 使用 Godot 原生復原／重做；切換詞條不會丟失草稿。重新載入遇到未儲存修改時會先詢問。

## 可以修改什麼

主選單、關卡、設定、教學、結算、進度頁、塔／卡牌與遺物名稱說明、敵軍介紹／行進路線／能力、時間軸提示與單位資訊。已把先前分散在 GDScript 的玩家中英文文案移到共同翻譯表；敵人既有的自訂文字保持原文，不恢復舊版本。新增兵種如果沒有對應詞條，仍可使用原 Resource 的文字備援。

工具只修改 `assets/translations/card_names.csv` 的兩語文字欄；不提供編輯識別碼、價格、傷害、攻速、尋路權重或技能參數的功能，也不儲存任何遊戲 Resource。`{bonus_percent}`、`{duration}`、`%d`、`%s` 等必要內容由程式帶入；可以移動位置，但不能刪除、改名或改格式。輸入缺少參數時會顯示原因並停用儲存，修正或復原即可。

CSV 儲存保留未修改資料列的原始內容與順序，支援多行、逗號、雙引號、中文及 BOM。寫入暫存檔驗證後才替換原檔，並通知 Godot 重匯翻譯。若原檔已被外部工具修改，會保留編輯草稿並拒絕覆寫；可先複製要保留的草稿，再重新載入與整合。

## 維護與驗證

- `text_document.gd`：CSV 草稿、驗證、衝突檢查與文字欄儲存。
- `text_editor.tscn`／`.gd`：Godot 主工作區、分類搜尋、中英欄位、預覽與復原／重做。
- `scripts/interface/game_text.gd`：正式遊戲讀取共同文案；不引用 editor 外掛。
- `RelicDefinition.description_values()`：提供唯讀數值，與正式遺物說明共用。

```powershell
Godot --headless --path . --script res://tests/editor/text_document_check.gd
Godot --headless --path . --editor -- --test-text-editor
Godot --path . --script res://tests/editor/text_editor_preview.gd
```

外掛測試只寫入忽略的 `.godot/text-editor/` 測試副本，不把測試文字寫回正式翻譯表。

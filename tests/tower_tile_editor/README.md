# Tower Tile Editor 驗證入口

- `combinations_input.tscn`：必須真渲染；具名跨塔組合、實際勾選／另存／切換重開、商店／放置白名單、內建隱藏／排除、空池及較高塔身的預覽／實例一致性。

- `editor.tscn`：直接進入繪圖工作台，再一鍵返回同一個試玩關卡。
- `playground.tscn`：從直線地圖開始，右上選塔／配置、補牌、編輯、重抽與重開。
- `rules.tscn`：可 headless；原生資源存取、真實商店權重、任意連通形狀、完整占位／旋轉／升級／清理、六塔邏輯中心及自訂兵營、三種路線規則。
- `input.tscn`：必須真渲染；以 SubViewport 注入實際滑鼠／鍵盤，執行繪圖、接口、存取、拖放、兩波混兵、重開、刪除確認及十字塔體。

測試使用獨立 `.godot/test-results/tower_tile_editor/` 配置目錄，避免改動使用者正式自建資源；圖、JSON 與 log 也存於該處。完成 marker 和空 failures 才表示通過，並須檢查沒有 SCRIPT ERROR，不能只看 `--quit-after` 的 exit code。原始 `.tres` 留作持久化測試證據。

操作、直接 runtime 啟動命令、人工情境 A–E、當次結果及限制見 [工具文件](../../docs/tower_tile_editor.md)。

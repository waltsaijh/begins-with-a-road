# 開發工具

以下命令均在專案根目錄執行。工具不隨遊戲匯出；素材產生腳本會寫回指定的 assets，只在需要重建時執行。

| 目錄 | 用途 |
| --- | --- |
| `build/` | Windows／Web GDExtension 建置 |
| `assets/` | Godot 離線重建地塊庫、敵人、塔、端點、介面圖示與卡牌圖片 |
| `web/` | 測試場景匯出、本機伺服器及 Playwright 功能驗證 |

```powershell
./tools/build/build_native.ps1 -Platform windows -Target template_debug
./tools/build/build_native.ps1 -Platform web -Target template_release
python tools/web/serve_web.py --port 8765
godot --headless --path . --script res://tools/assets/build_tile_library.gd
godot --headless --path . --script res://tools/assets/build_sentry_shot.gd
```

建置環境、SDK 版本與額外參數見 [原生核心](../native/README.md)。伺服器預設讀取 `build/web/`，只監聽 `127.0.0.1`。

`build_sentry_shot.gd` 以固定亂數種子合成哨塔弓弦與箭矢破風聲，輸出 `assets/audio/towers/sentry_shot.wav`（0.22 秒、48 kHz、16-bit mono，無外部取樣）。重新產生後讓 editor 匯入 WAV；正式關卡只讀取音檔，不執行合成器。

五塔離線轉換為 `godot --headless --path . --script res://tools/assets/restore_towers.gd -- --prototype=D:/games/card-tower-defense`；只讀來源，會覆寫 Sandbox 內產生的五塔資源／模型／音效，不處理 Sentry。圖示使用實際渲染命令 `godot --path . --script res://tools/assets/render_restored_tower_icons.gd`，完成後讓 editor 匯入圖片，再重跑轉換器即可綁定新圖示。重建前檢查人工修改，來源與參數語意見 [塔資料](../assets/data/towers/README.md)。

Web 功能驗證可使用 `web/export_test.ps1 -Godot <Godot執行檔>`，預設將 `tests/enemies/enemies.tscn` 匯出至 `.godot/enemy_web/index.html`。`-Scene` 與 `-OutputDirectory` 可指定其他測試；工具在結束時還原主場景與匯出設定，正式匯出仍排除測試。

正式 Web 輸出可附上 `web/start_game.ps1`（複製為輸出目錄的 `StartGame.ps1`），以 Windows PowerShell 提供本機 HTTP、wasm MIME 與跨來源隔離標頭，自動在 Chrome 開啟。不依賴 Python／Node；`-NoBrowser` 供測試、`-Port` 可改連接埠。它是輸出目錄的啟動輔助工具，不會放入遊戲 PCK；不得直接用本機 file:// 開啟匯出的 HTML。

`node tools/web/verify_release_audio.cjs --directory=build/web` 在獨立Chrome context量測成品destination的真實音訊，無autoplay豁免：首次手勢後BGM、隔離BGM的UI音效、BGM與Master靜音／恢復均須通過。需要Playwright，TEST_BROWSER可指定Chrome；啟動成品StartGame.ps1使用8797連接埠，結束會清理瀏覽器與伺服器。報告位於.godot/test-results/audio/web-release.json，工具不會匯入PCK。

`web/verify_enemy_web.cjs` 讀取已匯出的測試與對應原生 log，比對 Windows／Web 結果。設定 `PLAYWRIGHT_MODULE`、`TEST_PYTHON`、`TEST_BROWSER` 後執行；`--directory=<匯出目錄>` 可指定服務位置。預設比對 enemies，原生輸出需存為 `.godot/enemy_tests.out`。其他選項與檔名見該腳本的 suites 表；多場景驗證需先將各測試以對應 HTML 名稱匯出至同一目錄。JSON、截圖寫入 `.godot/test-results/<功能>/`，log 放 `.godot/`。

已完成的一次性 benchmark 收集與彙整工具已清除，歷史結論見 [報告索引](../reports/README.md)。新的臨時量測工具用完即清除，原始資料保存在 `.godot/test-results/`。

Phase 4 六種敵軍的低面數場景與 SVG 圖示由 `python tools/assets/build_synergy_models.py` 產生；只使用 Python 標準函式庫，不讀取原型專案。重建前檢查手動修改，資料與模型責任見 [兵種](../assets/data/troops/README.md) 與 [敵人模型](../assets/models/enemies/README.md)。

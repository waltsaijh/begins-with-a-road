# 開發工具

以下命令均在專案根目錄執行。工具不會隨遊戲匯出；Godot 素材產生腳本會寫回指定的 assets，請只在需要重建素材時執行。

| 目錄 | 用途 |
| --- | --- |
| `build/` | `build_native.ps1`：Windows／Web GDExtension 建置 |
| `assets/` | Godot 離線素材重建：地塊庫、敵人、塔、端點、介面圖示與卡牌圖片 |
| `assets/blender/` | 先前方塊角色原型的 Blender 建模、匯出與預覽腳本；不影響目前遊戲模型 |
| `web/` | Web 匯出的本機伺服器及 Playwright 功能驗證 |
| `benchmarks/` | 跨平台候選路線效能收集與報告彙整 |

```powershell
./tools/build/build_native.ps1 -Platform windows -Target template_debug
./tools/build/build_native.ps1 -Platform web -Target template_release
python tools/web/serve_web.py --port 8765
godot --headless --path . --script res://tools/assets/build_tile_library.gd
```

建置環境、SDK 版本與額外參數見 [native/README.md](../native/README.md)。伺服器預設讀取 `build/web/`，只監聽 `127.0.0.1`。Web 驗證腳本需要先匯出對應測試及準備原生測試 log，再設定 `PLAYWRIGHT_MODULE`、`BENCHMARK_PYTHON`、`BENCHMARK_BROWSER`；報告寫入 `reports/` 的功能分類目錄。

Blender 腳本供 Blender／MCP 工作階段使用，需要 `bpy`。其中 `ROOT` 指向本機專案位置，換機或搬移專案時請先更新；一般 Godot 遊戲執行不會載入這些腳本。

極端負載測試使用 `tests/performance/extreme.tscn`。先將 Windows 執行輸出保存為 `.godot/extreme_windows.out`，再以 `benchmarks/export_extreme.ps1 -Godot <Godot執行檔>` 匯出測試場景。該工具會在結束時還原原始主場景與匯出設定。接著設定上述三個環境變數並執行 `node tools/benchmarks/benchmark_extreme.cjs`，啟動本機伺服器與 headless 瀏覽器、比對路線結構及配額指紋，將原始逐幀資料寫入 `reports/performance/`。完整方法與限制見 [效能報告](../reports/performance/extreme_2026-10-20.md)。

雙 GPU 筆電可再執行 `node tools/benchmarks/benchmark_extreme.cjs --high-performance-gpu`，要求瀏覽器使用高效能 GPU，另存 `extreme_web_discrete.json`；以結果中的 WebGL renderer 確認是否生效。最後執行 `node tools/benchmarks/summarize_extreme.cjs` 產生比較報告。

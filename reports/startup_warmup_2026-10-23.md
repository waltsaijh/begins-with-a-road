# 2026-10-23 主選單前共用顯示預熱

## 變更

正式入口改為明確配置的 `scenes/menus/boot.tscn`。啟動場景在白色載入介面下，以主 viewport、原敵人 renderer、與關卡共用的 Environment 及相同方向光實際繪製代表，再轉入原主選單。不建立關卡、敵群、導航、商店或正式出發配額。

DisplayWarmup 保留代表 Resource 與完成的顯示組合。組合由有效材質設定／shader、紋理、頂點格式、一般／MultiMesh、蒙皮／blend shape、陰影及 overlay 等條件決定；未知腳本或非變換動畫保守區分。Soldier 與 Quickfeet 兩個代表涵蓋目前三種正式兵種，Heavy 不重複預熱。viewport、MSAA、Environment 或光源／陰影條件不同，以及新材質組合仍由關卡補漏。正常啟動後 Frontier 只剩入口圖與第一波路線兩項準備；直接執行主選單仍可補漏，不依賴啟動成功的單一布林值。

啟動與轉場引用同一份明確配置的 LoadingDisplay；完成數是工作項目，不是 shader 編譯百分比或時間估算。第一波仍手動開始，沒有改動模型材質外觀、光照上限、尋路或敵人移動迴圈。

## Web 量測

實際點擊主選單 → 選圖 → 本局設定 → 開始作戰 → 開始下一波。使用未修改的正式 Frontier，第一波原本 4 名 Soldier；沒有套用歷史 32×32／256 人合成負載。

可見 Edge 155.0.4283.62、1280×800、DPR 1、AMD Radeon Graphics／ANGLE D3D11、Compatibility release、單執行緒及同一份原生擴充。每次啟動新的瀏覽器工作階段，不清除系統／驅動 shader 快取，也未限制 CPU 時脈。rAF 觀察到最高約 144 Hz；這不是原生遊戲 CPU 幀時間或固定 60 Hz 測試。

對照匯出以本次相同程式關閉啟動入口與代表去重，維持在選圖進關卡時準備三個模型；其餘 UI、波次、Environment 及渲染條件一致。新流程兩輪有效，舊流程一輪有效，不據此宣稱總啟動時間或穩態 FPS 改善。

| 指標 | 舊流程 before-2 | 新流程 after-1 | 新流程 after-2 |
| --- | ---: | ---: | ---: |
| 網頁開始執行至主選單兩次 rAF 確認 | 24.86 s | 31.61 s | 34.24 s |
| 進關卡轉場開始至完成（遊戲內事件） | 11.56 s | 1.65 s | 2.22 s |
| 完全變白後至關卡準備／淡入完成 | 11.31 s | 1.39 s | 1.97 s |
| 載入階段超過 20 ms 的 shader／program 查詢累計 | 9713 ms | 448 ms | 528 ms |
| 載入階段最長 shader／program 查詢 | 2540 ms | 79 ms | 82 ms |
| 首次開波點擊至生成後兩次 rAF | 1.765 s | 1.770 s | 1.683 s |
| 首次開波完整觀察窗最大間隔 | 27.75 ms | 27.87 ms | 27.89 ms |
| 觀察窗平均／P95／P99 | 7.14／7.10／13.88 ms | 7.37／13.78／13.99 ms | 9.55／14.02／20.88 ms |
| 最後 300 幀平均／P95／P99 | 6.97／7.08／7.11 ms | 7.11／7.07／13.85 ms | 8.84／13.95／14.16 ms |
| 關卡工作數／保留的代表 Resource 數 | 5／3 | 2／2 | 2／2 |

網頁至主選單包含 Godot／WASM 啟動及主選單自身的首次繪製，不可與玩家先前看到的選圖後約 11 秒當成同一段。新流程首個計時幀至啟動轉場開始的區間約 8.92／9.70 秒，包含代表繪製與清理；不是精確 GPU 編譯時間。新流程在主選單前仍有秒級編譯等待，載入 UI 仍可能凍結；本次主要是前移等待及避免重複代表，沒有消除總成本。

首次開波觀察從點擊開始，持續至首隻生成後至少 12 秒，包含原本 1.5 秒開場等待；三輪均正確生成 4 人。每輪首次出兵階段均沒有超過 20 ms 的 shader／program 查詢，沒有觀察到秒級出兵卡頓。這裡的舊流程已包含選圖後預熱，因此兩者首次出兵都平滑；不能稱為相對於「完全沒有預熱」的改善量。總逐幀樣本 5236 個，最後 300 幀僅作當次觀察，不代表長時間效能。

原始資料、逐幀間隔、進度、WebGL 查詢、console、截圖、來源／匯出包雜湊及 Windows 功能 log 放在 `.godot/test-results/menus/startup_web/`。`summary.json` 選取上述三輪。`before-1` 的額外往返操作逾時、`before-3` 在預定出兵前發生額外場景切換，均未納入表格。瀏覽器點擊指令的排程延遲與狀態輪詢會影響 JS 端量測，因此進關卡使用遊戲內 transition_start／transition_end；firstDraw 是帶輪詢誤差的畫面確認時間。

有效三輪均無 pageerror／Godot ERROR，但原有 WebGL buffer INVALID_OPERATION 警告仍存在（舊 70、新 66／64 筆），尚未修復，也未用來解釋本次編譯等待。量測後僅補上材質腳本、幾何淡出／透明／層與光源 mask 的保守辨識；正常三兵種及環境的代表選擇不變，最終 Windows／headless 回歸再次驗證兩個代表與兩項關卡工作。正式 Web 另做無計時探針的畫面檢查，確認主選單、關卡與實際首次出兵模型／血條，見 `release_menu.png`、`release_level.png`、`release_first_wave.png`。匯出程序有既有 Windows GDExtension DLL 影子複本佔用錯誤，但 release 匯出完成、實際 Web 原生路線及出兵可用；沒有為此關閉使用者編輯器。console、匯出 log 與正式包雜湊另留存。

## 功能驗證

- `startup_loading`：Windows RTX 3050 實際渲染及 headless 通過。檢查兩個代表、Heavy 去重、透明材質不誤合併、主 viewport、載入 UI、RNG、資源保留、關卡重用及 MSAA 改變補漏；載入畫面 `.godot/test-results/menus/startup_loading.png`。
- `scene_loading`：Windows 實際渲染及 headless 通過。直接開選單時準備四項，僅兩個顯示代表；開波鎖定、清理、進度與失敗／取消恢復通過，fixtures 的兩個轉場 ERROR 是預期輸出。
- `main_menu`：最終 Windows 實際渲染通過，包含原選單、設定、雙語、選圖／本局設定、返回主畫面、全新開局與九次白色轉場。
- `level_flow`：最終 headless 通過；未重跑全部專案功能或 256 人壓測。

一次性計時 Autoload、瀏覽器腳本、對照匯出包及測試服務用完移除；正式設定恢復並將不含計時探針的版本匯出至 `build/web`。

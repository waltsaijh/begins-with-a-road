# 特殊事件驗收

在 Godot 開啟 `tests/events/playground.tscn` 按 F6。這是獨立的雙入口、三座 Lv.2 塔、200 Gold、100 HP 測試關卡，不改正式 Frontier。

左上選單可指定九事件並按「Open event」，另提供 +100 Gold。只允許準備期開啟；進入後必須選 A／B、需要時再點高亮塔，不能取消。完成後照常用手牌及入口開波。可逐項確認：

1. 偵查兵 A 新增真正可通行支路；B 的每入口情報皆 +10。
2. 補給升級三塔，或指定拆塔後留下地面。
3. 商人購藥後點塔，可把 Lv.3 升到 Lv.4；普通塔牌仍不能繼續突破。Gold 不足只能選起司。
4. 徵兵點塔後有變暗／停火圖示，下一波不攻擊，波後恢復。
5. 道路牌可旋轉、拖放；兩張碎石可跨波保留，未放完則下一波真實傷害少 10%。
6. 祭壇扣基地 HP 並即時取得遺物，HP≤5 時 A 停用。
7. 工程師付款升兩塔；拒絕隨機降級，全部 Lv.1 時不能拒絕。
8. 軍餉的免費牌使用正常塔種／地塊配方；A 的重裝兵出現在下波情報並實際出生。
9. 大寶石未放置不加傷害；小寶石第三張放完才在後續正常清波多發 5 Gold。

自動回歸（Windows）：

```powershell
& 'C:/tools/Godot.exe' --headless --path 'D:/games/begins-with-a-road-routing' res://tests/events/regression.tscn
```

輸出 `SPECIAL_EVENTS_RESULT {"checks":...,"failures":[]}`。錯誤 log 也須核對，不以引擎 exit code 單獨判定。視覺批次以 `res://tests/events/playground.tscn -- --events-screenshots` 執行，截圖在 `.godot/test-results/events/`。繁中／英文皆擷取 1280×800 的九個事件，並以代表事件檢查 800×600 和 640×480。商人另外擷取 hover、金幣不足及離場，並用滑鼠事件驗證按壓與點擊；神秘寶石附第三張卡與備援插畫的版面測試。批次結束輸出 `EVENT_VISUALS_SAVED []`。

Web：

```powershell
./tools/web/export_test.ps1 -Godot 'C:/tools/Godot.exe' -Scene 'res://tests/events/regression.tscn' -OutputDirectory '.godot/special_events_web'
# 設定 PLAYWRIGHT_MODULE、TEST_PYTHON、TEST_BROWSER 為本機既有安裝後執行：
node tools/web/verify_special_events.cjs
```

測試匯出仍使用現有單執行緒 Web preset 與原 native WASM，測試檔案只在這份專用匯出暫時放行；正式 preset 排除設定與啟動場景會還原。如需 `--baseline`，先以相同 export_test 工具將 `res://tests/cards/rotation_pivot.tscn` 匯出到 `.godot/special_events_web/baseline`；此對照用於辨識既有 WebGL 警告，release 引擎不支援命令列覆寫場景。功能結果、警告及 browser log 寫 `.godot/test-results/events/`。此匯出不是正式發行包。

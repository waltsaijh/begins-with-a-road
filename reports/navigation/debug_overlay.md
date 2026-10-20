# 地圖除錯介面

2026-10-16，Godot 4.7.2 Compatibility。

- F1：目前兵種／起點候選池的有效節點與邊；不顯示編號，原始成本低的線較粗，高成本保留最小半線寬 0.022 地塊單位。共用實體線段採最低 edge 成本顯示，保留所有局部同成本連線。
- F2：threat 紅色熱圖與游標地塊欄位。較大 threat 呈現更紅、更不透明；未受威脅者不覆蓋。涵蓋 num_towers_around 與現有每格欄位。
- F3：本波所有預約行程的實體線段聯集，包含尚未出生者；每個敵人對相同線段只計一次，綠線寬度隨人數增加。本波完成後保留結果至下一波。

預設全部關閉，可獨立切換。移除舊常駐統計面板、區域顏色、邊界、節點編號與 N/P/Tab/G/L 操作。R 保留起點切換。每層一個 mesh，只在資料修改或首次開啟時建立；F2 關閉時停用滑鼠地塊查看。

原生增加 lazy get_debug_graph，取既有候選池的成本／局部走法，不建立 DAG、不重新搜尋。一般 find_paths 摘要不增加大型 debug payload；修改回傳資料不會破壞快取。

測試 tests/navigation/debug_overlay.tscn 驗證預設隱藏、沒有 Label3D、110 個有效節點／240 個有向選項（原 9x9 場景）、低／高成本線寬、極端成本下可見、熱圖、參數查看、流量包含待生成者、獨立切換與移動時 mesh 不重建。直橋的獨立對照：23 段，每段都包含 64 人。

tests/enemies/enemies.tscn 與 tests/combat/towers.tscn 同時驗證每波 64／每批 2、尾批、八鄰域、圓形半徑、疊加、移除、新地塊繼承及已預約行程不改變。Web release 測試使用一般 _check，而非會被 release 略過的 assert，所有操作與條件在匯出後仍執行。

Windows 與單執行緒 Web release 的三組測試全部通過，結果一致，瀏覽器沒有 console error。原始資料：debug_overlay.json、enemies.json、towers.json。圖片：debug_1.png、debug_2.png、debug_3.png。tools/web/verify_enemy_web.cjs --towers --debug 收集三個 Web 測試場景，並與 Windows 結果比對。

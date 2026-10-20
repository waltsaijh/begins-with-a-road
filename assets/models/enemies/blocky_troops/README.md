# 圓角方塊兵種

以 `blocky_grunt` 為基礎，透過 Blender MCP 製作的三種兵種外觀草稿。此資料夾保留可編輯原檔；目前遊戲的 Model 已改用從 `card-tower-defense` 匯入的 grunt、runner、brute，對應資源位於上一層資料夾。

| 兵種 | 造型 | 遊戲模型 | 三角形 |
|---|---|---|---|
| Soldier | 保留紅色衣甲、頭盔與長矛，移除盾牌 | `soldier/soldier.glb` | 4,518 |
| Quickfeet | 較瘦的輪廓、卡其色上衣、與 grunt 同色的紅色吊帶褲、小刀，無盾 | `quickfeet/quickfeet.glb` | 6,404 |
| Heavy | 加高加寬上身、胸背甲、肩甲、臂甲、包覆式頭盔、大型金屬盾，無長矛 | `heavy/heavy.glb` | 9,212 |

每個模型都是 5 個網格、1 個材質，內嵌 64×64 調色盤貼圖。`Walk-loop` 是一秒循環，Godot 可自動辨識並播放。Quickfeet 步幅較大，Heavy 的步幅與手臂擺動較小。模型面向 Godot -Z，原點位於腳底。各兵種的 icon 與能力數值由原有 `.tres` 設定。

`source/blocky_troops.blend` 保留三個 Editable 場景與三個合併後的 Game Export 場景；`Troops - Lineup` 是並排預覽。原始 grunt 參考場景也一併保存在 Blender 檔內。專案根目錄的 `reports/assets/blocky_troops.png` 是預覽圖。

修改外觀時使用各兵種的 Editable 場景，零件按 Soldier、Quickfeet、Heavy 前綴命名。重建工具為 `tools/assets/blender/build_blocky_troops.py`，需要 Blender 中已有 `Blocky Grunt - Character` 參考集合；它會呼叫共用的 `tools/assets/blender/export_blocky_grunt.py` 匯出。`tools/assets/blender/preview_blocky_troops.py` 製作預覽並儲存原檔。

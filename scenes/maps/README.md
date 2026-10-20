# 在場景中編輯道路與起終點

開啟 `tile_map.tscn`：

1. 選取根節點 **TileMap**，使用 Godot 的 GridMap 筆刷繪製／刪除道路；同一層 `Y = 0` 上相鄰的道路會在遊戲中自動連接。
2. 展開 **Endpoints**，選取 **Start** 或 **Goal** 的根節點，用移動工具擺到道路上。端點會自動貼齊格子；旋轉根節點可改變模型朝向。
3. 選取 **Start** 後按 **Ctrl+D** 可新增起點，也可以將 `components/start_point.tscn` 拖入 Endpoints。新地圖可拖入 `components/goal_point.tscn` 作為終點；每張地圖需要至少一個起點與剛好一個終點。
4. 儲存地形場景後按 **F5** 執行關卡。關卡資源的 `terrain` 指向這個場景，`use_terrain_endpoints` 預設啟用，無須另外修改座標。

請移動 Start／Goal 根節點，而不是底下的 Visual。`height_offset` 控制端點模型距離地表的高度，`snap_to_grid` 可切換編輯器的自動對齊。模型細節可在 `components/start_point.tscn`／`components/goal_point.tscn` 的 Visual 中調整。

多個入口依場景樹中的順序編號。波次編輯器的「出生入口」會自動列出各入口及其格子座標；修改順序也會改變編號。敵人沿已擺放的道路尋路，分岔時繼續使用各兵種原有的 Uniform／Softmax 設定。

端點放在空地、互相重疊、缺少起點／終點，或道路無法連通時，關卡會回報設定錯誤。沒有端點的舊地形仍可使用關卡資源的 `starts`／`goal`；停用 `use_terrain_endpoints` 也可明確改用這組舊座標。

`main.tscn`、`9x9.tscn` 與 `11x11big.tscn` 是保留獨立起終點的測試場景，因此會隱藏地形中的 Endpoints 預覽。正式關卡 `level.tscn` 會從地形取出端點、保留外觀與朝向，供尋路及起點對話框共用，不會重複繪製兩套模型。

上述三個獨立場景固定自己的地形原點，避免修改共用 `tile_map.tscn` 的根節點位置後，原有測試起終點偏離道路。正式關卡仍會使用所選地形場景保存的變換與端點位置。

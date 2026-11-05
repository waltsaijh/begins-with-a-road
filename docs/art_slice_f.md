# Art Slice F — Tower Color Identity

2026-11-05，Godot 4.7.2／Compatibility，沿用 Art Slice E 六塔正式外觀。本輪完成 B 識別色版本，預設供新建正式塔與 Ghost 使用；A 暖灰白基準保留，可隨時切回。沒有重製模型、改動畫或調整戰鬥、占格、道路、UI、正式攝影機及環境。

## 配色結果

| 塔 | 識別色 | 集中區域 | 著色三角形表面面積占比 |
| --- | --- | --- | --- |
| Watchtower／sentry | `#648A82` 青綠 | 頂部護欄、後擋與武器座；平台底板保留原色 | 24.3% |
| Great Ballista／ballista | `#537B9A` 鋼藍 | 兩側弓臂與中央箭軌外側 | 17.8% |
| Barracks | `#B78C58` 赭金 | 雙門及上部堡壘防護結構 | 17.8% |
| Mortar | `#A96F61` 磚紅 | 短粗主砲管外殼，內膛保留深色 | 13.0% |
| Crossfire | `#887BA6` 灰紫 | 四向發射器外殼 | 18.9% |
| Broadside Airship／broadside | `#648EA0` 青藍 | 船舷、甲板與駕駛艙；大面積升力艇體保留暖灰白 | 43.4% |

採用原候選色，沒有新增第三色。上表為所有三角形面積（包含不可見面），不是畫面像素占比；飛行艇可見的大型暖白升力艇體仍是主要輪廓。所有塔超過一半的表面保持原色，砲口、弦、箭矢與機械深色頂點變更數為零。第一輪較大的哨塔平台與飛行艇頂面著色已收斂至上述區域。

## 可回退、可重建的管線

- 可編輯輸入：[tower_color_identity.tres](../assets/data/rendering/tower_color_identity.tres) 的 `identity_colors`、`identity_parts`，以及 Inspector 的 `Variant`（A／B，預設 B）。這是專案配色設定，未改 TowerDefinition 的卡牌 accent_color。
- A 網格及原包裝場景留在 `assets/models/towers/integrated/`；B 的 31 個共享網格留在 `assets/models/towers/color_identity/b/`。原 GLB、Blender、動畫場景與節點路徑皆保留。
- 離線建置依原 GLB 零件名選取功能區，在合併前烘焙 COLOR；最終以 A 的已保存 surface buffer 為基準，只複製 B 的 RGBA8 COLOR 位元組。這避免二次法線量化，非 COLOR buffer 完整保留。
- 執行時只替換共享 Mesh 引用；仍共用原 `solid_color.tres`，不新增 Shader、貼圖、材質實例、surface、動畫軌或每幀配色工作。正式塔與 Ghost 皆由相同外觀 factory 在 configure 時套用同一 Variant。
- 修改 Variant 後重新執行遊戲／重新建立外觀即可；測試場景可即時切換既有塔。此輪沒有新增正式遊戲的配色 UI。

```powershell
# 修改識別色／區域後，只重建 B，不覆寫 A 或 GLB。
& C:/tools/Godot.exe --headless --path . --script res://tools/assets/build_integrated_towers.gd -- --identity

# 未來更換 GLB 時：先匯入，重建 A，再重建 B。
& C:/tools/Godot.exe --headless --editor --path . --import
& C:/tools/Godot.exe --headless --path . --script res://tools/assets/build_integrated_towers.gd
& C:/tools/Godot.exe --headless --path . --script res://tools/assets/build_integrated_towers.gd -- --identity
```

`_surfaces` buffer 複製使用本專案 Godot 4.7.2 的序列化格式，只處理自有的衍生 ArrayMesh，不編輯 `.godot/imported`。升級 Godot 後須重跑幾何／材質一致性檢查。

## A/B 畫面與切換方式

F6 執行 [tower_color_identity.tscn](../tests/combat/tower_color_identity.tscn)：A／B 切色，1 正式 Frontier 六塔、2 密集 192 塔、3 最遠遊戲縮放。附加 `-- --capture` 自動儲存六張單圖及三張並排圖。每組左 A、右 B，原圖各 1280×800，並排圖無縮放。

同一組只切網格色盤，保留完全相同的塔、地圖、相機、光照、縮放與 UI。等待浮起／手牌動畫完成後才凍結顯示；背景雲層的 shader 時間一併固定。相機沿用正式 45° 仰角、30° 方位角，Frontier size 18.5；最遠 size 30.8333（18.5／minimum_zoom_scale 0.6）。未修改正式場景設定。

- [六塔 A](../.godot/test-results/modeling/art_slice_f/field_a.png)／[六塔 B](../.godot/test-results/modeling/art_slice_f/field_b.png)／[並排](../.godot/test-results/modeling/art_slice_f/field_comparison.png)：透過正式 validate_card／place_card 放入 Frontier，含原道路、雲海、卡牌與 HUD。
- [192 塔 A](../.godot/test-results/modeling/art_slice_f/dense_a.png)／[192 塔 B](../.godot/test-results/modeling/art_slice_f/dense_b.png)／[並排](../.godot/test-results/modeling/art_slice_f/dense_comparison.png)：16×12 的顯示副本，使用實際 tower body 填石地及原道路顯示器，保留大小差異；不是 192 座參與戰鬥的效能測試。相機 size 30.8333，移至獨立比較地圖中心，A/B 不移動。
- [最遠 A](../.godot/test-results/modeling/art_slice_f/far_a.png)／[最遠 B](../.godot/test-results/modeling/art_slice_f/far_b.png)／[並排](../.godot/test-results/modeling/art_slice_f/far_comparison.png)：同一 Frontier 六塔，在目前允許的最遠縮放下比較。

## 本輪實際驗證

| 驗證 | 結果 |
| --- | --- |
| Godot headless editor 匯入 | PASS；新增配色 Resource／腳本正常載入 |
| GPU 三組 A/B（RTX 4060 Laptop／Compatibility） | PASS；相機與節點不變，三組各有可見塔色差；塔投影 bounds 外的背景／UI 差異像素皆為 0 |
| 31 個 A/B 網格 | PASS；頂點、索引、UV／UV2、自訂通道、材質一致，最大法線誤差 0，深色機械頂點變更 0 |
| 配色建置再執行 | PASS；31 個 B 網格 SHA256 不變，50 個 A／wrapper／GLB 基準檔不變，六份 GLB 與 Slice D 交付 hash 一致 |
| tower_integration：A 與 B 分別執行 | PASS；各 84 組真實配置／旋轉，頂點占格、攻擊中心、正式／合法及非法預覽逐網格一致 |
| 同測試的實際事件／動畫 | PASS；射擊、兵營首次部署及重生、四向／左右舷獨立與並行、快速重觸發、缺失動畫 fallback；無改傷害或冷卻 |
| 既有 tower_restoration | PASS；failures 0 |
| 既有 card_drag_placement | PASS；failures 0，旋轉／驗證／取消／UI 與鏡頭排除保留 |
| git diff --check | PASS；無 whitespace error，僅前輪檔案的 CRLF 正規化提示 |

早期 headless 整合測試退出時出現 AudioStreamWAV／Playback 資源殘留，verbose 定位為 Dummy 音效播放而非配色；測試現於 headless 關閉視覺測試塔的 shot_sound 並釋放場景。正式遊戲音效程式與資產未修改。本輪不驗收音效。

```powershell
& C:/tools/Godot.exe --path . res://tests/combat/tower_color_identity.tscn -- --capture
& C:/tools/Godot.exe --headless --path . res://tests/combat/tower_integration.tscn
& C:/tools/Godot.exe --headless --path . res://tests/combat/tower_integration.tscn -- --palette-a
& C:/tools/Godot.exe --headless --path . res://tests/combat/tower_restoration.tscn
& C:/tools/Godot.exe --headless --path . res://tests/cards/card_drag_placement.tscn
```

原始結果位於 `.godot/test-results/modeling/art_slice_f/` 的 `check.json`、`rebuild.json`、`integration_a.json`、`integration_b.json`，以及 `.godot/slice-f-*.log`。截圖／例行測試產物依專案規範留在忽略目錄。

## 視覺判斷與限制

B 版讓頂部功能區成為穩定色點，密集陣列更容易分開讀取；暖白底座、暖石路面與青灰雲海仍維持共同基調。磚紅迫擊砲與灰紫十字最容易快速區分，沒有出現高彩度搶焦。兵營赭金接近道路金色、巨弓鋼藍與飛行艇青藍接近，因此最遠景仍需要原有堡壘／弓臂／艇體輪廓輔助，不把顏色當作唯一辨識手段。

本輪沒有改卡面 UI，現有卡牌配色與識別色大致相容但不是一對一的圖例。未做真人辨識速度、色覺障礙驗收、完整十五波、長時間效能或 Web 匯出／瀏覽器測試；不沿用 Slice E 的結果標為本輪 PASS。

本輪主要來源改動：色盤 Resource／`tower_color_identity.gd`、`imported_tower_visual.gd` 的 configure 套用、離線建置器的 `--identity` 分支、31 個 B 網格、比較場景／測試及文件。TowerDefinition、戰鬥與道路相關既有未提交修改屬於前輪，未因本輪配色再次改寫。

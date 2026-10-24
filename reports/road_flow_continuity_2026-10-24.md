# 2026-10-24 流量亮段連續性與 Web 量測

下列效能表格為「接點裁切之前」的相位修正版，不代表後續接點、圓角與中央重合版本；後續功能驗證見末節。修正前基準為 `main` 的 `cd3491d`。正式 Frontier、搜尋、配額與敵人移動未修改。

## 原因與修正

舊版在有向邊聯集上做 BFS，每條邊只取首次抵達的相位。長短支路在同一格匯流時，共用後段只接得上其中一個時間；環路重訪同邊也會丟失相位。這不是候選行程未抵達終點。

新版從實際分配的完整行程保存所有邊／連續轉彎的抵達步數，重複行程只建立一份時鐘，流量仍照實際通過次數加總。相同抵達間距共用相位表，shader 固定查詢最近相位，不逐行程迴圈。保留米白筆觸、兩端漸淡、流量粗細／透明度、雙向側位、圓角、單格 quad／單批次及聯集透明度。沒有新增敵人移動階段工作。

## 驗證

- `road_flow_preview.tscn`：headless 與 Windows 實際渲染通過；包含入口／兵種篩選、RNG／配額、失效、開波／ACT／暫停／重開，以及原線形、無底線、重合不加深的像素回歸。
- `road_flow_continuity.tscn`：長短支路匯流、環路重走同一條有向邊、反向分線、週期接縫、70 個抵達相位與篩選快取。資料檢查 27 次行程邊經過，渲染模式另取樣 37 個邊中點／終點、軟尾及應維持透明的時刻。
- 同一連續性回歸在 WebGL 亦通過，37 個像素取樣與週期距離比對均為零失敗。最初 RGF 浮點紋理讀回比對在 Web 失敗，改用 RGBA8 中兩組 16-bit 整數後通過；不能用只有亮起的正向取樣判定全部時刻正確，因此補上應維持透明的負向取樣。Web 禁止寫入 res，結果改由瀏覽器收集 console JSON；原始結果為 `.godot/test-results/levels/flow_web/continuity_1_continuity.json/log`。
- 原始功能結果：`.godot/test-results/levels/flow_continuity_*.json/png`、`road_flow_*.json/png`；log：`.godot/flow_continuity_*.log`、`.godot/flow_full_rendered.log`、`.godot/flow_regression.log`。

## Web 方法

Godot 4.7.2 Compatibility、release Web 匯出、單執行緒 GDExtension；Edge 155.0.0.0，ANGLE／AMD Radeon Graphics／D3D11，1280×800。同設定空白頁另量 240 次 rAF，間隔中位數 6.9 ms、P10 6.8 ms（約 144 Hz 級），未另加 60 FPS 限制；原始資料 `browser_clock.json`。此時鐘測試不與遊戲量測並行。使用正式 level 系統，但以獨立 Resource 建立 25×21、255 格道路、雙入口、交錯橫縱支路與多個環的合成地形；下一波三兵種合計 256 人，分配成 88 條不同完整行程。量測準備期預覽，**沒有生成 256 名存活敵人**，不當成戰鬥效能結果。

前／後／後／前／前／後交錯各三輪，固定取景、攔截外部滑鼠／鍵盤，無其他渲染測試同時執行。每輪先等 120 幀，重建預覽九次、切換入口篩選十二次，再等 120 幀，取 900 個 Godot process-frame 間隔。重建時間只含流量統計、相位資料及 mesh，不含候選池／排程。篩選保留首次建立該入口相位表的成本。

表中為「各輪數值／各輪重建中位數」的三輪中位數，非合併所有幀後的百分位數：

| 指標 | 修正前 | 修正後 |
| --- | ---: | ---: |
| 平均幀時間 | 11.84 ms | 11.27 ms |
| P95 | 15.75 ms | 14.56 ms |
| P99 | 18.90 ms | 18.04 ms |
| 每輪最大幀時間 | 35.52 ms | 25.01 ms |
| 預覽重建 | 55.68 ms | 67.49 ms |
| 入口篩選顯示重建 | 14.27 ms | 14.79 ms |
| 所有重建中的最慢一次 | 69.78 ms | 97.72 ms |

| 輪次 | 版本 | 平均 ms | P99 ms |
| --- | --- | ---: | ---: |
| 1 | 前 | 11.65 | 18.90 |
| 2 | 後 | 11.27 | 18.04 |
| 3 | 後 | 13.05 | 21.43 |
| 4 | 前 | 11.84 | 17.61 |
| 5 | 前 | 12.13 | 20.42 |
| 6 | 後 | 10.90 | 15.46 |

兩版都顯示 255 格、整體 267 draw calls；流量仍只有一批。新版幾何資料紋理 199,920 bytes，與舊版相同；新增相位表 55×6 RGBA8，1,320 bytes。沒有按路線數複製幾何或增加逐幀 CPU 更新。

本次平均幀時間與 P99 的三輪中位數略降，但新版仍有一輪明顯較慢（平均 13.05 ms、P99 21.43 ms）；不宣稱跨硬體或長時間 FPS 改善。預覽重建中位數增加約 11.81 ms，仍為同步工作，觀測到最慢約 98 ms；穩態取樣不涵蓋重建尖峰。量測排除了引擎／WASM／shader 首次啟動，不推論載入時間或戰鬥表現。

最終六輪原始 JSON、console log、截圖及彙總位於 `.godot/test-results/levels/flow_web/performance_*` 與 `summary.json`，六輪均無腳本／shader／瀏覽器錯誤。`draft/`、`draft_unpacked/`、`draft_float/`、`draft_web_readback/` 為開發過程樣本，未用於上述結論；前者含一次取景被改動的樣本，`draft_unpacked/` 為尚未壓回兩 texel 的版本，`draft_float/` 為改用 RGBA8 前的最終浮點表樣本。一次性量測場景／程式在完成後移除；永久功能回歸保留。


## 同日後續：接點突出裁切

接點改用實際轉向的抵達相位，兩條偏移後中心線在共同交點接合，再以互補裁切面消除內部圓頭。只有完整行程起終點保留圓頭；米白筆觸、透明度聯集、雙向側位與非分岔圓角保留。每個 primitive 增加一個裁切法線 texel，格內固定容量由 24 改為 40，涵蓋四向全部轉向、U-turn 及起終點；仍為每格一個 quad、整體一批，不增加敵人移動工作。

本次新增四種朝向的突出區透明、交點連通、反向接合、真正端點圓頭及滿容量十字接點驗證，原有完整行程／環路檢查一併執行。Windows／WebGL 均通過 70 個像素取樣、27 次行程邊經過與四種接點朝向，無腳本／shader 錯誤；Web 結果為 `.godot/test-results/levels/flow_join_web.json/log`。結構驗證改讀 CPU 幾何，避免 Web RGBAF 紋理讀回對負法線與大於一的計數截斷，實際裁切仍以 GPU 像素驗證。Windows 原始結果為 `.godot/flow_join_pixels.log`，接點截圖為 `.godot/test-results/levels/flow_junction_trimmed.png`，完整預覽回歸為 `.godot/flow_join_full.log`。未重跑上方 255 格 Web 效能對照，不能把上述幀時間套用到接點裁切版。


## 同日後續：所有路口圓角／雙向中央重合

移除只在雙鄰居格使用圓角的限制；T 字、十字及一般轉角內的實際 90 度轉向一律使用相同半徑的圓弧。移除方向側移，a→b 與 b→a 在道路中央使用相同幾何，各自保留原有流量與完整行程相位，透明度繼續取聯集最大值，不相加。

四分之一圓改用一個解析 primitive，兩旁各一段直線（一般圓角由十個 primitive 減為三個）；shader 以圓半徑和有向角度計算輪廓／進度。最滿十字格的固定容量為 48，涵蓋八個 90 度轉向各三段、八個直行／折返各兩段及八個起終點半段，不按行程數擴張。

Windows（RTX 3050）與 WebGL（Edge 155／ANGLE AMD 內顯）均通過 78 個像素取樣、27 次行程邊經過、四種朝向、正反方向獨立動畫、重合透明度聯集及滿容量繪製；完整預覽的 GUI／流量／生命週期回歸亦通過。原始結果為 `.godot/flow_center_pixels.log`、`.godot/flow_center_full.log`、`.godot/flow_center_headless.log`、`.godot/test-results/levels/flow_center_web.json/log`；驗證圖為 `.godot/test-results/levels/flow_junction_rounded.png`。本次未重跑上方效能對照，不把舊幀時間套用到目前版本。


## 同日後續：不同流量接點的寬度過渡

移除弧線固定採用進出流量較小值的樣式。每個 primitive 保存兩端強度，弧線由進入強度平滑過渡至離開強度；直行接點的兩個半段透過共用中間強度接合。shader 以 smoothstep 同時過渡線寬及透明度，原有向邊的端點強度保留，完整行程相位仍線性推進。資料仍為三 texel／primitive、固定 48 上限，沒有新增 mesh、draw call 或敵人移動工作。

新增流量 1 對 16 的增寬／縮窄、四種朝向及七個弧線截面的實測，共 56 個輪廓寬度量測點，允許三個輸出像素的取樣／抗鋸齒差異；並檢查每個弧線／直段端點的寬度及透明度資料相同，直行接點亦平滑。Windows／WebGL 均通過，既有 78 個像素取樣及完整預覽回歸仍通過。原始結果為 `.godot/flow_width_pixels.log`、`.godot/flow_width_full.log`、`.godot/flow_width_headless.log`、`.godot/test-results/levels/flow_width_web.json/log`，驗證圖為 `.godot/test-results/levels/flow_width_tapered.png`。此為功能驗證，未重跑效能對照。

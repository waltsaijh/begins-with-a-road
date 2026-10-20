# 敵人 MultiMesh 與走路動畫

2026-10-16，Godot 4.7.2 Compatibility。

每個 EnemyWave 建立一個 EnemyMultiMesh；所有敵人共用原型 grunt 的單 surface、637 三角形 mesh 與一份 ShaderMaterial。單隻敵人保留路線快照、位置及移動狀態，不再擁有 MeshInstance3D、Skeleton 或 AnimationPlayer。邏輯節點到達時發出 arrived，渲染器監聽後立即回收顯示 slot；邏輯節點隨後刪除。

slot 使用密集陣列，刪除時將末尾敵人搬到空位，更新該敵人的索引與 transform／custom data。開波先預留容量，超出時倍增；只在容量成長時重填 buffer，不會每次生成／刪除都重新配置。每幀每隻提交一個 transform 與步態 custom data。Compatibility 下明確啟用 instance colors 並設成白色，保留模型頂點配色。

模型生成工具在 UV／UV2 烘焙腿、手臂分類及局部支點；shader 按原型 skybridge_pawns.animate 的方式繞支點擺動四肢，並加入身體起伏與側擺。法線隨旋轉更新。相位由實際行進距離推進，出生相位錯開，停下時停止擺動。共用 mesh 的包圍盒預留動畫位移，降低邊界裁切問題。shader 不使用 compute、骨架或 Forward+ 功能。

轉角使用 lerp_angle，混合比例為 1-exp(-turn_sharpness*delta)，避免跨越 +/-PI 時繞一整圈，並保持不同幀率下的轉向速度一致。邏輯位置沿出生前固定的中心線移動，跨越數段的剩餘距離不丟失，沒有逐幀重新尋路。邏輯移動後由共用 MultiMesh 統一提交顯示位置；tile 分群的 O(N) 左右視覺分離見 enemy_visual_separation.md。

敵人邏輯位於 scripts/enemies/enemy.gd 與 enemy_wave.gd；渲染位於 scripts/enemies/rendering/。enemy_pose.gd 保存每隻顯示朝向、相位與步態強度，enemy_multimesh.gd 批次提交，enemy_visual_separation.gd 計算顯示偏移，enemy_wave_controls.gd 顯示選單與波次資訊。邏輯節點不持有 renderer 或步態資料；EnemyWave 自行追蹤存活敵人，建塔行程保護不依賴顯示列表。

EnemyConstants 管理波次、移動與候選探索預設；EnemyRenderConstants 管理四肢擺幅、相位步幅、轉向與視覺分離。兩者都可透過 class_name 直接使用。波次數量、生成間隔、速度與轉向仍可在 EnemyWave Inspector 覆寫。

## 驗證

- tests/enemies/enemies.tscn：main、9x9、11x11big，包含雙起點、跨波不重複選路、生成批次／尾批、速度、終點刪除、計數與顯示 slot 同步；Windows／Web 結果一致，見 enemies.json。
- tests/enemies/enemy_multimesh.tscn：65 隻超出初始容量、密集 slot、刪除中間敵人、外部刪除、GPU 資料同步、距離步態、四肢資料、平滑轉向、跨 PI 與不同 delta 等價性；Windows OpenGL／WebGL2 結果一致，見 enemy_multimesh.json。純 headless dummy renderer 不提供 GPU buffer 讀回，相關讀回檢查使用實際繪圖裝置執行。
- tests/enemies/enemy_walk_render.tscn：實際繪製三個 instance，檢查紅衣配色仍可見、改變步態後畫面確實改變；Windows／Web 結果一致，見 enemy_walk_render.json、enemy_walk.png 與 enemy_walk_web.png。
- tests/navigation/debug_overlay.tscn：Windows 通過，路網／威脅／流量圖層與待生成流量保持正確。

Web 使用 release 匯出與 Edge WebGL2，單執行緒、GDExtension enabled；獨立測試專案匯出，不修改正式主場景或排除設定。沒有 script／shader／browser console error。未進行 FPS 或 CPU／GPU 時間 benchmark，批次繪圖不代表路線規劃與每隻移動計算也合併。

API 參考：[Godot MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html)。

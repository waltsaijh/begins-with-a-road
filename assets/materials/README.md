# 不透明純色模型

道路、木橋、Sentry、端點的非發光零件與三種正式敵人共用 `solid_color.tres`，材質引用 `assets/shaders/solid_color.gdshader`。每個模型直接保存同一份外部材質引用，執行時不複製材質或逐模型轉換。

網格資料：

| 通道 | 用途 |
| --- | --- |
| COLOR | 原本的純色 × 頂點色 |
| UV.y、UV2.xy | GPU 四肢支點 z、xy；靜態模型保留但不使用 |
| UV.x | 烘焙來源的帶正負四肢編號，便於重新烘焙與驗證 |
| CUSTOM0.xyzw（float） | 帶方向的四肢擺幅、起伏、側擺、關鍵影格間隔數 + 1；w=0 表示靜態 |
| CUSTOM1.xy（float） | 粗糙度、specular；保留亮木板的 1.0／0.08，其他多為 0.98／0.12 |
| INSTANCE_CUSTOM.xy | 敵人相位與移動 blend，由原有 MultiMesh 更新；不增加每幀提交欄位 |

顏色與表面參數是網格資料；動畫週期與播放倍率仍由兵種／GPU Model 控制。修改 GPU Model 的擺幅、起伏或側擺後，須重新烘焙網格。靜態幾何直接略過步態，不根據模型名稱或兵種編號在 shader 裡硬編參數。

`tools/assets/solid_mesh_baker.gd` 是離線轉換共用邏輯，檢查 StandardMaterial3D 的全部儲存設定，只接受可保留的純色、粗糙度與反光差異。透明、發光、紋理、非預設光照／剔除、next_pass 等特殊材質不轉換。雲海、柱底漸變／生長、端點光源、攻擊／死亡特效及 2D UI 保持各自材質。

`road.tres`、`stone_*.tres`、`wood*.tres` 保留作為離線製作色盤，不再是已烘焙道路的執行期材質。修改製作色盤不會自動改寫已烘焙的頂點；修改來源網格配色或重新生成來源後再烘焙。

轉換目前保存的本地模型（不重新生成原型、不重設地圖）：

```powershell
godot --headless --path . --script tools/assets/bake_solid_models.gd
```

工具保留場景節點、變換、動畫、外觀幾何及 MeshLibrary 項目；每個道路項目的純色面合為一個 surface，柱底另保留一個 surface。一般 MeshInstance、GridMap 及 MultiMesh 仍可能觸發不同的引擎 program；單一材質不等於整個遊戲只有一次 draw call 或一次 shader 編譯。

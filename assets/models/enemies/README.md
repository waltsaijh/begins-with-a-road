# 敵人模型

遊戲使用以下獨立模型，重建時參考 card-tower-defense 的原型素材；執行時不依賴原專案：

| 遊戲兵種 | 原專案模型 | 場景 | 外觀 |
|---|---|---|---|
| Soldier | grunt | `grunt.tscn` | 紅衣步兵、木盾與長矛 |
| Quickfeet | runner | `runner.tscn` | 較小較瘦、前傾、紅色兜帽與短刃 |
| Heavy | brute | `brute.tscn` | 寬肩盔甲、重盾與戰鎚 |

`tools/assets/build_enemy.gd` 從原專案 `art/enemies/miniature_humanoid.gd` 及其色盤產生這三種獨立資源。原始模型的比例、武器與配色直接沿用；原點統一到模型底部。可透過 `-- --prototype=原專案路徑` 指定其他來源位置。只有重建時需要原專案；遊戲執行使用本資料夾內的資源。

三種兵各有一份單一 surface 網格與 MultiMesh，全部與道路、塔共用 `assets/materials/solid_color.tres` 及 `solid_color.gdshader`。`grunt_gpu.tres` 保留 Soldier 原本依距離推進的步態；`runner_gpu.tres`、`brute_gpu.tres` 保存各自的週期與擺幅，精確重現原 Walk 的 17 個線性插值關鍵影格。Quickfeet 保留 3 倍動畫速度，Heavy 保留較慢的原週期；停下時兩者凍結在當前姿勢。各兵種的移速與能力仍由 `assets/data/troops/*.tres` 設定。

Runner、Brute 的 `.tscn` 保留原本身體、雙腿、雙臂五個網格及 AnimationPlayer，作為可編輯來源與外觀／步態回歸參考，正式敵群不建立這些逐隻實例。修改來源後，執行：

```powershell
godot --headless --path . --script tools/assets/bake_enemy_gpu.gd
```

此工具直接烘焙本資料夾目前保存的模型，不讀取或重建原型，保留頂點、法線、配色及支點；輸出 `runner_mesh.res`、`brute_mesh.res` 與對應 `_gpu.tres`。步態擺幅／起伏／側擺／取樣數存在 CUSTOM0，表面參數存在 CUSTOM1，不再是逐兵種材質 uniform。修改 GPU Model 擺幅後可執行 `tools/assets/bake_solid_models.gd` 更新已有網格；修改來源動畫／幾何則執行上述 GPU 烘焙。格式見 [共用材質](../../materials/README.md)。如果改動超出目前支援的剛體步態，工具會拒絕烘焙；將 Troop 的 GPU Model 清空即可使用原場景動畫。先前的原型重建工具執行後也須重新烘焙 GPU 資料。任意匯入模型未提供相符 GPU Model 時，仍保留原材質、骨架與 AnimationPlayer。

`tests/enemies/enemy_gpu_models.gd` 比對所有烘焙頂點、法線、色彩、動畫時間與混兵 slot 回收；`enemy_gpu_render.gd` 以實際 Compatibility renderer 比對原場景與 GPU 在多個姿勢的畫面。後者不可用 headless 代替。

## Phase 4 自足模型

`rat_swarm`、`shield_guardian`、`blood_mage`、`winged_beast`、`scout`、`saboteur` 為本專案新製的低面數微縮場景，不引用原型。各模型以可編輯 MeshInstance3D 組成，分別使用長尾鼠輪廓、大盾、法杖、雙翼、望遠鏡與炸藥背包區分。共用 `scripts/enemies/rendering/miniature_enemy.gd` 處理步態／擺臂／翼拍，由 EnemyModel.advance 依模擬時間更新。

重建入口 `python tools/assets/build_synergy_models.py`，同時產生本目錄六個場景及 `assets/sprites/enemies/` 六個 SVG 圖示。這會覆寫對應產物，重建前先確認手動修改；不需要另一專案或額外 Python 套件。

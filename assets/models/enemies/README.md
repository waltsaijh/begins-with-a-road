# 敵人模型

遊戲使用以下獨立模型，重建時參考 card-tower-defense 的原型素材；執行時不依賴原專案：

| 遊戲兵種 | 原專案模型 | 場景 | 外觀 |
|---|---|---|---|
| Soldier | grunt | `grunt.tscn` | 紅衣步兵、木盾與長矛 |
| Quickfeet | runner | `runner.tscn` | 較小較瘦、前傾、紅色兜帽與短刃 |
| Heavy | brute | `brute.tscn` | 寬肩盔甲、重盾與戰鎚 |

`tools/assets/build_enemy.gd` 從原專案 `art/enemies/miniature_humanoid.gd` 及其色盤產生這三種獨立資源。原始模型的比例、武器與配色直接沿用；原點統一到模型底部。可透過 `-- --prototype=原專案路徑` 指定其他來源位置。只有重建時需要原專案；遊戲執行使用本資料夾內的資源。

Grunt 使用 `grunt_mesh.res` 單一合批網格與現有 GPU 步態。Runner、Brute 各合併成身體、雙腿、雙臂五個網格，共用一個色盤材質，附循環 Walk 動畫：步幅與擺臂依原專案設定，Runner 動作較快、Brute 較慢。三種兵種的移速與能力仍由 `assets/data/troops/*.tres` 設定。

## Phase 4 自足模型

`rat_swarm`、`shield_guardian`、`blood_mage`、`winged_beast`、`scout`、`saboteur` 為本專案新製的低面數微縮場景，不引用原型。各模型以可編輯 MeshInstance3D 組成，分別使用長尾鼠輪廓、大盾、法杖、雙翼、望遠鏡與炸藥背包區分。共用 `scripts/enemies/rendering/miniature_enemy.gd` 處理步態／擺臂／翼拍，由 EnemyModel.advance 依模擬時間更新。

重建入口 `python tools/assets/build_synergy_models.py`，同時產生本目錄六個場景及 `assets/sprites/enemies/` 六個 SVG 圖示。這會覆寫對應產物，重建前先確認手動修改；不需要另一專案或額外 Python 套件。

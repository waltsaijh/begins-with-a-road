# 已接入的六塔外觀

TowerDefinition.visual_model引用同名wrapper，Art是GLB衍生的烘焙／合併場景。

- `ballista` ← Art Slice D `great_ballista.glb`
- `sentry` ← `watchtower.glb`
- 其餘同名；`broadside` ← `broadside_airship.glb`

用 `tools/assets/build_integrated_towers.gd` 在Godot完成GLB重匯入後重建。不要手改 `_art.tscn`／`_part_*.res`；wrapper是掛載入口，邏輯與視覺事件在 `scripts/towers/imported_tower_visual.gd`。原GLB、Blender與Art Slice D來源均保留。

本目錄共用既有solid_color；沒有每塔shader。無動畫控制的同父剛體mesh已合併，動畫目標與Marker3D保留。占格與不相容形狀fallback由TowerBodyVisual處理，不能靠Root Scale或鏡射修改占格。

完整事件、尺寸與驗證見 [Art Slice E](../../../../docs/art_slice_e.md)。

Art Slice F：本目錄保留 A 暖灰白基準。正式／預覽外觀會依 `assets/data/rendering/tower_color_identity.tres` 的 Variant 選擇 A 或 B（預設 B），B 的共享網格在鄰近 `color_identity/b/`；只改 COLOR，仍共用原材質。修改色盤後以同一建置器加 `-- --identity` 重建 B；若更換 GLB，先重建本目錄，再重建 B。切換與比較入口見 [Art Slice F](../../../../docs/art_slice_f.md)。

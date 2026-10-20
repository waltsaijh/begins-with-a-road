# 死亡與 AOE 特效

造型移植自同工作區 `card-tower-defense/scripts/presentation/effects_3d.gd`：擴散圓環、六枚五角低多邊形碎片，以及 AOE 的縮小亮色核心。使用獨立場景，不依賴參考專案或物理粒子系統。

- `components/death_burst.tscn`：死亡用的紅棕圓環與碎片，半徑 **0.35 格**（參考效果最大約 0.8 格）、持續 **0.3 秒**。
- `components/aoe_burst.tscn`：繼承死亡場景，換成琥珀圓環、灰米色碎片，開啟 `Core`；持續 **0.4 秒**。視覺半徑為攻擊 `splash_radius × radius_scale`，預設倍率 **0.65**，傷害與選敵範圍仍由攻擊資料決定。
- `death_effects.tscn`：死亡場景的回收池，同時最多 48 組。
- `impact_effects.tscn`：AOE 回收池，同時最多 24 組，由 AttackVisuals 推進時間。
- `attack_visuals.tscn`：原有箭矢／光束的共用 mesh，以及 `ImpactEffects`。

可直接調根節點的 `duration`、`radius`、`radius_scale`、`start_radius_fraction`、`hop_height`。`Ring` 可改 TorusMesh 與材質；`Shards` 下可增減 MeshInstance3D，位置方向決定散射方向，scale 決定碎片大小；`Core` 的可見性、位置、scale 與材質也都能編輯。相同材質需勾選 **Local To Scene**，讓不同次特效各自淡出。編輯器顯示靜態造型，腳本僅在遊戲中推進，不會將動畫中的縮小位置回存到場景。

只在 `enemy.died` 觸發死亡特效，抵達終點與外部清除不觸發；死亡時取最後的視覺避讓偏移。最後一隻敵人死亡後，特效仍會完成並回收，不延遲死亡、結算或下一波流程。暫停會一起停止特效，倍速沿用遊戲時間。

`tests/combat/combat_bursts.tscn` 驗證單次死亡、顯示位置、變換後地圖、材質獨立、回收與上限、AOE 共用樣式，並輸出 `.godot/test-results/combat/combat_bursts.png`。`tests/combat/combat.tscn` 驗證 AOE 的落點、實際傷害與狀態效果維持原規則。

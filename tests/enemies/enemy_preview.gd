extends Node3D
## Frozen, reproducible presentation of a staggered wave.
func _ready() -> void:
	var scene: Node3D = load("res://scenes/9x9.tscn").instantiate()
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	add_child(scene)
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing or controller.plan.is_empty():
		await get_tree().process_frame
	var with_towers := "--towers" in OS.get_cmdline_user_args()
	if with_towers:
		for x in [6, 13, 19]:
			var tower: Node3D = scene.get_node("TowerMap").place_tower(Vector3i(x, 0, 0))
			assert(tower != null)
		while controller.plan.is_empty():
			await get_tree().process_frame
	var started: bool = wave.start_wave()
	assert(started)
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	for tick in 780:
		wave._process(1.0 / 60.0)
		for enemy in wave.visuals.units.duplicate():
			enemy._process(1.0 / 60.0)
		wave.visuals._process(1.0 / 60.0)
	wave.visuals.set_process(false)
	var overlay: Node = scene.get_node("PortalOverlay")
	var suffix := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--layer="):
			var layer := argument.trim_prefix("--layer=")
			if layer == "all":
				for i in 3:
					overlay._toggle(i)
			else:
				overlay._toggle(int(layer)-1)
			suffix = "debug_"+layer
	await get_tree().process_frame
	await get_tree().process_frame
	# Headless Web collector takes its own screenshot; native uses the viewport.
	if not OS.has_feature("web"):
		await RenderingServer.frame_post_draw
		var file := suffix+".png" if not suffix.is_empty() else "tower_enemy_preview.png" if with_towers else "enemy_preview.png"
		var folder := "navigation" if not suffix.is_empty() else "combat" if with_towers else "enemies"
		get_viewport().get_texture().get_image().save_png("res://reports/"+folder+"/"+file)
		print("ENEMY_PREVIEW_READY")
		get_tree().quit()
	else:
		print("ENEMY_PREVIEW_READY")

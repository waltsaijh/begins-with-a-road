extends Node3D
## Render both a neutral and walking pose. This catches shader and palette failures.
const Batch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")

func _ready() -> void:
	call_deferred("verify")

func _frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func verify() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.16, 0.2)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.7
	add_child(camera)
	camera.position = Vector3(1.4, 1.2, -2.5)
	camera.look_at(Vector3(0, 0.32, 0))
	camera.current = true
	var batch := Batch.new()
	add_child(batch)
	for i in 3:
		var enemy: Node3D = Enemy.instantiate()
		add_child(enemy)
		enemy.follow(i, {}, PackedVector3Array([Vector3((i-1)*0.55, 0, 0), Vector3((i-1)*0.55, 0, -10)]))
		batch.add_enemy(enemy)
		enemy.set_process(false)
		batch._poses[i].walk_phase = 0.0
		batch._poses[i].walk_blend = 1.0
		batch.update_enemy(enemy)
	batch.set_process(false)
	await _frame()
	var rest := get_viewport().get_texture().get_image()
	for i in batch.units.size():
		var enemy: Node3D = batch.units[i]
		batch._poses[i].walk_phase = PI * 0.5 if i % 2 == 0 else PI * 1.5
		batch.update_enemy(enemy)
	await _frame()
	var walking := get_viewport().get_texture().get_image()
	var changed := 0
	var red := 0
	for y in walking.get_height():
		for x in walking.get_width():
			var color := walking.get_pixel(x, y)
			if color.r > color.g * 1.2 and color.r > 0.2:
				red += 1
			if color != rest.get_pixel(x, y):
				changed += 1
	if red < 100 or changed < 100:
		push_error("Walking shader render failed: palette=%d, changed pixels=%d" % [red, changed])
		if not OS.has_feature("web"):
			get_tree().quit(1)
		return
	if not OS.has_feature("web"):
		walking.save_png("res://reports/enemies/enemy_walk.png")
	print("ENEMY_WALK_RENDER_CHECK:" + JSON.stringify({"palette_visible": true, "poses_differ": true, "shared_instances": batch.multimesh.visible_instance_count}))
	if not OS.has_feature("web"):
		get_tree().quit()

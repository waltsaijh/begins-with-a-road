extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")

func _ready() -> void:
	verify.call_deferred()

func verify() -> void:
	var cells: Array[Vector2i] = []
	for y in 5:
		for x in 7:
			cells.append(Vector2i(x, y))
	for x in [-2, -1, 7, 8]:
		cells.append(Vector2i(x, 2))
	var scene := Fixture.scene_for(cells, Vector2i(-2, 2), Vector2i(8, 2))
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	wave.enemy_count = 20
	add_child(scene)
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing or controller.plan.is_empty():
		await get_tree().process_frame
	for z in [1, 2, 3]:
		var tower: Node3D = scene.get_node("TowerMap").place_tower(Vector3i(3, 0, z))
		assert(tower != null)
	while controller.computing or controller.plan.is_empty():
		await get_tree().process_frame
	scene.get_node("TileVisuals").finish()
	var heavy := "--heavy" in OS.get_cmdline_user_args()
	if heavy:
		wave.select_troop(2)
	var started: bool = wave.start_wave()
	assert(started)
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	for tick in 300:
		wave._process(1.0 / 60.0)
		for enemy in wave.visuals.units.duplicate():
			enemy._process(1.0 / 60.0)
		wave.visuals._process(1.0 / 60.0)
	wave.visuals.set_process(false)
	var overlay: Node = scene.get_node("PortalOverlay")
	overlay._toggle(2)
	scene.get_node("Camera3D").size = 10.5
	await get_tree().process_frame
	await get_tree().process_frame
	if not OS.has_feature("web"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://reports/combat/heavy_preview.png" if heavy else "res://reports/combat/tower_obstacles.png")
		print("TOWER_OBSTACLE_PREVIEW_READY")
		get_tree().quit()
	else:
		print("TOWER_OBSTACLE_PREVIEW_READY")

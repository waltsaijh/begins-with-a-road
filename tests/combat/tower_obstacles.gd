extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func ready_map(scene: Node) -> void:
	var controller: Node = scene.get_node("PortalMap")
	for i in 120:
		if not controller.computing and not controller.plan.is_empty():
			check(controller.graph.get("valid", false) and controller.plan.get("reachable", false), "All starts must have a valid graph")
			return
		await get_tree().process_frame
	check(false, "Timed out waiting for map")

func make_scene(cells: Array[Vector2i], start: Vector2i, goal: Vector2i) -> Node3D:
	var scene := Fixture.scene_for(cells, start, goal)
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	return scene

func room(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			cells.append(Vector2i(x, y))
	return cells

func verify_routes(controller: Node) -> int:
	var count := 0
	for origin in controller.start_nodes.size():
		var plan: Dictionary = controller.plan_for(controller.troop, origin)
		check(plan.get("reachable", false), "Origin lost its route")
		for index in plan.get("routes", 0):
			for seed in 8:
				var route: Dictionary = controller.sample_for(controller.troop, seed, origin, index)
				check(not route.is_empty(), "Route disappeared")
				if route.is_empty():
					continue
				for i in route.cells.size():
					var cell := Vector2i(route.cells[i])
					check(not controller.blocked_cells.has(cell), "Enemy route crosses tower footprint")
					if i > 0:
						var step := cell - Vector2i(route.cells[i-1])
						check(absi(step.x) + absi(step.y) == 1, "Route skips a physical cell")
				count += 1
	return count

func verify() -> void:
	var checked_routes := 0
	var scene := make_scene(Fixture.room(false), Vector2i(-3, 5), Vector2i(13, 5))
	await ready_map(scene)
	var controller: Node = scene.get_node("PortalMap")
	var manager: Node = scene.get_node("TowerMap")
	var baseline: float = controller.plan.score
	var record: Resource = controller.tile_parameters.get_tile(Vector2i(5, 5))
	record.terrain_id = 77
	var tower: DefenseTower = manager.place_tower(Vector3i(5, 0, 5))
	check(tower != null and tower.definition.name_key == "tower.sentry.name", "Sentry definition not applied")
	if tower == null:
		get_tree().quit(1)
		return
	check(tower.get_node("Visual/Base").mesh.get_surface_count() == 1 and tower.get_node("Visual/AimPivot/Weapon").mesh.get_surface_count() == 1, "Tower rigid parts must be baked and shared")
	await ready_map(scene)
	# Wide-region portal representatives can add distance; keep the current
	# abstraction, and verify the resulting routes actually avoid the obstacle.
	check(controller.plan.score > baseline, "Blocking the direct line must require a detour")
	check(not Vector2(5, 5) in controller.graph.tiles, "Blocked tile still present in navigation graph")
	check(controller.tile_parameters.get_tile(Vector2i(5, 5)) == record, "Blocking a tile lost its parameters")
	checked_routes += verify_routes(controller)
	check(manager.remove_tower(Vector3i(5, 0, 5)), "Tower removal failed")
	await ready_map(scene)
	check(controller.plan.score == baseline and controller.tile_parameters.get_tile(Vector2i(5, 5)).terrain_id == 77, "Removal must restore walkability and tile data")
	# A second tower type can reuse the base with a larger footprint, no script copy.
	var definition: TowerDefinition = load("res://assets/data/towers/sentry.tres").duplicate()
	definition.footprint = [Vector2i.ZERO, Vector2i.RIGHT]
	var template := DefenseTower.new()
	template.definition = definition
	var larger := PackedScene.new()
	check(larger.pack(template) == OK, "Failed to create reusable tower type")
	template.free()
	tower = manager.place_tower(Vector3i(5, 0, 5), larger)
	check(tower != null and manager.occupied.size() == 2, "Multi-cell footprint not registered")
	check(manager.place_tower(Vector3i(6, 0, 5)) == null, "Overlapping footprint accepted")
	await ready_map(scene)
	checked_routes += verify_routes(controller)
	check(manager.remove_tower(Vector3i(6, 0, 5)) and manager.occupied.is_empty(), "Clicking non-anchor cell must remove full tower")
	scene.queue_free()
	await get_tree().process_frame
	# Preserve every origin, including a secondary spawn on a degree-two corridor.
	var cells: Array[Vector2i] = []
	for x in 7:
		cells.append(Vector2i(x, 0))
	for position in [Vector2i(2,-1), Vector2i(2,-2), Vector2i(3,-2), Vector2i(4,-2), Vector2i(4,-1)]:
		cells.append(position)
	scene = Fixture.scene_for(cells, Vector2i.ZERO, Vector2i(6, 0))
	scene.get_node("EnemyWave").auto_start = false
	var second := Node3D.new()
	second.name = "Start2"
	var map: GridMap = scene.get_node("TileMap")
	second.position = map.transform * map.map_to_local(Vector3i(3, 0, -2))
	scene.add_child(second)
	controller = scene.get_node("PortalMap")
	controller.start_paths.append(^"../Start2")
	add_child(scene)
	await ready_map(scene)
	manager = scene.get_node("TowerMap")
	check(controller.start_nodes.size() == 2, "Secondary corridor spawn disappeared")
	check(manager.place_tower(Vector3i(2, 0, -1)) != null, "One side of a loop should remain buildable")
	await ready_map(scene)
	checked_routes += verify_routes(controller)
	var revision: int = controller.revision
	check(manager.place_tower(Vector3i(4, 0, -1)) == null, "Construction disconnected secondary origin")
	check(controller.revision == revision and manager.occupied.size() == 1, "Rejected placement mutated committed state")
	check(manager.place_tower(Vector3i.ZERO) == null and manager.place_tower(Vector3i(6, 0, 0)) == null, "Endpoints must remain protected")
	scene.queue_free()
	await get_tree().process_frame
	# Build a wall until only one passage remains; reject closing the final gap.
	scene = make_scene(room(3, 3), Vector2i(0, 1), Vector2i(2, 1))
	await ready_map(scene)
	manager = scene.get_node("TowerMap")
	check(manager.place_tower(Vector3i(1, 0, 0)) != null and manager.place_tower(Vector3i(1, 0, 1)) != null, "Partial wall was rejected")
	await ready_map(scene)
	controller = scene.get_node("PortalMap")
	check(controller.plan.score == 4.0, "The remaining narrow detour must have its exact shortest cost")
	check(manager.place_tower(Vector3i(1, 0, 2)) == null, "Final passage can be sealed")
	checked_routes += verify_routes(controller)
	scene.queue_free()
	await get_tree().process_frame
	# Both waiting and active enemies reserve their remaining route. Passed cells
	# become buildable without redirecting any living enemy or rebuilding its path.
	scene = make_scene(room(5, 3), Vector2i(0, 1), Vector2i(4, 1))
	await ready_map(scene)
	manager = scene.get_node("TowerMap")
	var wave: Node = scene.get_node("EnemyWave")
	wave.enemy_count = 2
	wave.batch_size = 1
	wave.spawn_interval = 1.0
	wave.move_speed = 1.0
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	check(wave.start_wave(), "Wave failed to start")
	check(manager.place_tower(Vector3i(1, 0, 1)) == null, "Pending enemy route was blocked")
	wave._process(0.0)
	wave._process(1.0)
	var snapshots := []
	for enemy: Node3D in wave.visuals.units:
		snapshots.append(enemy.route.cells.duplicate())
		enemy._process(2.1)
	check(manager.place_tower(Vector3i(3, 0, 1)) == null, "Active remaining route was blocked")
	check(manager.place_tower(Vector3i(1, 0, 1)) != null, "Passed route cell did not become buildable")
	var units: Array = wave.visuals.units.duplicate()
	for i in units.size():
		check(units[i].route.cells == snapshots[i], "Construction redirected a committed enemy")
		units[i]._process(10000.0)
	check(wave.completed == 2 and not wave.active, "Enemies failed to reach goal around committed obstacles")
	await ready_map(scene)
	checked_routes += verify_routes(scene.get_node("PortalMap"))
	scene.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("TOWER_OBSTACLE_CHECK:" + JSON.stringify({"sentry_model": true, "footprints": true, "shortest_detour": true, "parameter_identity": true, "removal_restores_road": true, "multi_origin": true, "disconnect_rejected": true, "pending_and_live_protected": true, "passed_cells_released": true, "sampled_routes": checked_routes}))
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)

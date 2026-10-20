extends Node3D
## Real scene wiring + allocation across waves + movement and deletion.
var _units: Array[Node3D] = []

func _ready() -> void:
	call_deferred("verify")

func _record(enemy: Node3D) -> void:
	enemy.set_process(false)
	_units.append(enemy)

func _wait_spawn(wave: Node) -> void:
	for frame in 120:
		if wave.spawned == wave.enemy_count:
			return
		await get_tree().process_frame
	_check(false, "Wave failed to generate the configured enemies")

func verify() -> void:
	await _check_batches()
	var report := []
	for scene_name: String in ["main", "9x9", "11x11big"]:
		var scene: Node3D = load("res://scenes/"+scene_name+".tscn").instantiate()
		var wave: Node = scene.get_node("EnemyWave")
		wave.spawn_interval = 0.0
		wave.enemy_spawned.connect(_record)
		add_child(scene)
		var controller: Node = scene.get_node("PortalMap")
		await _wait_spawn(wave)
		var origins: int = controller.start_nodes.size()
		var initial_route_index := -1
		for origin in origins:
			var seen := {}
			var indices := []
			var plan: Dictionary = controller.plan_for(controller.troop, origin)
			if origin == 0:
				initial_route_index = controller.allocate_route_for(controller.troop, 0, wave.enemy_count, origin).route_index
			var batches := 2 if scene_name == "9x9" else 1
			for batch in batches:
				if origin > 0 or batch > 0:
					wave.start_index = origin
					# Same signal as the visible replay button.
					wave.controls.spawn_button.pressed.emit()
					await _wait_spawn(wave)
				_check(_units.size() == wave.enemy_count and wave.alive == wave.enemy_count and wave.active)
				_check(not wave.start_wave()) # no overlapping accidental waves
				var goal: Vector2i = controller.graph.nodes[controller.graph.goal_node].cell
				var finish: Vector3 = controller.map.to_global(controller.map.map_to_local(Vector3i(goal.x, 0, goal.y))+Vector3.UP*0.025)
				for i in _units.size():
					var enemy: Node3D = _units[i]
					var route: Dictionary = enemy.route
					_check(route.route_index == controller.allocate_route_for(controller.troop, enemy.enemy_id % wave.enemy_count, wave.enemy_count, origin).route_index)
					_check(route.route_index >= 0 and route.route_index < plan.routes)
					indices.append(route.route_index)
					var signature := str(route.cells)
					_check(route.selection_probability > 0 and route.selection_probability == plan.route_probabilities[route.route_index])
					seen[signature] = true
					_check(route.nodes[0] == controller.start_nodes[origin] and route.nodes[-1] == controller.graph.goal_node)
					_check(route.score-plan.score < controller.troop.score_threshold)
					_check(enemy.get_child_count() == 0) # no individual render/skeleton nodes
					_check(wave.visuals.multimesh.mesh.get_surface_count() == 1 and wave.visuals.multimesh.mesh.get_aabb().size.y > 0.5)
					_check(wave.visuals.multimesh.visible_instance_count == wave.alive)
					var position_before := enemy.global_position
					enemy._process(0.2)
					_check(is_equal_approx(enemy.global_position.distance_to(position_before), enemy.move_speed*0.2))
					enemy._process(10000.0) # traverse corners and many cells in one update
					_check(enemy.global_position.is_equal_approx(enemy.waypoints[-1]) and enemy.global_position.is_equal_approx(finish) and enemy.is_queued_for_deletion())
					_check(wave.visuals.multimesh.visible_instance_count == wave.alive)
				_check(wave.completed == wave.enemy_count and wave.alive == 0 and not wave.active)
				_check(wave.visuals.units.is_empty())
				await get_tree().process_frame
				for index in _units.size():
					_check(not is_instance_valid(_units[index]))
				_units.clear()
			_check(controller.sample_for(controller.troop, 0, origin, plan.routes).is_empty())
			_check(controller.sample_for(controller.troop, 0, origin, -2).is_empty())
			# Compare quotas across platforms; random departure order is intentional.
			indices.sort()
			report.append({"scene": scene_name, "origin": origin, "pool": wave.pool_size, "spawned_and_deleted": batches*wave.enemy_count, "unique_node_routes": seen.size(), "route_indices": indices})
		# Restoring costs restores the same wave-local quota assignment.
		var profile: Resource = controller.troop
		var threshold: float = profile.score_threshold
		profile.score_threshold = 0
		await get_tree().process_frame
		_check(not wave.start_wave() and controller.next_route_for(profile, 0).is_empty())
		profile.score_threshold = threshold
		await get_tree().process_frame
		_check(controller.allocate_route_for(profile, 0, wave.enemy_count).route_index == initial_route_index)
		scene.queue_free()
		await get_tree().process_frame
	print("ENEMY_CHECK:"+JSON.stringify({"cases": report, "model_surfaces": 1, "movement_and_cleanup": true, "default_total": 64, "batch_size": 1, "partial_batch": [3, 2]}))
	if not OS.has_feature("web"):
		get_tree().quit()

func _check_batches() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	var wave: Node = scene.get_node("EnemyWave")
	_check(wave.enemy_count == 64 and wave.batch_size == 1)
	wave.auto_start = false
	wave.show_button = false
	wave.enemy_spawned.connect(_record)
	add_child(scene)
	wave.set_process(false)
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing or controller.plan.is_empty():
		await get_tree().process_frame
	_check(wave.start_wave())
	wave._process(0.0)
	_check(wave.spawned == 1)
	wave._process(0.19)
	_check(wave.spawned == 1)
	wave._process(0.02)
	_check(wave.spawned == 2)
	wave._process(10.0)
	_check(wave.spawned == 3) # a slow frame must not emit a catch-up burst
	while wave.spawned < 64:
		var before: int = wave.spawned
		wave._process(0.2)
		_check(wave.spawned-before == 1)
	wave._process(10.0)
	_check(wave.spawned == 64)
	for enemy: Node3D in _units:
		enemy._process(10000.0)
	_check(wave.completed == 64 and not wave.active)
	await get_tree().process_frame
	_units.clear()
	wave.enemy_count = 5
	wave.batch_size = 3
	_check(wave.start_wave())
	wave._process(0.0)
	_check(wave.spawned == 3)
	wave._process(0.2)
	_check(wave.spawned == 5)
	for enemy: Node3D in _units:
		enemy._process(10000.0)
	_check(wave.completed == 5 and not wave.active)
	await get_tree().process_frame
	_units.clear()
	scene.queue_free()
	await get_tree().process_frame

func _check(condition: bool, message := "test check failed") -> void:
	if not condition:
		push_error(message)
		if not OS.has_feature("web"):
			get_tree().quit(1)

extends Node3D
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func ready_map(scene: Node) -> void:
	for i in 120:
		var controller: Node = scene.get_node("PortalMap")
		if not controller.computing and controller.plan.get("reachable", false):
			return
		await get_tree().process_frame
	check(false, "Map failed to prepare")

func actual_score(controller: Node, profile: Troop, route: Dictionary) -> float:
	var result := 0.0
	for i in range(1, route.cells.size()):
		result += profile.evaluation(controller.tile_parameters.get_tile(Vector2i(route.cells[i])))
	return result

func verify() -> void:
	var soldier: Troop = (TroopCatalog.find("soldier").duplicate() as Troop)
	var quick: Troop = (TroopCatalog.find("quickfeet").duplicate() as Troop)
	var heavy: Troop = (TroopCatalog.find("heavy").duplicate() as Troop)
	# Routing examples below deliberately score threat alone; keep the fixture
	# independent of the designer's editable per-step base cost.
	quick.path_base_cost = 0.0
	# Isolate the frozen-stat checks from editable game balance.
	quick.max_health = 50
	quick.speed_multiplier = 1.5
	heavy.max_health = 500
	heavy.speed_multiplier = 0.5
	check(soldier.max_health == 100 and soldier.speed_multiplier == 1 and is_inf(soldier.score_threshold), "Soldier defaults incorrect")
	# Movement speed is editable balance, independent of the routing contract.
	check(quick.configuration_error().is_empty(), "Quickfeet resource is invalid")
	check(quick.max_health == 50 and quick.speed_multiplier == 1.5 and quick.score_threshold == 25, "Quickfeet fixture stats incorrect")
	check(heavy.max_health == 500 and heavy.speed_multiplier == 0.5 and heavy.score_threshold == 25, "Heavy fixture stats incorrect")
	for profile in [soldier, quick, heavy]:
		for property: Dictionary in profile.get_property_list():
			check(property.name not in ["scoring_mode", "shuffle_candidates", "candidate_threshold"], "Redundant troop option remains")
	var cells: Array[Vector2i] = [Vector2i(0, 1), Vector2i(4, 1)]
	for x in 5:
		cells.append(Vector2i(x, 0))
		cells.append(Vector2i(x, 2))
	var scene := Fixture.scene_for(cells, Vector2i(0, 1), Vector2i(4, 1))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	await ready_map(scene)
	var controller: Node = scene.get_node("PortalMap")
	check(controller.troop == TroopCatalog.find("soldier") and scene.get_node("EnemyWave").available_troops[0] == controller.troop, "Map and wave did not share the troop definition")
	var catalog := TroopCatalog.all()
	var catalog_size := catalog.size()
	catalog.clear()
	check(TroopCatalog.all().size() == catalog_size, "Caller modified the shared troop registry")
	var danger: Resource = controller.tile_parameters.get_tile(Vector2i(2, 0))
	danger.threat = 50
	await get_tree().process_frame
	check(soldier.evaluation(danger) == 1 and quick.evaluation(danger) == 50 and heavy.evaluation(danger) == -50, "Raw evaluation was transformed")
	var safe: Dictionary = controller.plan_for(quick)
	var risky: Dictionary = controller.plan_for(heavy)
	check(safe.get("reachable", false) and safe.score == 0, "Quickfeet failed to choose the safe branch")
	check(risky.get("reachable", false) and risky.score == -50, "Heavy failed to choose the dangerous branch")
	var all_routes: Dictionary = controller.plan_for(soldier)
	check(all_routes.routes == all_routes.candidate_routes and all_routes.routes == 2, "Soldier did not use the same unfiltered candidate pool")
	for i in all_routes.routes:
		var route: Dictionary = controller.sample_for(soldier, i, 0, i)
		check(route.score == actual_score(controller, soldier, route), "Soldier bypassed raw candidate scoring")
	for profile in [quick, heavy]:
		var plan: Dictionary = controller.plan_for(profile)
		check(plan.cached, "Signed-score plan not cached")
		for i in plan.routes:
			var route: Dictionary = controller.sample_for(profile, i, 0, i)
			check(route.score == actual_score(controller, profile, route), "Reported score differs from raw tile sum")
			check(route.score-plan.score < 25, "Candidate threshold not applied to raw score")
			check((Vector2(2, 0) in route.cells) == (profile == heavy), "Wrong dangerous/safe branch retained")
		var debug: Dictionary = controller.debug_graph_for(profile)
		var details: Dictionary = controller.debug_summary_for(profile)
		check(debug.nodes.size() == details.active_nodes and debug.edges.size() == details.used_edges, "Signed debug graph contains rejected candidates")
	# Strict cutoff: an exactly 25-point worse candidate is excluded.
	danger.threat = 25
	await get_tree().process_frame
	check(controller.sample_for(quick, 0).is_empty(), "Tile edit did not invalidate raw-score sampling")
	check(controller.plan_for(quick).routes == 1 and controller.plan_for(heavy).routes == 1, "Threshold equality should be excluded")
	quick.score_threshold = INF
	heavy.score_threshold = INF
	check(controller.plan_for(quick).routes == 2 and controller.plan_for(heavy).routes == 2, "INF should retain both candidate branches")
	for i in 2:
		var route: Dictionary = controller.next_route_for(quick, i)
		check(not route.is_empty() and route.selection_probability > 0, "Weighted candidate draw failed")
		check(controller.next_route_for(quick, i).route_index == route.route_index, "Same seed changed its route")
	# Runtime stats are copied once per wave, including pending enemies.
	var wave: Node = scene.get_node("EnemyWave")
	wave.troop = heavy
	wave.enemy_count = 2
	wave.batch_size = 1
	wave.move_speed = 2.5
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	heavy.max_shield = 80
	check(wave.start_wave(), "Heavy wave could not start")
	heavy.max_health = 999
	heavy.max_shield = 160
	heavy.speed_multiplier = 3
	wave._process(0.0)
	wave._process(1.0)
	for enemy: Node3D in wave.visuals.units.duplicate():
		check(enemy.health == 500 and enemy.max_health == 500 and enemy.move_speed == 1.25, "Pending enemy stats were not frozen")
		check(enemy.shield == 80 and enemy.max_shield == 80, "Pending enemy shields were not frozen")
		enemy._process(10000)
	await get_tree().process_frame
	check(wave.completed == 2 and not wave.active, "Heavy enemies failed to complete")
	wave.enemy_count = 1
	for index in [0, 1]:
		wave.select_troop(index)
		var profile: Troop = wave.available_troops[index]
		check(wave.troop == profile and controller.troop == profile, "Troop selector did not update gameplay and preview")
		check(wave.start_wave(), "Selected troop failed to spawn")
		wave._process(0)
		var enemy: Node3D = wave.visuals.units[0]
		check(enemy.health == profile.max_health and enemy.move_speed == 2.5*profile.speed_multiplier, "Selected troop did not apply HP/speed")
		enemy._process(10000)
		await get_tree().process_frame
	scene.queue_free()
	await get_tree().process_frame
	# A wider room needs a longer safe local detour, absent from the neutral pool.
	cells = []
	for y in 3:
		for x in 3:
			cells.append(Vector2i(x, y))
	scene = Fixture.scene_for(cells, Vector2i(0, 1), Vector2i(2, 1))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	await ready_map(scene)
	controller = scene.get_node("PortalMap")
	controller.tile_parameters.get_tile(Vector2i(1, 1)).threat = 100
	await get_tree().process_frame
	quick = (TroopCatalog.find("quickfeet").duplicate() as Troop)
	quick.path_base_cost = 0.0
	quick.score_threshold = 1
	heavy = (TroopCatalog.find("heavy").duplicate() as Troop)
	heavy.score_threshold = 1
	check(controller.plan_for(quick).score == 0 and controller.plan_for(heavy).score == -100, "Guided representatives missed local safe/dangerous alternatives")
	check(controller.sample_for(quick, 0).length == 4 and controller.sample_for(heavy, 0).length == 2, "Local detour selection incorrect")
	scene.queue_free()
	await get_tree().process_frame
	var cases := []
	for name in ["9x9", "11x11big"]:
		scene = load("res://scenes/"+name+".tscn").instantiate()
		scene.get_node("EnemyWave").auto_start = false
		add_child(scene)
		await ready_map(scene)
		controller = scene.get_node("PortalMap")
		# Reproducible nonzero threat pattern, without changing physical topology.
		controller.tile_parameters.begin_update()
		for tile: Resource in controller.tile_parameters.all_tiles():
			tile.threat = float(posmod(tile.cell.x*7+tile.cell.y*13, 9))
		controller.tile_parameters.end_update()
		await get_tree().process_frame
		for origin in controller.start_nodes.size():
			for profile in TroopCatalog.all():
				var plan: Dictionary = controller.plan_for(profile, origin)
				check(plan.get("reachable", false), "Troop lost a test-map origin")
				for i in mini(plan.get("routes", 0), 8):
					var route: Dictionary = controller.sample_for(profile, i, origin, i)
					if profile.route_rule == Troop.RouteRule.COST:
						check(not route.is_empty() and route.score == actual_score(controller, profile, route), "Test-map score not exact")
					else:
						check(not route.is_empty() and route.identity == str(route.cells), "Hard-rule route lost physical identity")
				cases.append({"scene": name, "origin": origin, "troop": profile.troop_name, "routes": plan.get("routes", 0), "score": plan.get("score", 0), "candidates": plan.get("candidate_routes", plan.get("routes", 0))})
		scene.queue_free()
		await get_tree().process_frame
	var report := {"platform": OS.get_name(), "failures": failures, "raw_signed_scoring": true, "stats_frozen": true, "safe_local_detour": true, "cases": cases}
	print("TROOP_CHECK:"+JSON.stringify(report))
	if not OS.has_feature("web"):
		var file := FileAccess.open(Artifacts.path("enemies/troop_profiles_windows.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ")+"\n")
		get_tree().quit(1 if failures else 0)

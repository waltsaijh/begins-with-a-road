extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")

func _ready() -> void:
	call_deferred("verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		if not OS.has_feature("web"):
			get_tree().quit(1)

func _ladder() -> Node3D:
	var occupied := {}
	for x in range(-2, 13):
		occupied[Vector2i(x, 0)] = true
	for x in range(0, 11):
		occupied[Vector2i(x, -4)] = true
	for x in [0, 5, 10]:
		for y in range(-4, 1):
			occupied[Vector2i(x, y)] = true
	var cells: Array[Vector2i] = []
	for cell: Vector2i in occupied:
		cells.append(cell)
	return Fixture.scene_for(cells, Vector2i(-2, 0), Vector2i(12, 0))

func verify() -> void:
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var cases := []
	for name in ["double_loop", "9x9", "11x11big"]:
		var scene: Node3D = _ladder() if name == "double_loop" else load("res://scenes/"+name+".tscn").instantiate()
		scene.get_node("EnemyWave").auto_start = false
		add_child(scene)
		var controller: Node = scene.get_node("PortalMap")
		while controller.computing or controller.plan.is_empty():
			await get_tree().process_frame
		var costs: PackedFloat64Array = controller.tile_parameters.evaluate(controller.troop).costs
		var raw := []
		var latest := {}
		var check := {}
		for round_index in 23:
			var planner: RefCounted = ClassDB.instantiate("RoadRoutePlanner")
			var prepared: Dictionary = planner.prepare(controller.graph)
			_check(prepared.valid, "prepare failed")
			var began := Time.get_ticks_usec()
			var plan: Dictionary = planner.find_paths("waypoint", costs, -1, -1, INF, 1.0, 64)
			var elapsed := Time.get_ticks_usec()-began
			_check(plan.valid and plan.reachable and plan.attempts <= 64, "plan failed")
			if round_index >= 3:
				raw.append(elapsed)
			latest = plan
			if round_index == 22:
				var middle_routes := 0
				var maximum_score := 0.0
				for index in plan.routes:
					var route: Dictionary = planner.sample_route("waypoint", index, index)
					_check(not route.is_empty() and route.nodes[0] == controller.graph.start_node and route.nodes[-1] == controller.graph.goal_node, "invalid endpoints")
					var seen := {}
					for node: int in route.nodes:
						_check(not seen.has(node), "repeated entrance node")
						seen[node] = true
					var middle := false
					for i in range(1, route.cells.size()):
						var delta: Vector2 = route.cells[i]-route.cells[i-1]
						_check(absf(delta.x)+absf(delta.y) == 1.0, "disconnected tiles")
						if name == "double_loop" and route.cells[i].x == 5 and route.cells[i].y > -4 and route.cells[i].y < 0:
							middle = true
					middle_routes += int(middle)
					maximum_score = maxf(maximum_score, route.score)
				if name == "double_loop":
					_check(plan.routes == (2 if baseline else 4), "unexpected double-loop route count")
					_check(middle_routes == (0 if baseline else 2), "central connector missing")
					_check(plan.get("waypoint_added", 0) == (0 if baseline else 2), "fallback not recorded")
				check = {"middle_routes": middle_routes, "maximum_score": maximum_score, "simple_connected_samples": true}
			await get_tree().process_frame
		cases.append({"scene": name, "routes": latest.routes, "used_edges": latest.used_edges, "best": latest.score, "attempts": latest.attempts, "waypoint_attempts": latest.get("waypoint_attempts", 0), "waypoint_searches": latest.get("waypoint_searches", 0), "waypoint_added": latest.get("waypoint_added", 0), "stop": latest.stop_reason, "raw_plan_us": raw, "check": check})
		scene.queue_free()
		await get_tree().process_frame
	print("WAYPOINT_CHECK:"+JSON.stringify({"platform": OS.get_name(), "baseline": baseline, "warmup": 3, "rounds": 20, "cases": cases}))
	if not OS.has_feature("web"):
		get_tree().quit()

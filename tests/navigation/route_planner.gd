extends SceneTree
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
func _initialize() -> void:
	call_deferred("verify")

func ready_plan(scene: Node) -> Node:
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing:
		await process_frame
	assert(controller.plan.valid and controller.plan.reachable)
	return controller

func check_sample(graph: Dictionary, route: Dictionary) -> void:
	assert(not route.is_empty())
	assert(route.nodes[0] == graph.start_node and route.nodes[-1] == graph.goal_node)
	assert(route.cells.size() == route.length+1)
	var seen := {}
	for id: int in route.nodes:
		assert(not seen.has(id))
		seen[id] = true
	var actual := PackedInt32Array()
	var node_at := {}
	for node: Dictionary in graph.nodes:
		node_at[Vector2(node.cell)] = node.id
	for i in route.cells.size():
		if i:
			var delta: Vector2 = route.cells[i]-route.cells[i-1]
			assert(absi(int(delta.x))+absi(int(delta.y)) == 1)
		if node_at.has(route.cells[i]):
			actual.append(node_at[route.cells[i]])
	assert(actual == route.nodes)

func verify() -> void:
	assert(ClassDB.class_exists("RoadRoutePlanner") and not ClassDB.class_exists("RoadRouteZdd"))
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var controller: Node = await ready_plan(scene)
	assert(controller.plan.routes == 1 and controller.plan.score == 23)
	check_sample(controller.graph, controller.sample_route(0))
	assert(controller.plan_for(controller.troop).cached)
	scene.queue_free()
	await process_frame
	scene = Fixture.scene_for([Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE], Vector2i.ZERO, Vector2i.ONE)
	root.add_child(scene)
	controller = await ready_plan(scene)
	assert(controller.plan.routes == 2 and controller.plan.candidate_routes == 2)
	var variants := {}
	for seed in 32:
		var route: Dictionary = controller.sample_route(seed)
		check_sample(controller.graph, route)
		variants[route.cells[1]] = true
	assert(variants.size() == 2)
	controller.rebuild()
	assert(controller.plan.is_empty() and controller.sample_route(0).is_empty())
	await ready_plan(scene)
	scene.queue_free()
	await process_frame
	scene = Fixture.scene_for(Fixture.annotated(), Vector2i(-3, 0), Vector2i(11, 0))
	root.add_child(scene)
	controller = await ready_plan(scene)
	for seed in 32:
		check_sample(controller.graph, controller.sample_route(seed))
	var prepared: Dictionary = controller.planner.prepare(controller.graph)
	var costs := PackedFloat64Array()
	for cell: Vector2 in prepared.cells:
		costs.append(1.0)
	var first: Dictionary = controller.planner.find_paths("fast", costs)
	assert(first.valid and not first.cached and controller.planner.find_paths("fast", costs).cached)
	# Returned packed buffers must not let a caller corrupt the cached summary.
	var original_steps: PackedInt32Array = first.steps.duplicate()
	var original_directions: PackedVector2Array = first.directions.duplicate()
	first.steps[0] = -999
	first.directions[0] = Vector2(-999, -999)
	var isolated: Dictionary = controller.planner.find_paths("fast", costs)
	assert(isolated.steps == original_steps and isolated.directions == original_directions)
	var limited: Dictionary = controller.planner.find_paths("fast", costs, -1, -1, 10, 1, 1)
	assert(limited.geometry_cached and not limited.cached and limited.routes == 1 and limited.attempts == 1)
	assert(controller.planner.find_paths("fast", costs, -1, -1, 10, 1, 1).cached)
	costs[0] += 5
	var changed: Dictionary = controller.planner.find_paths("fast", costs)
	assert(not changed.cached)
	assert(controller.planner.find_paths("safe", costs).valid)
	assert(controller.planner.find_paths("fast", costs).cached)
	assert(not controller.planner.find_paths("bad", PackedFloat64Array([0])).valid)
	controller.plan = controller.plan_for(controller.troop)
	var view: Node3D = scene.get_node("PortalOverlay")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F1
	view._unhandled_key_input(event)
	assert(view.show_routes)
	event.keycode = KEY_F2
	view._unhandled_key_input(event)
	assert(view.show_parameters)
	scene.queue_free()
	await process_frame
	for name in ["9x9", "11x11big"]:
		scene = load("res://scenes/"+name+".tscn").instantiate()
		root.add_child(scene)
		controller = await ready_plan(scene)
		assert(is_inf(controller.troop.score_threshold))
		var maximum_score := controller.plan.score as float
		for index in controller.plan.routes:
			var candidate: Dictionary = controller.sample_for(controller.troop, index, 0, index)
			check_sample(controller.graph, candidate)
			maximum_score = maxf(maximum_score, candidate.score)
		if name == "9x9":
			assert(maximum_score-controller.plan.score >= 25) # Previously filtered routes now survive.
		for seed in 32:
			var route: Dictionary = controller.sample_route(seed)
			check_sample(controller.graph, route)
			assert(route.length == route.score and route.score-controller.plan.score < controller.troop.score_threshold)
		print("SCENE_POOL:", name, " vertices=", controller.plan.active_nodes, " edges=", controller.plan.used_edges, " paths=", controller.plan.routes, " best=", controller.plan.score, " max_score=", maximum_score)
		scene.queue_free()
		await process_frame
	print("PASS: shared cyclic graph and route pool, profile cache/invalidation, all local ties, actual nonrepeated portal visits, physical weighted samples, controls and both real scenes")
	quit()

extends SceneTree
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Profile = preload("res://scripts/enemies/troops/troop.gd")
const Record = preload("res://scripts/map/tile/tile_parameters.gd")

class RiskProfile extends Profile:
	var calls := 0
	var multiplier := 1.0:
		set(value):
			multiplier = value
			emit_changed()
	func evaluation(tile: Record) -> float:
		calls += 1
		return (1.0+tile.damage_per_second)*multiplier

func _initialize() -> void:
	call_deferred("verify")

func wait_plan(controller: Node) -> void:
	await process_frame
	while controller.computing or controller.plan.is_empty():
		await process_frame
	assert(controller.plan.valid and controller.plan.reachable)

func verify() -> void:
	var cells: Array[Vector2i] = []
	for y in 3:
		for x in 3:
			cells.append(Vector2i(x, y))
	var scene := Fixture.scene_for(cells, Vector2i(0, 1), Vector2i(2, 1))
	var profile := RiskProfile.new()
	profile.score_threshold = 1.0 # This fixture compares only the best raw-score ties.
	var controller: Node = scene.get_node("PortalMap")
	controller.troop = profile
	root.add_child(scene)
	await wait_plan(controller)
	assert(profile.calls == 9 and controller.plan.score == 2)
	assert(controller.plan_for(profile).cached and profile.calls == 9)
	var center: Resource = controller.tile_parameters.get_tile(Vector2i(1, 1))
	center.damage_per_second = 99
	assert(controller.plan.is_empty() and controller.sample_for(profile, 0).is_empty())
	await wait_plan(controller)
	assert(profile.calls == 18 and controller.plan.score == 4)
	for seed in 32:
		var route: Dictionary = controller.sample_for(profile, seed)
		assert(route.length == 4 and route.score == 4 and not Vector2(1, 1) in route.cells)
	# Direct route and longer detours now have exactly the same cost.
	center.damage_per_second = 2
	await wait_plan(controller)
	var lengths := {}
	for seed in 128:
		var route: Dictionary = controller.sample_for(profile, seed)
		assert(route.score == 4)
		lengths[route.length] = true
	assert(lengths.has(2) and lengths.has(4))
	var debug: Dictionary = controller.debug_graph_for(profile)
	var has_detour := false
	for edge: Dictionary in debug.edges:
		has_detour = has_detour or edge.links.size() > 4
	assert(has_detour)
	var before_calls := profile.calls
	profile.multiplier = 2
	await wait_plan(controller)
	assert(profile.calls == before_calls+9 and controller.plan.score == 8)
	var other := RiskProfile.new()
	other.score_threshold = 1.0
	var other_plan: Dictionary = controller.plan_for(other)
	assert(other_plan.score == 4 and other.calls == 9)
	assert(controller.plan_for(other).cached and other.calls == 9)
	# Fields and arbitrary parameters survive geometry rebuilds at the same cell.
	center.set_parameter(&"fire", 42)
	await wait_plan(controller)
	controller.rebuild()
	await wait_plan(controller)
	assert(controller.tile_parameters.get_tile(Vector2i(1, 1)) == center and center.get_parameter(&"fire") == 42)
	# C++ consumes a tile array and counts each entered endpoint once.
	var planner: RefCounted = controller.planner
	var costs := PackedFloat64Array()
	for cell: Vector2 in controller.graph.tiles:
		costs.append(7.0 if cell == Vector2(0, 1) else 2.0 if cell == Vector2(2, 1) else 3.0 if cell == Vector2(1, 1) else 1.0)
	var forward: Dictionary = planner.find_paths("asymmetric", costs)
	assert(forward.score == 5)
	var backward: Dictionary = planner.find_paths("backward", costs, controller.graph.goal_node, controller.graph.start_node)
	assert(backward.score == 10)
	assert(planner.sample_route("backward", 0).score == 10)
	costs[0] = 0
	assert(not planner.find_paths("asymmetric", costs).valid and planner.sample_route("asymmetric", 0).is_empty())
	profile.multiplier = -1
	await process_frame
	await process_frame
	assert(controller.plan.valid and controller.plan.reachable)
	for seed in 16:
		var route: Dictionary = controller.sample_for(profile, seed)
		var score := 0.0
		for i in range(1, route.cells.size()):
			score += profile.evaluation(controller.tile_parameters.get_tile(Vector2i(route.cells[i])))
		assert(route.score == score and route.score < 0)
	scene.queue_free()
	await process_frame
	print("PASS: tile records, per-profile cache, parameter invalidation, safe detours, finite tied representatives, weighted overlay, asymmetric endpoints and signed candidate scores")
	quit()

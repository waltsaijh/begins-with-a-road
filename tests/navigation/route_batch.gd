extends SceneTree
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
var failures := 0

class CountingController extends Node:
	var source: Node
	var map: GridMap
	var batches := 0
	func prepare_route_batch(profile: Troop, total: int, origin: int, modifiers: Variant = null) -> Dictionary:
		batches += 1
		return source.prepare_route_batch(profile, total, origin, modifiers)

func _initialize() -> void: verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func wait_map(controller: Node) -> void:
	for i in 120:
		if not controller.computing and controller.plan.get("reachable", false): return
		await process_frame
	check(false, "Map did not become ready")

func group(profile: Troop, count: int) -> WaveSpawnGroup:
	var result := WaveSpawnGroup.new()
	result.troop = profile
	result.enemy_count = count
	result.interval_ticks = 0
	return result

func verify() -> void:
	var cells: Array[Vector2i] = []
	for x in 7:
		cells.append(Vector2i(x, 0))
		cells.append(Vector2i(x, 2))
	cells.append_array([Vector2i(0, 1), Vector2i(6, 1)])
	var scene := Fixture.scene_for(cells, Vector2i(0, 1), Vector2i(6, 1))
	scene.get_node("EnemyWave").auto_start = false
	root.add_child(scene)
	var controller: Node = scene.get_node("PortalMap")
	await wait_map(controller)
	var profile := TroopCatalog.find("soldier").duplicate() as Troop
	profile.route_selection = Troop.RouteSelection.UNIFORM
	var light: Dictionary = controller.plan_for(profile)
	var cache_key: String = controller._profile_key(profile)
	for field in ["active_nodes", "used_edges", "steps", "directions"]:
		check(not light.has(field), "Gameplay summary retained an eager or stale native union")
	check(controller._candidate_routes._plans[cache_key].details.is_empty(), "Cold plan eagerly constructed debug details")
	var first: Dictionary = controller.prepare_route_batch(profile, 256)
	check(first.routes.size() == 256 and first.pool_size == 2, "Batch quota was not prepared")
	for i in 256:
		var expected: Dictionary = controller.allocate_route_for(profile, i, 256)
		check(first.routes[i] == expected, "Batch allocation changed a route, raw score or probability")
	check(controller._candidate_routes._plans[cache_key].details.is_empty(), "Batch allocation triggered debug union construction")
	var details: Dictionary = controller.debug_summary_for(profile)
	var expected_nodes := {}
	var expected_edges := {}
	var expected_directions := {}
	for i in light.routes:
		var route: Dictionary = controller.sample_for(profile, 0, 0, i)
		for node: int in route.nodes: expected_nodes[node] = true
		for j in route.edges.size(): expected_edges[route.edges[j]] = [route.nodes[j], route.edges[j], route.nodes[j+1]]
		for j in range(1, route.cells.size()):
			var a: Vector2 = route.cells[j-1]
			var b: Vector2 = route.cells[j]
			expected_directions[Vector4i(a.x, a.y, b.x, b.y)] = true
	check(details.active_nodes == expected_nodes.size() and details.used_edges == expected_edges.size(), "Lazy debug counts differ from accepted candidate union")
	check(details.steps.size() == expected_edges.size()*3 and details.directions.size() == expected_directions.size()*2, "Lazy debug union sizes differ")
	for i in range(0, details.steps.size(), 3):
		check(expected_edges[details.steps[i+1]] == [details.steps[i], details.steps[i+1], details.steps[i+2]], "Lazy debug edge direction changed")
	for i in range(0, details.directions.size(), 2):
		var a: Vector2 = details.directions[i]
		var b: Vector2 = details.directions[i+1]
		check(expected_directions.has(Vector4i(a.x, a.y, b.x, b.y)), "Lazy debug physical direction changed")
	details.steps[0] = -999
	check(controller.debug_summary_for(profile).steps[0] != -999, "Caller corrupted the lazy debug cache")
	profile.route_selection = Troop.RouteSelection.SOFTMAX
	profile.path_base_cost = 2
	var updated: Dictionary = controller.plan_for(profile)
	check(controller._candidate_routes._plans[cache_key].details.is_empty(), "Invalidation retained stale debug details")
	var next: Dictionary = controller.prepare_route_batch(profile, 256)
	for i in 256:
		check(next.routes[i] == controller.allocate_route_for(profile, i, 256), "Softmax batch quota differs from scalar allocation")
	check(first.routes[0].score == 8 and next.routes[0].score == 16, "Profile edits rewrote already frozen batch scores")
	var proxy := CountingController.new()
	proxy.source = controller
	proxy.map = controller.map
	var definition := WaveDefinition.new()
	definition.groups = [group(profile, 100), group(profile, 156)]
	seed(4421)
	var expected_random := randi()
	seed(4421)
	var schedule := WaveSpawnSchedule.build(definition, proxy, 0, false)
	check(randi() == expected_random, "Unshuffled batch preview consumed randomness")
	check(proxy.batches == 1 and schedule.pending.size() == 256, "Same troop/origin was prepared more than once across groups")
	check(schedule.waypoint_paths == 2, "Identical walks did not reuse their world-space waypoint snapshot")
	var saved_points: PackedVector3Array = schedule.pending[0].points.duplicate()
	for member: Dictionary in schedule.pending:
		for j in member.route.cells.size():
			var cell := Vector2i(member.route.cells[j])
			var expected: Vector3 = controller.map.to_global(controller.map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*EnemyConstants.GROUND_OFFSET)
			check(member.points[j].is_equal_approx(expected), "Cached world waypoint differs from direct map projection")
	controller.map.position += Vector3(3, 2, -4)
	var moved := WaveSpawnSchedule.build(definition, proxy, 10000, false)
	check(schedule.pending[0].points == saved_points, "A later wave or map transform rewrote the old snapshot")
	check(moved.pending[0].points[0].is_equal_approx(saved_points[0]+Vector3(3, 2, -4)), "World-space cache survived across wave builds with a stale transform")
	var first_enemy := EnemyScene.instantiate() as Node3D
	var second_enemy := EnemyScene.instantiate() as Node3D
	root.add_child(first_enemy)
	root.add_child(second_enemy)
	first_enemy.follow(1, schedule.pending[0].route, schedule.pending[0].points, true)
	second_enemy.follow(2, schedule.pending[0].route, schedule.pending[0].points, true)
	first_enemy.set_process(false)
	second_enemy.set_process(false)
	first_enemy._process(0.1)
	check(first_enemy.global_position != second_enemy.global_position and second_enemy._next == 1, "Shared waypoints coupled enemy movement state")
	check(first_enemy.waypoints == saved_points and second_enemy.waypoints == saved_points, "Movement mutated shared waypoint data")
	var external_points := saved_points.duplicate()
	second_enemy.follow(2, {}, external_points)
	external_points[0] += Vector3.ONE
	check(second_enemy.waypoints == saved_points, "Public follow lost its defensive waypoint snapshot")
	check(controller.prepare_route_batch(profile, 0).is_empty() and controller.prepare_route_batch(profile, 2, -1).is_empty(), "Invalid batch inputs were accepted")
	verify_modified_batches(controller, profile)
	first_enemy.queue_free()
	second_enemy.queue_free()
	proxy.free()
	scene.queue_free()
	await process_frame
	print("ROUTE_BATCH_CHECK:"+JSON.stringify({"failures": failures, "lazy_details": true, "scalar_equivalent_256": true, "shared_wave_waypoints": true, "frozen_scores_and_transforms": true, "independent_movement": true, "no_preview_randomness": true}))
	quit(1 if failures else 0)

func verify_modified_batches(controller: Node, profile: Troop) -> void:
	var effect := {"tags": [&"ground"], "cells": {Vector2i(3, 0): true}, "multiplier": 0.5}
	for rule in [Troop.RouteRule.COST, Troop.RouteRule.SHORTEST, Troop.RouteRule.NEWEST]:
		var selected := profile.duplicate() as Troop
		selected.route_rule = rule
		var baseline: Dictionary = controller.plan_for(selected)
		var modified: Dictionary = controller.plan_for(selected, 0, [effect])
		check(baseline.route_probabilities != modified.route_probabilities, "Traffic fixture did not change the selected rule's distribution")
		controller.set_traffic_effects([effect])
		for modifiers in [null, [], [effect]]:
			var batch: Dictionary = controller.prepare_route_batch(selected, 64, 0, modifiers)
			check(not batch.is_empty(), "Modified/special route batch was not prepared")
			if batch.is_empty(): continue
			for i in 64:
				check(batch.routes[i] == controller.allocate_route_for(selected, i, 64, 0, modifiers), "Modified/special batch differs from scalar allocation")
		controller.set_traffic_effects([])
	var flying := profile.duplicate() as Troop
	flying.flight_height = 0.75
	var definition := WaveDefinition.new()
	definition.groups = [group(profile, 8), group(flying, 8)]
	var schedule := WaveSpawnSchedule.build(definition, controller, 0, false)
	check(schedule.waypoint_paths == 4, "Ground and airborne snapshots shared different heights")
	for member: Dictionary in schedule.pending:
		var cell := Vector2i(member.route.cells[0])
		var expected: Vector3 = controller.map.to_global(controller.map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*(EnemyConstants.GROUND_OFFSET+member.profile.flight_height*controller.map.cell_size.y))
		check(member.points[0].is_equal_approx(expected), "World waypoints lost the profile's flight height")
	var cohort := profile.duplicate() as Troop
	cohort.cohort_size = 5
	definition.groups = [group(cohort, 7)]
	schedule = WaveSpawnSchedule.build(definition, controller, 0, false)
	check(schedule.pending.size() == 7, "Cohort batch changed the number of individuals")
	if schedule.pending.size() == 7:
		schedule.pending[0].route["test_marker"] = true
		check(not schedule.pending[1].route.has("test_marker"), "Cohort members shared a mutable route dictionary")
		schedule.pending[0].abilities["test_marker"] = true
		check(not schedule.pending[1].abilities.has("test_marker"), "Cohort members shared mutable ability state")

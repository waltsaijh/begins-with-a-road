extends SceneTree
const Walk = preload("res://scripts/navigation/routes/candidate_walk.gd")
const Candidates = preload("res://scripts/navigation/routes/candidate_routes.gd")
const Distribution = preload("res://scripts/navigation/routes/route_distribution.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const LoopFixture = preload("res://tests/fixtures/route_loop_fixture.gd")
var failures := 0

class SamplePlanner extends RefCounted:
	var walks: Array[PackedVector2Array] = []
	func find_paths(_key: String, _weights: PackedFloat64Array, _start: int, _goal: int, _threshold: float, _penalty: float, _budget: int) -> Dictionary:
		return {"valid": true, "reachable": true, "routes": walks.size(), "choice_edges": 99}
	func sample_route(_key: String, _variant: int, route_index: int) -> Dictionary:
		return {"cells": walks[route_index], "nodes": PackedInt32Array([0, 1, 2]), "edges": PackedInt32Array([90, 91]), "length": walks[route_index].size()-1, "score": -999.0, "best_score": -999.0, "route_index": route_index}

func _initialize() -> void: verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func check_route(graph: Dictionary, route: Dictionary) -> void:
	check(route.length == route.cells.size()-1, "Normalized length is stale")
	var node_at := {}
	for node: Dictionary in graph.nodes: node_at[Vector2(node.cell)] = node.id
	var nodes := PackedInt32Array()
	var seen := {}
	for i in route.cells.size():
		var cell: Vector2 = route.cells[i]
		check(not seen.has(cell), "Normalized route revisits a physical cell")
		seen[cell] = true
		if i > 0:
			var delta: Vector2 = cell-route.cells[i-1]
			check(absf(delta.x)+absf(delta.y) == 1, "Loop erasure disconnected the route")
		if node_at.has(cell): nodes.append(node_at[cell])
	check(nodes == route.nodes and route.edges.size() == maxi(0, nodes.size()-1), "Normalized vertex or edge metadata is stale")
	check(route.cells[0] == Vector2(graph.nodes[graph.start_node].cell) and route.cells[-1] == Vector2(graph.nodes[graph.goal_node].cell), "Loop erasure changed endpoints")

func verify() -> void:
	var tiles := PackedVector2Array()
	var indices := {}
	for y in 2:
		for x in 4:
			indices[Vector2i(x, y)] = tiles.size()
			tiles.append(Vector2(x, y))
	var graph := {"tiles": tiles, "nodes": [{"id": 0, "cell": Vector2i(0, 0)}, {"id": 1, "cell": Vector2i(1, 1)}, {"id": 2, "cell": Vector2i(3, 0)}], "start_node": 0, "goal_node": 2}
	var planner := SamplePlanner.new()
	planner.walks = [
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(2, 1), Vector2(2, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)]),
		PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(2, 1), Vector2(3, 1), Vector2(3, 0)])]
	var node_at := PackedInt32Array()
	node_at.resize(tiles.size())
	node_at.fill(-1)
	for node: Dictionary in graph.nodes: node_at[indices[node.cell]] = node.id
	var segment_ids := {}
	var raw := planner.sample_route("", 0, 0)
	var normalized := Walk.normalize(raw, tiles, indices, node_at, segment_ids)
	check(normalized.valid and normalized.erased_steps == 4, "Loop erasure missed a loop through a vertex")
	check(normalized.route.cells == planner.walks[1] and normalized.route.nodes == PackedInt32Array([0, 2]), "Erased vertex remained in route metadata")
	check(normalized.ranges == [Vector2i(0, 3)] and normalized.indices == PackedInt32Array([0, 1, 2, 3]), "Spliced segment range or tile indices are stale")
	check(not normalized.route.has("score") and not normalized.route.has("best_score"), "Untrimmed exploration scores leaked through normalization")
	check_route(graph, normalized.route)
	var same := Walk.normalize(planner.sample_route("", 0, 1), tiles, indices, node_at, segment_ids)
	check(same.route.edges == normalized.route.edges and segment_ids.size() == 1, "Equivalent physical segments have inconsistent IDs")
	var nested := {"cells": PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(2, 0), Vector2(3, 0)])}
	var nested_result := Walk.normalize(nested, tiles, indices, node_at, segment_ids)
	check(nested_result.valid and nested_result.route.length == 5, "Revisiting a previously popped cell broke nested loop erasure")
	check_route(graph, nested_result.route)
	check(not Walk.normalize({"cells": PackedVector2Array([Vector2(99, 99)])}, tiles, indices, node_at, segment_ids).valid, "Unknown physical tiles were accepted")
	var candidates := Candidates.new()
	candidates.prepare(graph)
	var profile := Troop.new()
	profile.route_selection = Troop.RouteSelection.UNIFORM
	profile.score_threshold = INF
	var weights := PackedFloat64Array([1, 1, 1, 1, 1, 1, 1, 1])
	var plan := candidates.plan_for(planner, profile, "uniform", 0, weights)
	check(plan.valid and plan.routes == 2 and plan.score == 3, "Candidates were not deduplicated and rescored after loop erasure")
	check(plan.route_probabilities == PackedFloat64Array([0.5, 0.5]), "Collapsed raw guides distorted Uniform probabilities")
	var counts := [0, 0]
	for i in 256:
		var route := candidates.allocate("uniform", i, 256)
		counts[route.route_index] += 1
		check_route(graph, route)
		check(route.score == route.length, "Scoring charged erased steps or the spawn tile")
	check(counts == [128, 128], "256 enemy quotas used unnormalized multiplicities")
	profile.score_threshold = 2
	var strict := candidates.plan_for(planner, profile, "strict", 0, weights)
	check(strict.routes == 1 and strict.score == 3, "Strict threshold used untrimmed scores or included equality")
	profile.score_threshold = INF
	profile.route_selection = Troop.RouteSelection.SOFTMAX
	profile.route_temperature = 2
	var softmax := candidates.plan_for(planner, profile, "softmax", 0, weights)
	check(is_equal_approx(softmax.route_probabilities[0], 1.0/(1.0+exp(-1.0))), "Softmax was not rebuilt from normalized scores")
	var expected := Distribution.build(PackedFloat64Array([3, 5]), 2)
	for i in 256: check(candidates.allocate("softmax", i, 256).route_index == Distribution.allocate(expected.cdf, i, 256), "Normalized Softmax quotas differ from the rebuilt CDF")
	var signed_weights := PackedFloat64Array([0, -2, -2, -2, 0, -3, -3, -3])
	var shared_segments: Dictionary = candidates._pools.values()[0].segments.duplicate(true)
	var signed_plan := candidates.plan_for(planner, profile, "signed", 0, signed_weights)
	check(signed_plan.routes == 2 and signed_plan.score == -11, "Signed raw scoring used erased tiles or shifted exploration costs")
	check(candidates._pools.values()[0].segments == shared_segments, "Guided plan mutated the shared geometry segment registry")
	for selected: Dictionary in candidates._plans.signed.routes:
		var entry: Dictionary = selected.entry
		check(entry.ranges.size() == entry.route.edges.size(), "Segment metadata count differs from normalized edges")
		for span: Vector2i in entry.ranges:
			check(span.x >= 0 and span.y < entry.indices.size() and span.x < span.y, "Segment references erased positions")
	# Real native sampling on a room network: many source walks overlap even
	# though their compressed vertex routes are simple.
	var scene := Fixture.scene_for(LoopFixture.cells(), Vector2i(0, 3), Vector2i(31, 27))
	scene.get_node("EnemyWave").auto_start = false
	root.add_child(scene)
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing or controller.plan.is_empty(): await process_frame
	var real_plan: Dictionary = controller.plan
	check(real_plan.get("loop_erased_routes", 0) > 0, "Synthetic 32x32 map did not exercise native overlapping walks")
	var all_paths := {}
	for i in real_plan.routes:
		# Select every candidate explicitly, not only a random subset.
		var route: Dictionary = controller.sample_for(controller.troop, 0, 0, i)
		check_route(controller.graph, route)
		check(not all_paths.has(route.cells), "Normalized complete candidates were not deduplicated")
		all_paths[route.cells] = true
		check(route.score == route.length, "Native normalized length and raw score differ")
	var debug: Dictionary = controller.debug_graph_for(controller.troop)
	check(debug.edges.size() == real_plan.used_edges and debug.nodes.size() == real_plan.active_nodes, "Debug summary includes erased nodes or segments")
	var normalized_count := real_plan.routes as int
	var erased_count := real_plan.loop_erased_routes as int
	scene.queue_free()
	await process_frame
	print("LOOP_ERASURE_CHECK:"+JSON.stringify({"failures": failures, "native_candidates": normalized_count, "erased_source_walks": erased_count, "metadata": true, "raw_signed_scores": true, "strict_threshold": true, "deduplication": true, "quotas_256": true}))
	quit(1 if failures else 0)

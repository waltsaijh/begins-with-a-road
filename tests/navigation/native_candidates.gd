extends SceneTree
const Walk = preload("res://tests/fixtures/candidate_walk_reference.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const LoopFixture = preload("res://tests/fixtures/route_loop_fixture.gd")
const Distribution = preload("res://scripts/navigation/routes/route_distribution.gd")
var failures := 0

func _initialize() -> void: verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func reference(planner: RefCounted, key: String, graph: Dictionary, count: int, segments: Dictionary) -> Dictionary:
	var tiles: PackedVector2Array = graph.tiles
	var indices := {}
	var node_at := PackedInt32Array()
	node_at.resize(tiles.size())
	node_at.fill(-1)
	for i in tiles.size(): indices[Vector2i(tiles[i])] = i
	for node: Dictionary in graph.nodes: node_at[indices[node.cell]] = node.id
	var entries := []
	var raw_seen := {}
	var seen := {}
	var erased_steps := 0
	var erased_routes := 0
	for index in count:
		for variant in EnemyConstants.CANDIDATE_LOCAL_SAMPLES:
			var route: Dictionary = planner.sample_route(key, variant, index)
			if route.is_empty() or raw_seen.has(route.cells): continue
			raw_seen[route.cells] = true
			var entry := Walk.normalize(route, tiles, indices, node_at, segments)
			check(entry.valid, "Reference sample failed to normalize")
			erased_steps += entry.erased_steps
			if entry.erased_steps: erased_routes += 1
			if seen.has(route.cells): continue
			seen[route.cells] = true
			route.candidate_variant = variant
			entries.append({"route": route, "indices": entry.indices, "ranges": entry.ranges})
	return {"entries": entries, "raw_samples": raw_seen.size(), "loop_erased_steps": erased_steps, "loop_erased_routes": erased_routes}

func reference_distribution(scores: PackedFloat64Array, temperature: float, selection: int) -> Dictionary:
	var best := INF
	for score in scores: best = minf(best, score)
	var weights := PackedFloat64Array()
	var total := 0.0
	for score in scores:
		var weight := 1.0 if selection == Troop.RouteSelection.UNIFORM or is_inf(temperature) else exp(-(score-best)/temperature)
		weights.append(weight)
		total += weight
	var cdf := PackedFloat64Array()
	var cumulative := 0.0
	for i in weights.size():
		cumulative += weights[i]
		weights[i] /= total
		cdf.append(cumulative/total)
	return {"probabilities": weights, "cdf": cdf}

func verify() -> void:
	var scene := Fixture.scene_for(LoopFixture.cells(), Vector2i(0, 3), Vector2i(31, 27))
	scene.get_node("EnemyWave").auto_start = false
	root.add_child(scene)
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing or controller.plan.is_empty(): await process_frame
	var planner := RoadRoutePlanner.new()
	check(planner.prepare(controller.graph).valid, "Native prepare failed")
	var expected_segments := {}
	var actual_segments := {}
	var combined := []
	var signed_weights := PackedFloat64Array()
	for i in controller.graph.tiles.size(): signed_weights.append(float(i%9-4))
	var shifted := RoadRoutePlanner.search_costs(signed_weights)
	check(shifted.valid and not shifted.neutral, "Signed exploration transform failed")
	for i in signed_weights.size(): check(shifted.costs[i] == signed_weights[i]+5, "Positive search cost differs")
	check(RoadRoutePlanner.search_costs(PackedFloat64Array([-3, -3])).neutral, "Constant signed costs should reuse neutral exploration")
	check(not RoadRoutePlanner.search_costs(PackedFloat64Array([NAN])).valid and not RoadRoutePlanner.search_costs(PackedFloat64Array([INF])).valid, "Nonfinite search scores accepted")
	var compared := 0
	for kind in ["neutral", "guided"]:
		var costs: PackedFloat64Array = PackedFloat64Array() if kind == "neutral" else shifted.costs
		var plan := planner.find_paths(kind, costs, controller.start_nodes[0], -1, INF, 1.0, 64)
		check(plan.valid and plan.reachable, "Native source failed")
		var expected := reference(planner, kind, controller.graph, plan.routes, expected_segments)
		var actual := planner.candidate_representatives(kind, EnemyConstants.CANDIDATE_LOCAL_SAMPLES, actual_segments)
		check(actual.valid and actual.entries == expected.entries, "Native candidate order, cells, nodes, segments or provenance differs from scalar reference")
		check(actual_segments == expected_segments, "Native segment registry differs from reference")
		for field in ["raw_samples", "loop_erased_steps", "loop_erased_routes"]:
			check(actual.normalization[field] == expected[field], "Native normalization diagnostic differs: "+field)
		combined.append_array(actual.entries)
		compared += actual.entries.size()
	# Include repeated entries from both sources. Rank must retain first occurrence.
	combined.append_array(combined.slice(0, mini(5, combined.size())))
	var seen := {}
	var unique := []
	var scores := PackedFloat64Array()
	var best := INF
	for entry: Dictionary in combined:
		if seen.has(entry.route.cells): continue
		seen[entry.route.cells] = true
		var score := 0.0
		for i in range(1, entry.indices.size()): score += signed_weights[entry.indices[i]]
		best = minf(best, score)
		unique.append(entry)
		scores.append(score)
	for threshold in [0.0, 1.0, 25.0, INF]:
		for selection in [Troop.RouteSelection.UNIFORM, Troop.RouteSelection.SOFTMAX]:
			var expected := []
			var accepted_scores := PackedFloat64Array()
			for i in unique.size():
				if not is_inf(threshold) and scores[i]-best >= threshold: continue
				expected.append({"entry": unique[i], "score": scores[i]})
				accepted_scores.append(scores[i])
			var ranked := RoadRoutePlanner.rank_candidates(combined, signed_weights, threshold, 4, selection)
			check(ranked.valid and ranked.routes == expected and ranked.score == best and ranked.candidate_routes == unique.size(), "Native deduplication, signed scoring or strict threshold differs")
			var distribution := reference_distribution(accepted_scores, 4, selection)
			check(ranked.distribution.cdf == distribution.cdf and ranked.distribution.probabilities == distribution.probabilities, "Native distribution differs from script reference")
			for total in [0, 1, 5, 256]:
				var indices := RoadRoutePlanner.allocate_indices(distribution.cdf, total)
				check(indices.size() == (total if not distribution.cdf.is_empty() else 0), "Native batch allocation count differs")
				for i in indices.size(): check(indices[i] == Distribution.allocate(distribution.cdf, i, total), "Native quota boundary differs")
	check(not planner.candidate_representatives("absent", 4, {}).valid and not planner.candidate_representatives("neutral", 0, {}).valid, "Invalid extraction accepted")
	check(not RoadRoutePlanner.rank_candidates(combined, PackedFloat64Array([1]), INF, 4, 0).valid, "Invalid tile indices accepted")
	for cdf in [PackedFloat64Array([0, 0.2, 1, 1]), PackedFloat64Array([0, 1, 1]), PackedFloat64Array([0.2, 0.8, 1])]:
		for total in [1, 5, 256]:
			var indices := RoadRoutePlanner.allocate_indices(cdf, total)
			for i in total: check(indices[i] == Distribution.allocate(cdf, i, total), "Batch selected a zero-mass interval or used the wrong exact boundary")
	check(not RoadRoutePlanner.rank_candidates(combined, signed_weights, NAN, 4, 0).valid, "NaN threshold accepted")
	planner.invalidate()
	check(not planner.candidate_representatives("neutral", 4, {}).valid, "Invalidated sources remained accessible")
	scene.queue_free()
	await process_frame
	print("NATIVE_CANDIDATES_CHECK:"+JSON.stringify({"failures": failures, "compared_candidates": compared, "metadata_and_order": true, "signed_scores": true, "strict_threshold": true, "cdf_and_256_quotas": true}))
	quit(1 if failures else 0)

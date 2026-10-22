extends RefCounted
const Distribution = preload("res://scripts/navigation/routes/route_distribution.gd")
## All troops rank a FINITE set of complete routes using raw tile scores.
## Geometry/local representatives are shared across troops with the same search settings.
var _pools := {}
var _plans := {}

func prepare(_graph: Dictionary) -> void:
	_pools.clear()
	_plans.clear()

func invalidate(profile_key := "") -> void:
	if profile_key.is_empty():
		_plans.clear()
	else:
		_plans.erase(profile_key)

func _pool(planner: RefCounted, profile: Troop, start: int) -> Dictionary:
	var key := "candidate:%d:%s:%d" % [start, str(profile.overlap_penalty), profile.search_budget]
	if _pools.has(key):
		return _pools[key]
	var base: Dictionary = planner.find_paths(key, PackedFloat64Array(), start, -1, INF, profile.overlap_penalty, profile.search_budget)
	if not base.get("valid", false):
		return base
	var segment_ids := {}
	var extracted := _representatives(planner, key, base, segment_ids)
	if not extracted.valid:
		return extracted
	var pool := {"valid": true, "base": base, "entries": extracted.entries, "segments": segment_ids, "normalization": extracted.normalization}
	_pools[key] = pool
	return pool

func _representatives(planner: RefCounted, key: String, _base: Dictionary, segment_ids: Dictionary) -> Dictionary:
	return planner.candidate_representatives(key, EnemyConstants.CANDIDATE_LOCAL_SAMPLES, segment_ids)

func plan_for(planner: RefCounted, profile: Troop, key: String, start: int, weights: PackedFloat64Array) -> Dictionary:
	if _plans.has(key):
		var cached: Dictionary = _plans[key].summary.duplicate(true)
		cached.cached = true
		return cached
	if is_nan(profile.score_threshold) or profile.score_threshold < 0:
		return {"valid": false, "error": "候選門檻必須非負，可使用 INF"}
	if profile.route_selection not in [Troop.RouteSelection.UNIFORM, Troop.RouteSelection.SOFTMAX]:
		return {"valid": false, "error": "未知的路線分配模式"}
	if profile.route_selection == Troop.RouteSelection.SOFTMAX and (is_nan(profile.route_temperature) or profile.route_temperature <= 0):
		return {"valid": false, "error": "路線 temperature 必須為正，可使用 INF 表示等機率"}
	var pool := _pool(planner, profile, start)
	if not pool.get("valid", false):
		return pool
	# Include positive-guided alternatives so a safe local detour can enter the
	# pool even when it is longer than the geometric shortest route.
	var search := RoadRoutePlanner.search_costs(weights)
	if not search.valid: return search
	var entries: Array = pool.entries.duplicate()
	var normalization: Dictionary = pool.normalization.duplicate()
	# The shared pool already used all-one costs; do not run the same search twice.
	if not search.neutral:
		var guided_key := "guided:"+key
		var guided: Dictionary = planner.find_paths(guided_key, search.costs, start, -1, INF, profile.overlap_penalty, profile.search_budget)
		if not guided.get("valid", false):
			return guided
		# The geometry registry is immutable. Guided-only segments live with
		# this plan, so profile edits cannot accumulate stale global segments.
		var segment_ids: Dictionary = pool.segments.duplicate()
		var extracted := _representatives(planner, guided_key, guided, segment_ids)
		if not extracted.valid:
			return extracted
		for field: String in normalization:
			normalization[field] += extracted.normalization[field]
		entries.append_array(extracted.entries)
	var ranked := RoadRoutePlanner.rank_candidates(entries, weights, profile.score_threshold, profile.route_temperature, profile.route_selection)
	if not ranked.valid: return ranked
	var accepted: Array = ranked.routes
	var summary: Dictionary = pool.base.duplicate(true)
	# Native guide unions describe untrimmed exploration, not final candidates.
	# Gameplay needs only the light summary; build final unions on explicit demand.
	for field in ["active_nodes", "used_edges", "steps", "directions"]: summary.erase(field)
	summary.score = ranked.score
	summary.routes = accepted.size()
	summary.reachable = not accepted.is_empty()
	summary.score_threshold = profile.score_threshold
	summary.candidate_routes = ranked.candidate_routes
	summary.source_node_routes = pool.base.routes
	summary.local_samples = EnemyConstants.CANDIDATE_LOCAL_SAMPLES
	summary.cached = false
	summary.merge(normalization)
	var distribution: Dictionary = ranked.distribution
	summary.route_selection = profile.route_selection
	summary.route_temperature = profile.route_temperature
	summary.route_probabilities = distribution.probabilities
	_plans[key] = {"summary": summary, "routes": accepted, "weights": weights, "cdf": distribution.cdf, "details": {}, "debug": {}}
	return summary.duplicate(true)

func debug_summary(key: String) -> Dictionary:
	if not _plans.has(key): return {}
	var plan: Dictionary = _plans[key]
	if plan.details.is_empty():
		var nodes := {}
		var edges := {}
		var directions := {}
		for candidate: Dictionary in plan.routes:
			var route: Dictionary = candidate.entry.route
			for node: int in route.nodes: nodes[node] = true
			for i in route.edges.size(): edges[route.edges[i]] = [route.nodes[i], route.edges[i], route.nodes[i+1]]
			for i in range(1, route.cells.size()):
				var a := Vector2i(route.cells[i-1])
				var b := Vector2i(route.cells[i])
				directions[Vector4i(a.x, a.y, b.x, b.y)] = true
		var steps := PackedInt32Array()
		for step: Array in edges.values(): steps.append_array(PackedInt32Array(step))
		var packed_directions := PackedVector2Array()
		for segment: Vector4i in directions:
			packed_directions.append(Vector2(segment.x, segment.y))
			packed_directions.append(Vector2(segment.z, segment.w))
		plan.details = {"active_nodes": nodes.size(), "used_edges": edges.size(), "steps": steps, "directions": packed_directions}
	var summary: Dictionary = plan.summary.duplicate(true)
	summary.merge(plan.details.duplicate(true))
	summary.cached = true
	return summary

func allocate(key: String, index: int, total: int) -> Dictionary:
	if not _plans.has(key):
		return {}
	var route_index := Distribution.allocate(_plans[key].cdf, index, total)
	return sample(key, 0, route_index) if route_index >= 0 else {}

func sample(key: String, seed: int, route_index := -1) -> Dictionary:
	if not _plans.has(key):
		return {}
	var plan: Dictionary = _plans[key]
	if plan.routes.is_empty() or route_index < -1 or route_index >= plan.routes.size():
		return {}
	var index := Distribution.sample(plan.cdf, seed) if route_index < 0 else route_index
	return _snapshot(plan, index)

## A wave owns these snapshots. Equal selections share immutable packed route
## buffers, while each member has its own dictionary and movement/stat state.
func allocate_many(key: String, total: int) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	if not _plans.has(key) or total <= 0: return routes
	var plan: Dictionary = _plans[key]
	if plan.routes.is_empty(): return routes
	var snapshots := {}
	for index: int in RoadRoutePlanner.allocate_indices(plan.cdf, total):
		if not snapshots.has(index): snapshots[index] = _snapshot(plan, index)
		routes.append(snapshots[index].duplicate())
	return routes

func _snapshot(plan: Dictionary, index: int) -> Dictionary:
	var selected: Dictionary = plan.routes[index]
	var route: Dictionary = selected.entry.route.duplicate(true)
	route.source_route_index = route.route_index
	route.route_index = index
	route.score = selected.score
	route.best_score = plan.summary.score
	route.selection_probability = plan.summary.route_probabilities[index]
	return route

func debug_graph(key: String) -> Dictionary:
	if not _plans.has(key):
		return {}
	var plan: Dictionary = _plans[key]
	if not plan.debug.is_empty():
		return plan.debug.duplicate(true)
	var nodes := {}
	var edges := {}
	for selected: Dictionary in plan.routes:
		var entry: Dictionary = selected.entry
		var route: Dictionary = entry.route
		for node: int in route.nodes:
			nodes[node] = true
		for i in route.edges.size():
			var id: int = route.edges[i]
			var span: Vector2i = entry.ranges[i]
			var score := 0.0
			if not edges.has(id):
				edges[id] = {"id": id, "from": route.nodes[i], "to": route.nodes[i+1], "cost": INF, "segments": {}}
			for j in range(span.x+1, span.y+1):
				score += plan.weights[entry.indices[j]]
				var a: Vector2i = Vector2i(route.cells[j-1])
				var b: Vector2i = Vector2i(route.cells[j])
				edges[id].segments[Vector4i(a.x, a.y, b.x, b.y)] = true
			edges[id].cost = minf(edges[id].cost, score)
	var packed_edges := []
	for edge: Dictionary in edges.values():
		var links := PackedVector2Array()
		for segment: Vector4i in edge.segments:
			links.append(Vector2(segment.x, segment.y))
			links.append(Vector2(segment.z, segment.w))
		packed_edges.append({"id": edge.id, "from": edge.from, "to": edge.to, "cost": edge.cost, "links": links})
	plan.debug = {"nodes": PackedInt32Array(nodes.keys()), "edges": packed_edges}
	return plan.debug.duplicate(true)

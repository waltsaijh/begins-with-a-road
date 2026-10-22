extends RefCounted
const Distribution = preload("res://scripts/navigation/routes/route_distribution.gd")
const Walk = preload("res://scripts/navigation/routes/candidate_walk.gd")
## All troops rank a FINITE set of complete routes using raw tile scores.
## Geometry/local representatives are shared across troops with the same search settings.
var _cell_indices := {}
var _tiles := PackedVector2Array()
var _node_at := PackedInt32Array()
var _pools := {}
var _plans := {}

func prepare(graph: Dictionary) -> void:
	_cell_indices.clear()
	_tiles = graph.tiles.duplicate()
	_node_at.resize(_tiles.size())
	_node_at.fill(-1)
	_pools.clear()
	_plans.clear()
	for i in graph.tiles.size():
		_cell_indices[Vector2i(graph.tiles[i])] = i
	for node: Dictionary in graph.nodes:
		_node_at[_cell_indices[Vector2i(node.cell)]] = node.id

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

func _representatives(planner: RefCounted, key: String, base: Dictionary, segment_ids: Dictionary) -> Dictionary:
	var entries := []
	var seen := {}
	var raw_seen := {}
	var normalization := {"normalization_us": 0, "loop_erased_routes": 0, "loop_erased_steps": 0, "raw_samples": 0}
	for route_index in base.routes:
		for variant in EnemyConstants.CANDIDATE_LOCAL_SAMPLES:
			var route: Dictionary = planner.sample_route(key, variant, route_index)
			if route.is_empty():
				continue
			# Repeated local samples need no second normalization. Deduplicate
			# distinct guides again below, after their loops have been erased.
			if raw_seen.has(route.cells): continue
			raw_seen[route.cells] = true
			var began := Time.get_ticks_usec()
			var entry := Walk.normalize(route, _tiles, _cell_indices, _node_at, segment_ids)
			normalization.normalization_us += Time.get_ticks_usec()-began
			normalization.raw_samples += 1
			if not entry.valid: return entry
			if entry.erased_steps > 0:
				normalization.loop_erased_routes += 1
				normalization.loop_erased_steps += entry.erased_steps
			if seen.has(route.cells): continue
			seen[route.cells] = true
			route.candidate_variant = variant
			entries.append({"route": route, "indices": entry.indices, "ranges": entry.ranges})
	return {"valid": true, "entries": entries, "normalization": normalization}

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
	var minimum := INF
	for value in weights:
		minimum = minf(minimum, value)
	# A common shift preserves tile preferences, including negative evaluations.
	# It changes route-length tradeoffs, so only raw sums decide the final cutoff.
	var shift := 1.0-minimum if minimum <= 0.0 else 0.0
	var guided_weights := PackedFloat64Array()
	guided_weights.resize(weights.size())
	var neutral := true
	for i in weights.size():
		var value := weights[i]+shift
		if not is_finite(value) or value <= 0:
			return {"valid": false, "error": "候選探索成本必須為正有限數值"}
		guided_weights[i] = value
		neutral = neutral and value == 1.0
	var entries: Array = pool.entries.duplicate()
	var normalization: Dictionary = pool.normalization.duplicate()
	# The shared pool already used all-one costs; do not run the same search twice.
	if not neutral:
		var guided_key := "guided:"+key
		var guided: Dictionary = planner.find_paths(guided_key, guided_weights, start, -1, INF, profile.overlap_penalty, profile.search_budget)
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
		var seen := {}
		for entry: Dictionary in entries:
			seen[entry.route.cells] = true
		for entry: Dictionary in extracted.entries:
			if not seen.has(entry.route.cells):
				seen[entry.route.cells] = true
				entries.append(entry)
	var scored := []
	var best := INF
	for entry: Dictionary in entries:
		var score := 0.0
		# Charge entering each tile, exactly as the native planner; spawn is free.
		for i in range(1, entry.indices.size()):
			score += weights[entry.indices[i]]
		if not is_finite(score):
			return {"valid": false, "error": "候選路線總評分超出有限範圍"}
		best = minf(best, score)
		scored.append({"entry": entry, "score": score})
	var accepted := []
	var nodes := {}
	var edges := {}
	var directions := {}
	for candidate: Dictionary in scored:
		if not is_inf(profile.score_threshold) and candidate.score-best >= profile.score_threshold:
			continue
		accepted.append(candidate)
		var route: Dictionary = candidate.entry.route
		for node: int in route.nodes:
			nodes[node] = true
		for i in route.edges.size():
			edges[route.edges[i]] = [route.nodes[i], route.edges[i], route.nodes[i+1]]
		for i in range(1, route.cells.size()):
			var a := Vector2i(route.cells[i-1])
			var b := Vector2i(route.cells[i])
			directions[Vector4i(a.x, a.y, b.x, b.y)] = true
	var summary: Dictionary = pool.base.duplicate(true)
	summary.score = best
	summary.routes = accepted.size()
	summary.reachable = not accepted.is_empty()
	summary.score_threshold = profile.score_threshold
	summary.candidate_routes = scored.size()
	summary.source_node_routes = pool.base.routes
	summary.local_samples = EnemyConstants.CANDIDATE_LOCAL_SAMPLES
	summary.active_nodes = nodes.size()
	summary.used_edges = edges.size()
	summary.cached = false
	summary.merge(normalization)
	var accepted_scores := PackedFloat64Array()
	for candidate: Dictionary in accepted:
		accepted_scores.append(candidate.score)
	var distribution := Distribution.build(accepted_scores, profile.route_temperature, profile.route_selection)
	summary.route_selection = profile.route_selection
	summary.route_temperature = profile.route_temperature
	summary.route_probabilities = distribution.probabilities
	var steps := PackedInt32Array()
	for step: Array in edges.values():
		steps.append_array(PackedInt32Array(step))
	summary.steps = steps
	var packed_directions := PackedVector2Array()
	for segment: Vector4i in directions:
		packed_directions.append(Vector2(segment.x, segment.y))
		packed_directions.append(Vector2(segment.z, segment.w))
	summary.directions = packed_directions
	_plans[key] = {"summary": summary, "routes": accepted, "weights": weights, "cdf": distribution.cdf, "debug": {}}
	return summary.duplicate(true)

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

extends RefCounted
const Distribution = preload("res://scripts/navigation/routes/route_distribution.gd")
## Routes judged by one tile instead of a sum; the native search finds them exactly.
var map: Node
var plans := {}

func invalidate() -> void: plans.clear()

func plan_for(profile: Troop, origin: int, effects: Array) -> Dictionary:
	var key := [profile.get_instance_id(),origin,effects]
	if plans.has(key): return plans[key].summary.duplicate(true)
	var history: RefCounted = map.route_history
	if history.current.is_empty() or origin < 0 or origin >= history.current.starts.size(): return {"valid":false,"error":"尚未建立道路歷史"}
	if not ClassDB.class_exists("RoadReducedRoutes"): return {"valid":false,"error":"請重新建置並重啟 Godot 以載入尋路擴充"}
	var cells: PackedInt32Array = history.current.cells
	var tile_scores := PackedFloat64Array()
	var by_cell := {}
	for i in range(0,cells.size(),2):
		var tile = map.tile_parameters.get_tile(Vector2i(cells[i],cells[i+1]))
		var value: float = profile.evaluation(tile) if tile != null else INF
		tile_scores.append(value)
		by_cell[Vector2(cells[i],cells[i+1])] = value
	var use_min := profile.tile_cost_reduce == Troop.TileCostReduce.MIN
	var search: RefCounted = ClassDB.instantiate("RoadReducedRoutes")
	var generated: Dictionary = search.plan(cells,history.current.ports,Vector2i(history.current.starts[origin]),history.current.goal,tile_scores,use_min)
	var routes: Array = []
	var scores := PackedFloat64Array()
	var best := INF
	for path: Dictionary in generated.paths:
		var reduced: float = by_cell[path.cells[0]]
		for cell: Vector2 in path.cells: reduced = minf(reduced,by_cell[cell]) if use_min else maxf(reduced,by_cell[cell])
		path.score = reduced
		best = minf(best,reduced)
	for path: Dictionary in generated.paths:
		if not is_inf(profile.score_threshold) and path.score-best >= profile.score_threshold: continue
		var route := path.duplicate(true)
		route.length = route.cells.size()-1
		route.best_score = best
		route.route_index = routes.size()
		route.identity = str(route.cells)
		routes.append({"entry":{"route":route}})
		scores.append(route.score)
	var distribution := Distribution.build(scores,profile.route_temperature,profile.route_selection,TrafficWeights.log_multipliers(routes,profile,effects))
	if not distribution.valid: return distribution
	var summary := {"valid":true,"reachable":not routes.is_empty(),"routes":routes.size(),"score":best if not routes.is_empty() else 0.0,"route_selection":profile.route_selection,"route_temperature":profile.route_temperature,"route_probabilities":distribution.probabilities,"distance":generated.get("distance",0),"specialized":true}
	plans[key] = {"routes":routes,"distribution":distribution,"summary":summary}
	return summary.duplicate(true)

func route_for(profile: Troop, origin: int, effects: Array, index: int, total: int, seed := -1, route_index := -1) -> Dictionary:
	var summary := plan_for(profile,origin,effects)
	if not summary.get("reachable",false): return {}
	var plan: Dictionary = plans[[profile.get_instance_id(),origin,effects]]
	var chosen := route_index
	if chosen < 0: chosen = Distribution.sample(plan.distribution.cdf,seed) if seed >= 0 else Distribution.allocate(plan.distribution.cdf,index,total)
	if chosen < 0 or chosen >= plan.routes.size(): return {}
	var route: Dictionary = plan.routes[chosen].entry.route.duplicate(true)
	route.selection_probability = plan.distribution.probabilities[chosen]
	return route

## The caller has already prepared this troop/entrance plan once for the wave.
func allocate_many(profile: Troop, origin: int, effects: Array, total: int) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	var key := [profile.get_instance_id(), origin, effects]
	if not plans.has(key) or total <= 0: return routes
	var plan: Dictionary = plans[key]
	if not plan.summary.get("reachable", false): return routes
	var snapshots := {}
	for chosen: int in RoadRoutePlanner.allocate_indices(plan.distribution.cdf, total):
		if not snapshots.has(chosen):
			var route: Dictionary = plan.routes[chosen].entry.route.duplicate(true)
			route.selection_probability = plan.distribution.probabilities[chosen]
			snapshots[chosen] = route
		routes.append(snapshots[chosen].duplicate())
	return routes

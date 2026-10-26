extends RefCounted
const Distribution = preload("res://scripts/navigation/routes/route_distribution.gd")
var history: RefCounted
var plans := {}

func invalidate() -> void: plans.clear()

func plan_for(profile: Troop, origin: int, effects: Array) -> Dictionary:
	var key := [profile.get_instance_id(),origin,effects]
	if plans.has(key): return plans[key].summary.duplicate(true)
	var generated: Dictionary = history.candidates(origin,profile.route_rule == Troop.RouteRule.SHORTEST)
	if not generated.get("valid",false): return generated
	var routes: Array = []
	var scores := PackedFloat64Array()
	for path: Dictionary in generated.paths:
		var route := path.duplicate(true)
		route.length = route.cells.size()-1
		# Hard rules use physical eligibility, never threat/damage evaluation or
		# the ordinary score cutoff. Equal scores retain the configured base mode.
		route.score = 0.0
		route.best_score = 0.0
		route.route_index = routes.size()
		route.identity = str(route.cells)
		routes.append({"entry":{"route":route}})
		scores.append(0.0)
	var distribution := Distribution.build(scores,profile.route_temperature,profile.route_selection,TrafficWeights.log_multipliers(routes,profile,effects))
	if not distribution.valid: return distribution
	var summary := {"valid":true,"reachable":not routes.is_empty(),"routes":routes.size(),"score":0.0,"route_selection":profile.route_selection,"route_temperature":profile.route_temperature,"route_probabilities":distribution.probabilities,"birth_wave":generated.get("birth_wave",0),"distance":generated.get("distance",0),"specialized":true}
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

extends RefCounted
## Scout events reuse construction geometry while preserving their alternate-road rule.
const Search = preload("res://scripts/map/tile/road_construction_search.gd")

static func propose(towers: Node3D, margin := 8, max_nodes := 12000) -> Dictionary:
	var context := Search.capture(towers.controller,margin,max_nodes)
	if context.is_empty(): return {}
	for start: Vector2i in context.terminals.slice(1):
		var route := Search.path(Search.tree(context,start),start)
		var proposed := Search.proposal(context,route)
		if proposed.is_empty() or proposed.fresh < 4 or proposed.separated < maxi(2,proposed.fresh/3): continue
		if not Search.validate(towers.controller,proposed).is_empty(): return proposed
	return {}

static func commit(towers: Node3D, proposed: Dictionary) -> bool:
	return Search.commit(towers.controller,proposed).ok

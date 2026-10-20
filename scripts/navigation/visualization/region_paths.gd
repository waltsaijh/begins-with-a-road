extends RefCounted
## Shared weighted distance fields encode all equal-cost paths.

static func directed_links(graph: Dictionary, pair: Dictionary, reverse := false) -> PackedInt32Array:
	var region: Dictionary = graph.regions[pair.region]
	var distances: PackedFloat64Array = region.route_distances
	var backwards: PackedFloat64Array = region.route_reverse_distances
	var costs: PackedFloat64Array = region.route_cell_costs
	var links: PackedInt32Array = region.route_links
	var size: int = region.cells.size()
	var source: int = (pair.target_field if reverse else pair.source_field)*size
	var target: int = (pair.source_field if reverse else pair.target_field)*size
	var score: float = pair.reverse_score if reverse else pair.score
	var result := PackedInt32Array()
	for i in range(0, links.size(), 2):
		var a := links[i]
		var b := links[i+1]
		if distances[source+a] >= 0 and backwards[target+b] >= 0 and distances[source+b] > distances[source+a] and _equal(distances[source+a]+costs[b]+backwards[target+b], score):
			result.append(a)
			result.append(b)
		elif distances[source+b] >= 0 and backwards[target+a] >= 0 and distances[source+a] > distances[source+b] and _equal(distances[source+b]+costs[a]+backwards[target+a], score):
			result.append(b)
			result.append(a)
	return result

static func _equal(a: float, b: float) -> bool:
	return absf(a-b) <= 1e-10*maxf(1.0, maxf(absf(a), absf(b)))

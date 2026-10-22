extends RefCounted
## Threshold-filtered complete routes: uniform or stable softmax weights.
## Build once; look up cumulative probability intervals in O(log routes).
static func build(scores: PackedFloat64Array, temperature: float, selection: Troop.RouteSelection = Troop.RouteSelection.SOFTMAX) -> Dictionary:
	return RoadRoutePlanner.build_distribution(scores, temperature, selection)

static func sample(cdf: PackedFloat64Array, seed: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# randf may include 1; use the greatest representable double below 1.
	var draw := minf(rng.randf(), 0.9999999999999999)
	return _index_at(cdf, draw)

## Wave-local indices 0..total-1 give deterministic quotas before shuffling.
static func allocate(cdf: PackedFloat64Array, index: int, total: int) -> int:
	if total <= 0 or index < 0 or index >= total:
		return -1
	return _index_at(cdf, float(index)/float(total))

static func _index_at(cdf: PackedFloat64Array, draw: float) -> int:
	if cdf.is_empty():
		return -1
	var low := 0
	var high := cdf.size()
	while low < high:
		var middle := (low+high)>>1
		if draw < cdf[middle]:
			high = middle
		else:
			low = middle+1
	return low

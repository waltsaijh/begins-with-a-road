extends RefCounted
## Threshold-filtered complete routes: uniform or stable softmax weights.
## Build once; look up cumulative probability intervals in O(log routes).
static func build(scores: PackedFloat64Array, temperature: float, selection: Troop.RouteSelection = Troop.RouteSelection.SOFTMAX) -> Dictionary:
	if selection not in [Troop.RouteSelection.UNIFORM, Troop.RouteSelection.SOFTMAX]:
		return {"valid": false, "error": "未知的路線分配模式"}
	if selection == Troop.RouteSelection.SOFTMAX and (is_nan(temperature) or temperature <= 0):
		return {"valid": false, "error": "路線 temperature 必須為正，可使用 INF 表示等機率"}
	var best := INF
	for score in scores:
		if not is_finite(score):
			return {"valid": false, "error": "路線評分必須為有限數值"}
		best = minf(best, score)
	var probabilities := PackedFloat64Array()
	var cdf := PackedFloat64Array()
	probabilities.resize(scores.size())
	cdf.resize(scores.size())
	var total := 0.0
	for i in scores.size():
		var weight := 1.0 if selection == Troop.RouteSelection.UNIFORM or is_inf(temperature) else exp(-(scores[i]-best)/temperature)
		probabilities[i] = weight
		total += weight
	var cumulative := 0.0
	for i in scores.size():
		# Accumulate raw weights in the same order as total, including trailing
		# zeros. This gives a final CDF of exactly one without inventing mass.
		cumulative += probabilities[i]
		probabilities[i] /= total
		cdf[i] = cumulative/total
	return {"valid": true, "probabilities": probabilities, "cdf": cdf}

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

class_name TrafficWeights
extends RefCounted
## Log products avoid overflow with many overlapping structures.
static func log_multipliers(routes: Array, profile: Troop, effects: Array) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for candidate: Dictionary in routes:
		var value := 0.0
		for effect: Dictionary in effects:
			var applies := true
			for tag: StringName in effect.tags:
				if not profile.has_tag(tag): applies = false
			for tag: StringName in effect.get("excluded_tags", []):
				if profile.has_tag(tag): applies = false
			if not applies: continue
			for cell: Vector2 in candidate.entry.route.cells:
				if effect.cells.has(Vector2i(cell)):
					var multiplier: float = effect.multiplier
					if not is_finite(multiplier) or multiplier < 0: return PackedFloat64Array([NAN])
					value += log(multiplier) if multiplier > 0 else -INF
					break
		result.append(value)
	return result

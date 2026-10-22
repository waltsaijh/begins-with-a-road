class_name RoadFlowForecast
extends RefCounted
## Counts visits to directed cell edges in allocated complete trips, never candidates.
var all := {}
var by_troop := {}
var by_origin := {}
var by_troop_origin := {}
## Exact counts after the existing scheduler has assigned entrances.
var counts_by_origin := {}

static func troop_counts(definition: WaveDefinition) -> Dictionary:
	var counts := {}
	if definition == null: return counts
	for group in definition.groups:
		if group != null and group.troop != null:
			counts[group.troop] = int(counts.get(group.troop, 0))+group.enemy_count
	return counts

static func from_pending(pending: Array) -> RoadFlowForecast:
	var result := RoadFlowForecast.new()
	for member: Dictionary in pending:
		var profile: Troop = member.profile
		var origin: int = member.start_index
		if not result.counts_by_origin.has(origin): result.counts_by_origin[origin] = {}
		result.counts_by_origin[origin][profile] = int(result.counts_by_origin[origin].get(profile,0))+1
		if not result.by_troop.has(profile):
			result.by_troop[profile] = {}
			result.by_troop_origin[profile] = {}
		if not result.by_origin.has(origin): result.by_origin[origin] = {}
		if not result.by_troop_origin[profile].has(origin): result.by_troop_origin[profile][origin] = {}
		var cells: PackedVector2Array = member.route.cells
		for i in range(1, cells.size()):
			var a := Vector2i(cells[i-1])
			var b := Vector2i(cells[i])
			# A malformed/non-road step must never draw a shortcut across the map.
			if absi(a.x-b.x)+absi(a.y-b.y) != 1: continue
			var key := Vector4i(a.x, a.y, b.x, b.y)
			for bucket: Dictionary in [result.all, result.by_troop[profile], result.by_origin[origin], result.by_troop_origin[profile][origin]]:
				bucket[key] = int(bucket.get(key, 0))+1
	return result

func segments(profile: Troop = null) -> Dictionary:
	return all if profile == null else by_troop.get(profile, {})

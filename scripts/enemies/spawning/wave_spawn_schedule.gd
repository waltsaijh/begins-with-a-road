class_name WaveSpawnSchedule
extends RefCounted
const Waypoints = preload("res://scripts/enemies/spawning/route_waypoints.gd")
## Freeze routes/stats at wave start. Shuffle assignments only within each group.
static func origins_for(group: WaveSpawnGroup, additional_starts: PackedInt32Array) -> PackedInt32Array:
	var origins := PackedInt32Array([group.start_index])
	for index in additional_starts:
		if not index in origins: origins.append(index)
	return origins

static func build(definition: WaveDefinition, controller: Node, first_id: int, shuffle_departures := true, additional_starts: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	if not definition.configuration_error().is_empty(): return {}
	# Allocate entrances by troop + authored origin across the whole wave first.
	# IDs never seed either entrance or route choice; only departures are shuffled.
	var assignments := _assigned_origins(definition,additional_starts)
	var quotas := {}
	var sources := {}
	var used := {}
	var pool_size := 0
	for group_index in definition.groups.size():
		var group := definition.groups[group_index]
		for origin in assignments[group_index]:
			var key := "%d:%d" % [group.troop.get_instance_id(), origin]
			if not quotas.has(key):
				quotas[key] = 0
				used[key] = 0
				sources[key] = {"profile": group.troop, "origin": origin}
			quotas[key] += 1
	var batches := {}
	for key: String in quotas:
		var source: Dictionary = sources[key]
		var batch: Dictionary = controller.prepare_route_batch(source.profile, quotas[key], source.origin)
		if batch.is_empty(): return {}
		batches[key] = batch.routes
		pool_size += int(batch.pool_size)
	var pending: Array[Dictionary] = []
	var offset := 0
	var map: GridMap = controller.map
	var waypoint_cache := {}
	for group_index in definition.groups.size():
		var group := definition.groups[group_index]
		var profile := group.troop
		var members: Array[Dictionary] = []
		for i in group.enemy_count:
			var origin := assignments[group_index][i]
			var key := "%d:%d" % [profile.get_instance_id(), origin]
			var allocation_index := int(used[key])
			used[key] += 1
			var route: Dictionary = batches[key][allocation_index]
			var points := Waypoints.for_route(route, map, waypoint_cache)
			members.append({"id": first_id+offset+i, "wave_index": offset+i, "route": route, "points": points,
				"profile": profile, "health": profile.max_health, "shield": profile.max_shield,
				"speed": definition.move_speed*profile.speed_multiplier, "group_index": group_index,
				"allocation_index": allocation_index, "allocation_total": int(quotas[key]), "start_index": origin})
		if shuffle_departures: members.shuffle()
		for i in members.size():
			members[i]["spawn_tick"] = group.spawn_tick(i)
			members[i]["slot"] = offset+i
			pending.append(members[i])
		offset += group.enemy_count
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.spawn_tick < b.spawn_tick if a.spawn_tick != b.spawn_tick else a.slot < b.slot)
	return {"pending": pending, "pool_size": pool_size, "waypoint_paths": waypoint_cache.size()}

## The same deterministic entrance assignment used by combat, without route queries.
static func _assigned_origins(definition: WaveDefinition, additional_starts: PackedInt32Array) -> Array[PackedInt32Array]:
	var source_totals := {}
	var source_used := {}
	for group in definition.groups:
		var key := "%d:%d" % [group.troop.get_instance_id(),group.start_index]
		source_totals[key] = int(source_totals.get(key,0))+group.enemy_count
		source_used[key] = 0
	var assignments: Array[PackedInt32Array] = []
	for group in definition.groups:
		var key := "%d:%d" % [group.troop.get_instance_id(),group.start_index]
		var origins := origins_for(group,additional_starts)
		var assigned := PackedInt32Array()
		for i in group.enemy_count:
			var fraction := (int(source_used[key])+i+0.5)/int(source_totals[key])
			assigned.append(origins[mini(origins.size()-1,floori(fraction*origins.size()))])
		source_used[key] += group.enemy_count
		assignments.append(assigned)
	return assignments

static func counts_by_origin(definition: WaveDefinition, additional_starts: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var result := {}
	if definition == null or not definition.configuration_error().is_empty(): return result
	var assignments := _assigned_origins(definition,additional_starts)
	for i in definition.groups.size():
		var profile := definition.groups[i].troop
		for origin in assignments[i]:
			if not result.has(origin): result[origin] = {}
			result[origin][profile] = int(result[origin].get(profile,0))+1
	return result

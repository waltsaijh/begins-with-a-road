extends RefCounted
## Synthetic loop/junction terrain; never changes the authored Frontier resource.
static func group(profile: Troop, count: int, origin := 0) -> WaveSpawnGroup:
	var result := WaveSpawnGroup.new()
	result.troop = profile
	result.enemy_count = count
	result.start_index = origin
	result.interval_ticks = 1
	return result

static func level() -> LevelDefinition:
	var result := LevelDefinition.new()
	result.use_terrain_endpoints = false
	result.starts = [Vector2i(0, 0), Vector2i(0, 4)]
	result.goal = Vector2i(10, 2)
	var terrain := GridMap.new()
	terrain.mesh_library = load("res://assets/models/mesh_library.tres")
	terrain.cell_size = Vector3.ONE
	terrain.cell_center_y = false
	terrain.position = Vector3(-5.5, 0, -2.5)
	for x in 9:
		for z in [0, 4]: terrain.set_cell_item(Vector3i(x, 0, z), 6)
	for x in [0, 4, 8]:
		for z in 5: terrain.set_cell_item(Vector3i(x, 0, z), 6)
	for x in range(8, 11): terrain.set_cell_item(Vector3i(x, 0, 2), 6)
	result.terrain = PackedScene.new()
	result.terrain.pack(terrain)
	terrain.free()
	var soldier := TroopCatalog.find("soldier").duplicate() as Troop
	var heavy := TroopCatalog.find("heavy").duplicate() as Troop
	var quick := TroopCatalog.find("quickfeet").duplicate() as Troop
	var wave := WaveDefinition.new()
	wave.groups = [group(soldier, 10), group(heavy, 5, 1), group(soldier, 6, 1), group(quick, 8)]
	var next := WaveDefinition.new()
	next.groups = [group(quick, 6), group(heavy, 3, 1)]
	var first_act := ActDefinition.new()
	first_act.waves = [wave, next]
	var last_act := ActDefinition.new()
	last_act.title = "ACT II"
	last_act.waves = [wave]
	result.acts = [first_act, last_act]
	return result

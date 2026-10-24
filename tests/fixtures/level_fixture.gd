extends RefCounted
## Small authored-in-memory levels, independent of designer maps and balance.
const Start = preload("res://scenes/maps/components/start_point.tscn")
const Goal = preload("res://scenes/maps/components/goal_point.tscn")

static func endpoint(map: GridMap, prefab: PackedScene, cell: Vector2i, marker_name: String, height := 0.0305) -> TerrainEndpoint:
	var marker := prefab.instantiate() as TerrainEndpoint
	marker.name = marker_name
	marker.height_offset = height
	marker.position = map.map_to_local(Vector3i(cell.x,0,cell.y))+Vector3.UP*height
	map.add_child(marker)
	marker.owner = map
	return marker

static func level(id: String, required := PackedStringArray(), vertical := false) -> LevelDefinition:
	var result := LevelDefinition.new()
	result.level_id = id
	result.required_to_complete_levels = required
	var terrain := GridMap.new()
	terrain.name = "FixtureTerrain"
	terrain.mesh_library = load("res://assets/models/mesh_library.tres")
	terrain.cell_size = Vector3.ONE
	terrain.cell_center_y = false
	for i in 8: terrain.set_cell_item(Vector3i(0,0,i) if vertical else Vector3i(i,0,0),3)
	endpoint(terrain,Start,Vector2i.ZERO,"Start")
	endpoint(terrain,Goal,Vector2i(0,7) if vertical else Vector2i(7,0),"Goal")
	result.terrain = PackedScene.new()
	result.terrain.pack(terrain)
	terrain.free()
	var group := WaveSpawnGroup.new()
	group.troop = TroopCatalog.find("soldier")
	group.enemy_count = 1
	group.interval_ticks = 0
	var wave := WaveDefinition.new()
	wave.groups = [group]
	var act := ActDefinition.new()
	act.waves = [wave]
	result.acts = [act]
	return result

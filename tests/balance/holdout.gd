extends RefCounted
## Frozen before holdout execution. Distinct unequal-loop topology, one entrance.
static func apply(level: LevelDefinition) -> void:
	var terrain := GridMap.new()
	terrain.mesh_library = load("res://assets/models/mesh_library.tres")
	terrain.cell_size = Vector3.ONE
	terrain.cell_center_y = false
	terrain.position = Vector3(-11.5,0,-2.5)
	for x in range(0,20): terrain.set_cell_item(Vector3i(x,0,0),6)
	for x in range(3,20): terrain.set_cell_item(Vector3i(x,0,4),6)
	for x in [3,19]:
		for z in 5: terrain.set_cell_item(Vector3i(x,0,z),6)
	for x in range(19,23): terrain.set_cell_item(Vector3i(x,0,2),6)
	var endpoints = preload("res://tests/fixtures/level_fixture.gd")
	endpoints.endpoint(terrain,endpoints.Start,Vector2i(0,0),"Start")
	endpoints.endpoint(terrain,endpoints.Goal,Vector2i(22,2),"Goal")
	level.terrain = PackedScene.new()
	level.terrain.pack(terrain)
	terrain.free()

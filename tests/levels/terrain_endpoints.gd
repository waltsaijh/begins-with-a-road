extends Node
const Layout = preload("res://scripts/map/terrain/terrain_layout.gd")
const Endpoint = preload("res://scripts/map/terrain/terrain_endpoint.gd")
const Start = preload("res://scenes/maps/components/start_point.tscn")
const Goal = preload("res://scenes/maps/components/goal_point.tscn")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func wait_map(scene: Node) -> void:
	for i in 120:
		if not scene.get_node("PortalMap").computing: return
		await get_tree().process_frame
	check(false, "Terrain graph never became ready")

func marker(map: GridMap, parent: Node3D, prefab: PackedScene, cell: Vector2i, marker_name: String) -> Node3D:
	var point := prefab.instantiate() as Node3D
	point.name = marker_name
	point.height_offset = 0.075
	point.position = parent.transform.affine_inverse()*(map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*point.height_offset)
	point.rotation.y = 0.37
	parent.add_child(point)
	point.owner = map
	return point

func recipe(origin: int) -> WaveDefinition:
	var definition := WaveDefinition.new()
	var group := WaveSpawnGroup.new()
	group.troop = TroopCatalog.find("soldier")
	group.enemy_count = 2
	group.interval_ticks = 0
	group.start_index = origin
	definition.groups = [group]
	return definition

func verify() -> void:
	var authored := load("res://scenes/maps/tile_map.tscn").instantiate() as GridMap
	var layout := Layout.read(authored)
	var authored_start := authored.local_to_map(authored.get_node("Endpoints/Start").position)
	var authored_goal := authored.local_to_map(authored.get_node("Endpoints/Goal").position)
	check(layout.error.is_empty() and layout.start_cells == [Vector2i(authored_start.x, authored_start.z)] and layout.goal_cell == Vector2i(authored_goal.x, authored_goal.z), "Authored tile map did not supply its endpoints")
	check(authored.get_node("Endpoints/Start/Visual") != null and authored.get_node("Endpoints/Goal/Visual") != null, "Map authoring templates lost their visible models")
	authored.free()
	var markerless := GridMap.new()
	check(Layout.read(markerless).error.contains("至少一個 Start"), "Terrain without endpoints silently accepted a fallback")
	markerless.free()
	# Use nested transforms and nonstandard grid sizes.
	var source := GridMap.new()
	source.name = "CustomTerrain"
	source.mesh_library = load("res://assets/models/mesh_library.tres")
	source.cell_size = Vector3(1.25, 0.8, 1.5)
	source.cell_center_x = true
	source.cell_center_y = false
	source.cell_center_z = true
	source.transform = Transform3D(Basis(Vector3.UP, PI/2), Vector3(8, 0.4, -6))
	for x in range(2, 7): source.set_cell_item(Vector3i(x, 0, 2), 3)
	for z in range(3, 7): source.set_cell_item(Vector3i(6, 0, z), 3)
	var group := Node3D.new()
	group.name = "Endpoints"
	group.transform = Transform3D(Basis(Vector3.UP, -PI/2), Vector3(1.25, 0, 0))
	source.add_child(group)
	group.owner = source
	var first := marker(source, group, Start, Vector2i(2, 2), "WestEntry")
	var second := marker(source, group, Start, Vector2i(4, 2), "InnerEntry")
	var goal := marker(source, group, Goal, Vector2i(6, 6), "Exit")
	first.get_node("Visual").scale = Vector3(0.8, 0.9, 0.7)
	source.set_editable_instance(first, true)
	layout = Layout.read(source)
	check(layout.error.is_empty() and layout.start_cells == [Vector2i(2, 2), Vector2i(4, 2)] and layout.goal_cell == Vector2i(6, 6), "Nested/transformed endpoints were not resolved in map coordinates")
	var invalid := second.transform
	second.transform = first.transform
	check(Layout.read(source).error.contains("重疊"), "Overlapping endpoints accepted")
	second.transform = invalid
	goal.position += Vector3(100, 0, 0)
	check(not Layout.read(source).error.is_empty(), "Endpoint over empty space accepted")
	goal.position -= Vector3(100, 0, 0)
	var duplicate_goal := marker(source, group, Goal, Vector2i(5, 2), "ExtraGoal")
	check(not Layout.read(source).error.is_empty(), "Multiple goals accepted")
	duplicate_goal.free()
	goal.role = Endpoint.Role.START
	check(not Layout.read(source).error.is_empty(), "Terrain without a Goal was accepted")
	goal.role = Endpoint.Role.GOAL
	first.role = Endpoint.Role.GOAL
	second.role = Endpoint.Role.GOAL
	check(not Layout.read(source).error.is_empty(), "Terrain without a Start was accepted")
	first.role = Endpoint.Role.START
	second.role = Endpoint.Role.START
	source.set_cell_item(Vector3i(6, 0, 4), -1)
	check(Layout.read(source).error.contains("無法"), "Disconnected entry accepted")
	source.set_cell_item(Vector3i(6, 0, 4), 3)
	var packed := PackedScene.new()
	check(packed.pack(source) == OK, "Scene fixture did not serialize")
	check(ResourceSaver.save(packed, "res://.godot/terrain_endpoint_roundtrip.tscn") == OK, "Terrain scene could not be saved")
	var level := LevelDefinition.new()
	level.terrain = load("res://.godot/terrain_endpoint_roundtrip.tscn")
	var act := ActDefinition.new()
	act.waves = [recipe(1)]
	level.acts = [act]
	check(level.configuration_error().is_empty(), "Wave validation did not use the scene entrance count")
	var scene := load("res://scenes/level.tscn").instantiate() as Node3D
	scene.level = level
	add_child(scene)
	await wait_map(scene)
	scene.set_process(false)
	var controller: Node = scene.get_node("PortalMap")
	var wave: Node = scene.get_node("EnemyWave")
	wave.set_process(false)
	scene.get_node("TowerMap").combat.enabled = false
	check(scene._valid and controller.start_nodes.size() == 2 and controller.graph.get("valid", false), "Scene endpoints were not loaded into the protected road graph")
	check(controller.terminal_cells() == [Vector2i(6, 6), Vector2i(2, 2), Vector2i(4, 2)], "Gameplay did not use the authored endpoints")
	var runtime_first: Node3D = scene.get_node("Start")
	var expected: Transform3D = source.transform*layout.starts[0].transform
	check(runtime_first.transform.is_equal_approx(expected), "Authored endpoint transform was lost while loading")
	check(runtime_first.get_node("Visual").scale.is_equal_approx(Vector3(0.8, 0.9, 0.7)), "Endpoint model override was lost while loading")
	check(scene.get_node("LevelHUD").start_marker == runtime_first, "Start Now callout did not follow the authored first entrance")
	check(not scene.get_node("TileMap/Endpoints").is_visible_in_tree() and runtime_first.is_visible_in_tree(), "Gameplay renders duplicate endpoint models")
	check(wave.start_wave(), "Authored scene route could not launch a wave")
	for entry: Dictionary in wave._pending:
		check(entry.route.cells[0] == Vector2(4, 2) and entry.route.cells[-1] == Vector2(6, 6), "Enemy route ignored scene-placed entrance/goal")
	scene.queue_free()
	await get_tree().process_frame
	# Manual snap also tests the same transformation math used by the editor tool.
	add_child(source)
	first.position += Vector3(0.19, 1.0, 0.17)
	first.snap()
	check(source.local_to_map(source.to_local(first.global_position)) == Vector3i(2, 0, 2), "Endpoint did not snap to the expected ground cell")
	check(first._get_configuration_warnings().is_empty(), "Valid endpoint reports an authoring warning")
	first.position += Vector3(100, 0, 0)
	check(not first._get_configuration_warnings().is_empty(), "Empty-space authoring did not report a warning")
	source.queue_free()
	await get_tree().process_frame
	var editor := load("res://addons/wave_editor/wave_editor.tscn").instantiate() as Control
	add_child(editor)
	editor.edit_level(level)
	check(editor.get_node("%EntrancePicker").item_count == 2 and editor.get_node("%EntrancePicker").get_item_text(1).contains("(4, 2)"), "Wave editor did not list the scene-authored entrances")
	# Editing the terrain is the only way to change the level's endpoints.
	var single := level.terrain.instantiate() as GridMap
	single.get_node("Endpoints/InnerEntry").free()
	level.terrain = PackedScene.new()
	level.terrain.pack(single)
	single.free()
	act.waves[0].groups[0].start_index = 0
	check(level.configuration_error().is_empty() and level.endpoint_layout().starts.size()==1, "Edited terrain did not replace the level endpoints")
	editor._refresh()
	check(editor.get_node("%EntrancePicker").item_count == 1 and editor.is_dirty(level), "Wave editor did not refresh or track terrain changes")
	editor.queue_free()
	await get_tree().process_frame
	print("TERRAIN_ENDPOINTS_CHECK:"+JSON.stringify({"failures": failures, "scene_placement": true, "nested_transforms": true, "two_starts": true, "visible_models": true, "model_overrides": true, "save_reload": true, "actual_routes": true, "snap": true, "validation": true, "endpoints_required": true}))
	get_tree().quit(1 if failures else 0)

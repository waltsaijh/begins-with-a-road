extends Node
const TestCards = preload("res://tests/fixtures/card_fixture.gd")
## Stable incremental art selection and visual transitions, independent of routing.

const Layout = preload("res://scripts/map/tile/appearance/tile_appearance_layout.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func verify() -> void:
	var roads: Array[Vector3i] = []
	var straight := {}
	var entrances := {}
	for x in 65:
		roads.append(Vector3i(x, 0, 0))
		straight[Vector3i(x, 0, 0)] = true
	for x in range(0, 65, 4):
		entrances[Vector3i(x, 0, 0)] = true
	var terminals: Array[Vector3i] = [Vector3i.ZERO, Vector3i(64, 0, 0)]
	var first := Layout.select(roads, straight, entrances, terminals)
	roads.append(Vector3i(65, 0, 0))
	straight[Vector3i(65, 0, 0)] = true
	var next := Layout.select(roads, straight, entrances, terminals, first)
	check(next.pillars == first.pillars and next.wood == first.wood, "Adding a candidate relocated valid appearances")
	var invalid_bridge: Vector3i = first.wood[0]
	straight.erase(invalid_bridge)
	next = Layout.select(roads, straight, entrances, terminals, first)
	check(not next.wood.has(invalid_bridge), "Invalid bridge was retained")
	for cell: Vector3i in first.wood:
		check(cell == invalid_bridge or next.wood.has(cell), "Repairing one bridge removed another valid bridge")
	check(next.wood.size() == first.wood.size(), "Repair failed to fill the vacant bridge quota")
	var invalid_pillar: Vector3i = first.pillars[2]
	entrances.erase(invalid_pillar)
	next = Layout.select(roads, straight, entrances, terminals, first)
	check(not next.pillars.has(invalid_pillar), "Non-entrance support was retained")
	for cell: Vector3i in first.pillars:
		check(cell == invalid_pillar or next.pillars.has(cell), "Repairing one pillar removed another valid pillar")
	# Cross a quota boundary; old valid bridges keep their slots before filling.
	for x in range(66, 80):
		roads.append(Vector3i(x, 0, 0))
		straight[Vector3i(x, 0, 0)] = true
	next = Layout.select(roads, straight, entrances, terminals, next)
	check(next.wood.size() == 5 and next.wood_target == 5, "Growing map did not fill only the new quota")
	# Actual scene pipeline. Layout-only refreshes must leave settled tiles alone.
	var scene: Node = load("res://scenes/9x9.tscn").instantiate()
	scene.get_node("EnemyWave").auto_start = false
	get_tree().root.add_child(scene)
	for i in 5:
		await get_tree().process_frame
	var map: GridMap = scene.get_node("TileMap")
	var art: Node = scene.get_node("TileAppearance")
	var visual: Node3D = scene.get_node("TileVisuals")
	var placement: Node = scene.get_node("TilePlacement")
	var controller: Node = scene.get_node("PortalMap")
	check(visual.jobs.is_empty() and not visual.is_processing(), "Initial map should be settled")
	check(not map.visible and visual.static_tiles.get_used_cells().size() == map.get_used_cells().size(), "Display grid must mirror the hidden authority")
	var retained: Dictionary = art.layout.variants.duplicate()
	var revision: int = controller.revision
	var planner_id: int = controller.planner.get_instance_id()
	var added := Vector3i(100, 0, 100)
	check(placement.place_cell(added), "New isolated tile failed")
	art.refresh()
	visual.sync()
	for cell: Vector3i in retained:
		check(art.layout.variants.get(cell) == retained[cell], "Unrelated edit changed a valid existing variant")
	check(controller.revision == revision and controller.planner.get_instance_id() == planner_id, "Animation triggered navigation rebuild")
	check(visual.jobs.size() == 1 and visual.jobs.has(added), "Only the new tile should animate")
	check(map.get_cell_item(added) == 3 and visual.static_tiles.get_cell_item(added) == -1, "Animation masked logical data instead of only rendering")
	check(is_equal_approx(visual.duration, TileAppearanceConstants.ANIMATION_DURATION), "Animation duration must use the shared default")
	check(is_equal_approx(visual.rise_depth, TileAppearanceConstants.RISE_DEPTH), "Animation depth must use the shared default")
	check(is_equal_approx(visual.jobs[added].model.position.y, -visual.rise_depth), "New tile must start at the configured depth")
	var snapshot := Snapshot.capture(map)
	visual._process(visual.duration * 0.25)
	var age: float = visual.jobs[added].age
	var old_body: Node3D = visual.jobs[added].body
	check(placement.place_cell(added + Vector3i.RIGHT), "Rapid adjacent edit failed")
	art.refresh()
	visual.sync()
	check(is_equal_approx(visual.jobs[added].age, age) and visual.jobs[added].target.x == 4, "Rapid shape edit restarted the rise or retained stale geometry")
	check(old_body.get_parent() == null, "Replaced model remained in the scene")
	var before_rise: float = visual.jobs[added].model.position.y
	visual._process(visual.duration * 0.43)
	check(visual.jobs[added].model.position.y <= 0.0 and visual.jobs[added].model.position.y > before_rise, "Tile must rise toward its target")
	visual.finish()
	check(visual.jobs.is_empty() and not visual.is_processing() and visual.static_tiles.get_cell_item(added) == 4, "Settling did not return tiles to the batched grid")
	# Find a normal straight tile for independently checking the transformation.
	var cell := Vector3i.ZERO
	for candidate in map.get_used_cells():
		if map.get_cell_item(candidate) == 1:
			cell = candidate
			break
	var orientation := map.get_cell_item_orientation(cell)
	snapshot = Snapshot.capture(map)
	for item in [TileConstants.item_for(1, TileConstants.Appearance.PILLAR), 1, TileConstants.WOOD_STRAIGHT, TileConstants.item_for(1, TileConstants.Appearance.PILLAR), TileConstants.WOOD_STRAIGHT, 1]:
		var old_item := map.get_cell_item(cell)
		map.set_cell_item(cell, item, orientation)
		visual.sync()
		check(visual.jobs.has(cell), "Replacement did not start")
		check(visual.static_tiles.get_cell_item(cell) == -1, "Old static model was not removed")
		var pillar_transition := TileConstants.appearance_of(old_item) == TileConstants.Appearance.PILLAR or TileConstants.appearance_of(item) == TileConstants.Appearance.PILLAR
		if pillar_transition:
			var fixed_top: bool = item != TileConstants.WOOD_STRAIGHT
			check(visual.jobs[cell].fixed_top == fixed_top and is_equal_approx(visual.jobs[cell].model.position.y, 0.0 if fixed_top else -visual.rise_depth), "Pillar conversion must hold the stone top; replacement wood must rise")
			check(visual.jobs[cell].support_material.get_shader_parameter("support_growth") == (0.0 if TileConstants.appearance_of(item) == TileConstants.Appearance.PILLAR else 1.0), "Pillar transition has incorrect initial support")
		else:
			check(visual.jobs[cell].body.get_child_count() == 1 and visual.jobs[cell].model.mesh == map.mesh_library.get_item_mesh(item), "Ordinary replacement must show only the new model")
			check(is_equal_approx(visual.jobs[cell].model.position.y, -visual.rise_depth), "Replacement must rise from the configured depth")
		visual._process(visual.duration * 0.5)
		if pillar_transition:
			check(is_equal_approx(visual.jobs[cell].support_material.get_shader_parameter("support_growth"), 0.5) and is_equal_approx(visual.jobs[cell].model.position.y, -visual.rise_depth / 8.0 if item == TileConstants.WOOD_STRAIGHT else 0.0), "Pillar must extend/retract independently of the new surface")
		else:
			check(is_equal_approx(visual.jobs[cell].model.position.y, -visual.rise_depth / 8.0), "Rise progress is incorrect")
		visual._process(visual.duration * 0.51)
		check(not visual.jobs.has(cell) and visual.static_tiles.get_cell_item(cell) == item, "Replacement failed to settle within its configured duration")
	check(Snapshot.capture(map) == snapshot, "Visual transitions changed navigation ports")
	check(visual.static_tiles.get_cell_item(cell) == 1 and visual.get_child_count() == 1, "Temporary model leak after settling")
	scene.queue_free()
	await get_tree().process_frame
	await verify_tower_rise()
	print("TILE_ANIMATION_CHECK: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	if not OS.has_feature("web"):
		get_tree().quit(0 if failures == 0 else 1)

func verify_tower_rise() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.get_node("EnemyWave").auto_start = false
	get_tree().root.add_child(scene)
	for i in 5: await get_tree().process_frame
	var visual: Node3D = scene.get_node("TileVisuals")
	var towers: Node3D = scene.get_node("TowerMap")
	var controller: Node = scene.get_node("PortalMap")
	var placement: Node = scene.get_node("TilePlacement")
	var card: BuildCard = TestCards.card("bridge")
	var cell := Vector3i(100, 0, 100)
	var tower: DefenseTower = towers.place_card(card, cell)
	check(tower != null, "New-ground tower placement failed")
	if tower == null:
		scene.queue_free()
		return
	var model: Node3D = tower.get_node("Visual")
	var logical_pose := tower.global_transform
	check(is_equal_approx(model.position.y, -visual.rise_depth), "New tower flashed at its final height before the ground rose")
	visual.set_process(false)
	while controller.computing: await get_tree().process_frame
	visual.sync()
	visual.set_process(false)
	check(visual.jobs.has(cell), "New tower ground has no rise transition")
	visual._process(visual.duration*0.4)
	check(is_equal_approx(model.position.y, visual.jobs[cell].model.position.y), "Tower and ground used different rise progress")
	check(tower.global_transform == logical_pose and towers.occupied.has(tower.grid_cell), "Visual rise moved the tower's logical position or occupancy")
	var age: float = visual.jobs[cell].age
	check(placement.place_cell(cell+Vector3i.RIGHT), "Adjacent edit during tower rise failed")
	scene.get_node("TileAppearance").refresh()
	visual.sync()
	check(is_equal_approx(visual.jobs[cell].age, age) and is_equal_approx(model.position.y, visual.jobs[cell].model.position.y), "Replacing ground geometry detached or restarted the rising tower")
	visual._process(visual.duration)
	check(model.position == Vector3.ZERO and visual._riders.is_empty(), "Completed rise left a tower offset or retained attachment")
	var settled: DefenseTower = towers.place_tower(cell+Vector3i.FORWARD)
	check(settled != null and settled.get_node("Visual").position == Vector3.ZERO, "Tower placed on existing ground should remain settled")
	while controller.computing: await get_tree().process_frame
	visual.finish()
	visual.animate = false
	var instant: DefenseTower = towers.place_card(card, Vector3i(110, 0, 110))
	check(instant != null and instant.get_node("Visual").position == Vector3.ZERO and visual._riders.is_empty(), "Disabling tile animation still lowered a new tower")
	scene.queue_free()
	await get_tree().process_frame

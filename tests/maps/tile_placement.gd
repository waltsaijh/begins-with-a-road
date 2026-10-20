extends SceneTree
## godot --headless --path . --script tests/maps/tile_placement.gd

const Placement = preload("res://scripts/map/tile/tile_placement.gd")

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.get_node("EnemyWave").auto_start = false
	root.add_child(scene)
	await process_frame
	var map: GridMap = scene.get_node("TileMap")
	var placement = scene.get_node("TilePlacement")
	var camera = scene.get_node("Camera3D")
	assert(map.get_used_cells().size() == 24)
	assert(not placement.place_cell(Vector3i.ZERO))
	assert(not placement.place_cell(Vector3i(23, 0, 0)))
	assert(map.mesh_library.get_item_list().size() == TileConstants.ITEM_COUNT)
	# Derive the rendered ports using the actual GridMap orientation.
	for mask in 16:
		var center := Vector3i(-100 + mask * 5, 0, 10)
		assert(placement.place_cell(center))
		for i in 4:
			if mask & (1 << i):
				assert(placement.place_cell(center + TileConstants.DIRECTIONS[i]))
		assert(placement.neighbor_mask(center) == mask)
		var item := map.get_cell_item(center)
		var basis := map.get_cell_item_basis(center)
		var rendered := 0
		for i in 4:
			if TileConstants.BASE_MASKS[item] & (1 << i):
				var port := Vector3i((basis * Vector3(TileConstants.DIRECTIONS[i])).round())
				rendered |= 1 << TileConstants.DIRECTIONS.find(port)
		assert(rendered == mask, "Rendered road ports must match all 16 neighbor combinations")
		for i in 4:
			if mask & (1 << i):
				assert(map.get_cell_item(center + TileConstants.DIRECTIONS[i]) == 4)
	# Adding to the bridge refreshes the old straight into a tee, then a cross.
	assert(placement.place_cell(Vector3i(8, 0, -1)))
	assert(map.get_cell_item(Vector3i(8, 0, 0)) == 5)
	assert(placement.place_cell(Vector3i(8, 0, 1)))
	assert(map.get_cell_item(Vector3i(8, 0, 0)) == 6)
	var isolated := Vector3i(-4, 0, -5)
	assert(placement.place_cell(isolated))
	assert(placement.place_cell(isolated + Vector3i(1, 0, 1)))
	assert(map.get_cell_item(isolated) == 3, "Diagonal neighbors do not connect")
	var before: int = map.get_used_cells().size()
	assert(not placement.place_cell(isolated))
	assert(map.get_used_cells().size() == before)
	assert(not placement.place_cell(TileConstants.INVALID_CELL))
	assert(not placement.place_cell(Vector3i(32767, 0, 0)))
	# The screen-to-grid conversion must survive panning, zoom and negative coordinates.
	camera.focus += Vector3(1.5, 0, -1.0)
	camera.size = 12.0
	camera.update_pose()
	var target := Vector3i(5, 0, -3)
	var screen: Vector2 = camera.unproject_position(map.to_global(map.map_to_local(target)))
	assert(placement.pick_cell(screen) == target)
	assert(not placement.has_node("PlacementPreview") and not placement.is_processing_unhandled_input())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen
	Input.parse_input_event(click)
	await process_frame
	assert(map.get_cell_item(target) == GridMap.INVALID_CELL_ITEM, "Clicking empty ground must not place a free tile")
	click.pressed = false
	Input.parse_input_event(click)
	await process_frame
	var next := Vector3i(6, 0, -3)
	click.position = camera.unproject_position(map.to_global(map.map_to_local(next)))
	click.button_mask = MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	assert(map.get_cell_item(next) == GridMap.INVALID_CELL_ITEM)
	var pose: Transform3D = camera.global_transform
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(100, 60)
	camera._unhandled_input(drag)
	assert(camera.global_transform.is_equal_approx(pose))
	print("PASS: 16 connection masks, reciprocal neighbors, tee/cross updates, isolated/diagonal tiles, occupied cells, picking after pan/zoom, no free ground placement or preview.")
	scene.free()
	quit()

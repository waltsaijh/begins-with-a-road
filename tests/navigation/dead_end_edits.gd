extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")

func _ready() -> void:
	call_deferred("verify")

func _check(condition: bool, message := "dead-end edit check failed") -> void:
	if not condition:
		push_error(message)
		if not OS.has_feature("web"):
			get_tree().quit(1)

func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _scene(extra: Array[Vector2i] = []) -> Node3D:
	var cells: Array[Vector2i] = []
	for x in 9:
		cells.append(Vector2i(x, 0))
	cells.append_array(extra)
	var scene := Fixture.scene_for(cells, Vector2i.ZERO, Vector2i(8, 0))
	scene.get_node("EnemyWave").auto_start = false
	return scene

func verify() -> void:
	var scene := _scene([Vector2i(3, 1)])
	add_child(scene)
	await _frames()
	var controller: Node = scene.get_node("PortalMap")
	var placement: Node = scene.get_node("TilePlacement")
	var view: Node = scene.get_node("PortalOverlay")
	_check(controller.revision == 1 and controller.plan.routes == 1 and controller._edit_guard_ready, "initial plan missing")
	var parameters: RefCounted = controller.tile_parameters
	var manager: Node = scene.get_node("TowerMap")
	# A tower now blocks navigation: host it on an existing dead-end beside the
	# bridge, so the subsequent test still starts with nine walkable cost slots.
	_check(manager.place_tower(Vector3i(3, 0, 1)) != null)
	await _frames()
	var initial_planner: int = controller.planner.get_instance_id()
	var first_revision: int = controller.revision
	var parameter_revision: int = parameters.revision
	var original_walk: PackedVector2Array = controller.sample_route(0).cells
	for cell in [Vector3i(4, 0, 1), Vector3i(4, 0, 2), Vector3i(5, 0, 2), Vector3i(6, 0, 2)]:
		_check(placement.place_cell(cell))
		await _frames()
		_check(controller.revision == first_revision and not controller.computing, "dead end rebuilt graph")
		_check(controller.planner.get_instance_id() == initial_planner and controller.plan_for(controller.troop).cached, "dead end invalidated plan")
		_check(parameters.revision == parameter_revision and parameters.ordered.size() == 9, "cost snapshot changed")
	var deferred: Resource = parameters.get_tile(Vector2i(4, 1))
	_check(deferred != null and deferred.threat == 1.0 and deferred.num_towers_around == 1, "deferred tile lost tower values")
	deferred.terrain_id = 7
	await _frames()
	_check(controller.plan_for(controller.troop).cached and parameters.revision == parameter_revision, "deferred data edit recalculated routes")
	view._toggle(1)
	await _frames()
	view._inspect_cell(Vector3i(4, 0, 1))
	_check(view._tooltip.visible and "terrain_id 7" in view._tooltip.text and view.parameters_mesh.mesh != null, "F2 omitted deferred tile")
	_check(placement.place_cell(Vector3i(6, 0, 1))) # Second route attachment.
	_check(controller.computing)
	await _frames()
	_check(controller.revision == first_revision+1 and controller.plan.routes >= 2, "reconnection did not rebuild")
	_check(parameters.get_tile(Vector2i(4, 1)) == deferred and deferred.terrain_id == 7, "rebuild replaced deferred record")
	_check(controller.graph.stats.tiles == 14 and parameters.ordered.size() == 14, "pending tiles missing in rebuilt graph")
	_check(original_walk.size() == 9)
	scene.queue_free()
	await _frames()
	# An initially present spur cycle must also stay deferred when extended.
	scene = _scene([Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4), Vector2i(3, 4)])
	add_child(scene)
	await _frames()
	controller = scene.get_node("PortalMap")
	placement = scene.get_node("TilePlacement")
	var cycle_revision: int = controller.revision
	for cell in [Vector3i(5, 0, 4), Vector3i(5, 0, 3), Vector3i(5, 0, 2)]:
		_check(placement.place_cell(cell))
		await _frames()
		_check(controller.revision == cycle_revision, "single-attachment loop rebuilt")
	_check(placement.place_cell(Vector3i(5, 0, 1)))
	await _frames()
	_check(controller.revision == cycle_revision+1, "spur reconnection skipped")
	scene.queue_free()
	await _frames()
	# Disconnected island; first contact is still one attachment, not a route.
	scene = _scene()
	add_child(scene)
	await _frames()
	controller = scene.get_node("PortalMap")
	placement = scene.get_node("TilePlacement")
	var island_revision: int = controller.revision
	for cell in [Vector3i(3, 0, 4), Vector3i(4, 0, 4), Vector3i(3, 0, 3), Vector3i(3, 0, 2), Vector3i(3, 0, 1)]:
		_check(placement.place_cell(cell))
		await _frames()
		_check(controller.revision == island_revision, "island/first attachment rebuilt")
	# Same-frame completion queues one rebuild capturing every edit.
	for cell in [Vector3i(5, 0, 4), Vector3i(5, 0, 3), Vector3i(5, 0, 2), Vector3i(5, 0, 1), Vector3i(6, 0, 4)]:
		_check(placement.place_cell(cell))
	await _frames()
	_check(controller.revision == island_revision+1 and controller.graph.stats.tiles == 19, "edit batching failed")
	scene.queue_free()
	await _frames()
	print("DEAD_END_CHECK:"+JSON.stringify({"initial_build": true, "dead_end_skipped": true, "cached_plan_kept": true, "reconnection_rebuilds": true, "spur_cycles_skipped": true, "islands_skipped": true, "deferred_parameters": true, "f2_deferred_tiles": true, "same_frame_batch": true}))
	if not OS.has_feature("web"):
		get_tree().quit()

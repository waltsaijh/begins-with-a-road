extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Profile = preload("res://scripts/enemies/troops/troop.gd")
const Record = preload("res://scripts/map/tile/tile_parameters.gd")
var _notifications := 0

class ThreatProfile extends Profile:
	func evaluation(tile: Record) -> float:
		return 1.0+tile.threat+tile.num_towers_around

func _ready() -> void:
	call_deferred("verify")

func verify() -> void:
	var cells: Array[Vector2i] = []
	for y in 9:
		for x in 9:
			cells.append(Vector2i(x, y))
	var scene := Fixture.scene_for(cells, Vector2i.ZERO, Vector2i(8, 8))
	var template: DefenseTower = load("res://scenes/towers/sentry.tscn").instantiate()
	template.definition = template.definition.duplicate(true)
	template.definition.attack_area = null
	var circular_scene := PackedScene.new()
	circular_scene.pack(template)
	template.free()
	scene.get_node("TowerMap").tower_scene = circular_scene
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing or controller.plan.is_empty():
		await get_tree().process_frame
	var manager: Node = scene.get_node("TowerMap")
	var records: RefCounted = controller.tile_parameters
	var profile := ThreatProfile.new()
	_check(records.evaluate(profile).valid and records.evaluate(profile).cached)
	var graph_revision: int = controller.revision
	var cells_before: int = controller.map.get_used_cells().size()
	records.costs_changed.connect(func(_id: int): _notifications += 1)
	var first: Node3D = manager.place_tower(Vector3i(4, 0, 4))
	_check(first != null and first.attack_radius == 3.0 and first.threat == 1.0)
	_check(_notifications == 1 and not records.evaluate(profile).cached)
	_check(records.get_tile(Vector2i(4, 4)).num_towers_around == 0) # exclude self
	var covered := 0
	var nearby := 0
	for tile: Resource in records.ordered:
		var delta: Vector2i = tile.cell-Vector2i(4, 4)
		var expected := 1.0 if delta.length_squared() <= 9 else 0.0
		_check(tile.threat == expected)
		_check(tile.num_towers_around == int(absi(delta.x) <= 1 and absi(delta.y) <= 1 and delta != Vector2i.ZERO))
		covered += int(tile.threat)
		nearby += tile.num_towers_around
	_check(covered == 29 and nearby == 8)
	_check(not manager.place_tower(Vector3i(4, 0, 4)))
	_check(not manager.place_tower(Vector3i.ZERO) and not manager.place_tower(Vector3i(8, 0, 8)))
	_check(not manager.place_tower(Vector3i(99, 0, 99)))
	_check(not manager.place_tower(Vector3i(2147483647, 0, 0)))
	_check(_notifications == 1)
	var second: Node3D = manager.place_tower(Vector3i(5, 0, 4))
	_check(second != null and _notifications == 2)
	_check(records.get_tile(Vector2i(4, 4)).num_towers_around == 1)
	_check(records.get_tile(Vector2i(5, 4)).num_towers_around == 1)
	_check(records.get_tile(Vector2i(3, 3)).num_towers_around == 1)
	_check(records.get_tile(Vector2i(7, 4)).threat == 2.0) # distance 3 is included
	_check(records.get_tile(Vector2i(7, 5)).threat == 1.0) # sqrt(10) is excluded
	_check(records.get_tile(Vector2i(7, 7)).threat == 0.0)
	second.threat = 2.5
	_check(_notifications == 3 and records.get_tile(Vector2i(4, 4)).threat == 3.5)
	second.attack_radius = 0.0
	_check(_notifications == 4)
	_check(records.get_tile(Vector2i(4, 4)).threat == 1.0 and records.get_tile(Vector2i(4, 4)).num_towers_around == 1)
	_check(records.get_tile(Vector2i(5, 4)).threat == 3.5)
	_check(manager.remove_tower(Vector3i(5, 0, 4)))
	_check(_notifications == 5 and records.get_tile(Vector2i(4, 4)).num_towers_around == 0)
	_check(not manager.remove_tower(Vector3i(5, 0, 4)))
	_check(manager.remove_tower(Vector3i(4, 0, 4)) and _notifications == 6)
	_check(controller.revision > graph_revision and controller.map.get_used_cells().size() == cells_before)
	for tile: Resource in records.ordered:
		_check(tile.threat == 0.0 and tile.num_towers_around == 0)
	# Coverage on currently empty cells must survive a later road rebuild.
	var edge: Node3D = manager.place_tower(Vector3i(8, 0, 4))
	_check(edge != null)
	_check(scene.get_node("TilePlacement").place_cell(Vector3i(9, 0, 4)))
	await get_tree().process_frame
	var added: Resource = records.get_tile(Vector2i(9, 4))
	_check(added != null and added.threat == 1.0 and added.num_towers_around == 1)
	_check(manager.remove_tower(Vector3i(8, 0, 4)))
	_check(added.threat == 0.0 and added.num_towers_around == 0)
	# Exercise the actual right-click picker after a map rebuild.
	await get_tree().process_frame
	var at := Vector3i(3, 0, 3)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = scene.get_node("Camera3D").unproject_position(controller.map.to_global(controller.map.map_to_local(at)))
	click.button_mask = MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE
	manager._unhandled_input(click)
	_check(manager.towers.is_empty())
	click.button_mask = MOUSE_BUTTON_MASK_RIGHT
	manager._unhandled_input(click)
	_check(manager.towers.has(Vector2i(3, 3)))
	manager._unhandled_input(click)
	_check(manager.towers.is_empty())
	await get_tree().process_frame
	_check(controller.plan.score == 16.0) # default evaluation remains 1
	# Only construction outside committed routes may proceed during a wave.
	var wave: Node = scene.get_node("EnemyWave")
	wave.enemy_count = 4
	wave.batch_size = 2
	wave.spawn_interval = 1.0
	wave.troop = profile
	wave.set_process(false)
	_check(wave.start_wave())
	var snapshots := []
	for data: Dictionary in wave._pending:
		snapshots.append(data.route.cells.duplicate())
	var safe := Vector3i(-1, 0, -1)
	var reserved := {}
	for path in snapshots:
		for position: Vector2 in path:
			reserved[Vector2i(position)] = true
	for position in controller.map.get_used_cells():
		if position != Vector3i.ZERO and position != Vector3i(8, 0, 8) and not reserved.has(Vector2i(position.x, position.z)):
			safe = position
			break
	_check(safe.y == 0 and manager.place_tower(safe) != null)
	var units: Array[Node3D] = []
	wave.enemy_spawned.connect(func(enemy: Node3D):
		enemy.set_process(false)
		units.append(enemy))
	wave._process(0.0)
	wave._process(1.0)
	_check(units.size() == 4)
	for i in units.size():
		_check(units[i].route.cells == snapshots[i])
		units[i]._process(10000.0)
	_check(wave.completed == 4 and not wave.active)
	await get_tree().process_frame
	while controller.computing or controller.plan.is_empty():
		await get_tree().process_frame
	var report := {"radius": 3, "default_threat": 1, "covered_tiles": covered, "neighbors": nearby, "overlap": true, "range_edit": true, "new_tile": true, "removal": true, "right_click": true, "one_notification_per_change": true, "locked_routes": true, "default_score": controller.plan.score}
	scene.queue_free()
	await get_tree().process_frame
	print("TOWER_CHECK:"+JSON.stringify(report))
	if not OS.has_feature("web"):
		get_tree().quit()

func _check(condition: bool, message := "test check failed") -> void:
	if not condition:
		push_error(message)
		if not OS.has_feature("web"):
			get_tree().quit(1)

extends Node
const Fixture = preload("res://tests/construction/fixture.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	push_error(message)

func ready_session() -> Node3D:
	var scene := Fixture.session(1)
	add_child(scene)
	for i in 4: await get_tree().process_frame
	return scene

func ports(snapshot: Dictionary) -> Dictionary:
	var result := {}
	for index in snapshot.ports.size():
		result[Vector2i(snapshot.cells[index * 2], snapshot.cells[index * 2 + 1])] = int(snapshot.ports[index])
	return result

func verify() -> void:
	var scene := await ready_session()
	var towers: Node = scene.get_node("TowerMap")
	var map: GridMap = scene.get_node("TileMap")
	var controller: Node = scene.get_node("PortalMap")
	var card := Fixture.card("pocket")
	var anchor := Vector3i(8, 0, 0)
	var before := ports(Snapshot.capture(map, towers.occupied))
	var revision: int = controller.revision
	var plan: Dictionary = towers.construction_plan([{"card": card, "anchor": anchor, "turns": 0}])
	check(plan.ok, "Complete U bypass rejected: " + plan.error)
	check(before == ports(Snapshot.capture(map, towers.occupied)) and revision == controller.revision, "Construction preview mutated topology")
	var tower: DefenseTower = towers.place_card(card, anchor)
	check(tower != null and tower.grid_cell == Vector2i(8, 0), "Compound placement did not create its declared tower")
	if plan.ok:
		check(ports(plan.snapshot) == ports(Snapshot.capture(map, towers.occupied)), "Candidate and committed compound ports differ")
	check(Snapshot.connects_terminals(Snapshot.capture(map, towers.occupied), controller.terminal_cells()), "Complete U failed to preserve a real route")
	var built_count := map.get_used_cells().size()
	var built_revision: int = controller.revision
	var unrelated_shape := Fixture.card("cross")
	var upgraded: DefenseTower = towers.place_card(unrelated_shape, anchor, 1)
	check(upgraded == tower and tower.level == 2 and tower.rotation_steps == 0, "Same tower card did not upgrade without rotating existing tower")
	check(map.get_used_cells().size() == built_count and controller.revision == built_revision, "Upgrade regenerated a different preset's roads")
	var changed_tower := Fixture.card("pocket", "crossfire")
	check(towers.place_card(changed_tower, anchor) == null and map.get_used_cells().size() == built_count, "Wrong tower kind overlapped a built tower")
	check(towers.place_card(Fixture.card("pocket"), Vector3i(3, 0, 0)) == null, "Compound footprint covered protected entrance")
	scene.queue_free()
	await get_tree().process_frame
	for turn in 4:
		scene = await ready_session()
		towers = scene.get_node("TowerMap")
		map = scene.get_node("TileMap")
		card = Fixture.card("straight")
		var offset_preset: TilePreset = card.tile_preset.duplicate(true)
		offset_preset.tower_offset = Vector2i(1, 1)
		offset_preset.occupied_offsets.erase(Vector2i.ZERO)
		offset_preset.occupied_offsets.append(Vector2i(1, 1))
		card.tile_preset = offset_preset
		anchor = Vector3i(8, 0, 7)
		plan = towers.construction_plan([{"card": card, "anchor": anchor, "turns": turn}])
		tower = towers.place_card(card, anchor, turn)
		var expected := card.tower_anchor(Vector2i(8, 7), turn)
		check(tower != null and tower.grid_cell == expected and towers.occupied.get(expected) == tower, "Rotated tower offset did not reach actual occupancy")
		if tower != null:
			var expected_position := map.to_global(map.map_to_local(Vector3i(expected.x, 0, expected.y)) + Vector3.UP * TowerConstants.GROUND_OFFSET)
			check(tower.global_position.is_equal_approx(expected_position), "Rotated tower offset did not reach actual model position")
		check(plan.ok and ports(plan.snapshot) == ports(Snapshot.capture(map, towers.occupied)), "Rotated candidate disagrees with actual ports")
		scene.queue_free()
		await get_tree().process_frame
	await _verify_ports()
	var file := FileAccess.open("res://.godot/test-results/construction/placement.json", FileAccess.WRITE)
	var report := {"checks": checks, "failures": failures, "immediate_compound": true, "rotations_and_offset": true, "port_union": true, "legacy_fallback": true}
	file.store_string(JSON.stringify(report, "\t"))
	print("CONSTRUCTION_PLACEMENT_CHECK:" + JSON.stringify(report))
	get_tree().quit(1 if failures else 0)

func _verify_ports() -> void:
	var scene := await ready_session()
	var towers: Node = scene.get_node("TowerMap")
	var map: GridMap = scene.get_node("TileMap")
	var placement: Node = scene.get_node("TilePlacement")
	var parallel := Fixture.card("straight")
	check(towers.place_card(parallel, Vector3i(8, 0, 2)) != null, "Parallel compound road could not be placed")
	var actual := ports(Snapshot.capture(map, towers.occupied))
	for x in range(5, 12):
		check(not int(actual.get(Vector2i(x, 1), 0)) & 1 and not int(actual.get(Vector2i(x, 0), 0)) & 4, "Adjacent parallel roads gained a false connecting side port")
	var join := TilePreset.new()
	join.preset_id = "construction.test_join"
	join.road_offsets = [Vector2i(-2, -2)]
	join.occupied_offsets = [Vector2i.ZERO, Vector2i(-2, -2)]
	join.explicit_road_ports = {Vector2i(-2, -2): 5}
	var join_card := BuildCard.from_parts(parallel.tower, join)
	var plan: Dictionary = towers.construction_plan([{"card": join_card, "anchor": Vector3i(10, 0, 3), "turns": 0}])
	check(towers.place_card(join_card, Vector3i(10, 0, 3)) != null, "Same-cell road interface union rejected")
	actual = ports(Snapshot.capture(map, towers.occupied))
	check(placement.port_overrides.get(Vector2i(8, 1)) == 15 and bool(int(actual.get(Vector2i(8, 1), 0)) & 1), "Same-cell interfaces did not merge EW and NS")
	check(plan.ok and ports(plan.snapshot) == actual, "Interface union preview differs from commit")
	var legacy := Fixture.card("bridge", "sentry", true)
	legacy.tile_preset.road_offsets.append(Vector2i.ZERO)
	check(towers.place_card(legacy, Vector3i(4, 0, 0)) != null, "Legacy card fallback failed on a map with explicit roads")
	actual = ports(Snapshot.capture(map, towers.occupied))
	check(not bool(int(actual.get(Vector2i(6, 1), 0)) & 1), "Legacy addition removed neighboring explicit port restrictions")
	scene.queue_free()
	await get_tree().process_frame

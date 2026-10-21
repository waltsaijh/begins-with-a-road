extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const TestCards = preload("res://tests/fixtures/card_fixture.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited
var failures := 0
var viewport: SubViewport

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func wait_map(scene: Node) -> void:
	for i in 120:
		if not scene.get_node("PortalMap").computing: return
		await frames(1)
	check(false, "Map rebuild did not complete")

func same_cells(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size(): return false
	for cell in a:
		if not cell in b: return false
	return true

func position_unit(enemy: Node3D, map: GridMap, cell: Vector2i) -> void:
	enemy.global_position = map.to_global(map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*0.025)

func verify() -> void:
	var sentry: TowerDefinition = load("res://assets/data/towers/sentry.tres")
	check(sentry.attack_area != null and sentry.attack_area.configuration_error().is_empty(), "Sentry attack area is missing or invalid")
	var expected: Array[Vector2i] = []
	for y in range(-3, 2):
		for x in range(-1, 2): expected.append(Vector2i(x, y))
	var bad := TowerAttackArea.new()
	check(not bad.configuration_error().is_empty(), "Empty authored range was silently accepted")
	var definition := sentry.duplicate(true) as TowerDefinition
	# Geometry checks use the original example independently of designer edits.
	definition.attack_area.offsets = expected.duplicate()
	var path := Artifacts.path("combat/attack_area_roundtrip.tres")
	check(ResourceSaver.save(definition.attack_area, path) == OK, "Attack area could not be saved")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as TowerAttackArea
	check(loaded != null and same_cells(loaded.cells_at(Vector2i.ZERO), expected), "Attack area lost its tiles after reloading")
	var cells: Array[Vector2i] = []
	for y in 9:
		for x in 9: cells.append(Vector2i(x, y))
	var scene := Fixture.scene_for(cells, Vector2i(0, 4), Vector2i(8, 4))
	var card := TestCards.card("corner")
	card.tower = definition
	scene.get_node("CardPlacement").cards.assign([card])
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	wave.enemy_count = 3
	wave.batch_size = 3
	viewport = TestViewport.new()
	viewport.size = Vector2i(1152, 648)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(scene)
	await wait_map(scene)
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	var towers: Node3D = scene.get_node("TowerMap")
	var combat: Node = towers.combat
	combat.set_process(false)
	var map: GridMap = scene.get_node("TileMap")
	var records: RefCounted = scene.get_node("PortalMap").tile_parameters
	var cards: Node3D = scene.get_node("CardPlacement")
	var camera: Camera3D = scene.get_node("Camera3D")
	camera.size = 12.0
	camera.update_pose()
	var anchor := Vector2i(4, 4)
	var cell := Vector3i(4, 0, 4)
	var point := camera.unproject_position(map.to_global(map.map_to_local(cell)))
	cards.select_card(0)
	for turns in 4:
		cards.turns = turns
		cards._dirty = true
		var motion := InputEventMouseMotion.new()
		motion.position = point
		viewport.push_input(motion, true)
		await frames(3)
		var covered := definition.attack_cells_at(anchor, turns)
		check(cards.preview.visible and same_cells(cards.preview.range_cells, covered), "Preview did not rotate with the actual attack area")
		check(cards.preview.attack_area.mesh != null and cards.preview.attack_area.mesh.get_surface_count() == 1, "Attack area tiles were not rendered")
		if turns == 0:
			var original_offsets: Array[Vector2i] = definition.attack_area.offsets.duplicate()
			definition.attack_area.offsets = [Vector2i(0, -2)]
			await frames(2)
			check(cards.preview.range_cells.size() == 1 and cards.preview.range_cells[0] == anchor+Vector2i(0, -2), "Editing the selected card's range did not refresh a stationary preview")
			definition.attack_area.offsets = original_offsets
			await frames(2)
			check(same_cells(cards.preview.range_cells, covered), "Restoring the selected card range left stale preview tiles")
		var stable_mesh: Mesh = cards.preview.attack_area.mesh
		await frames(2)
		check(cards.preview.attack_area.mesh == stable_mesh, "Unchanged hover rebuilt the attack preview every frame")
		if turns == 0 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(Artifacts.path("combat/attack_area_preview.png"))
		var tower: DefenseTower = towers.place_card(card, cell, turns)
		check(tower != null, "Directional tower could not be placed")
		if tower == null: continue
		check(same_cells(tower.attack_offsets(), definition.attack_cells_at(Vector2i.ZERO, turns)), "Placed tower range differs from preview")
		for tile in records.all_tiles():
			check(is_equal_approx(tile.threat, definition.threat if tile.cell in covered else 0.0), "Threat did not match the rotated attack tiles")
		check(towers.remove_tower(cell), "Directional tower could not be removed")
		for tile in records.all_tiles(): check(is_zero_approx(tile.threat), "Removing the tower left stale threat")
		await wait_map(scene)
	var tower: DefenseTower = towers.place_card(card, cell)
	check(tower != null, "Combat tower fixture failed")
	if tower == null:
		get_tree().quit(1)
		return
	tower.attack = BeamAttack.new()
	tower.damage = 10
	await wait_map(scene)
	check(wave.start_wave(), "Combat wave fixture failed")
	wave._process(0)
	var units: Array[Node3D] = wave.living_enemies()
	check(units.size() == 3, "Combat fixture did not spawn its enemies")
	if units.size() != 3:
		get_tree().quit(1)
		return
	position_unit(units[0], map, anchor+Vector2i(1, -3))
	position_unit(units[1], map, anchor+Vector2i(2, 0))
	position_unit(units[2], map, anchor+Vector2i(0, 2))
	var health := [units[0].health, units[1].health, units[2].health]
	tower.aim_at(combat.aim_position(units[0], tower.attack), 1.0)
	combat._process(0)
	check(units[0].health == health[0]-10 and units[1].health == health[1] and units[2].health == health[2], "Nearer enemies outside the shape stole the shot, or its far corner was rejected by a circle")
	tower.rotation_steps = 1
	tower.next_attack_time = 0.0
	tower.aim_at(combat.aim_position(units[1], tower.attack), 1.0)
	combat._process(1.0)
	check(units[0].health == health[0]-10 and units[1].health == health[1]-10 and units[2].health == health[2], "Rotating the tower retained stale target coverage")
	var rotated := definition.attack_cells_at(anchor, 1)
	for tile in records.all_tiles():
		check(is_equal_approx(tile.threat, definition.threat if tile.cell in rotated else 0.0), "Runtime rotation did not update threat")
	# Edited shape data updates both sparse influence and actual coverage.
	tower.rotation_steps = 0
	definition.attack_area.offsets = [Vector2i(5, 0), Vector2i(5, 0)]
	check(tower.attack_offsets().size() == 1 and tower.covers_cell(Vector2i(9, 4)) and not tower.covers_cell(anchor), "Editing/deduplicating the range did not invalidate the tower cache")
	scene.get_node("TilePlacement").place_cell(Vector3i(9, 0, 4))
	await frames(2)
	check(records.get_tile(Vector2i(9, 4)) != null and records.get_tile(Vector2i(9, 4)).threat == definition.threat, "A new road did not inherit custom sparse range influence")
	definition.attack_area = null
	tower.attack_radius = 1.0
	check(tower.attack_offsets().size() == 5 and not tower.covers_cell(Vector2i(9, 4)), "Clearing the shape did not restore circular fallback")
	towers.remove_tower(cell)
	for tile in records.all_tiles(): check(is_zero_approx(tile.threat), "Changed range left threat after removal")
	var report := {"failures": failures, "resource_roundtrip": true, "four_rotations": true, "preview_matches_combat_threat": true, "non_circular_targeting": true, "runtime_shape_edit": true, "sparse_new_road": true, "circle_fallback": true}
	FileAccess.open(Artifacts.path("combat/attack_area.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("ATTACK_AREA_CHECK:"+JSON.stringify(report))
	get_tree().quit(1 if failures else 0)

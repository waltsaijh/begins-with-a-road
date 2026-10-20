extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const TestCards = preload("res://tests/fixtures/card_fixture.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
var failures := 0
var events := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func ready_map(scene: Node) -> void:
	for i in 120:
		var controller: Node = scene.get_node("PortalMap")
		if not controller.computing and controller.plan.get("reachable", false):
			return
		await get_tree().process_frame
	check(false, "Timed out waiting for card graph")

func make_scene() -> Node3D:
	var cells: Array[Vector2i] = []
	for x in range(-3, 4):
		cells.append(Vector2i(x, 0))
	var scene := Fixture.scene_for(cells, Vector2i(-3, 0), Vector2i(3, 0))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	return scene

func ports_at(snapshot: Dictionary) -> Dictionary:
	var result := {}
	for i in snapshot.ports.size():
		result[Vector2i(snapshot.cells[2*i], snapshot.cells[2*i+1])] = int(snapshot.ports[i])
	return result

func verify_card_ui() -> void:
	var card: BuildCard = TestCards.card("bridge").duplicate()
	card.tower = card.tower.duplicate()
	var view: Button = load("res://scenes/cards/components/card_view.tscn").instantiate()
	view.card = card
	add_child(view)
	var icon: TextureRect = view.get_node("%TowerIcon")
	var frame: NinePatchRect = view.get_node("Accent")
	var diagram: Control = view.get_node("%TileDiagram")
	check(icon.texture == card.tower.icon and icon.self_modulate == card.tower.accent_color.darkened(view.icon_darkening), "Tower artwork/color not sourced from tower")
	card.tower.accent_color = Color("dd8855")
	check(icon.self_modulate == card.tower.accent_color.darkened(view.icon_darkening) and frame.self_modulate == card.tower.accent_color and diagram.accent == card.tower.accent_color, "Tower color edit did not update the whole card")
	view.icon_darkening = 0.6
	check(icon.self_modulate == card.tower.accent_color.darkened(0.6), "Icon darkness edit did not update the tint")
	var texture := ImageTexture.create_from_image(Image.create_empty(32, 32, false, Image.FORMAT_RGBA8))
	card.tower.icon = texture
	card.frame_texture = texture
	card.background_texture = texture
	check(icon.texture == texture and frame.texture == texture and view.get_node("Background").texture == texture, "Custom PNG-like textures did not replace artwork")
	card.frame_texture = null
	card.background_texture = null
	card.tower.icon = null
	check(frame.texture == view.default_frame and icon.texture == view.default_icon and view.get_node("Background").texture == view.default_background, "Default artwork fallback failed")
	view.selected = true
	view.turns = 1
	view.key_number = 3
	card.tile_preset = card.tile_preset.duplicate()
	card.tile_preset.prefix_key = "tile_preset.test_custom.prefix"
	check(view.get_node("Selection").visible and diagram.turns == 1 and view.get_node("%Shortcut").text == "3" and view.get_node("%CardTitle/Prefix").text == card.localized_prefix() and view.get_node("%CardTitle/TowerName").text == card.tower.localized_name(), "Scene UI did not track card state")
	for node: Node in view.find_children("*", "Control", true, false):
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Child UI intercepts card clicks")
	view.queue_free()
	await get_tree().process_frame

func verify_empty_hand() -> void:
	var hand: CanvasLayer = load("res://scenes/cards/card_hand.tscn").instantiate()
	add_child(hand)
	var empty: Array[BuildCard] = []
	hand.setup(empty)
	hand.set_collapsed(true)
	hand.set_collapsed(false)
	await get_tree().process_frame
	check(hand._motion == null, "Empty hand created a Tween without animation targets")
	var card: BuildCard = TestCards.card("bridge")
	hand.append_card(card)
	check(hand._motion != null and hand._entering.size() == 1, "Refilling an empty hand lost the insertion animation")
	# Consume the last card while its entry is still in flight.
	hand.remove_card(0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(hand._motion == null and hand._fresh.is_empty() and hand._entering.is_empty(), "Last-card removal left an empty Tween or stale animation state")
	hand.set_collapsed(true)
	hand.set_collapsed(false)
	get_viewport().size_changed.emit()
	await get_tree().process_frame
	check(hand._motion == null, "Folding an empty hand created an empty Tween")
	hand.append_card(card)
	hand._motion.custom_step(1.0)
	check(hand.views.size() == 1 and hand._entering.is_empty() and hand.views[0].mouse_filter == Control.MOUSE_FILTER_STOP, "Refilled hand failed to finish or restore card input")
	hand.queue_free()
	await get_tree().process_frame

func verify() -> void:
	await verify_empty_hand()
	await verify_card_ui()
	var bridge: BuildCard = TestCards.card("bridge")
	var corner: BuildCard = TestCards.card("corner")
	var scene := make_scene()
	await ready_map(scene)
	var towers: Node = scene.get_node("TowerMap")
	var controller: Node = scene.get_node("PortalMap")
	var map: GridMap = scene.get_node("TileMap")
	var placement: Node = scene.get_node("TilePlacement")
	var cards: Node = scene.get_node("CardPlacement")
	check(cards.hand.views.size() == 3, "Missing card hand")
	cards.select_card(1)
	check(not towers.input_enabled and not placement.is_processing_unhandled_input(), "Card selection did not claim construction input")
	cards.rotate_card(5)
	check(cards.turns == 1, "Rotation must wrap")
	cards.select_card(-1)
	check(towers.input_enabled and not cards.preview.visible and not placement.is_processing_unhandled_input(), "Cancel restored standalone ground placement")
	var before := map.get_used_cells().size()
	var revision: int = controller.revision
	check(not towers.validate_card(corner, Vector3i.ZERO).is_empty(), "A card that seals the bridge was accepted")
	check(towers.place_card(corner, Vector3i.ZERO) == null, "Invalid card committed")
	check(map.get_used_cells().size() == before and towers.towers.is_empty() and controller.revision == revision, "Rejected card partially mutated world")
	check(towers.place_card(bridge, Vector3i(-3, 0, 0)) == null, "Card covered spawn")
	var broken := BuildCard.new()
	check(towers.place_card(broken, Vector3i.ZERO) == null, "Invalid resource accepted")
	cards.cards.append(null)
	cards.select_card(3)
	check(cards.selected == -1, "Null card should not claim input")
	cards.cards[3] = broken
	cards.select_card(3)
	cards._process(0.3)
	check(not cards.preview.visible, "Incomplete card tried to draw invalid geometry")
	cards.select_card(-1)
	cards.cards.remove_at(3)
	check(towers.place_card(bridge, TileConstants.INVALID_CELL) == null, "Invalid anchor accepted")
	check(towers.place_card(bridge, Vector3i(32766, 0, 0)) == null, "Out-of-bounds offset accepted")
	check(towers.validate_card(bridge, Vector3i.ZERO).is_empty(), "New roads should allow a bypass before the tower is committed")
	var additions := {}
	for cell in bridge.ground_cells(Vector2i.ZERO):
		additions[cell] = true
	var predicted := ports_at(Snapshot.capture(map, {Vector2i.ZERO: true}, additions))
	check(map.get_used_cells().size() == before and controller.revision == revision, "Preview mutated the map")
	placement.cell_placed.connect(func(_cell: Vector3i):
		events += 1
		check(towers.occupied.has(Vector2i.ZERO) and map.get_used_cells().size() == before+3, "Observers saw an incomplete card transaction"))
	var record: Resource = controller.tile_parameters.get_tile(Vector2i(-1, 0))
	record.terrain_id = 81
	var tower: DefenseTower = towers.place_card(bridge, Vector3i.ZERO)
	check(tower != null and events == 3, "Card must add exactly three road tiles and one tower")
	check(controller.revision == revision+1, "Card must rebuild navigation once, not once per tile")
	check(predicted == ports_at(Snapshot.capture(map, towers.occupied)), "Prospective ports differ from committed ports")
	await ready_map(scene)
	check(controller.tile_parameters.get_tile(Vector2i(-1, 0)) == record and record.terrain_id == 81, "Overlapping ground lost its existing parameters")
	var fresh: Resource = controller.tile_parameters.get_tile(Vector2i(0, -1))
	check(fresh.threat == 1 and fresh.num_towers_around == 1, "New road missed tower influence")
	var samples := 0
	for seed in 16:
		var route: Dictionary = controller.sample_route(seed)
		check(not route.is_empty(), "Card bypass is not traversable")
		for cell: Vector2 in route.cells:
			check(Vector2i(cell) != Vector2i.ZERO, "Enemy path crosses card tower")
		samples += 1
	before = map.get_used_cells().size()
	revision = controller.revision
	check(towers.place_card(bridge, Vector3i.ZERO) == null and map.get_used_cells().size() == before and controller.revision == revision, "Overlapping card was partially committed")
	scene.queue_free()
	await get_tree().process_frame
	# Every orientation, including negative coordinates and a multi-cell tower.
	for turn in 4:
		scene = make_scene()
		await ready_map(scene)
		towers = scene.get_node("TowerMap")
		map = scene.get_node("TileMap")
		var card: BuildCard = corner.duplicate()
		card.tower = corner.tower.duplicate()
		card.tower.footprint = [Vector2i.ZERO, Vector2i.RIGHT]
		var anchor := Vector2i(-1, -4)
		var rotated: DefenseTower = towers.place_card(card, Vector3i(anchor.x, 0, anchor.y), turn)
		check(rotated != null, "Rotated multi-cell card rejected")
		if rotated != null:
			for cell in card.ground_cells(anchor, turn):
				check(map.get_cell_item(Vector3i(cell.x, 0, cell.y)) > 0, "Rotated ground missing")
			check(rotated.occupied_cells == card.tower_cells(anchor, turn), "Tower/card rotated footprints disagree")
			check(rotated.rotation_steps == turn, "Tower rotation not applied")
			var cell: Vector2i = rotated.occupied_cells.back()
			check(towers.remove_tower(Vector3i(cell.x, 0, cell.y)), "Rotated footprint removal failed")
		scene.queue_free()
		await get_tree().process_frame
	# A valid preview becomes invalid after enemies choose their fixed routes.
	scene = make_scene()
	await ready_map(scene)
	towers = scene.get_node("TowerMap")
	map = scene.get_node("TileMap")
	check(towers.validate_card(bridge, Vector3i.ZERO).is_empty(), "Expected valid preview")
	var wave: Node = scene.get_node("EnemyWave")
	wave.enemy_count = 2
	check(wave.start_wave(), "Wave failed to start")
	wave.set_process(false)
	before = map.get_used_cells().size()
	check(towers.place_card(bridge, Vector3i.ZERO) == null and map.get_used_cells().size() == before, "Commit trusted a stale preview and blocked locked routes")
	scene.queue_free()
	await get_tree().process_frame
	var report := {"failures": failures, "rotations": 4, "atomic_tile_events": events, "sampled_routes": samples, "single_rebuild": true, "stale_preview_rejected": true, "scene_ui": true, "tower_artwork_and_tint": true}
	print("CARD_CHECK:"+JSON.stringify(report))
	if not OS.has_feature("web"):
		var file := FileAccess.open("res://reports/cards/cards.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ")+"\n")
	get_tree().quit(1 if failures else 0)

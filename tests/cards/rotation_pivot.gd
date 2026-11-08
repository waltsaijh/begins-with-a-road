extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0
var checks := 0
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited
var viewport: SubViewport

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func _ready() -> void:
	verify.call_deferred()

func motion(point: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = mask
	viewport.push_input(event, true)

func mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	viewport.push_input(event, true)

func rotate_key() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_R
		event.pressed = pressed
		viewport.push_input(event, true)

func verify() -> void:
	viewport = TestViewport.new()
	viewport.size = Vector2i(1152,648)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	# Every production preset, including offsets, custom shapes and default facings.
	for key in ["sentry", "mortar", "crossfire", "ballista", "broadside", "barracks"]:
		var definition: TowerDefinition = load("res://assets/data/towers/"+key+".tres")
		for candidate in definition.preset_candidates():
			var card := BuildCard.from_parts(definition, candidate.resolve_preset())
			for initial in 4:
				var center := TowerBodyGeometry.center(card.tower_cells(Vector2i.ZERO, initial))
				for turn in range(initial, initial+9):
					var offset := card.rotation_anchor_offset(turn, initial)
					var after := TowerBodyGeometry.center(card.tower_cells(offset, turn))
					check(absf(center.x-after.x) <= 0.5 and absf(center.y-after.y) <= 0.5, key+" body center must stay within the nearest grid snap")
					if turn%4 == initial: check(offset == Vector2i.ZERO, key+" complete turns must not accumulate displacement")
	# Exact square footprint: off-center authored anchor and roads must rotate as one.
	for key in ["mortar", "crossfire"]:
		for drag in [false, true]: await verify_input(key, drag)
	# Let the audio mixer release UI/placement voices before the short test exits.
	get_tree().root.get_node("GameAudio").queue_free()
	await get_tree().create_timer(0.15, true, false, true).timeout
	print("ROTATION_PIVOT_CHECK: checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func verify_input(key: String, drag: bool) -> void:
	var cells: Array[Vector2i] = []
	for y in 15:
		for x in 15: cells.append(Vector2i(x,y))
	var stage := Fixture.scene_for(cells, Vector2i.ZERO, Vector2i(14,14))
	stage.get_node("EnemyWave").auto_start = false
	var preset := TilePreset.new()
	preset.preset_id = "rotation_square"
	preset.tower_footprint = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]
	preset.road_offsets = [Vector2i(-1,0), Vector2i(-1,1)]
	var definition: TowerDefinition = load("res://assets/data/towers/"+key+".tres")
	var card := BuildCard.from_parts(definition, preset)
	stage.get_node("CardPlacement").cards.assign([card])
	viewport.add_child(stage)
	await frames(12)
	var cards: Node = stage.get_node("CardPlacement")
	var map: GridMap = stage.get_node("TileMap")
	var camera: Camera3D = stage.get_node("Camera3D")
	cards._mouse_in_viewport = true
	cards.hand.finish_animation()
	while stage.get_node("PortalMap").computing: await frames(1)
	var pointer_cell := Vector3i(7,0,7)
	var point := camera.unproject_position(map.to_global(map.map_to_local(pointer_cell)))
	if drag:
		var view: Button = cards.hand.views[0]
		var start := view.get_global_transform_with_canvas()*(view.size*0.5)
		motion(start)
		mouse(start, MOUSE_BUTTON_LEFT, true)
		motion(point, MOUSE_BUTTON_MASK_LEFT)
	else:
		cards.select_card(0, false)
		motion(point)
	await frames()
	var expected := card.tower_cells(Vector2i(7,7),0)
	for turn in 5:
		check(cards.turns == turn%4, key+" input must advance clockwise once")
		var anchor: Vector3i = cards.pick_card_cell(point)
		var occupied := card.tower_cells(Vector2i(anchor.x,anchor.z),cards.turns)
		check(occupied.size() == 4 and occupied.all(func(cell): return cell in expected), key+" all four rotations must retain exactly the original four cells")
		check(cards.preview.visible and cards._preview_error.is_empty(), key+" rotated preview must remain legal and visible")
		check(cards.preview.displayed_ground == cards.towers.card_ground(card,Vector2i(anchor.x,anchor.z),cards.turns), key+" preview must use the compensated authoritative footprint and roads")
		if DisplayServer.get_name() != "headless" and not drag and turn < 4:
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(Artifacts.path("cards/pivot_"+key+"_"+str(turn)+".png"))
		if turn == 4: break
		if not drag and turn%2 == 1:
			mouse(point,MOUSE_BUTTON_RIGHT,true)
			mouse(point,MOUSE_BUTTON_RIGHT,false)
		else: rotate_key()
		await frames()
	rotate_key()
	await frames()
	var origin: Vector3i = cards.pick_card_cell(point)
	var expected_ground: Array[Vector2i] = cards.towers.card_ground(card,Vector2i(origin.x,origin.z),cards.turns)
	if not drag: mouse(point,MOUSE_BUTTON_LEFT,true)
	mouse(point,MOUSE_BUTTON_LEFT,false)
	await frames(3)
	var built: DefenseTower = cards.towers.upgrade_target(pointer_cell)
	check(built != null and cards.cards.is_empty(), key+" rotated click/drop must commit once")
	if built != null:
		check(built.occupied_cells.size() == 4 and built.occupied_cells.all(func(cell): return cell in expected), key+" committed body must match preview")
		check(built.placement_origin == Vector2i(origin.x,origin.z) and built.geometry_turns == 1, key+" commit must preserve the compensated origin and facing")
		for cell in expected_ground: check(map.get_cell_item(Vector3i(cell.x,0,cell.y)) >= 0, key+" committed ground must match preview")
		var other_definition: TowerDefinition = load("res://assets/data/towers/"+("crossfire" if key == "mortar" else "mortar")+".tres")
		var other_card := BuildCard.from_parts(other_definition, preset)
		cards.add_card(other_card)
		cards.hand.finish_animation()
		cards.select_card(0, false)
		cards.rotate_card(1)
		motion(point)
		await frames()
		var overlap_origin: Vector3i = cards.pick_card_cell(point)
		check(cards.preview.visible and not cards.preview.upgrade_mode and cards.preview.ground.mesh != null, "Different towers must keep the complete placement preview when overlapping")
		check(cards.preview._definition == other_definition and not cards._preview_error.is_empty(), "Overlapping preview must show the held tower as invalid, rather than morphing into the existing tower")
		check(overlap_origin != pointer_cell and cards.towers.upgrade_target(overlap_origin,other_card) == null, "Different towers must retain their whole-body rotation pivot and never become upgrade targets")
		var revision: int = stage.get_node("PortalMap").revision
		mouse(point,MOUSE_BUTTON_LEFT,true)
		mouse(point,MOUSE_BUTTON_LEFT,false)
		await frames()
		check(built.level == 1 and cards.cards.size() == 1 and cards.towers.towers.size() == 1 and stage.get_node("PortalMap").revision == revision, "Different-tower overlap must not consume the card, upgrade, build, or edit the map")
		if DisplayServer.get_name() != "headless" and not drag:
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(Artifacts.path("cards/pivot_"+key+"_different_tower.png"))
		cards.cards.clear()
		cards.hand.set_cards(cards.cards)
		cards.select_card(-1)
		cards.add_card(card)
		cards.hand.finish_animation()
		cards.select_card(0, false)
		cards.rotate_card(1)
		motion(point)
		await frames()
		check(cards.pick_card_cell(point) == pointer_cell and cards.preview.upgrade_mode, "Rotated upgrade cards must target the occupied cell under the pointer")
		mouse(point,MOUSE_BUTTON_LEFT,true)
		mouse(point,MOUSE_BUTTON_LEFT,false)
		await frames()
		check(built.level == 2 and cards.cards.is_empty(), "Rotated card must upgrade without shifting or adding a tower")
	stage.queue_free()
	await frames(3)

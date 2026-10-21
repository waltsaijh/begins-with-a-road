extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const TestCards = preload("res://tests/fixtures/card_fixture.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited

var failures := 0
var viewport: SubViewport
var scene: Node3D
var cards: Node3D
var camera: Camera3D

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func motion(point: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = mask
	viewport.push_input(event, true)

func left(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	viewport.push_input(event, true)

func card_point(index := 0) -> Vector2:
	var view: Button = cards.hand.views[index]
	return view.get_global_transform_with_canvas()*(view.size*0.5)

func click(point: Vector2) -> void:
	motion(point)
	left(point, true)
	left(point, false)

func drag_to(point: Vector2, index := 0) -> void:
	cards.hand.finish_animation()
	var start := card_point(index)
	motion(start)
	left(start, true)
	motion(point, MOUSE_BUTTON_MASK_LEFT)

func valid_cell(index := 0, turns := 0) -> Vector3i:
	var map: GridMap = scene.get_node("TileMap")
	for cell in map.get_used_cells():
		var point := camera.unproject_position(map.to_global(map.map_to_local(cell)))
		if not Rect2(Vector2(20, 100), Vector2(1050, 300)).has_point(point): continue
		if cards.towers.validate_card(cards.cards[index], cell, turns).is_empty(): return cell
	return TileConstants.INVALID_CELL

func point_for(cell: Vector3i) -> Vector2:
	var map: GridMap = scene.get_node("TileMap")
	return camera.unproject_position(map.to_global(map.map_to_local(cell)))

func verify() -> void:
	viewport = TestViewport.new()
	viewport.size = Vector2i(1152, 648)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	scene = load("res://scenes/level.tscn").instantiate()
	scene.get_node("CardPlacement").cards = TestCards.starting_hand()
	viewport.add_child(scene)
	await frames(12)
	while scene.get_node("PortalMap").computing: await frames(1)
	cards = scene.get_node("CardPlacement")
	camera = scene.get_node("Camera3D")
	cards.hand.finish_animation()
	# Hover and selection share the lift tween; sway never moves the hit target.
	var view: Button = cards.hand.views[0]
	var rest := view.position
	var bottom := view.get_global_transform_with_canvas()*Vector2(view.size.x*0.5, view.size.y-2.0)
	motion(card_point())
	cards.hand.finish_animation()
	var hovered := view.position
	check(is_equal_approx(hovered.distance_to(rest), CardFanLayout.HOVER_LIFT*CardFanLayout.CARD_SCALE), "Hover lift did not use the smaller amount")
	click(card_point())
	check(view.position.is_equal_approx(hovered), "Hover-to-selection lift snapped")
	cards.hand._motion.pause()
	cards.hand._motion.custom_step(cards.hand.selection_seconds*0.5)
	check(view.position.distance_to(rest) > hovered.distance_to(rest) and view.position.distance_to(rest) < cards.hand.selected_lift*CardFanLayout.CARD_SCALE, "Selection lift did not transition between hover and selected heights")
	cards.hand.finish_animation()
	var raised := view.position
	check(is_equal_approx(raised.distance_to(rest), cards.hand.selected_lift*CardFanLayout.CARD_SCALE), "Selection was not raised more than hover")
	await get_tree().create_timer(0.45, true, false, true).timeout
	var artwork: Control = view.get_node("Visuals")
	check(absf(artwork.rotation_degrees) > 0.05 and absf(artwork.rotation_degrees) <= view.selected_sway_degrees and view.position.is_equal_approx(raised), "Selection sway was absent, excessive or moved the input button")
	motion(bottom)
	check(cards.hand._hovered == 0 and CardFanLayout.pick(cards.hand.views, bottom, 0, 0) == 0, "Selected card lost its original lower hit area")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(Artifacts.path("cards/card_selected_sway.png"))
	click(card_point())
	check(view.position.is_equal_approx(raised), "Selection-to-hover lift snapped")
	cards.hand.finish_animation()
	check(is_equal_approx(view.position.distance_to(rest), CardFanLayout.HOVER_LIFT*CardFanLayout.CARD_SCALE), "Deselection did not return to hover height")
	motion(Vector2(500, 220))
	cards.hand.finish_animation()
	await get_tree().create_timer(0.25, true, false, true).timeout
	await frames(2)
	check(view.position.is_equal_approx(rest) and is_zero_approx(artwork.rotation), "Deselected card did not settle to rest")
	click(card_point())
	check(cards.selected == 0 and not cards.hand.is_dragging(), "Click did not select a hand card")
	click(card_point())
	check(cards.selected == -1, "Clicking the selected card did not deselect it")
	var cell := valid_cell()
	check(cell != TileConstants.INVALID_CELL, "No valid drag-placement fixture")
	if cell == TileConstants.INVALID_CELL:
		get_tree().quit(1)
		return
	var point := point_for(cell)
	var count: int = cards.cards.size()
	var angle: float = camera.azimuth
	drag_to(point)
	await frames(3)
	check(cards.hand.is_dragging() and cards.selected == 0 and cards.preview.visible, "Dragging did not select the card and show the world hologram")
	check(cards.cards.size() == count and is_equal_approx(camera.azimuth, angle) and camera._orbit_press == null, "A held card drag placed early or started camera rotation")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(Artifacts.path("cards/card_drag_preview.png"))
	left(point, false)
	await frames(3)
	check(cards.cards.size() == count-1 and cards.selected == -1 and not cards.hand.is_dragging(), "Dropping on a valid tile did not consume exactly one card")
	while scene.get_node("PortalMap").computing: await frames(1)
	# Occupied tower cell rejects a second drop without changing the hand/map.
	count = cards.cards.size()
	var revision: int = scene.get_node("PortalMap").revision
	drag_to(point)
	await frames(2)
	left(point, false)
	check(cards.cards.size() == count and cards.selected == 0 and scene.get_node("PortalMap").revision == revision, "An invalid drop consumed the card or changed the map")
	# Re-dragging the selected card retains its clockwise rotation.
	cards.rotate_card(1)
	var hud: CanvasLayer = scene.get_node("LevelHUD")
	var ui_point: Vector2 = hud.speed_button.get_global_rect().get_center()
	drag_to(ui_point)
	await frames(2)
	check(cards.turns == 1 and not cards.preview.visible, "Re-dragging lost rotation or showed a hologram over UI")
	left(ui_point, false)
	check(cards.cards.size() == count and hud.speed_index == 0 and cards.selected == 0, "Dropping on UI bought/placed a card or activated the button")
	# Dropping back onto the source or another hand card cancels selection.
	for destination in [0, 1]:
		drag_to(point)
		await frames(2)
		var destination_point := card_point(destination)
		motion(destination_point, MOUSE_BUTTON_MASK_LEFT)
		left(destination_point, false)
		check(cards.selected == -1 and cards.cards.size() == count and not cards.preview.visible and not cards.hand.is_dragging(), "Dropping onto a hand card did not cancel focus safely")
	# Closed shop backs also cancel focus without opening or buying anything.
	var shop: Node = cards.get_node("Shop")
	shop._on_wave_started()
	shop._on_wave_finished()
	shop.view.finish_animation()
	var wallet: int = shop.coins
	var deals: int = shop.deals
	drag_to(point)
	await frames(2)
	var back: Button = shop.view.slots.back().get_node("Face/Back")
	var back_point := back.get_global_transform_with_canvas()*(back.size*0.5)
	motion(back_point, MOUSE_BUTTON_MASK_LEFT)
	left(back_point, false)
	check(cards.selected == -1 and cards.cards.size() == count and shop.coins == wallet and shop.deals == deals and not shop.view.opened, "Dropping onto a shop back did not cancel focus or triggered a transaction")
	# Esc cancels the captured drag, and its release must not place anything.
	drag_to(point)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	viewport.push_input(escape, true)
	left(point, false)
	check(cards.selected == -1 and cards.cards.size() == count and not cards.hand.is_dragging(), "Esc did not cancel dragging safely")
	# Pausing cancels dragging; resuming still allows an ordinary card click.
	drag_to(point)
	hud.set_paused(true)
	left(point, false)
	check(not cards.hand.is_dragging() and cards.cards.size() == count, "Pause allowed a drop or retained dragging")
	hud.set_paused(false)
	cards.select_card(-1)
	cards._pause_card_motion.custom_step(1.0)
	cards.hand.finish_animation()
	click(card_point())
	check(cards.selected == 0, "Normal clicking stopped working after a cancelled drag")
	# Leaving the viewport and starting a wave both cancel capture.
	drag_to(point)
	viewport.mouse_exited.emit()
	left(point, false)
	check(not cards.hand.is_dragging() and cards.cards.size() == count, "Leaving the viewport committed or retained a drag")
	viewport.mouse_entered.emit()
	drag_to(point)
	cards.prepare_wave_start()
	left(point, false)
	check(cards.input_suspended and not cards.hand.is_dragging() and cards.cards.size() == count, "Wave start allowed a drop or retained capture")
	cards._on_wave_started()
	cards._on_wave_finished()
	cards.hand.finish_animation()
	# The original click-card, click-world workflow still commits successfully.
	click(card_point())
	cell = valid_cell()
	check(cell != TileConstants.INVALID_CELL, "No valid click-placement fixture")
	if cell != TileConstants.INVALID_CELL:
		click(point_for(cell))
		await frames(3)
		check(cards.cards.size() == count-1, "Click-card/click-world placement regressed")
	var report := {"failures": failures, "hover_selection_transition": true, "selected_sway_stable_hit": true, "drag_and_click": true, "drop_validation": true, "drop_on_card_cancels_focus": true, "ui_safe": true, "rotation_preserved": true, "camera_excluded": true, "cancel_escape_pause_wave_exit": true}
	FileAccess.open(Artifacts.path("cards/card_drag_placement.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CARD_DRAG_PLACEMENT_CHECK:"+JSON.stringify(report))
	get_tree().quit(1 if failures else 0)

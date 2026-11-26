extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const TestCards = preload("res://tests/fixtures/card_fixture.gd")
const TestLevel = preload("res://tests/levels/road_flow_fixture.gd")
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
	# Input coverage needs legal placements independent of the editable Frontier.
	scene.level = TestLevel.level()
	scene.get_node("CardPlacement").cards = TestCards.starting_hand()
	viewport.add_child(scene)
	await frames(12)
	while scene.get_node("PortalMap").computing: await frames(1)
	# Match the other input fixtures: a hidden native window may lose focus
	# during startup, and synthetic SubViewport input needs its own enter event.
	await get_tree().create_timer(0.25,true,false,true).timeout
	viewport.mouse_entered.emit()
	cards = scene.get_node("CardPlacement")
	camera = scene.get_node("Camera3D")
	cards.hand.finish_animation()
	# Hover and selection share the lift tween; sway never moves the hit target.
	var view: Button = cards.hand.views[0]
	var rest := view.position
	var bottom := view.get_global_transform_with_canvas()*Vector2(view.size.x*0.5, view.size.y-2.0)
	GameAudio._effects[&"hover"].stop()
	GameAudio._effects[&"card_hover"].stop()
	motion(card_point())
	check(GameAudio._effects[&"card_hover"].playing and not GameAudio._effects[&"hover"].playing, "Hand hover must play only its own card cue")
	GameAudio._effects[&"card_hover"].stop()
	motion(card_point()+Vector2(1, 0))
	check(not GameAudio._effects[&"card_hover"].playing, "Moving within one hovered card must not replay the cue")
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
	var sample_at := Time.get_ticks_usec()
	motion(Vector2(500, 220))
	cards.hand.finish_animation()
	await get_tree().create_timer(0.25, true, false, true).timeout
	await frames(2)
	print("HAND_RETURN state=",{"position":view.position,"rest":rest,"artwork_rotation":artwork.rotation,"hover_index":cards.hand._hovered,"selected":cards.selected,"sway":view._sway_amount,"elapsed_usec":Time.get_ticks_usec()-sample_at})
	check(view.position.is_equal_approx(rest) and is_zero_approx(artwork.rotation), "Deselected card did not settle to rest")
	print("HAND_RETURN failures=",failures)
	get_tree().quit(0 if not failures else 1)

extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited

const TestCards = preload("res://tests/fixtures/card_fixture.gd")
var failures := 0
var _viewport: SubViewport

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func move_to(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	_viewport.push_input(motion, true)
	await frames()

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	_viewport.push_input(event, true)
	await frames()

func verify() -> void:
	# Isolate synthetic input from the desktop cursor without moving the user's mouse.
	_viewport = TestViewport.new()
	_viewport.size = Vector2i(1152, 648)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	scene.get_node("CardPlacement").cards = TestCards.starting_hand()
	scene.get_node("EnemyWave").auto_start = false
	_viewport.add_child(scene)
	await frames(12)
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing or controller.plan.is_empty(): await frames(1)
	scene.get_node("TileVisuals").finish()
	var cards: Node = scene.get_node("CardPlacement")
	var map: GridMap = scene.get_node("TileMap")
	var camera: Camera3D = scene.get_node("Camera3D")
	cards.select_card(1)
	cards.set_process(false)
	var cell := Vector3i(16, 0, 0)
	var point := camera.unproject_position(map.to_global(map.map_to_local(cell)))
	await move_to(point)
	cards._process(0.49)
	check(cards.preview.visible, "Hologram should be visible")
	check(not cards.rotation_hint.visible, "Hint appeared before 0.5 seconds")
	var footprint: Mesh = cards.preview.ground.mesh
	cards._process(0.02)
	check(cards.rotation_hint.visible, "Hint did not appear after 0.5 seconds")
	cards._process(0.15)
	check(is_equal_approx(cards.rotation_hint.modulate.a, 1.0), "Hint did not finish fading in")
	cards.rotation_hint.reset()
	Engine.time_scale = 4.0
	cards._process(0.49*4.0)
	check(not cards.rotation_hint.visible, "Combat speed accelerated the hover delay")
	cards._process(0.17*4.0)
	Engine.time_scale = 1.0
	check(cards.rotation_hint.visible, "Hint did not appear at 4x combat speed")
	check(cards.rotation_hint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Hint intercepts placement input")
	check(cards.preview.ground.mesh == footprint, "Dwell timer rebuilt the cached hologram")
	var hint_rect: Rect2 = cards.rotation_hint.get_global_rect()
	check(hint_rect.end.y < camera.unproject_position(cards.preview.hint_anchor).y, "Hint is not above the hologram")
	await move_to(point+Vector2(1, 0))
	cards._process(0.01)
	check(cards.rotation_hint.visible, "Small movement within a tile reset the hint")
	await press(KEY_Q)
	await press(KEY_E)
	check(cards.turns == 0, "Q/E still rotate the card")
	var origin_before: int = controller.active_start
	await press(KEY_R)
	cards._process(0.01)
	check(cards.turns == 1, "R did not rotate clockwise")
	check(controller.active_start == origin_before, "Card rotation changed the debug origin")
	check(cards.rotation_hint.visible, "Rotation hid the hint on the same tile")
	for i in 3: await press(KEY_R)
	check(cards.turns == 0, "Four R rotations did not wrap back to zero")
	cards._process(0.01)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_viewport.get_texture().get_image().save_png(Artifacts.path("cards/rotation_key_hint.png"))
	await move_to(camera.unproject_position(map.to_global(map.map_to_local(cell+Vector3i(1, 0, 0)))))
	cards._process(0.01)
	check(not cards.rotation_hint.visible, "Changing tile did not reset the hint")
	cards._process(0.66)
	check(cards.rotation_hint.visible, "Hint did not reappear after dwelling on another tile")
	var view: Control = cards.hand.views[0]
	await move_to(view.get_global_transform_with_canvas()*(view.size*0.5))
	cards._process(0.1)
	check(not cards.preview.visible and not cards.rotation_hint.visible, "Hovering UI did not hide hologram and hint")
	await move_to(point)
	cards._process(0.66)
	check(cards.rotation_hint.visible, "Hint did not return after leaving UI")
	var towers_before: int = cards.towers.towers.size()
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_viewport.push_input(click, true)
	click.pressed = false
	_viewport.push_input(click, true)
	await frames()
	check(cards.towers.towers.size() == towers_before+1 and cards.selected == -1 and not cards.rotation_hint.visible, "Hint blocked placement or remained after committing the card")
	cards.select_card(0)
	cards.set_process(false)
	cards._process(0.66)
	cards.select_card(-1)
	check(not cards.rotation_hint.visible, "Cancel did not hide the hint")
	cards.select_card(1)
	cards.set_process(false)
	cards._process(0.66)
	cards.prepare_wave_start()
	check(cards.selected == -1 and not cards.rotation_hint.visible, "Wave preparation did not clear the hint")
	print("ROTATION_HINT_CHECK:"+JSON.stringify({"failures": failures, "delay": 0.5, "clockwise_key": "R"}))
	get_tree().quit(1 if failures else 0)

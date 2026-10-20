extends Node3D
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const TestCards = preload("res://tests/fixtures/card_fixture.gd")
## Reproducible UI/footprint rendering fixture, also used by the Web verifier.
func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		get_tree().quit(1)

func verify() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.get_node("CardPlacement").cards = TestCards.starting_hand()
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing or controller.plan.is_empty():
		await get_tree().process_frame
	var towers: Node = scene.get_node("TowerMap")
	var card: BuildCard = TestCards.card("bridge")
	check(towers.place_card(card, Vector3i(8, 0, 0)) != null, "Initial card failed")
	while controller.computing or controller.plan.is_empty():
		await get_tree().process_frame
	scene.get_node("TileVisuals").finish()
	var cards: Node = scene.get_node("CardPlacement")
	cards.hand.views[1].pressed.emit()
	check(cards.selected == 1, "Button did not select card")
	# Exercise actual input propagation: selected cards must suppress legacy tools.
	var rotation := InputEventKey.new()
	rotation.physical_keycode = KEY_R
	rotation.pressed = true
	Input.parse_input_event(rotation)
	await get_tree().process_frame
	check(cards.turns == 1, "First rotation event failed")
	Input.parse_input_event(rotation)
	await get_tree().process_frame
	check(cards.turns == 2, "Second rotation event failed")
	var map: GridMap = scene.get_node("TileMap")
	var camera: Camera3D = scene.get_node("Camera3D")
	var cell := Vector3i(16, 0, 0)
	var point := camera.unproject_position(map.to_global(map.map_to_local(cell)))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	check(cards.preview.visible, "Footprint preview hidden")
	check(cards._preview_error.is_empty(), "Footprint preview invalid")
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await get_tree().process_frame
	click.pressed = false
	Input.parse_input_event(click)
	await get_tree().process_frame
	check(towers.towers.size() == 2 and towers.occupied.has(Vector2i(16, 0)), "Click did not commit card")
	check(map.get_used_cells().size() == 30, "Legacy input interfered with card click")
	while controller.computing or controller.plan.is_empty():
		await get_tree().process_frame
	scene.get_node("TileVisuals").finish()
	cell = Vector3i(12, 0, 0)
	cards.set_process(false)
	cards.preview.show_at(map, card, cell, 2, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var report := {"selected": cards.selected, "turns": cards.turns, "cards": cards.hand.views.size(), "towers": towers.towers.size(), "tiles": map.get_used_cells().size(), "preview_valid": true, "input_propagation": true}
	if not OS.has_feature("web"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("cards/cards.png"))
		print("CARD_RENDER_CHECK:"+JSON.stringify(report))
		get_tree().quit()
	else:
		print("CARD_RENDER_CHECK:"+JSON.stringify(report))

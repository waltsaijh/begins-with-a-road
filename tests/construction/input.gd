extends Node
const Playground = preload("res://tests/construction/playground.tscn")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited
var viewport: SubViewport
var game: Node3D
var checks := 0
var failures: Array[String] = []

func _ready() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame
func motion(point: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = mask
	viewport.push_input(event,true)
func left(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	viewport.push_input(event,true)
func click(point: Vector2) -> void:
	motion(point)
	left(point,true)
	left(point,false)
	await frames()
func center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	viewport.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event,true)
	await frames()
func point(cell: Vector3i) -> Vector2:
	var map: GridMap = game.session.get_node("TileMap")
	return game.session.get_node("Camera3D").unproject_position(map.to_global(map.map_to_local(cell)))
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	check(image != null and image.get_size() == viewport.size,"Real GPU viewport image is available: "+name)
	image.save_png(Artifacts.path("construction/"+name+".png"))
func drag_card(index: int, cell: Vector3i) -> void:
	var cards: Node = game.session.get_node("CardPlacement")
	cards.hand.finish_animation()
	check(not cards.cards[0].localized_name().contains("construction.") and game.shape_picker.get_item_text(0).contains("長廊"),"Imported Chinese card and shape translations are visible")
	var start := center(cards.hand.views[index])
	motion(start)
	left(start,true)
	motion(point(cell),MOUSE_BUTTON_MASK_LEFT)
	await frames()
	check(cards.hand.is_dragging() and cards.preview.visible,"Real hand drag shows full compound preview")
	left(point(cell),false)
	await frames(5)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Construction input requires an actual rendering backend")
		get_tree().quit(2)
		return
	viewport = TestViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	game = Playground.instantiate()
	viewport.add_child(game)
	await frames(20)
	await get_tree().create_timer(0.3,true,false,true).timeout
	viewport.mouse_entered.emit()
	var cards: Node = game.session.get_node("CardPlacement")
	var towers: Node = game.session.get_node("TowerMap")
	var portal: Node = game.session.get_node("PortalMap")
	var wave: Node = game.session.get_node("EnemyWave")
	cards.hand.finish_animation()
	await capture("playground_initial")
	var history: int = portal.route_history.revision
	await click(center(cards.hand.views[0]))
	check(cards.selected == 0,"Real click selects a compound tower card")
	await click(point(Vector3i(6,0,0)))
	check(game.batch.entries.size() == 1 and cards.cards.size() == 6 and towers.towers.is_empty(),"Real map click reserves a disconnected draft without consuming a card")
	check(not game.batch.validate().ok and game.batch.status.contains("道路尚未連通"),"Disconnected draft explains why combat is unavailable")
	await capture("draft_disconnected")
	await click(center(game.session.get_node("LevelHUD/WorldActions/EarlyStart")))
	check(not game.session._wave_starting and not wave.active,"Actual entrance click cannot start broken draft")
	await click(center(game.move_button))
	check(game.batch.moving,"Move button begins draft relocation")
	await click(point(Vector3i(6,0,1)))
	check(game.batch.entries[0].anchor == Vector3i(6,0,1),"Real click relocates draft")
	await key(KEY_R)
	check(game.batch.entries[0].turns == 1,"R rotates the selected draft")
	await click(center(game.remove_button))
	check(game.batch.entries.is_empty() and cards.cards.size() == 6 and portal.route_history.revision == history,"Undo releases reservation with no history or inventory change")
	await drag_card(0,Vector3i(6,0,0))
	cards.hand.finish_animation()
	await click(center(cards.hand.views[1]))
	await key(KEY_R)
	check(cards.turns == 1,"Selected hand card rotates with R")
	await click(point(Vector3i(9,0,-2)))
	check(game.batch.entries.size() == 2 and game.batch.validate().ok,"Two real placement gestures form a legal composite bypass")
	await click(center(game.earlier_button))
	check(game.batch.selected_entry == 0 and game.batch.entries[0].card_index == 1 and game.batch.validate().ok,"Reordering drafts preserves reservations and final legality")
	get_tree().paused = true
	await frames()
	check(game.batch._ghosts.all(func(ghost): return not ghost.visible) and not game.batch.editable(),"Pause hides pending ghosts and locks edits")
	get_tree().paused = false
	await frames()
	check(game.batch.entries.size() == 2 and game.batch._ghosts.all(func(ghost): return ghost.visible),"Resume restores the same drafts")
	await capture("draft_connected")
	await click(center(game.confirm_button))
	await frames(10)
	check(game.batch.entries.is_empty() and towers.towers.size() == 2 and cards.cards.size() == 4,"Confirm button atomically builds both towers and consumes two cards")
	check(portal.route_history.revision == history+1,"Confirmation publishes one route history snapshot")
	await get_tree().create_timer(0.6,true,false,true).timeout
	await capture("confirmed_bypass")
	# The normal shop and its real card buttons remain in use.
	var shop: Node = cards.get_node("Shop")
	shop.view.finish_animation()
	await click(center(shop.view.slots[0].get_node("Face/Back")))
	shop.view.finish_animation()
	check(shop.view.opened,"Actual deck click opens the normal shop")
	var price: int = shop.prices[0]
	var coins: int = shop.coins
	var count: int = cards.cards.size()
	var offer: BuildCard = shop.offers[0]
	await click(center(shop.view.slots[1].get_node("Face/Card")))
	shop.view.finish_animation()
	check(shop.coins == coins-price and cards.cards.size() == count+1 and cards.cards.back() == offer,"Actual shop purchase uses original identity, snapshot price and one debit")
	await key(KEY_ESCAPE)
	await frames(5)
	check(not shop.view.opened and not cards.input_suspended,"Closing shop restores construction input")
	# No draft is required to start. Observe the actual 1.5 second opening.
	await click(center(game.session.get_node("LevelHUD/WorldActions/EarlyStart")))
	check(game.session._wave_starting,"Entrance click enters real opening transition")
	await get_tree().create_timer(2.0,true,false,true).timeout
	check(wave.active and cards.input_suspended,"Committed compound map starts real mixed enemies and locks card input")
	check(wave._committed_routes.size() == wave.total and wave.total > 0,"Combat freezes the complete mixed schedule")
	check(not game.batch.stage(cards.cards[0],Vector3i(2,0,4),0,0).ok,"Combat locks draft API")
	await capture("compound_combat")
	Engine.time_scale = 4.0
	var deadline := Time.get_ticks_msec()+25000
	while game.session.current_wave == 0 and Time.get_ticks_msec() < deadline: await frames(2)
	Engine.time_scale = 1.0
	await frames(5)
	check(game.session.current_wave == 1 and not wave.active and not game.session._wave_starting,"Actual enemies complete the first wave and return to manual preparation")
	check(shop.available and shop.coins == coins-price+18 and game.batch.editable(),"Wave completion grants one reward and restores the normal shop and construction")
	await capture("next_preparation")
	# Cleanup exercises queued forecast/geometry callbacks as the level exits.
	game.queue_free()
	await frames(4)
	var output := {"checks":checks,"failures":failures,"rendered":true,"input":"SubViewport real mouse/key events; actual shop, opening and EnemyWave","human_playtest":"NOT RUN"}
	FileAccess.open(Artifacts.path("construction/input.json"),FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("CONSTRUCTION_INPUT:",JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)

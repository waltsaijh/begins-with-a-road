extends "res://scripts/levels/level_session.gd"
const Regression = preload("res://tests/events/regression.gd")
var picker: OptionButton
var tools: CanvasLayer
var host: Node3D
var screenshot_failures: Array[String] = []

func _enter_tree() -> void:
	LevelLaunch.select(Regression.definition())
	super._enter_tree()

func _ready() -> void:
	super._ready()
	setup.call_deferred()

func setup() -> void:
	host = self
	for i in 120:
		await get_tree().process_frame
		if not host.get_node("PortalMap").computing: break
	var tower_map: Node3D = host.get_node("TowerMap")
	var definition: TowerDefinition = load("res://assets/data/towers/sentry.tres")
	var preset := TilePreset.new()
	preset.road_offsets = [Vector2i.ZERO]
	for x in [5,9,13]:
		var tower: DefenseTower = tower_map.place_card(BuildCard.from_parts(definition,preset),Vector3i(x,0,3))
		if tower != null: tower.upgrade()
	tools = CanvasLayer.new()
	tools.layer = 15
	add_child(tools)
	var row := HBoxContainer.new()
	row.position = Vector2(16,92)
	tools.add_child(row)
	picker = OptionButton.new()
	for event in host.special_events.catalog: picker.add_item(event.text("title"))
	row.add_child(picker)
	var open := Button.new()
	open.text = "指定事件 / Open event"
	open.pressed.connect(open_event)
	row.add_child(open)
	var fund := Button.new()
	fund.text = "+100 Gold"
	fund.pressed.connect(func():
		if not host.choosing_event and not host._wave.active: host.get_node("CardPlacement/Shop").grant_gold(100,"playground"))
	row.add_child(fund)
	if "--events-screenshots" in OS.get_cmdline_user_args(): screenshots.call_deferred()

func open_event() -> void:
	if host.finished or host._wave.active or host._wave_starting or host.choosing_start or host.choosing_relic or host.choosing_event or get_tree().paused: return
	host.choosing_event = true
	host._wave.start_allowed = false
	host.get_node("CardPlacement").set_entry_selection(true)
	host._update_start_callout()
	if not host.special_events.begin(host.special_events.catalog[picker.selected]):
		host.choosing_event = false
		host._continue_after_expansion()

func screenshots() -> void:
	var folder := "res://.godot/test-results/events"
	DirAccess.make_dir_recursive_absolute(folder)
	tools.hide()
	for language in ["zh_TW","en"]:
		TranslationServer.set_locale(language)
		for dimensions in [Vector2i(1280,800),Vector2i(800,600),Vector2i(640,480)]:
			DisplayServer.window_set_size(dimensions)
			for i in 3: await get_tree().process_frame
			var event_indices := range(9) if dimensions.x == 1280 else [2, 3, 4, 8]
			for event_index in event_indices:
				picker.select(event_index)
				open_event()
				await get_tree().create_timer(0.38, true, false, true).timeout
				var path := folder+"/%s_%d_event%d" % [language,dimensions.x,event_index+1]
				_save_event_image(path)
				var choice: CanvasLayer = host.special_events.choice
				var first: Button = choice.buttons[0]
				var second: Button = choice.buttons[1]
				_expect(first.size.is_equal_approx(second.size), path + ": equal card dimensions")
				_expect(get_viewport().get_visible_rect().encloses(choice.scroll.get_global_rect()), path + ": dialog remains within the viewport")
				if event_index == 2 and dimensions.x == 1280:
					await _capture_merchant_states(path)
				if event_index == 8 and dimensions.x == 1280:
					await _capture_three_cards(path)
				host.special_events.active = null
				host.special_events.choice.dismiss()
				host.choosing_event = false
				host.get_node("CardPlacement").set_entry_selection(false)
	print("EVENT_VISUALS_SAVED ", JSON.stringify(screenshot_failures))
	get_tree().quit(0 if screenshot_failures.is_empty() else 1)

func _capture_merchant_states(path: String) -> void:
	var choice: CanvasLayer = host.special_events.choice
	var card: Button = choice.buttons[0]
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(8, 8)
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	motion.position = card.get_global_rect().get_center()
	get_viewport().push_input(motion, true)
	await get_tree().create_timer(0.18, true, false, true).timeout
	for i in 6:
		if card.visuals.position.y < -8.0 and card.visuals.scale.x > 1.02:
			break
		await get_tree().create_timer(0.04, true, false, true).timeout
	_expect(card.visuals.position.y < -8.0 and card.visuals.scale.x > 1.02, path + ": pointer lifts and scales the card")
	_save_event_image(path + "_hover")
	var shop: Node = host.get_node("CardPlacement/Shop")
	var gold: int = shop.coins
	shop.spend_gold(gold, "screenshot")
	await get_tree().create_timer(0.18, true, false, true).timeout
	_save_event_image(path + "_unavailable")
	await _click_card(card)
	_expect(host.special_events.active != null and shop.coins == 0, path + ": genuine pointer press cannot buy the disabled potion")
	shop.grant_gold(gold, "screenshot")
	var cheese: Button = choice.buttons[1]
	motion.position = cheese.get_global_rect().get_center()
	get_viewport().push_input(motion, true)
	await _click_card(cheese, path)
	_expect(host.special_events.active == null and choice.center.visible, path + ": genuine pointer click resolves and starts the exit")
	await get_tree().create_timer(0.07, true, false, true).timeout
	_save_event_image(path + "_exit")
	for i in 12:
		if not choice.root.visible:
			break
		await get_tree().create_timer(0.04, true, false, true).timeout
	_expect(not choice.root.visible, path + ": exit has finished")
	motion.position = Vector2(8, 8)
	get_viewport().push_input(motion, true)

func _capture_three_cards(path: String) -> void:
	# Presentation fixture only. The actual event manager still exposes two choices.
	var choice: CanvasLayer = host.special_events.choice
	choice._set_card_count(3)
	var third: Button = choice.buttons[2]
	var art = choice.Art
	third.show_option("Preview", "Third card layout with fallback illustration.", art.illustration(&"unknown", 2), "Free", third.INK, art.mat_color(&"unknown", 2))
	third.set_availability("Preview only")
	choice._layout()
	await get_tree().create_timer(0.16, true, false, true).timeout
	_expect(is_equal_approx(third.position.y, choice.buttons[0].position.y), path + ": three cards fit on one row")
	_expect(third.size.is_equal_approx(choice.buttons[0].size), path + ": third card matches the others")
	_save_event_image(path + "_three_cards")

func _click_card(card: Button, press_test := "") -> void:
	var click := InputEventMouseButton.new()
	click.position = card.get_global_rect().get_center()
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	if not press_test.is_empty():
		await get_tree().create_timer(0.09, true, false, true).timeout
		_expect(card.button_pressed and is_equal_approx(card.visuals.scale.x, 1.01), press_test + ": card compresses while the pointer is held")
	click.button_mask = 0
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		screenshot_failures.append(message)
		push_error(message)

func _save_event_image(path: String) -> void:
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(path + ".png")

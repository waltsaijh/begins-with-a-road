extends "res://scripts/levels/level_session.gd"
const Regression = preload("res://tests/events/regression.gd")
var picker: OptionButton
var tools: CanvasLayer
var host: Node3D

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
	for language in ["zh_TW","en"]:
		TranslationServer.set_locale(language)
		for dimensions in [Vector2i(1280,800),Vector2i(800,600)]:
			DisplayServer.window_set_size(dimensions)
			for i in 3: await get_tree().process_frame
			for event_index in [2,3,8]:
				picker.select(event_index)
				open_event()
				for i in 3: await get_tree().process_frame
				RenderingServer.force_draw()
				var image := get_viewport().get_texture().get_image()
				image.save_png(folder+"/%s_%d_event%d.png" % [language,dimensions.x,event_index+1])
				host.special_events.active = null
				host.special_events.choice.dismiss()
				host.choosing_event = false
				host.get_node("CardPlacement").set_entry_selection(false)
	print("EVENT_VISUALS_SAVED")
	get_tree().quit()

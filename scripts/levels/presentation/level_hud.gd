extends CanvasLayer
## Pause UI keeps processing while the rest of the scene is paused.
signal home_requested
const SettingsAdapter = preload("res://scripts/settings/game_settings.gd")
const SettingsScene = preload("res://scenes/settings/settings_page.tscn")
const ProgressScene = preload("res://scenes/progress/progress_page.tscn")
var settings_page: Control
var progress_page: Control
var _settings_camera: Camera3D
@export_range(0.0, 1.0, 0.01) var settings_veil_alpha := 0.82
var _settings_veil_motion: Tween
var _pause_veil_alpha := 0.0
var _returning_home := false
var inspection_owner: Node
var _inspection_was_requested := false
var _inspection_was_paused := false
var _inspection_scale := 1.0
var _inspection_focus: Control
var _header_layout_busy := false
var _header_signature: Array = []
var status_row_rect := Rect2()
const SPEEDS := [1.0, 2.0, 4.0]
const StartCallout = preload("res://scenes/levels/components/start_wave_callout.tscn")
var start_callouts: Array[Button] = []
var start_markers: Array[Node3D] = []
const PauseIcon = preload("res://assets/sprites/interface/pause.png")
const SPEED_ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/interface/speed_1x.png"),
	preload("res://assets/sprites/interface/speed_2x.png"),
	preload("res://assets/sprites/interface/speed_4x.png"), # Three-chevron third preset.
]
var speed_index := 0
var _start_was_disabled := false
## Presentation transition duration; gameplay pauses immediately.
@export_range(0.01, 1.0, 0.01) var pause_seconds := 0.35
@export_range(0.01, 1.0, 0.01) var pause_menu_fade_seconds := 0.35
var pause_requested := false
var _pause_menu_motion: Tween
@export var start_anchor_height := 0.55
@export var start_anchor_gap := 12.0
@export var start_collapse_height := 0.18
@export_range(0.05, 2.0, 0.01) var start_retract_seconds := 0.24
@export_range(0.05, 2.0, 0.01) var start_reveal_seconds := 0.36
var _callout_available := false
var _callout_motion: Tween
var _callout_reveal := 0.0:
	set(value):
		_callout_reveal = value
		if is_node_ready(): _position_callout()
@onready var early_start: Button = $WorldActions/EarlyStart
@onready var start_marker := get_node_or_null("../Start") as Node3D
@onready var speed_button: Button = $Header/Actions/Speed
@onready var pause_button: Button = $Header/Actions/Pause
@onready var pause_menu: Control = $PauseBlocker
@onready var resume_button: Button = $PauseBlocker/Menu/Margin/Actions/Resume/Button
@onready var restart_button: Button = $PauseBlocker/Menu/Margin/Actions/Restart/Button
@onready var progress_button: Button = $PauseBlocker/Menu/Margin/Actions/Progress/Button
@onready var settings_button: Button = $PauseBlocker/Menu/Margin/Actions/Settings/Button
@onready var home_button: Button = $PauseBlocker/Menu/Margin/Actions/ReturnHome/Button
@onready var _menu_buttons: Array[Button] = [resume_button, restart_button, progress_button, settings_button, home_button]
@onready var _cards: Node = get_node_or_null("../CardPlacement")

func _ready() -> void:
	start_callouts = [early_start]
	start_markers = [start_marker]
	_pause_veil_alpha = $PauseBlocker/WhiteVeil.color.a
	speed_button.pressed.connect(cycle_speed)
	if _cards != null:
		_cards.get_node("Shop").balance_changed.connect(_update_wallet_tooltip)
	pause_button.pressed.connect(func(): set_paused(not pause_requested))
	resume_button.pressed.connect(set_paused.bind(false))
	restart_button.pressed.connect(request_restart)
	home_button.pressed.connect(request_return_home)
	var codex: Button = $PauseBlocker/Menu/Margin/Actions/Codex/Button
	_menu_buttons.append(codex)
	codex.pressed.connect(func():
		var guide: Node = get_parent().get("enemy_intelligence")
		if guide != null: guide.open_codex())
	ScreenTransition.finished.connect(_on_transition_finished)
	settings_page = SettingsScene.instantiate()
	add_child(settings_page)
	settings_page.option_changed.connect(func(key: StringName, value: Variant): SettingsAdapter.apply(key, value, get_viewport()))
	settings_page.visibility_changed.connect(_on_page_visibility_changed.bind(settings_button))
	settings_button.pressed.connect(open_settings)
	progress_page = ProgressScene.instantiate()
	add_child(progress_page)
	progress_page.visibility_changed.connect(_on_page_visibility_changed.bind(progress_button))
	progress_button.pressed.connect(open_progress)
	pause_menu.hide()
	pause_menu.modulate.a = 0.0
	Engine.time_scale = SPEEDS[speed_index]
	_update_labels()
	_position_callout()
	$Header/WaveTimeline.resized.connect(_layout_status_row)
	get_viewport().size_changed.connect(_layout_status_row)
	_layout_status_row()

func open_settings() -> void:
	if not pause_requested or ScreenTransition.active or is_instance_valid(inspection_owner) or _page_open(): return
	settings_page.configure(SettingsAdapter.sections(), SettingsAdapter.read(get_viewport()))
	settings_page.open()

## Pauses first when opened from a next-wave troop icon, then lands on that entry.
func open_progress(entry_id := "") -> void:
	if ScreenTransition.active or is_instance_valid(inspection_owner) or _page_open(): return
	set_paused(true)
	if not pause_requested: return
	progress_page.configure(ProgressCatalog.sections(), {})
	progress_page.open()
	if not entry_id.is_empty(): progress_page.show_entry(entry_id)

func _page_open() -> bool:
	return (is_instance_valid(settings_page) and settings_page.visible) or (is_instance_valid(progress_page) and progress_page.visible)

func _on_page_visibility_changed(button: Button) -> void:
	var active := _page_open()
	_set_settings_navigation_locked(active)
	if not is_inside_tree(): return
	$PauseBlocker/Menu.visible = not active
	_fade_settings_veil(active)
	if not active and pause_requested: button.grab_focus()

func _set_settings_navigation_locked(value: bool) -> void:
	if value: _settings_camera = get_viewport().get_camera_3d()
	if is_instance_valid(_settings_camera) and _settings_camera.has_method("set_navigation_locked"):
		_settings_camera.set_navigation_locked(value)
	if not value: _settings_camera = null

func _fade_settings_veil(reveal: bool) -> void:
	if _settings_veil_motion != null: _settings_veil_motion.kill()
	_settings_veil_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_settings_veil_motion.tween_property($PauseBlocker/WhiteVeil, "color:a", maxf(_pause_veil_alpha, settings_veil_alpha) if reveal else _pause_veil_alpha, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _process(_delta: float) -> void:
	_position_callout()
	$Header/WaveTimeline.set_reward_active(get_parent().get("choosing_relic") == true)
	_layout_status_row()

## Center the visible information as one row. Timeline width drives every
## position during its existing real-time tween, keeping the gaps constant.
func _layout_status_row() -> void:
	if _header_layout_busy or not is_node_ready(): return
	_header_layout_busy = true
	var session := get_parent()
	var items: Array[Control] = []
	var widths: Array[float] = []
	var status: Node = session.get("run_status")
	if is_instance_valid(status) and not status.get_node("Integrity").visibility_changed.is_connected(_layout_status_row): status.get_node("Integrity").visibility_changed.connect(_layout_status_row)
	if is_instance_valid(status) and status.get_node("Integrity").visible:
		items.append(status.get_node("Integrity"))
		widths.append(56.0)
	items.append($Header/Balance)
	widths.append(56.0)
	var choice: Node = session.get("relic_choice")
	if is_instance_valid(choice) and not choice.get_node("RelicBar").visibility_changed.is_connected(_layout_status_row): choice.get_node("RelicBar").visibility_changed.connect(_layout_status_row)
	if is_instance_valid(choice) and choice.get_node("RelicBar").visible:
		var bar: Control = choice.get_node("RelicBar")
		var count: int = bar.get_node("Items").get_child_count()
		items.append(bar)
		widths.append(minf(176.0,count*38.0+maxi(0,count-1)*6.0))
	var timeline: Control = $Header/WaveTimeline
	var timeline_index := items.size()
	items.append(timeline)
	widths.append(0.0)
	var guide: Node = session.get("enemy_intelligence")
	if is_instance_valid(guide) and not guide.toggle.visibility_changed.is_connected(_layout_status_row): guide.toggle.visibility_changed.connect(_layout_status_row)
	if is_instance_valid(guide) and guide.toggle.visible:
		items.append(guide.toggle)
		widths.append(80.0)
	items.append($Header/Actions)
	widths.append(72.0)
	var gap := 16.0
	var remaining := gap*(items.size()-1)
	for width in widths: remaining += width
	var viewport_width := get_viewport().get_visible_rect().size.x
	timeline.manage_header_width(viewport_width-remaining-40.0)
	widths[timeline_index] = timeline.size.x
	var total := remaining+timeline.size.x
	var signature := [viewport_width,items,widths]
	if signature != _header_signature:
		_header_signature = signature
		var cursor := (viewport_width-total)*0.5
		status_row_rect = Rect2(cursor,34,total,38)
		for i in items.size():
			items[i].anchor_left = 0.0
			items[i].anchor_right = 0.0
			items[i].position.x = cursor
			items[i].size.x = widths[i]
			cursor += widths[i]+gap
	_header_layout_busy = false

func set_start_available(available: bool) -> void:
	if not is_inside_tree(): return
	for action in start_callouts:
		action.mouse_filter = Control.MOUSE_FILTER_STOP if available else Control.MOUSE_FILTER_IGNORE
		if not available: action.disabled = true
	if _callout_available != available:
		_callout_available = available
		_animate_callout(available)
	_position_callout()

func _animate_callout(reveal: bool) -> void:
	if _callout_motion != null: _callout_motion.kill()
	if not reveal:
		for action in start_callouts: action.call("clear_hover")
	var target := 1.0 if reveal else 0.0
	if is_equal_approx(_callout_reveal, target): return
	_callout_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_callout_motion.tween_property(self, "_callout_reveal", target, start_reveal_seconds if reveal else start_retract_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if reveal else Tween.EASE_IN)

func sync_start_callouts(markers: Array[Node3D]) -> void:
	if markers.is_empty(): return
	while start_callouts.size() > markers.size():
		var action := start_callouts.pop_back() as Button
		action.get_parent().remove_child(action)
		action.queue_free()
	while start_callouts.size() < markers.size():
		var action := StartCallout.instantiate() as Button
		action.name = "EarlyStart%d" % (start_callouts.size()+1)
		action.disabled = early_start.disabled
		$WorldActions.add_child(action)
		action.pressed.connect(_request_from_callout)
		start_callouts.append(action)
	start_markers = markers.duplicate()
	start_marker = start_markers[0]
	_position_callout()

func _request_from_callout() -> void:
	# All entrances share the existing single wave action and opening guard.
	if not _callout_available or pause_requested or get_tree().paused or early_start.disabled: return
	early_start.pressed.emit()

func _position_callout() -> void:
	if not is_inside_tree(): return
	if _page_open():
		for action in start_callouts: action.hide()
		return
	var viewport := get_viewport()
	if viewport == null or not is_instance_valid(early_start): return
	if pause_requested: early_start.disabled = true
	var camera := viewport.get_camera_3d()
	for i in start_callouts.size():
		var action := start_callouts[i]
		var marker: Node3D = start_markers[i]
		if i > 0: action.disabled = early_start.disabled or not _callout_available or pause_requested
		action.mouse_filter = Control.MOUSE_FILTER_STOP if _callout_available and not pause_requested else Control.MOUSE_FILTER_IGNORE
		_position_one_callout(action,marker,camera,viewport)
		action.call("update_pointer_hover")

func _position_one_callout(action: Button, marker: Node3D, camera: Camera3D, viewport: Viewport) -> void:
	if _callout_reveal <= 0.001 or not is_instance_valid(marker) or camera == null:
		action.hide()
		return
	var anchor := marker.global_position+Vector3.UP*start_anchor_height
	if camera.is_position_behind(anchor):
		action.hide()
		return
	var point := camera.unproject_position(anchor)
	var rest := point-Vector2(action.size.x*0.5, action.size.y+start_anchor_gap)
	var tower := camera.unproject_position(marker.global_position+Vector3.UP*start_collapse_height)
	var center := tower.lerp(rest+action.size*0.5, _callout_reveal)
	action.pivot_offset = action.size*0.5
	action.position = center-action.size*0.5
	action.scale = Vector2.ONE*maxf(0.001, _callout_reveal)
	action.modulate.a = minf(1.0, _callout_reveal*2.0)
	# Each entrance independently follows/clips against the moving camera.
	action.visible = viewport.get_visible_rect().intersects(action.get_global_rect())

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _update_labels()

func _update_labels() -> void:
	var english := TranslationServer.get_locale().begins_with("en")
	speed_button.text = ""
	speed_button.icon = SPEED_ICONS[speed_index]
	pause_button.icon = PauseIcon
	speed_button.tooltip_text = ("Game speed: %d×\nClick / Tab to cycle 1× / 2× / 4×." if english else "遊戲速度：%d 倍\n點擊／Tab 切換 1／2／4 倍速。") % SPEEDS[speed_index]
	pause_button.tooltip_text = "Pause game · open menu · Esc" if english else "暫停遊戲並開啟選單 · Esc"
	if _cards != null: _update_wallet_tooltip(_cards.get_node("Shop").coins)
	resume_button.text = tr("ui.pause.resume")
	restart_button.text = tr("ui.pause.restart")
	progress_button.text = tr("ui.pause.progress")
	settings_button.text = tr("ui.pause.settings")
	home_button.text = tr("ui.pause.home")
	$PauseBlocker/Menu/Margin/Actions/Codex/Button.text = "Enemy codex" if TranslationServer.get_locale().begins_with("en") else "敵軍圖鑑"

func _update_wallet_tooltip(amount: int) -> void:
	$Header/Balance.tooltip_text = ("Gold: %d\nBuy tower cards or refresh the shop." if TranslationServer.get_locale().begins_with("en") else "金幣：%d\n用於購買塔牌與重刷商店。") % amount

func cycle_speed() -> void:
	if pause_requested or ScreenTransition.active: return
	speed_index = (speed_index+1)%SPEEDS.size()
	if not pause_requested: Engine.time_scale = SPEEDS[speed_index]
	_update_labels()

func set_paused(value: bool) -> void:
	if _returning_home: return
	if is_instance_valid(inspection_owner) and not value: return
	if value == pause_requested: return
	if not value:
		settings_page.hide()
		progress_page.hide()
	$PauseBlocker/Menu.show()
	pause_requested = value
	if value:
		get_tree().paused = true
		Engine.time_scale = 0.0
		_start_was_disabled = early_start.disabled
		early_start.disabled = true
	if _cards != null: _cards.set_pause_locked(value, pause_seconds)
	for button: Button in [speed_button, pause_button]:
		button.disabled = value
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	_fade_pause_menu(value)
	pause_button.set_pressed_no_signal(value)
	_update_labels()
	if value:
		resume_button.grab_focus()
	else:
		get_tree().paused = false
		Engine.time_scale = SPEEDS[speed_index]
		early_start.disabled = _start_was_disabled
		var wave := get_node_or_null("../EnemyWave")
		if wave != null: wave._update_button()
		for button in _menu_buttons: button.release_focus()

func _fade_pause_menu(reveal: bool) -> void:
	if _pause_menu_motion != null: _pause_menu_motion.kill()
	if reveal: pause_menu.show()
	for button in _menu_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if reveal else Control.MOUSE_FILTER_IGNORE
		if not reveal: button.call("clear_hover")
	_pause_menu_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pause_menu_motion.tween_property(pause_menu, "modulate:a", 1.0 if reveal else 0.0, pause_menu_fade_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not reveal:
		_pause_menu_motion.tween_callback(func():
			if not pause_requested: pause_menu.hide())

func _input(event: InputEvent) -> void:
	if ScreenTransition.active:
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(inspection_owner): return
	if _page_open(): return
	if event is InputEventKey:
		var shortcut: int = event.physical_keycode if event.physical_keycode else event.keycode
		if shortcut == KEY_ESCAPE or (shortcut == KEY_TAB and not pause_requested):
			if event.pressed and not event.echo:
				if shortcut == KEY_ESCAPE: set_paused(not pause_requested)
				else: cycle_speed()
			get_viewport().set_input_as_handled()
			return
	if not pause_requested: return
	var camera := get_viewport().get_camera_3d()
	if event is InputEventMouse:
		# Menu input reaches the camera's click/drag arbitration before GUI.
		# The camera delivers ordinary menu clicks without changing gameplay.
		for button in _menu_buttons:
			if button.is_visible_in_tree() and button.call("accepts_pointer", event.position): return
	if camera != null and camera.has_method("handle_navigation_input") and camera.handle_navigation_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if key in [KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and get_viewport().gui_get_focus_owner() in _menu_buttons:
			return
	elif event is InputEventMouse:
		# Deliver release events so dragging out of a menu button clears its press.
		if event is InputEventMouseButton and not event.pressed: return
	get_viewport().set_input_as_handled()

func request_restart() -> void:
	if not pause_requested or ScreenTransition.active: return
	set_paused(false)
	Engine.time_scale = 1.0
	var session := get_parent()
	var error: int = session.restart_level() if session.has_method("restart_level") else get_tree().reload_current_scene()
	if error != OK: push_error("Could not restart the current scene: %s" % error_string(error))

func request_return_home() -> void:
	if not pause_requested or ScreenTransition.active: return
	if not ScreenTransition.change_scene("res://scenes/menus/main_menu.tscn"): return
	_returning_home = true
	_set_settings_navigation_locked(true)
	home_requested.emit()

func _on_transition_finished(error: int) -> void:
	if error != OK and _returning_home:
		_returning_home = false
		_set_settings_navigation_locked(false)

func _exit_tree() -> void:
	_set_settings_navigation_locked(false)
	if _settings_veil_motion != null: _settings_veil_motion.kill()
	if _pause_menu_motion != null: _pause_menu_motion.kill()
	get_tree().paused = false
	Engine.time_scale = 1.0

## Inspection panels borrow the existing HUD pause/hand transition, preserving
## both an already-open pause menu and an external tree pause on return.
func begin_inspection(owner_panel: Node) -> bool:
	if is_instance_valid(inspection_owner): return inspection_owner == owner_panel
	if ScreenTransition.active or _page_open() or _returning_home: return false
	if get_parent().get("choosing_relic") == true or get_parent().get("finished") == true: return false
	_inspection_was_requested = pause_requested
	_inspection_was_paused = get_tree().paused
	_inspection_scale = Engine.time_scale
	_inspection_focus = get_viewport().gui_get_focus_owner()
	set_paused(true)
	inspection_owner = owner_panel
	$PauseBlocker/Menu.hide()
	_set_settings_navigation_locked(true)
	return true

func end_inspection(owner_panel: Node) -> void:
	if inspection_owner != owner_panel: return
	inspection_owner = null
	_set_settings_navigation_locked(false)
	set_paused(_inspection_was_requested)
	$PauseBlocker/Menu.visible = _inspection_was_requested
	if not _inspection_was_requested:
		get_tree().paused = _inspection_was_paused
		Engine.time_scale = _inspection_scale
	if is_instance_valid(_inspection_focus) and _inspection_focus.is_visible_in_tree(): _inspection_focus.grab_focus()
	_inspection_focus = null

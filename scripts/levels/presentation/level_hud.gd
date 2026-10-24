extends CanvasLayer
## Pause UI keeps processing while the rest of the scene is paused.
signal exit_requested
const SPEEDS := [1.0, 2.0, 4.0]
const StartCallout = preload("res://scenes/levels/components/start_wave_callout.tscn")
var start_callouts: Array[Button] = []
var start_markers: Array[Node3D] = []
const PauseIcon = preload("res://assets/sprites/interface/pause.png")
const SPEED_ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/interface/speed_1x.png"),
	preload("res://assets/sprites/interface/speed_2x.png"),
	preload("res://assets/sprites/interface/speed_4x.png"),
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
@onready var settings_button: Button = $PauseBlocker/Menu/Margin/Actions/Settings/Button
@onready var exit_button: Button = $PauseBlocker/Menu/Margin/Actions/Exit/Button
@onready var _menu_buttons: Array[Button] = [resume_button, restart_button, settings_button, exit_button]
@onready var _cards: Node = get_node_or_null("../CardPlacement")

func _ready() -> void:
	start_callouts = [early_start]
	start_markers = [start_marker]
	speed_button.pressed.connect(cycle_speed)
	pause_button.pressed.connect(func(): set_paused(not pause_requested))
	resume_button.pressed.connect(set_paused.bind(false))
	restart_button.pressed.connect(request_restart)
	exit_button.pressed.connect(request_exit)
	pause_menu.hide()
	pause_menu.modulate.a = 0.0
	Engine.time_scale = SPEEDS[speed_index]
	_update_labels()
	_position_callout()

func _process(_delta: float) -> void:
	_position_callout()

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
	var hover: float = action.get("hover_amount")
	var center := tower.lerp(rest+action.size*0.5, _callout_reveal)-Vector2(0, hover*2.0)
	action.pivot_offset = action.size*0.5
	action.position = center-action.size*0.5
	action.scale = Vector2.ONE*maxf(0.001, _callout_reveal)*lerpf(1.0, 1.035, hover)
	action.modulate.a = minf(1.0, _callout_reveal*2.0)
	# Each entrance independently follows/clips against the moving camera.
	action.visible = viewport.get_visible_rect().intersects(action.get_global_rect())

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _update_labels()

func _update_labels() -> void:
	speed_button.text = ""
	speed_button.icon = SPEED_ICONS[speed_index]
	pause_button.icon = PauseIcon
	resume_button.text = tr("ui.pause.resume")
	restart_button.text = tr("ui.pause.restart")
	settings_button.text = tr("ui.pause.settings")
	exit_button.text = tr("ui.pause.exit")

func cycle_speed() -> void:
	if pause_requested: return
	speed_index = (speed_index+1)%SPEEDS.size()
	if not pause_requested: Engine.time_scale = SPEEDS[speed_index]
	_update_labels()

func set_paused(value: bool) -> void:
	if value == pause_requested: return
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
		if key == KEY_ESCAPE and event.pressed and not event.echo:
			set_paused(false)
		elif key in [KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and get_viewport().gui_get_focus_owner() in _menu_buttons:
			return
	elif event is InputEventMouse:
		# Deliver release events so dragging out of a menu button clears its press.
		if event is InputEventMouseButton and not event.pressed: return
	get_viewport().set_input_as_handled()

func request_restart() -> void:
	if not pause_requested: return
	set_paused(false)
	Engine.time_scale = 1.0
	var error := get_tree().reload_current_scene()
	if error != OK: push_error("Could not restart the current scene: %s" % error_string(error))

func request_exit() -> void:
	if _pause_menu_motion != null: _pause_menu_motion.kill()
	pause_requested = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	exit_requested.emit()
	get_tree().quit()

func _exit_tree() -> void:
	if _pause_menu_motion != null: _pause_menu_motion.kill()
	get_tree().paused = false
	Engine.time_scale = 1.0

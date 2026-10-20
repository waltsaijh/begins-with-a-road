extends CanvasLayer
## Pause UI keeps processing while the rest of the scene is paused.
signal exit_requested
@export var early_reward_scene: PackedScene = preload("res://scenes/levels/components/early_start_reward.tscn")
const SPEEDS := [1.0, 2.0, 4.0]
const PauseIcon = preload("res://assets/sprites/interface/pause.png")
const PlayIcon = preload("res://assets/sprites/interface/play.png")
const SPEED_ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/interface/speed_1x.png"),
	preload("res://assets/sprites/interface/speed_2x.png"),
	preload("res://assets/sprites/interface/speed_4x.png"),
]
var speed_index := 0
var _start_was_disabled := false
## Player input locks immediately; simulation decelerates before the tree freezes.
@export_range(0.01, 1.0, 0.01) var pause_seconds := 0.25
@export_range(0.01, 1.0, 0.01) var pause_menu_fade_seconds := 0.25
var pause_requested := false
var _pause_motion: Tween
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
@onready var resume_button: Button = $PauseBlocker/Menu/Margin/Actions/Resume
@onready var exit_button: Button = $PauseBlocker/Menu/Margin/Actions/Exit
@onready var _cards: Node = get_node_or_null("../CardPlacement")

func _ready() -> void:
	speed_button.pressed.connect(cycle_speed)
	pause_button.pressed.connect(func(): set_paused(not pause_requested))
	resume_button.pressed.connect(set_paused.bind(false))
	exit_button.pressed.connect(request_exit)
	pause_menu.hide()
	pause_menu.modulate.a = 0.0
	Engine.time_scale = SPEEDS[speed_index]
	_update_labels()
	_position_callout()

func _process(_delta: float) -> void:
	_position_callout()

func set_preparation(remaining: float, duration: float, available: bool) -> void:
	early_start.mouse_filter = Control.MOUSE_FILTER_STOP if available else Control.MOUSE_FILTER_IGNORE
	if _callout_available != available:
		_callout_available = available
		_animate_callout(available)
	early_start.call("set_preparation", remaining, duration)
	_position_callout()

func _animate_callout(reveal: bool) -> void:
	if _callout_motion != null: _callout_motion.kill()
	if not reveal: early_start.call("clear_hover")
	var target := 1.0 if reveal else 0.0
	if is_equal_approx(_callout_reveal, target): return
	_callout_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_callout_motion.tween_property(self, "_callout_reveal", target, start_reveal_seconds if reveal else start_retract_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if reveal else Tween.EASE_IN)

func _position_callout() -> void:
	if pause_requested: early_start.disabled = true
	var camera := get_viewport().get_camera_3d()
	if _callout_reveal <= 0.001 or start_marker == null or camera == null:
		early_start.hide()
		return
	var anchor := start_marker.global_position+Vector3.UP*start_anchor_height
	if camera.is_position_behind(anchor):
		early_start.hide()
		return
	var point := camera.unproject_position(anchor)
	var rest := point-Vector2(early_start.size.x*0.5, early_start.size.y+start_anchor_gap)
	var tower := camera.unproject_position(start_marker.global_position+Vector3.UP*start_collapse_height)
	var hover: float = early_start.get("hover_amount")
	var center := tower.lerp(rest+early_start.size*0.5, _callout_reveal)-Vector2(0, hover*2.0)
	early_start.pivot_offset = early_start.size*0.5
	early_start.position = center-early_start.size*0.5
	early_start.scale = Vector2.ONE*maxf(0.001, _callout_reveal)*lerpf(1.0, 1.035, hover)
	early_start.modulate.a = minf(1.0, _callout_reveal*2.0)
	# Let the viewport clip partial bubbles instead of hiding the whole control.
	early_start.visible = get_viewport().get_visible_rect().intersects(early_start.get_global_rect())

func show_early_reward(amount: int) -> void:
	if amount <= 0 or not early_start.visible: return
	var label := early_reward_scene.instantiate() as Label
	label.text = "+%d" % amount
	$WorldActions.add_child(label)
	label.reset_size()
	label.position = early_start.position+Vector2((early_start.size.x-label.size.x)*0.5, -label.size.y)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y-24.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(label.queue_free)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _update_labels()

func _update_labels() -> void:
	speed_button.text = ""
	speed_button.icon = SPEED_ICONS[speed_index]
	pause_button.icon = PlayIcon if pause_requested else PauseIcon
	resume_button.text = tr("ui.pause.resume")
	exit_button.text = tr("ui.pause.exit")

func cycle_speed() -> void:
	speed_index = (speed_index+1)%SPEEDS.size()
	if not pause_requested: Engine.time_scale = SPEEDS[speed_index]
	_update_labels()

func set_paused(value: bool) -> void:
	if value == pause_requested: return
	pause_requested = value
	if _pause_motion != null: _pause_motion.kill()
	if value:
		_start_was_disabled = early_start.disabled
		early_start.disabled = true
	if _cards != null: _cards.set_pause_locked(value)
	_fade_pause_menu(value)
	pause_button.set_pressed_no_signal(value)
	_update_labels()
	if value:
		resume_button.grab_focus()
		_pause_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_pause_motion.tween_method(_set_simulation_scale, Engine.time_scale, 0.0, pause_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pause_motion.tween_callback(_finish_pause)
	else:
		get_tree().paused = false
		Engine.time_scale = SPEEDS[speed_index]
		early_start.disabled = _start_was_disabled
		var wave := get_node_or_null("../EnemyWave")
		if wave != null: wave._update_button()
		resume_button.release_focus()

func _fade_pause_menu(reveal: bool) -> void:
	if _pause_menu_motion != null: _pause_menu_motion.kill()
	if reveal: pause_menu.show()
	for button: Button in [resume_button, exit_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if reveal else Control.MOUSE_FILTER_IGNORE
	_pause_menu_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pause_menu_motion.tween_property(pause_menu, "modulate:a", 1.0 if reveal else 0.0, pause_menu_fade_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not reveal:
		_pause_menu_motion.tween_callback(func():
			if not pause_requested: pause_menu.hide())

func _set_simulation_scale(value: float) -> void:
	Engine.time_scale = value

func _finish_pause() -> void:
	if not pause_requested: return
	Engine.time_scale = 0.0
	get_tree().paused = true

func _input(event: InputEvent) -> void:
	if not pause_requested: return
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("handle_navigation_input") and camera.handle_navigation_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if key == KEY_ESCAPE and event.pressed and not event.echo:
			set_paused(false)
		elif key in [KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and get_viewport().gui_get_focus_owner() in [resume_button, exit_button]:
			return
	elif event is InputEventMouse:
		for button: Button in [resume_button, exit_button, speed_button, pause_button]:
			if button.is_visible_in_tree() and button.get_global_rect().has_point(event.position): return
		# Deliver release events so dragging out of a menu button clears its press.
		if event is InputEventMouseButton and not event.pressed: return
	get_viewport().set_input_as_handled()

func request_exit() -> void:
	if _pause_motion != null: _pause_motion.kill()
	if _pause_menu_motion != null: _pause_menu_motion.kill()
	pause_requested = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	exit_requested.emit()
	get_tree().quit()

func _exit_tree() -> void:
	if _pause_motion != null: _pause_motion.kill()
	if _pause_menu_motion != null: _pause_menu_motion.kill()
	get_tree().paused = false
	Engine.time_scale = 1.0

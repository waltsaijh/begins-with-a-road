extends CardButton

const INK := Color("315956")
const BORDER := Color("98ada1")
const GOLD := Color("785d2a")
const RISK := Color("874f46")

var scroll_area: ScrollContainer
var entry_offset := 0.0:
	set(value):
		entry_offset = value
		_update_offset()

var _lift := 0.0:
	set(value):
		_lift = value
		_update_offset()
var _paper_style: StyleBoxFlat
var _art_style: StyleBoxFlat
var _motion: Tween
var _locked := false
var _over := false
var _pressed_inside := false
var _unavailable := false
var _summary_color := INK

@onready var visuals: Control = $Visuals
@onready var paper: PanelContainer = %Paper
@onready var art: TextureRect = %Art
@onready var title: Label = %Title
@onready var effect: Label = %Effect
@onready var footer: VBoxContainer = %Footer
@onready var summary: Label = %Summary
@onready var reason: Label = %Reason
@onready var illustration: PanelContainer = %Illustration

func _ready() -> void:
	_paper_style = paper.get_theme_stylebox("panel").duplicate()
	paper.add_theme_stylebox_override("panel", _paper_style)
	_art_style = illustration.get_theme_stylebox("panel").duplicate()
	illustration.add_theme_stylebox_override("panel", _art_style)
	resized.connect(func(): visuals.pivot_offset = size * 0.5)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	focus_entered.connect(_animate)
	focus_exited.connect(_animate)
	button_down.connect(_set_pressed_inside.bind(true))
	button_up.connect(_set_pressed_inside.bind(false))

func _has_point(point: Vector2) -> bool:
	if _locked or not super._has_point(point):
		return false
	if scroll_area == null:
		return true
	var canvas_point := get_global_transform_with_canvas() * point
	var scroll_point := scroll_area.get_global_transform_with_canvas().affine_inverse() * canvas_point
	return Rect2(Vector2.ZERO, scroll_area.size).has_point(scroll_point)

func show_option(option_title: String, description: String, texture: Texture2D, summary_text: String, summary_color: Color, tint: Color) -> void:
	title.text = option_title
	effect.text = description
	art.texture = texture
	summary.text = summary_text
	_summary_color = summary_color
	_art_style.bg_color = tint
	accessibility_name = option_title

func set_availability(message: String) -> void:
	_unavailable = not message.is_empty()
	reason.text = message
	reason.visible = _unavailable
	summary.add_theme_color_override("font_color", RISK if _unavailable else _summary_color)
	art.modulate = Color(0.72, 0.72, 0.72, 0.62) if _unavailable else Color.WHITE
	mouse_default_cursor_shape = Control.CURSOR_ARROW if _unavailable else Control.CURSOR_POINTING_HAND
	var screen_reader_text := PackedStringArray([effect.text, summary.text])
	if _unavailable:
		screen_reader_text.append(message)
	accessibility_description = "\n".join(screen_reader_text)
	disabled = _locked or _unavailable
	if _unavailable and has_focus():
		release_focus()
	_animate()

func unlock() -> void:
	_locked = false
	_pressed_inside = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_over = is_hovered()
	_stop_motion()
	visuals.scale = Vector2.ONE
	_lift = 0.0

func lock_for_exit(selected: bool) -> void:
	_locked = true
	_stop_motion()
	disabled = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	release_focus()
	if selected:
		_paper_style.border_color = INK
		_paper_style.shadow_size = 8

func _set_hover(value: bool) -> void:
	_over = value
	if value and not disabled and is_visible_in_tree():
		GameAudio.play_effect(&"card_hover")
	_animate()

func _set_pressed_inside(value: bool) -> void:
	_pressed_inside = value
	_animate()

func _animate() -> void:
	if _locked:
		return
	_stop_motion()
	var raised := _over and not _unavailable
	var pressed_inside := _pressed_inside and (raised or has_focus()) and not _unavailable
	var emphasis := raised or has_focus()
	var rest_color := Color("b1b6a9") if _unavailable else BORDER
	var scale_amount := 1.01 if pressed_inside else (1.03 if raised else 1.0)
	var lift_amount := -4.0 if pressed_inside else (-9.0 if raised else 0.0)
	_motion = create_tween().set_parallel().set_ignore_time_scale(true)
	_motion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var duration := 0.07 if pressed_inside else 0.15
	_motion.tween_property(self, "_lift", lift_amount, duration)
	_motion.tween_property(visuals, "scale", Vector2.ONE * scale_amount, duration)
	_motion.tween_property(_paper_style, "border_color", INK if emphasis else rest_color, duration)
	_motion.tween_property(_paper_style, "shadow_size", 9 if raised else 5, duration)
	_motion.tween_property(_paper_style, "shadow_color:a", 0.25 if raised else 0.16, duration)

func _update_offset() -> void:
	visuals.position.y = entry_offset + _lift

func _stop_motion() -> void:
	if _motion != null:
		_motion.kill()

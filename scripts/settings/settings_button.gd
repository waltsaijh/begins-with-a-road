@tool
extends Button
## Shared text-only interaction for categories, actions and option values.
@export var checkbox := false
@export_range(1.0, 1.5, 0.01) var hover_scale := 1.1
@export_range(0.05, 0.5, 0.01) var hover_seconds := 0.2
@export_range(0.05, 0.5, 0.01) var focus_seconds := 0.2
@export_range(0.0, 10.0, 1.0) var underline_inset := 5.0
var underline := 0.0
var _hover_amount := 0.0
var _last_usec := 0

func _ready() -> void:
	_last_usec = Time.get_ticks_usec()
	mouse_entered.connect(_update_hover)
	mouse_exited.connect(_update_hover)
	resized.connect(_update_pivot)
	_update_pivot()
	_reserve_text_width()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_reserve_text_width.call_deferred()

func _reserve_text_width() -> void:
	# Hover changes the visual transform, never the layout width or font weight.
	var light := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var label := tr(text)
	custom_minimum_size.x = ceilf(light.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 24.0
	queue_redraw()

func _update_hover() -> void:
	if is_hovered() and not disabled:
		add_theme_color_override("font_focus_color", Color.BLACK)
	else:
		remove_theme_color_override("font_focus_color")
	queue_redraw()

func _update_pivot() -> void:
	var x := size.x*0.5
	if alignment == HORIZONTAL_ALIGNMENT_LEFT: x = 12.0
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT: x = size.x-12.0
	pivot_offset = Vector2(x, size.y*0.5)

func _has_point(point: Vector2) -> bool:
	# Retain the unscaled hit area as well as the enlarged visual bounds.
	return Rect2(Vector2.ZERO, size).has_point(point) or Rect2(position, size).has_point(get_transform()*point)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var seconds := float(now - _last_usec) / 1000000.0
	_last_usec = now
	var hovering := is_visible_in_tree() and is_hovered() and not disabled
	_hover_amount = move_toward(_hover_amount, 1.0 if hovering else 0.0, seconds/maxf(0.01, hover_seconds))
	var hover_eased := _hover_amount*_hover_amount*(3.0-2.0*_hover_amount)
	scale = Vector2.ONE*lerpf(1.0, hover_scale, hover_eased)
	# A toggle's underline represents its value, even while it retains focus.
	var active := not disabled and (button_pressed if toggle_mode else has_focus())
	var next := move_toward(underline, 1.0 if active else 0.0, seconds / maxf(0.01, focus_seconds))
	if not is_equal_approx(next, underline):
		underline = next
		queue_redraw()

func _draw() -> void:
	var state := "font_focus_color" if has_focus() or button_pressed else "font_color"
	if is_hovered(): state = "font_hover_color"
	var color := get_theme_color(state)
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var width := font.get_string_size(tr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var content_width := width
	var left := 12.0 if alignment == HORIZONTAL_ALIGNMENT_LEFT else (size.x-content_width)*0.5
	var eased := underline*underline*(3.0-2.0*underline)
	if eased > 0.0:
		var center := left+content_width*0.5
		draw_line(Vector2(center-content_width*eased*0.5, size.y-underline_inset), Vector2(center+content_width*eased*0.5, size.y-underline_inset), color, 1.0, true)

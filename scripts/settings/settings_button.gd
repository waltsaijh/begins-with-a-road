@tool
extends Button
## Shared text-only interaction for categories, actions and option values.
@export var checkbox := false
@export_range(0.05, 0.5, 0.01) var focus_seconds := 0.2
@export_range(0.0, 10.0, 1.0) var underline_inset := 5.0
var underline := 0.0
var _last_usec := 0

func _ready() -> void:
	_last_usec = Time.get_ticks_usec()
	mouse_entered.connect(_update_hover)
	mouse_exited.connect(_update_hover)
	_reserve_text_width()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_reserve_text_width.call_deferred()

func _reserve_text_width() -> void:
	# Reserve translated text width without changing font weight on hover.
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

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var seconds := float(now - _last_usec) / 1000000.0
	_last_usec = now
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

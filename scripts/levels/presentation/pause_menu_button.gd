extends Button
## Animate within a fixed row so hover never abandons the original hit area.
@export_range(0.0, 48.0, 1.0) var hover_shift := 12.0
@export_range(0.05, 1.0, 0.01) var hover_seconds := 0.2
var _motion: Tween
var _amount := 0.0:
	set(value):
		_amount = value
		_update_transform()

func _ready() -> void:
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(clear_hover)
	resized.connect(_update_transform)
	_update_transform()

func clear_hover() -> void:
	_set_hover(false)

func _set_hover(value: bool) -> void:
	if _motion != null: _motion.kill()
	var active := value and not disabled and mouse_filter != Control.MOUSE_FILTER_IGNORE
	if active:
		add_theme_color_override("font_focus_color", Color.BLACK)
	else:
		remove_theme_color_override("font_focus_color")
	var target := 1.0 if active else 0.0
	_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_motion.tween_property(self, "_amount", target, hover_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _update_transform() -> void:
	position.x = -hover_shift*_amount

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point) or Rect2(Vector2.ZERO, get_parent().size).has_point(get_transform()*point)

func accepts_pointer(point: Vector2) -> bool:
	return _has_point(get_global_transform_with_canvas().affine_inverse()*point)

@tool
extends Button
## Speech-bubble start action; its border follows the authoritative preparation clock.
@export_range(0.0, 1.0, 0.01) var border_fraction := 1.0:
	set(value):
		border_fraction = clampf(value, 0.0, 1.0)
		_update_visuals()
var hover_amount := 0.0:
	set(value):
		hover_amount = value
		_update_visuals()
@export var design_size := Vector2(128, 46)
@export var hover_background := Color("dcece7")
@export var hover_border := Color("3f7378")
@export var pressed_border := Color("315c61")
@export var hover_width_multiplier := 1.35
var _hover_motion: Tween
var _background: Color
var _border: Color
var _border_width: float

func _ready() -> void:
	_background = $Shape/Background.color
	_border = $Shape/Countdown.default_color
	_border_width = $Shape/Countdown.width
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	resized.connect(_update_visuals)
	button_down.connect(_update_visuals)
	button_up.connect(_update_visuals)
	_refresh_labels()
	_update_visuals()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh_labels()

func set_preparation(remaining: float, duration: float) -> void:
	border_fraction = remaining/maxf(duration, 0.001)

func clear_hover() -> void:
	_set_hover(false)

func _set_hover(hovered: bool) -> void:
	if _hover_motion != null: _hover_motion.kill()
	_hover_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_hover_motion.tween_property(self, "hover_amount", 1.0 if hovered and not disabled else 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _refresh_labels() -> void:
	var title := get_node_or_null("Title") as Label
	if title != null:
		title.text = tr("ui.wave.start_now")

func _outline() -> PackedVector2Array:
	return $Shape/Background.polygon

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point/$Shape.scale, _outline())

func _update_visuals() -> void:
	if not is_node_ready(): return
	$Shape.scale = size/design_size.max(Vector2.ONE)
	var edge := _outline()
	$Shape/Background.color = _background.lerp(Color(hover_background, _background.a), hover_amount)
	$Shape/Outline.points = edge
	var color := _border.lerp(hover_border, hover_amount)
	if disabled: color.a = 0.35
	elif is_pressed(): color = pressed_border
	var perimeter := 0.0
	for i in edge.size()-1: perimeter += edge[i].distance_to(edge[i+1])
	var remaining := perimeter*border_fraction
	var points := PackedVector2Array()
	if not edge.is_empty(): points.append(edge[0])
	for i in edge.size()-1:
		if remaining <= 0.0: break
		var length := edge[i].distance_to(edge[i+1])
		points.append(edge[i].lerp(edge[i+1], minf(1.0, remaining/maxf(0.001, length))))
		remaining -= length
	$Shape/Countdown.points = points
	$Shape/Countdown.default_color = color
	$Shape/Countdown.width = _border_width*lerpf(1.0, hover_width_multiplier, hover_amount)

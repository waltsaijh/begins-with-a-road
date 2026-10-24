@tool
extends Button
## Speech-bubble action for manually starting the next wave.
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
var _hovered := false

func _ready() -> void:
	_background = $Shape/Background.color
	_border = $Shape/Border.default_color
	_border_width = $Shape/Border.width
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	resized.connect(_update_visuals)
	button_down.connect(_update_visuals)
	button_up.connect(_update_visuals)
	_refresh_labels()
	_update_visuals()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh_labels()

func clear_hover() -> void:
	_animate_hover(false)

func update_pointer_hover() -> void:
	var control := get_viewport().gui_get_hovered_control()
	_animate_hover(is_visible_in_tree() and not disabled and control != null and (control == self or is_ancestor_of(control)))

func set_intel_height(height: float) -> void:
	custom_minimum_size = Vector2(216, 44+height)
	size = custom_minimum_size
	$Title.offset_bottom = 31.0
	_update_visuals()

func _set_hover(hovered: bool) -> void:
	_animate_hover(hovered and not disabled)

func _animate_hover(hovered: bool) -> void:
	if _hovered == hovered: return
	_hovered = hovered
	if _hover_motion != null: _hover_motion.kill()
	_hover_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_hover_motion.tween_property(self, "hover_amount", 1.0 if hovered and not disabled else 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _refresh_labels() -> void:
	var title := get_node_or_null("Title") as Label
	if title != null:
		title.text = tr("ui.wave.start_next")

func _outline() -> PackedVector2Array:
	return $Shape/Background.polygon

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point/$Shape.scale, _outline())

func _update_visuals() -> void:
	if not is_node_ready(): return
	$Shape.scale = Vector2.ONE
	var w := size.x
	var h := size.y-9.5
	var edge := PackedVector2Array([
		Vector2(w*0.5, 1.5), Vector2(w-5.5, 1.5), Vector2(w-1.5, 5.5),
		Vector2(w-1.5, h-4), Vector2(w-5.5, h), Vector2(w*0.5+5, h),
		Vector2(w*0.5, size.y-1.5), Vector2(w*0.5-5, h), Vector2(5.5, h),
		Vector2(1.5, h-4), Vector2(1.5, 5.5), Vector2(5.5, 1.5), Vector2(w*0.5, 1.5)])
	$Shape/Background.polygon = edge
	$Shape/Background.color = _background.lerp(Color(hover_background, _background.a), hover_amount)
	var color := _border.lerp(hover_border, hover_amount)
	if disabled: color.a = 0.35
	elif is_pressed(): color = pressed_border
	$Shape/Border.points = edge
	$Shape/Border.default_color = color
	$Shape/Border.width = _border_width*lerpf(1.0, hover_width_multiplier, hover_amount)

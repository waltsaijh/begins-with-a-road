@tool
extends Button
## Diamond action with hover-only next-wave details; the icon anchor stays fixed.
var hover_amount := 0.0:
	set(value):
		hover_amount = value
		_update_visuals()
@export var design_size := Vector2(48, 48)
@export var hover_background := Color("dcece7")
@export var hover_border := Color("3f7378")
@export var pressed_border := Color("315c61")
@export var hover_width_multiplier := 1.35
var _hover_motion: Tween
var _background: Color
var _border: Color
var _border_width: float
var _hovered := false
var _intel_available := false
var _intel_height := 38.0
var _pointer_position := Vector2.ZERO
var _pointer_known := false

func _ready() -> void:
	_background = $Shape/Background.color
	_border = $Shape/Border.default_color
	_border_width = $Shape/Border.width
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	resized.connect(_update_visuals)
	button_down.connect(_update_visuals)
	button_up.connect(_update_visuals)
	# Editor scene previews use a SubViewport without Window mouse signals.
	var viewport := get_viewport()
	if viewport.has_signal("mouse_exited"):
		viewport.connect("mouse_exited",_forget_pointer)
	_refresh_labels()
	_update_visuals()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh_labels()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready(): _forget_pointer()

func clear_hover() -> void:
	_animate_hover(false)

func _forget_pointer() -> void:
	_pointer_known = false
	clear_hover()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		# Use the viewport event coordinates, including forwarded/embedded input.
		_pointer_position = event.position
		_pointer_known = true

func update_pointer_hover() -> void:
	var control := get_viewport().gui_get_hovered_control()
	var owned := control != null and (control == self or is_ancestor_of(control))
	# Moving into a child or the unpainted bridge can emit mouse_exited on the
	# Button before GUI hover ownership is settled. Preserve the expanded region
	# using pointer geometry, but let unrelated controls above us own their input.
	var unobstructed := control == null or owned or control.is_ancestor_of(self)
	var local := get_global_transform_with_canvas().affine_inverse()*_pointer_position
	var inside := _pointer_known and _has_point(local)
	_animate_hover(is_visible_in_tree() and not disabled and inside and unobstructed)

func set_intel_height(height: float) -> void:
	_intel_height = height
	custom_minimum_size = design_size
	size = design_size
	var left := (size.x-216.0)*0.5
	$Title.offset_left = left
	$Title.offset_right = left+216
	$Title.offset_top = -height-42
	$Title.offset_bottom = -height-10
	$NextWaveIntel.offset_left = left+8
	$NextWaveIntel.offset_right = left+208-size.x
	$NextWaveIntel.offset_top = -height-10
	$NextWaveIntel.offset_bottom = -10
	_update_visuals()

func set_intel_available(available: bool) -> void:
	if _intel_available == available: return
	_intel_available = available
	if not available: _forget_pointer()
	_update_visuals()

func _set_hover(hovered: bool) -> void:
	if hovered: _animate_hover(not disabled)
	else: update_pointer_hover.call_deferred()

func _animate_hover(hovered: bool) -> void:
	if _hovered == hovered: return
	_hovered = hovered
	_update_visuals()
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
	if _hovered and _intel_available and not disabled:
		return Rect2(Vector2((size.x-216)*0.5,-_intel_height-44),Vector2(216,_intel_height+44+size.y)).has_point(point)
	return Geometry2D.is_point_in_polygon(point/$Shape.scale, _outline())

func _update_visuals() -> void:
	if not is_node_ready(): return
	$Shape.scale = Vector2.ONE
	var w := size.x
	var edge := PackedVector2Array([Vector2(w*0.5,1.5),Vector2(w-1.5,size.y*0.5),Vector2(w*0.5,size.y-1.5),Vector2(1.5,size.y*0.5),Vector2(w*0.5,1.5)])
	$Shape/Background.polygon = edge
	$Shape/Background.color = _background.lerp(Color(hover_background, _background.a), hover_amount)
	var color := _border.lerp(hover_border, hover_amount)
	if disabled: color.a = 0.35
	elif is_pressed(): color = pressed_border
	$Shape/Border.points = edge
	$Shape/Border.default_color = color
	$Shape/Border.width = _border_width*lerpf(1.0, hover_width_multiplier, hover_amount)
	var expanded := _hovered and _intel_available and not disabled
	$DetailsShape.visible = expanded
	$Title.visible = expanded
	$NextWaveIntel.visible = expanded
	var left := (w-216)*0.5
	var top := -_intel_height-44
	var details := PackedVector2Array([Vector2(left+4,top),Vector2(left+212,top),Vector2(left+216,top+4),Vector2(left+216,-8),Vector2(w*0.5+5,-8),Vector2(w*0.5,-2),Vector2(w*0.5-5,-8),Vector2(left,-8),Vector2(left,top+4),Vector2(left+4,top)])
	$DetailsShape/Background.polygon = details
	$DetailsShape/Background.color = $Shape/Background.color
	$DetailsShape/Border.points = details
	$DetailsShape/Border.default_color = color

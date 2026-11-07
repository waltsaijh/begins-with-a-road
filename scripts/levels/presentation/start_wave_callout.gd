@tool
extends Button
## The shared speech bubble encloses its start label and entrance troop icons.
const CONTENT_PADDING := Vector2(12, 8)
const TAIL_HEIGHT := 8.0
@export var hover_background := Color("dcece7")
@export var hover_border := Color("3f7378")
var hover_amount := 0.0:
	set(value):
		hover_amount = value
		_update_visuals()
var _hover_motion: Tween
var _hovered := false
var _intel_available := false
var _pointer_position := Vector2.ZERO
var _pointer_known := false
var _intel_size := Vector2(34, 34)
var _background: Color
var _border: Color

func _ready() -> void:
	_background = $Shape/Background.color
	_border = $Shape/Border.default_color
	resized.connect(_update_frame)
	_refresh_labels()
	_update_visuals()
	if Engine.is_editor_hint(): return
	mouse_entered.connect(update_pointer_hover)
	mouse_exited.connect(func(): update_pointer_hover.call_deferred())
	var viewport := get_viewport()
	if viewport.has_signal("mouse_exited"):
		viewport.connect("mouse_exited", _forget_pointer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _refresh_labels()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready(): _forget_pointer()

func clear_hover() -> void:
	if Engine.is_editor_hint(): return
	_animate_hover(false)
	$NextWaveIntel.clear_filter()

func _forget_pointer() -> void:
	_pointer_known = false
	clear_hover()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer_position = event.position
		_pointer_known = true

func update_pointer_hover() -> void:
	var control := get_viewport().gui_get_hovered_control()
	var owned := control != null and (control == self or is_ancestor_of(control))
	var unobstructed := control == null or owned or control.is_ancestor_of(self)
	var local := get_global_transform_with_canvas().affine_inverse()*_pointer_position
	var inside := _pointer_known and Rect2(Vector2.ZERO, size).has_point(local)
	_animate_hover(is_visible_in_tree() and _intel_available and not disabled and inside and unobstructed)
	$NextWaveIntel.set_interactive(_intel_available and not disabled)

func set_intel_size(value: Vector2) -> void:
	_intel_size = value
	_update_layout()

func _update_layout() -> void:
	if not is_node_ready(): return
	var width := maxf($Title.get_combined_minimum_size().x, _intel_size.x)+CONTENT_PADDING.x*2
	custom_minimum_size = Vector2(maxf(144,width), CONTENT_PADDING.y*2+30+_intel_size.y+TAIL_HEIGHT)
	size = custom_minimum_size
	$Title.offset_left = CONTENT_PADDING.x
	$Title.offset_top = CONTENT_PADDING.y
	$Title.offset_right = size.x-CONTENT_PADDING.x
	$Title.offset_bottom = CONTENT_PADDING.y+26
	$NextWaveIntel.offset_left = CONTENT_PADDING.x
	$NextWaveIntel.offset_top = CONTENT_PADDING.y+30
	$NextWaveIntel.offset_right = size.x-CONTENT_PADDING.x
	$NextWaveIntel.offset_bottom = size.y-CONTENT_PADDING.y-TAIL_HEIGHT
	_update_frame()

func _update_frame() -> void:
	if not is_node_ready(): return
	$Shape.frame_size = size

func set_intel_available(available: bool) -> void:
	if _intel_available == available: return
	_intel_available = available
	if not available: _forget_pointer()
	_update_visuals()

func _animate_hover(hovered: bool) -> void:
	if _hovered == hovered: return
	_hovered = hovered
	if _hover_motion != null: _hover_motion.kill()
	_hover_motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_hover_motion.tween_property(self, "hover_amount", 1.0 if hovered else 0.0, 0.15)

func _refresh_labels() -> void:
	$Title.text = tr("ui.wave.start_next")
	_update_layout()

func _update_visuals() -> void:
	if not is_node_ready(): return
	$Title.visible = _intel_available or Engine.is_editor_hint()
	$NextWaveIntel.visible = _intel_available or Engine.is_editor_hint()
	$Shape.visible = _intel_available or Engine.is_editor_hint()
	$Shape/Background.color = _background.lerp(Color(hover_background,_background.a),hover_amount)
	$Shape/Border.default_color = _border.lerp(hover_border,hover_amount)
	$Title.modulate = Color.WHITE.lerp(Color(0.45, 0.62, 0.62), hover_amount)
	if not Engine.is_editor_hint(): $NextWaveIntel.set_interactive(_intel_available and not disabled)

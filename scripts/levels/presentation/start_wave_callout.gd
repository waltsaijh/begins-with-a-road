@tool
extends Button
## The fixed hit area stays still; only its exclamation artwork swings.
@export_range(0,15,0.5) var swing_degrees := 10.0
@export var swing_cycle := 3.0
var hover_amount := 0.0:
	set(value):
		hover_amount = value
		_update_visuals()
var _hover_motion: Tween
var _hovered := false
var _intel_available := false
var _pointer_position := Vector2.ZERO
var _pointer_known := false
var _intel_size := Vector2(100,26)
var _swing_time := 0.0
var _last_usec := 0

func _ready() -> void:
	resized.connect(_layout_popup)
	$Title.text = "!"
	$Title.pivot_offset = $Title.size*0.5
	$NextWaveIntel.hide()
	_update_visuals()
	_last_usec = Time.get_ticks_usec()
	if Engine.is_editor_hint(): return
	mouse_entered.connect(update_pointer_hover)
	mouse_exited.connect(func(): update_pointer_hover.call_deferred())
	if get_viewport().has_signal("mouse_exited"): get_viewport().connect("mouse_exited",_forget_pointer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready(): _forget_pointer()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer_position = event.position
		_pointer_known = true

func clear_hover() -> void:
	if Engine.is_editor_hint(): return
	_animate_hover(false)
	$NextWaveIntel.clear_filter()

func _forget_pointer() -> void:
	_pointer_known = false
	clear_hover()

func update_pointer_hover() -> void:
	if not is_node_ready(): return
	_layout_popup()
	var control := get_viewport().gui_get_hovered_control()
	var owned := control != null and (control == self or is_ancestor_of(control))
	var unobstructed := control == null or owned or control.is_ancestor_of(self)
	var local := get_global_transform_with_canvas().affine_inverse()*_pointer_position
	var inside := Rect2(Vector2.ZERO,size).has_point(local)
	if _hovered: inside = Rect2(Vector2.ZERO,size).merge($Popup.get_rect()).grow(1).has_point(local)
	var hovered := _pointer_known and is_visible_in_tree() and _intel_available and not disabled and not get_tree().paused and inside and unobstructed
	_animate_hover(hovered)
	$NextWaveIntel.set_interactive(hovered)

func set_intel_size(value: Vector2) -> void:
	_intel_size = value
	_layout_popup()

func _layout_popup() -> void:
	if not is_node_ready(): return
	var extent := _intel_size+Vector2(20,16)
	var at := Vector2((size.x-extent.x)*0.5,size.y+4)
	# Include the gap in the hover rectangle; keep the list inside the viewport.
	var area := get_viewport_rect().grow(-8)
	var global_at := get_global_transform_with_canvas()*at
	global_at.x = clampf(global_at.x,area.position.x,maxf(area.position.x,area.end.x-extent.x))
	if global_at.y+extent.y > area.end.y: global_at.y = get_global_rect().position.y-extent.y-4
	at = get_global_transform_with_canvas().affine_inverse()*global_at
	$Popup.position = at
	$Popup.size = extent
	$NextWaveIntel.position = at+Vector2(10,8)
	$NextWaveIntel.size = _intel_size

func set_intel_available(available: bool) -> void:
	if _intel_available == available: return
	_intel_available = available
	if not available:
		_forget_pointer()
		_swing_time = 0.0
		$Title.rotation = 0.0
	_update_visuals()

func _animate_hover(hovered: bool) -> void:
	if _hovered == hovered: return
	_hovered = hovered
	if not hovered: $NextWaveIntel.clear_filter()
	if _hover_motion != null: _hover_motion.kill()
	_hover_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_hover_motion.tween_property(self,"hover_amount",1.0 if hovered else 0.0,0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_visuals() -> void:
	if not is_node_ready(): return
	$Title.visible = _intel_available or Engine.is_editor_hint()
	$Shape.visible = $Title.visible
	$Title.modulate = Color.WHITE.lerp(Color(0.45,0.62,0.62),hover_amount)
	var reveal := hover_amount > 0.001 and _intel_available and not disabled and not get_tree().paused
	$Popup.visible = reveal
	$NextWaveIntel.visible = reveal
	$Popup.modulate.a = hover_amount
	$NextWaveIntel.modulate.a = hover_amount

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var seconds := minf(0.1,(now-_last_usec)/1000000.0)
	_last_usec = now
	_update_visuals()
	if Engine.is_editor_hint() or get_tree().paused or disabled or not _intel_available or not is_visible_in_tree(): return
	_swing_time += seconds
	var phase := fposmod(_swing_time,maxf(2.0,swing_cycle))
	var angle := 0.0
	if phase < 0.4: angle = lerpf(0.0,-swing_degrees,smoothstep(0.0,0.4,phase))
	elif phase < 1.0: angle = lerpf(-swing_degrees,swing_degrees,smoothstep(0.4,1.0,phase))
	elif phase < 1.5: angle = lerpf(swing_degrees,0.0,smoothstep(1.0,1.5,phase))
	$Title.pivot_offset = $Title.size*0.5
	$Title.rotation_degrees = angle

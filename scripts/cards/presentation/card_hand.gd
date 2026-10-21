extends CanvasLayer
## Responsive hand layout; the placement controller owns inventory and selection.
signal card_selected(index: int)
signal card_drag_started(index: int)
signal card_dropped(index: int, point: Vector2)
const View = preload("res://scenes/cards/components/card_view.tscn")
@export_group("Layout")
@export var vertical_offset := 2.5
@export_range(0.0, 64.0, 1.0) var selected_lift := 24.0
@export_range(0.05, 0.6, 0.01) var selection_seconds := 0.22
## Pointer movement before a hand-card press becomes placement dragging.
@export_range(2.0, 24.0, 1.0) var drag_threshold := 8.0
var views: Array[Button] = []
var collapsed := false
var stowed := false
@onready var _canvas: Control = $Cards
var _motion: Tween
var _selected := -1
var _turns := 0
var _hovered := -1
var _fresh := {}
var _entering := {}
var _interaction_enabled := true
var _drag_candidate: Button
var _drag_start := Vector2.ZERO
var _dragging := false
var _consume_release := false

func setup(cards: Array[BuildCard]) -> void:
	get_viewport().size_changed.connect(_layout.bind(false))
	get_viewport().mouse_exited.connect(func():
		cancel_drag()
		_set_hover(-1))
	set_cards(cards)

func set_cards(cards: Array[BuildCard]) -> void:
	cancel_drag()
	if _motion != null: _motion.kill()
	_hovered = -1
	_fresh.clear()
	_entering.clear()
	for view in views:
		view.hide()
		view.queue_free()
	views.clear()
	for card in cards: _append_view(card)
	show_selection(-1, 0)
	_layout(false)

func _append_view(card: BuildCard) -> Button:
	var view: Button = View.instantiate()
	view.card = card
	view.pressed.connect(func(): card_selected.emit(views.find(view)))
	_canvas.add_child(view)
	views.append(view)
	_refresh_order()
	return view

func _refresh_order() -> void:
	for i in views.size():
		views[i].key_number = i+1
		views[i].show_shortcut = i < 9

func append_card(card: BuildCard) -> void:
	var view := _append_view(card)
	_fresh[view] = true
	_entering[view] = true
	_hovered = -1
	_layout(true)

func remove_card(index: int) -> void:
	cancel_drag()
	var view := views[index]
	_fresh.erase(view)
	_entering.erase(view)
	views.remove_at(index)
	view.hide()
	view.queue_free()
	_hovered = -1
	_refresh_order()
	_layout(true)

func set_collapsed(value: bool) -> void:
	if value: cancel_drag()
	collapsed = value
	_hovered = -1
	show_selection(_selected, _turns)
	_layout(true)

func set_stowed(value: bool) -> void:
	if value: cancel_drag()
	if stowed == value: return
	stowed = value
	_hovered = -1
	_layout(true)

func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	if not value: cancel_drag()

func is_dragging() -> bool:
	return _dragging

func cancel_drag() -> void:
	if _drag_candidate != null: _consume_release = true
	_drag_candidate = null
	_dragging = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: cancel_drag()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_consume_release = false
			if not _interaction_enabled or collapsed or stowed or event.button_mask & MOUSE_BUTTON_MASK_MIDDLE: return
			var index := CardFanLayout.pick(views, event.position, 0, _hovered)
			if index < 0 or views[index].disabled or views[index].mouse_filter == Control.MOUSE_FILTER_IGNORE: return
			_drag_candidate = views[index]
			_drag_start = event.position
			# Own the press before GUI, so dropping never also emits Button.pressed.
			get_viewport().set_input_as_handled()
		elif _drag_candidate != null or _consume_release:
			var index := views.find(_drag_candidate)
			var dropped := _dragging
			cancel_drag()
			_consume_release = false
			get_viewport().set_input_as_handled()
			if index < 0 or not _interaction_enabled or collapsed or stowed: return
			if dropped:
				card_dropped.emit(index, event.position)
			elif CardFanLayout.pick(views, event.position, 0, _hovered) == index:
				card_selected.emit(index)
	elif event is InputEventMouseMotion:
		if _drag_candidate != null:
			if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				cancel_drag()
			elif not _dragging and event.position.distance_to(_drag_start) >= drag_threshold:
				_dragging = true
				card_drag_started.emit(views.find(_drag_candidate))
			# Let pointer motion reach GUI so world previews can detect UI hover.
			return
		if _interaction_enabled and not collapsed and not stowed:
			_set_hover(CardFanLayout.pick(views, event.position, 0, _hovered))

func _set_hover(index: int) -> void:
	if collapsed or stowed or not _entering.is_empty() or index == _hovered: return
	_hovered = index
	_layout(true)

func finish_animation() -> void:
	if _motion != null: _motion.kill()
	_fresh.clear()
	_entering.clear()
	_layout(false)

func _layout(animate: bool, selection_changed := false) -> void:
	if _canvas == null or not is_inside_tree(): return
	if _motion != null: _motion.kill()
	_motion = null
	if views.is_empty():
		_hovered = -1
		_fresh.clear()
		_entering.clear()
		return
	if not animate:
		_fresh.clear()
		_entering.clear()
	var viewport := get_viewport().get_visible_rect().size
	var card_size := ShopConstants.CARD_SIZE
	if not views.is_empty(): card_size = views[0].get_combined_minimum_size()
	var scale_factor := CardFanLayout.CARD_SCALE
	var available := maxf(card_size.x, (viewport.x-480)/scale_factor)
	var step := CardFanLayout.step_for(card_size.x, views.size(), available)
	var base := Vector2(16, viewport.y-card_size.y*scale_factor-24-CardFanLayout.drop_for(views.size(), step)*scale_factor)
	if collapsed: base.y = viewport.y-card_size.y*scale_factor-16
	base.y += vertical_offset
	if stowed: base.y = viewport.y+24
	var duration := CardFanLayout.INSERT_TIME if not _entering.is_empty() else (selection_seconds if selection_changed else CardFanLayout.HOVER_TIME)
	if animate:
		_motion = create_tween().set_ignore_time_scale(true).set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in views.size():
		var target := base+CardFanLayout.offset(i, views.size(), step, -1, card_size)*scale_factor
		var angle := CardFanLayout.angle(i, views.size(), -1)
		if collapsed or stowed: target = base+Vector2(mini(i, 4)*5, -mini(i, 4)*3)*scale_factor
		if collapsed or stowed: angle = 0.0
		views[i].pivot_offset = Vector2(card_size.x*0.5, card_size.y)
		target += views[i].pivot_offset*(scale_factor-1)
		var lift := selected_lift if i == _selected else (CardFanLayout.HOVER_LIFT if i == _hovered else 0.0)
		if collapsed or stowed: lift = 0.0
		target += Vector2.UP.rotated(angle)*lift*scale_factor
		# New acquisitions enter on top of the folded hand and keep that order.
		views[i].z_index = i
		views[i].mouse_filter = Control.MOUSE_FILTER_IGNORE if collapsed or stowed or _entering.has(views[i]) else Control.MOUSE_FILTER_STOP
		if _fresh.erase(views[i]):
			views[i].position = Vector2(target.x, viewport.y+16)
			views[i].rotation = angle
			views[i].scale = Vector2.ONE*scale_factor
		if animate:
			_motion.tween_property(views[i], "position", target, duration)
			_motion.tween_property(views[i], "rotation", angle, duration)
			_motion.tween_property(views[i], "scale", Vector2.ONE*scale_factor, duration)
			_motion.tween_property(views[i], "hover_lift", lift, duration)
		else:
			views[i].position = target
			views[i].rotation = angle
			views[i].scale = Vector2.ONE*scale_factor
			views[i].hover_lift = lift
	if animate:
		_motion.finished.connect(func():
			_entering.clear()
			for view in views: view.mouse_filter = Control.MOUSE_FILTER_IGNORE if collapsed or stowed else Control.MOUSE_FILTER_STOP)

func show_selection(index: int, turns: int) -> void:
	var changed := index != _selected
	_selected = index
	_turns = turns
	for i in views.size():
		views[i].selected = i == index
		views[i].turns = turns if i == index else 0
	if changed: _layout(true, true)

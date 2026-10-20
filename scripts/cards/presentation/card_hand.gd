extends CanvasLayer
## Responsive hand layout; the placement controller owns inventory and selection.
signal card_selected(index: int)
const View = preload("res://scenes/cards/components/card_view.tscn")
@export_group("Layout")
@export var vertical_offset := 2.5
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

func setup(cards: Array[BuildCard]) -> void:
	get_viewport().size_changed.connect(_layout.bind(false))
	get_viewport().mouse_exited.connect(_set_hover.bind(-1))
	set_cards(cards)

func set_cards(cards: Array[BuildCard]) -> void:
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
	collapsed = value
	_hovered = -1
	show_selection(_selected, _turns)
	_layout(true)

func set_stowed(value: bool) -> void:
	if stowed == value: return
	stowed = value
	_hovered = -1
	_layout(true)

func _input(event: InputEvent) -> void:
	if not collapsed and not stowed and event is InputEventMouseMotion:
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

func _layout(animate: bool) -> void:
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
	var duration := CardFanLayout.INSERT_TIME if not _entering.is_empty() else CardFanLayout.HOVER_TIME
	if animate:
		_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in views.size():
		var target := base+CardFanLayout.offset(i, views.size(), step, -1, card_size)*scale_factor
		var angle := CardFanLayout.angle(i, views.size(), -1)
		if collapsed or stowed: target = base+Vector2(mini(i, 4)*5, -mini(i, 4)*3)*scale_factor
		if collapsed or stowed: angle = 0.0
		views[i].pivot_offset = Vector2(card_size.x*0.5, card_size.y)
		target += views[i].pivot_offset*(scale_factor-1)
		views[i].hover_lift = CardFanLayout.HOVER_LIFT if i == _hovered else 0.0
		if i == _hovered: target += Vector2.UP.rotated(angle)*CardFanLayout.HOVER_LIFT*scale_factor
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
		else:
			views[i].position = target
			views[i].rotation = angle
			views[i].scale = Vector2.ONE*scale_factor
	if animate:
		_motion.finished.connect(func():
			_entering.clear()
			for view in views: view.mouse_filter = Control.MOUSE_FILTER_IGNORE if collapsed or stowed else Control.MOUSE_FILTER_STOP)

func show_selection(index: int, turns: int) -> void:
	_selected = index
	_turns = turns
	for i in views.size():
		views[i].selected = i == index
		views[i].turns = turns if i == index else 0

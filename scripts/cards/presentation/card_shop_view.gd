@tool
extends CanvasLayer
## Seven reusable slots animate between a face-down deck and two shop rows.
signal open_requested
signal close_requested
signal purchase_requested(index: int)
signal reroll_requested
const ShopIcon = preload("res://assets/sprites/cards/shop_icon.png")
const RerollIcon = preload("res://assets/sprites/cards/reroll_icon.png")
@export_group("Layout")
@export var vertical_offset := 2.5
@export_group("Artwork")
## Shared by every card price. Original image colors are kept.
@export var coin_texture: Texture2D:
	set(value):
		coin_texture = value
		_refresh_artwork()
## Shared by all seven backs; edit card_back.tscn to adjust nine-patch margins.
@export var card_back_texture: Texture2D:
	set(value):
		card_back_texture = value
		_refresh_artwork()
var opened := false
var available := false
var slots: Array[Control] = []
var _motion: Tween
var _reroll_motion: Tween
var rerolling := false
var _animating := false
var _sold := PackedByteArray()
var _coins := 0
var _reroll_price := 0
var _hovered := -1
var _fresh := {}
var _entering := {}

func _ready() -> void:
	_refresh_artwork()
	if Engine.is_editor_hint(): return
	layer = 4
	for i in $Root/Slots.get_child_count():
		var slot: Control = $Root/Slots.get_child(i)
		slots.append(slot)
		slot.get_node("Face/Back").pressed.connect(_back_pressed.bind(i))
		slot.get_node("Face/Card").pressed.connect(_card_pressed.bind(i-1))
	get_viewport().size_changed.connect(_layout.bind(false, false))
	get_viewport().mouse_exited.connect(_set_hover.bind(-1))
	$Root.hide()

func _refresh_artwork() -> void:
	if not is_node_ready(): return
	for slot: Control in $Root/Slots.get_children():
		slot.get_node("Face/Card").coin_texture = coin_texture
		slot.get_node("Face/Back/Price/Gold").texture = coin_texture
		slot.get_node("Face/Back/Artwork").texture = card_back_texture

func price_view(index: int) -> HBoxContainer:
	var slot: Control = $Root/Slots.get_child(index)
	return slot.get_node("Face/Back/Price") if index == 0 else slot.get_node("Face/Card").get_node("%Price")

func _input(event: InputEvent) -> void:
	if opened and not _animating and event is InputEventMouseMotion:
		_set_hover(CardFanLayout.pick(slots, event.position, 0, _hovered))

func _set_hover(index: int) -> void:
	if not opened or _animating or index == _hovered: return
	_hovered = index
	_layout(true, false, false)

func _unhandled_input(event: InputEvent) -> void:
	if opened and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		# No full-screen Control or overlay: GUI cards handle their own clicks.
		# Consume only the closing click, so it cannot also place a world tile.
		get_viewport().set_input_as_handled()
		close_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if opened and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_requested.emit()
		get_viewport().set_input_as_handled()

func _back_pressed(index: int) -> void:
	if _animating: return
	if not opened: open_requested.emit()
	elif index == 0: reroll_requested.emit()

func _card_pressed(index: int) -> void:
	if opened and not _animating: purchase_requested.emit(index)

func show_offers(offers: Array[BuildCard], prices: PackedInt32Array, sold: PackedByteArray, coins: int, reroll_price: int, insert_offers := false) -> void:
	_hovered = -1
	_sold = sold.duplicate()
	_coins = coins
	_reroll_price = reroll_price
	for i in slots.size():
		var slot := slots[i]
		var price := reroll_price if i == 0 else (prices[i-1] if i-1 < prices.size() else 0)
		if i == 0:
			price_view(i).get_node("Number").text = str(price)
		else:
			var card: Button = slot.get_node("Face/Card")
			card.price_override = price
			card.can_afford = coins >= price
			card.card = offers[i-1] if i-1 < offers.size() else null
			var bought := i-1 < sold.size() and sold[i-1] != 0
			card.disabled = card.card == null or bought or coins < price
			card.modulate = Color(1, 1, 1, 0.6 if coins < price else 1.0)
		_show_face(i, opened)
		if insert_offers and i > 0 and _in_stock(i):
			_fresh[i] = true
			_entering[i] = true
	if opened and available:
		_layout(true, false, false)
		# A second click must not buy/reroll a card moving into the sold slot.
		_animating = true

func animate_reroll() -> void:
	_stop_reroll_animation()
	rerolling = true
	var icon: Control = slots[0].get_node("Face/Back/Icon")
	icon.pivot_offset = icon.size*0.5
	_reroll_motion = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_reroll_motion.tween_property(icon, "rotation", TAU, 0.5)
	_reroll_motion.finished.connect(func():
		icon.rotation = 0.0
		rerolling = false
		_show_face(0, opened))
	_show_face(0, opened)

func _stop_reroll_animation() -> void:
	if _reroll_motion != null: _reroll_motion.kill()
	rerolling = false
	if not slots.is_empty(): slots[0].get_node("Face/Back/Icon").rotation = 0.0

func set_open(value: bool) -> void:
	if value == opened or (value and not available): return
	opened = value
	_hovered = -1
	if not opened: _stop_reroll_animation()
	_layout(true, false)

func set_available(value: bool) -> void:
	if available == value: return
	available = value
	_hovered = -1
	_fresh.clear()
	_entering.clear()
	if value:
		opened = false
		$Root.show()
		_layout(true, true)
	else:
		_stop_reroll_animation()
		if _motion != null: _motion.kill()
		opened = false
		_animating = true
		_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var viewport := get_viewport().get_visible_rect().size
		var scale_factor := CardFanLayout.CARD_SCALE
		var exit := Vector2(viewport.x-ShopConstants.MARGIN-ShopConstants.CARD_SIZE.x*scale_factor, viewport.y+32)
		for i in slots.size():
			_show_face(i, false)
			price_view(i).hide()
			_motion.tween_property(slots[i], "position", exit+ShopConstants.STACK_OFFSET*i*scale_factor+slots[i].pivot_offset*(scale_factor-1), 0.2)
			_motion.tween_property(slots[i], "rotation", 0.0, 0.2)
			_motion.tween_property(slots[i], "scale", Vector2.ONE*scale_factor, 0.2)
		_motion.finished.connect(func():
			_animating = false
			if not available: $Root.hide())

func _show_face(index: int, face_up: bool) -> void:
	var slot := slots[index]
	slot.visible = not face_up or _in_stock(index)
	price_view(index).visible = face_up and _in_stock(index)
	slot.get_node("Face/Card").visible = face_up and index > 0
	slot.get_node("Face/Back").visible = not face_up or index == 0
	var back: Button = slot.get_node("Face/Back")
	back.get_node("Icon").visible = index == 0
	back.get_node("Icon").texture = RerollIcon if face_up else ShopIcon
	var unaffordable := face_up and index == 0 and _coins < _reroll_price
	back.disabled = face_up and index == 0 and (unaffordable or rerolling)
	back.modulate = Color(1, 1, 1, 0.6 if unaffordable else 1.0)

func _in_stock(index: int) -> bool:
	return index == 0 or (slots[index].get_node("Face/Card").card != null and index-1 < _sold.size() and _sold[index-1] == 0)

func active_indices() -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in slots.size():
		if not opened or _in_stock(i): result.append(i)
	return result

func row_indices(upper: bool) -> PackedInt32Array:
	var result := PackedInt32Array()
	for candidate in active_indices():
		if upper == (candidate >= 1 and candidate <= 4): result.append(candidate)
	if result.has(0):
		result.remove_at(result.find(0))
		result.append(0)
	return result

func _layout(animate: bool, entering: bool, flip := true) -> void:
	if not available or not is_inside_tree(): return
	if _motion != null: _motion.kill()
	if not animate:
		_fresh.clear()
		_entering.clear()
	var viewport := get_viewport().get_visible_rect().size
	var card := ShopConstants.CARD_SIZE
	var active := active_indices()
	var step := card.x-CardFanLayout.OVERLAP
	var width := CardFanLayout.width_for(card.x, 4, step)
	var scale_factor := minf(CardFanLayout.CARD_SCALE, (viewport.x-ShopConstants.MARGIN*2)/width) if opened else CardFanLayout.CARD_SCALE
	var base := Vector2(viewport.x-ShopConstants.MARGIN-(width if opened else card.x)*scale_factor, viewport.y-24-card.y*scale_factor+vertical_offset)
	if opened: base.y -= CardFanLayout.drop_for(4, step)*scale_factor
	$Root/ShopArea.position = base-Vector2(16, (card.y+102)*scale_factor if opened else 60)
	$Root/ShopArea.size = Vector2((width if opened else card.x)*scale_factor+32, card.y*scale_factor+(card.y+134)*scale_factor if opened else card.y*scale_factor+68)
	_animating = animate and (flip or not _entering.is_empty())
	var duration := CardFanLayout.INSERT_TIME if not _entering.is_empty() else (ShopConstants.ANIMATION_TIME if flip else CardFanLayout.SHIFT_TIME)
	if animate:
		_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in slots.size():
		var slot := slots[i]
		var rank := active.find(i)
		if opened and rank < 0:
			# The closed deck restores all seven backs. Sold slots must be
			# hidden again before skipping their layout on reopening.
			_show_face(i, true)
			continue
		var face: Control = slot.get_node("Face")
		face.scale = Vector2.ONE
		# Scale around the bottom centre; compensate so the fan stays anchored.
		slot.pivot_offset = Vector2(card.x*0.5, card.y)
		var compensation := slot.pivot_offset*(scale_factor-1)
		var target := base+CardFanLayout.offset(rank, active.size(), step, 1, card)*scale_factor+compensation if opened else base+ShopConstants.STACK_OFFSET*i*scale_factor+compensation
		var angle := 0.0
		if opened:
			var row := row_indices(i >= 1 and i <= 4)
			var row_rank := row.find(i)
			var row_width := CardFanLayout.width_for(card.x,row.size(),step)
			var row_base := base+Vector2((width-row_width)*scale_factor, -(card.y+20)*scale_factor if i >= 1 and i <= 4 else 0.0)
			target = row_base+CardFanLayout.offset(row_rank,row.size(),step,1,card)*scale_factor+compensation
			angle = CardFanLayout.angle(row_rank,row.size(),1)
		var lift := CardFanLayout.HOVER_LIFT if i == _hovered else 0.0
		if lift > 0: target += Vector2.UP.rotated(angle)*lift*scale_factor
		slot.get_node("Face/Card").hover_lift = lift
		slot.get_node("Face/Back").hover_lift = lift
		slot.z_index = (7 if i == 0 else i) if opened else slots.size()-i
		if entering or _fresh.erase(i):
			slot.position = Vector2(target.x, viewport.y+32+i*4)
			slot.scale = Vector2.ONE*scale_factor
			slot.rotation = 0.0
		if animate:
			_motion.tween_property(slot, "position", target, duration)
			_motion.tween_property(slot, "scale", Vector2.ONE*scale_factor, duration)
			_motion.tween_property(slot, "rotation", angle, duration)
			if flip and not entering and i > 0:
				_motion.tween_property(face, "scale:x", 0.0, 0.1)
				_motion.tween_callback(_show_face.bind(i, opened)).set_delay(0.1)
				_motion.tween_property(face, "scale:x", 1.0, 0.12).set_delay(0.1)
			else: _show_face(i, opened)
		else:
			slot.position = target
			slot.scale = Vector2.ONE*scale_factor
			slot.rotation = angle
			_show_face(i, opened)
	if animate:
		_motion.finished.connect(func():
			_animating = false
			_entering.clear())

## Useful for scene previews and deterministic UI checks; normal play uses Tweens.
func finish_animation() -> void:
	if _motion != null: _motion.kill()
	_animating = false
	_fresh.clear()
	_entering.clear()
	if available: _layout(false, false)
	else: $Root.hide()

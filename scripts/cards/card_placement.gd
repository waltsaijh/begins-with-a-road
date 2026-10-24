extends Node3D
signal cards_changed
signal traffic_preview_changed(effect: Dictionary)
var traffic_candidate := {}
## Input orchestration. BuildCard is data, TowerMap is the commit authority.
@export var cards: Array[BuildCard] = []
## Used when no fixed starting cards are authored above.
@export_range(0, 9, 1, "or_greater") var initial_card_count := 3
@onready var placement: Node3D = $"../TilePlacement"
@onready var towers: Node3D = $"../TowerMap"
@onready var controller: Node = $"../PortalMap"
@onready var hand: CanvasLayer = $Hand
@onready var preview: Node3D = $Preview
@onready var rotation_hint: Control = $Hints/RotationKeyHint
var selected := -1
var turns := 0
var _last_cell := TileConstants.INVALID_CELL
var _dirty := true
var _retry := 0.0
var _preview_error := ""
var _preview_definition: Resource
var input_suspended := false
var pause_locked := false
var entry_selection_active := false
var _pause_card_motion: Tween
var _hand_rest_y := 0.0
var _shop_rest_y := 0.0
var _pause_retraction := 0.0:
	set(value):
		_pause_retraction = value
		_position_paused_cards()
var _wave_active := false
var _wave_start_pending := false
var _shop_open := false
var _hint_cell := TileConstants.INVALID_CELL
var _mouse_in_viewport := true

func _ready() -> void:
	cards = cards.duplicate()
	controller.graph_changed.connect(_invalidate)
	towers.traffic.changed.connect(_invalidate)
	towers.tower_upgraded.connect(func(_tower): _invalidate())
	towers.relics.changed.connect(_invalidate)
	preview.relics = towers.relics
	preview.visibility_changed.connect(func():
		if not preview.visible: set_traffic_candidate({}))
	placement.cell_placed.connect(func(_cell: Vector3i): _invalidate())
	var wave := get_node_or_null("../EnemyWave")
	if wave != null:
		wave.routes_changed.connect(_invalidate)
		wave.wave_finished.connect(_invalidate)
		wave.wave_started.connect(_on_wave_started)
		wave.wave_finished.connect(_on_wave_finished)
	$Shop.setup(self, wave)
	if cards.is_empty(): cards.assign($Shop.roll_cards(initial_card_count))
	hand.setup(cards)
	_hand_rest_y = hand.get_node("Cards").position.y
	_shop_rest_y = $Shop/View/Root.position.y
	get_viewport().size_changed.connect(_position_paused_cards)
	hand.card_selected.connect(select_card)
	hand.card_drag_started.connect(_on_card_drag_started)
	hand.card_dropped.connect(_on_card_dropped)
	get_viewport().mouse_entered.connect(func(): _mouse_in_viewport = true)
	get_viewport().mouse_exited.connect(func():
		_mouse_in_viewport = false
		preview.hide()
		_reset_rotation_hint())
	if wave != null and wave.active:
		_on_wave_started()
	set_process(false)

func set_traffic_candidate(effect: Dictionary) -> void:
	if traffic_candidate == effect: return
	traffic_candidate = effect.duplicate(true)
	traffic_preview_changed.emit(traffic_candidate)

func preview_traffic_at(card: BuildCard, cell: Vector3i, rotation_steps: int, valid: bool) -> void:
	set_traffic_candidate(card.traffic.effect_at(Vector2i(cell.x,cell.z),rotation_steps) if valid and card.traffic != null else {})

func select_card(index: int, toggle := true) -> void:
	if input_suspended and index >= 0:
		return
	set_traffic_candidate({})
	if toggle: hand.cancel_drag()
	selected = index if index >= 0 and index < cards.size() and cards[index] != null and (not toggle or index != selected) else -1
	var next_definition: Resource = cards[selected].visual_definition() if selected >= 0 else null
	if _preview_definition != next_definition:
		if is_instance_valid(_preview_definition) and _preview_definition.changed.is_connected(_invalidate):
			_preview_definition.changed.disconnect(_invalidate)
		_preview_definition = next_definition
		if _preview_definition != null: _preview_definition.changed.connect(_invalidate)
	turns = 0
	towers.input_enabled = selected < 0 and not input_suspended
	preview.visible = false
	_reset_rotation_hint()
	_dirty = true
	hand.show_selection(selected, turns)
	set_process(selected >= 0)

func _on_card_drag_started(index: int) -> void:
	if input_suspended:
		hand.cancel_drag()
		return
	# Dragging the selected card preserves its current rotation.
	if selected != index: select_card(index, false)

func _on_card_dropped(index: int, point: Vector2) -> void:
	if input_suspended or selected != index or not _mouse_in_viewport: return
	if not get_viewport().get_visible_rect().has_point(point): return
	if CardButton.has_card_at(get_viewport(), point):
		select_card(-1)
		return
	if get_viewport().gui_get_hovered_control() != null: return
	place_selected(placement.pick_cell(point))

func set_shop_open(value: bool) -> void:
	_shop_open = value
	_refresh_input_state()

func set_entry_selection(value: bool) -> void:
	entry_selection_active = value
	if value: $Shop.close_shop()
	$Shop/View.visible = not value
	_refresh_input_state()

func set_pause_locked(value: bool, seconds := 0.35) -> void:
	if pause_locked == value: return
	pause_locked = value
	input_suspended = pause_locked or entry_selection_active or _wave_active or _wave_start_pending or _shop_open
	hand.set_interaction_enabled(not input_suspended)
	towers.input_enabled = selected < 0 and not input_suspended
	if value:
		preview.hide()
		_reset_rotation_hint()
	if _pause_card_motion != null: _pause_card_motion.kill()
	_pause_card_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pause_card_motion.tween_property(self, "_pause_retraction", 1.0 if value else 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dirty = true
	set_process(selected >= 0 and not input_suspended)

func _position_paused_cards() -> void:
	if not is_node_ready() or not is_inside_tree(): return
	# Move the presentation roots without changing selection, offers or fan layout.
	var offset := (get_viewport().get_visible_rect().size.y+32.0)*_pause_retraction
	hand.get_node("Cards").position.y = _hand_rest_y+offset
	$Shop/View/Root.position.y = _shop_rest_y+offset

func _on_wave_started() -> void:
	_wave_active = true
	_wave_start_pending = false
	_refresh_input_state()

func _on_wave_finished() -> void:
	_wave_active = false
	_refresh_input_state()

func prepare_wave_start() -> void:
	_wave_start_pending = true
	_refresh_input_state()
	$Shop.hide_for_wave_start()

func _refresh_input_state() -> void:
	input_suspended = pause_locked or entry_selection_active or _wave_active or _wave_start_pending or _shop_open
	hand.set_interaction_enabled(not input_suspended)
	select_card(-1)
	hand.set_collapsed(_shop_open)
	hand.set_stowed(entry_selection_active or _wave_active or _wave_start_pending)

func add_card(card: BuildCard) -> bool:
	if card == null or not card.configuration_error().is_empty():
		return false
	select_card(-1)
	cards.append(card)
	hand.append_card(card)
	cards_changed.emit()
	return true

func place_selected(cell: Vector3i) -> Node3D:
	if input_suspended or selected < 0 or selected >= cards.size():
		return null
	var tower: Node3D = towers.place_card(cards[selected], cell, turns)
	if tower == null:
		_dirty = true
		return null
	var removed := selected
	cards.remove_at(removed)
	select_card(-1)
	hand.remove_card(removed)
	cards_changed.emit()
	return tower

func rotate_card(amount: int) -> void:
	if input_suspended or selected < 0:
		return
	turns = posmod(turns+amount, 4)
	_dirty = true
	hand.show_selection(selected, turns)

func _invalidate() -> void:
	_dirty = true

func _unhandled_key_input(event: InputEvent) -> void:
	if input_suspended or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if key >= KEY_1 and key <= KEY_9 and key-KEY_1 < cards.size():
		select_card(key-KEY_1)
	elif selected >= 0 and key == KEY_ESCAPE:
		select_card(-1)
	elif selected >= 0 and key == KEY_R:
		rotate_card(1)
	else:
		return
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if input_suspended or selected < 0 or not event is InputEventMouseButton or not event.pressed or event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		place_selected(placement.pick_cell(event.position))
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		rotate_card(1)
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _mouse_in_viewport or get_viewport().gui_get_hovered_control() != null or not get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position()):
		preview.visible = false
		_reset_rotation_hint()
		_dirty = true
		return
	var cell: Vector3i = placement.pick_cell(get_viewport().get_mouse_position())
	if cell == TileConstants.INVALID_CELL:
		preview.visible = false
		_reset_rotation_hint()
		_dirty = true
		return
	_retry += delta
	# Retry a denied preview as enemies pass. A valid cached preview is still
	# revalidated on click, never trusted as authorization to commit.
	if _dirty or cell != _last_cell or (not _preview_error.is_empty() and _retry >= 0.25):
		_dirty = false
		_last_cell = cell
		_retry = 0.0
		_preview_error = towers.validate_card(cards[selected], cell, turns)
		preview_traffic_at(cards[selected], cell, turns, _preview_error.is_empty())
		if cards[selected].configuration_error().is_empty():
			var target: DefenseTower = towers.upgrade_target(cell) if cards[selected].tower != null else null
			if target != null: preview.show_upgrade(placement.map, target, _preview_error)
			else: preview.show_at(placement.map, cards[selected], cell, turns, _preview_error.is_empty())
		else:
			preview.visible = false
	if preview.visible:
		if preview.upgrade_mode:
			_reset_rotation_hint()
			return
		if cell != _hint_cell:
			_reset_rotation_hint()
			_hint_cell = cell
		rotation_hint.follow(get_viewport().get_camera_3d(), preview.hint_anchor, delta)
	else:
		_reset_rotation_hint()

func _reset_rotation_hint() -> void:
	_hint_cell = TileConstants.INVALID_CELL
	rotation_hint.reset()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready():
		_mouse_in_viewport = false
		preview.hide()
		_reset_rotation_hint()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_mouse_in_viewport = true
		_dirty = true

func _exit_tree() -> void:
	if is_instance_valid(_preview_definition) and _preview_definition.changed.is_connected(_invalidate):
		_preview_definition.changed.disconnect(_invalidate)
	if is_instance_valid(towers):
		towers.input_enabled = true

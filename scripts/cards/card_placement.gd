extends Node3D
signal cards_changed
## Input orchestration. BuildCard is data, TowerMap is the commit authority.
@export var cards: Array[BuildCard] = []
## Used when no fixed starting cards are authored above.
@export_range(0, 9, 1, "or_greater") var initial_card_count := 3
@export_range(0.0, 1.0, 0.05) var paused_cards_opacity := 0.15
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
var input_suspended := false
var pause_locked := false
var entry_selection_active := false
var _hand_pause_color := Color.WHITE
var _shop_pause_color := Color.WHITE
var _wave_active := false
var _wave_start_pending := false
var _shop_open := false
var _hint_cell := TileConstants.INVALID_CELL
var _mouse_in_viewport := true

func _ready() -> void:
	cards = cards.duplicate()
	controller.graph_changed.connect(_invalidate)
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
	hand.card_selected.connect(select_card)
	get_viewport().mouse_entered.connect(func(): _mouse_in_viewport = true)
	get_viewport().mouse_exited.connect(func():
		_mouse_in_viewport = false
		preview.hide()
		_reset_rotation_hint())
	if wave != null and wave.active:
		_on_wave_started()
	set_process(false)

func select_card(index: int) -> void:
	if input_suspended and index >= 0:
		return
	selected = index if index >= 0 and index < cards.size() and cards[index] != null and index != selected else -1
	turns = 0
	towers.input_enabled = selected < 0 and not input_suspended
	preview.visible = false
	_reset_rotation_hint()
	_dirty = true
	hand.show_selection(selected, turns)
	set_process(selected >= 0)

func set_shop_open(value: bool) -> void:
	_shop_open = value
	_refresh_input_state()

func set_entry_selection(value: bool) -> void:
	entry_selection_active = value
	if value: $Shop.close_shop()
	$Shop/View.visible = not value
	_refresh_input_state()

func set_pause_locked(value: bool) -> void:
	if pause_locked == value: return
	pause_locked = value
	input_suspended = pause_locked or entry_selection_active or _wave_active or _wave_start_pending or _shop_open
	towers.input_enabled = selected < 0 and not input_suspended
	if value:
		_hand_pause_color = hand.get_node("Cards").modulate
		_shop_pause_color = $Shop/View/Root.modulate
		hand.get_node("Cards").modulate = Color(_hand_pause_color, _hand_pause_color.a*paused_cards_opacity)
		$Shop/View/Root.modulate = Color(_shop_pause_color, _shop_pause_color.a*paused_cards_opacity)
		preview.hide()
		_reset_rotation_hint()
	else:
		hand.get_node("Cards").modulate = _hand_pause_color
		$Shop/View/Root.modulate = _shop_pause_color
	_dirty = true
	set_process(selected >= 0 and not input_suspended)

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

func place_selected(cell: Vector3i) -> DefenseTower:
	if input_suspended or selected < 0 or selected >= cards.size():
		return null
	var tower: DefenseTower = towers.place_card(cards[selected], cell, turns)
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
		if cards[selected].configuration_error().is_empty():
			preview.show_at(placement.map, cards[selected], cell, turns, _preview_error.is_empty())
		else:
			preview.visible = false
	if preview.visible:
		if cell != _hint_cell:
			_reset_rotation_hint()
			_hint_cell = cell
		rotation_hint.follow(get_viewport().get_camera_3d(), preview.hint_anchor, delta)
	else:
		_reset_rotation_hint()

func _reset_rotation_hint() -> void:
	_hint_cell = TileConstants.INVALID_CELL
	rotation_hint.reset()

func _exit_tree() -> void:
	if is_instance_valid(towers):
		towers.input_enabled = true

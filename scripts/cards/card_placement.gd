extends Node3D
signal cards_changed
signal selection_changed(card: BuildCard)
signal card_placed(card: BuildCard, tower: Node3D, cell: Vector3i, rotation_steps: int)
signal traffic_preview_changed(effect: Dictionary)
signal build_preview_changed(card: BuildCard, cell: Vector3i, rotation_steps: int, error: String)
var traffic_candidate := {}
## Only the independent construction playground installs this controller.
var construction: Node
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
@export var starting_spell: CommanderSpell = preload("res://assets/data/spells/shot.tres")
var commander_enabled := false
const Upgrades = preload("res://scripts/cards/definitions/base_upgrades.gd")
var milestone_counts := {}
var upgrades: Array[String] = []
var base_level: int:
	get: return upgrades.size() + 1
var _first_strike := TileConstants.INVALID_CELL
var _last_spell_wave := -1
@onready var _spell_ring := MeshInstance3D.new()
var turns := 0
var _initial_turns := 0
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
	var ring := TorusMesh.new()
	ring.inner_radius = 0.96
	ring.outer_radius = 1.0
	ring.material = SolidMaterials.transparent(Color(1.0, 0.69, 0.25, 0.86))
	_spell_ring.mesh = ring
	add_child(_spell_ring)
	_spell_ring.hide()
	var authored := cards.duplicate()
	cards = []
	for card: BuildCard in authored:
		if card != null and card.spell != null: _store_spell(card.spell, card.quantity)
		else: cards.append(card)
	controller.graph_changed.connect(_invalidate)
	towers.towers_changed.connect(_capture_milestones)
	_capture_milestones()
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
		_spell_ring.hide()
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
	if index >= 0 and not _can_use(index):
		return
	if is_instance_valid(construction) and index >= 0:
		if construction.is_reserved(index): return
		construction.cancel_move()
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
	if selected >= 0 and cards[selected].tile_preset != null: turns = cards[selected].tile_preset.default_rotation
	if selected >= 0 and not cards[selected].allows_rotation(turns):
		for next in 4:
			if cards[selected].allows_rotation(next):
				turns = next
				break
	_initial_turns = turns
	towers.input_enabled = selected < 0 and not input_suspended and not is_instance_valid(construction)
	preview.visible = false
	_spell_ring.hide()
	_reset_rotation_hint()
	_first_strike = TileConstants.INVALID_CELL
	_dirty = true
	hand.show_selection(selected, turns)
	set_process(selected >= 0)
	selection_changed.emit(cards[selected] if selected >= 0 else null)

func _on_card_drag_started(index: int) -> void:
	if not _can_use(index):
		hand.cancel_drag()
		return
	# Dragging the selected card preserves its current rotation.
	if selected != index: select_card(index, false)

func _on_card_dropped(index: int, point: Vector2) -> void:
	if not _can_use(index) or selected != index or not _mouse_in_viewport: return
	if not get_viewport().get_visible_rect().has_point(point): return
	if CardButton.has_card_at(get_viewport(), point):
		select_card(-1)
		return
	if get_viewport().gui_get_hovered_control() != null: return
	place_selected(pick_card_cell(point))

## Pointer coordinates become an authored recipe origin shared by preview and commit.
func pick_card_cell(point: Vector2) -> Vector3i:
	var cell: Vector3i = placement.pick_cell(point)
	if cell == TileConstants.INVALID_CELL or selected < 0 or selected >= cards.size(): return cell
	if cards[selected].spell != null: return cell
	# Upgrades continue to target the actual occupied cell under the pointer.
	if towers.upgrade_target(cell, cards[selected]) != null: return cell
	var offset := cards[selected].rotation_anchor_offset(turns, _initial_turns)
	return cell+Vector3i(offset.x, 0, offset.y)

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
	$Shop/View.set_entry_locked(value)
	input_suspended = pause_locked or entry_selection_active or _wave_active or _wave_start_pending or _shop_open
	hand.set_interaction_enabled(not input_suspended or _can_cast())
	towers.input_enabled = selected < 0 and not input_suspended and not is_instance_valid(construction)
	if value:
		_spell_ring.hide()
		preview.hide()
		_reset_rotation_hint()
	if _pause_card_motion != null: _pause_card_motion.kill()
	_pause_card_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pause_card_motion.tween_property(self, "_pause_retraction", 1.0 if value else 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dirty = true
	set_process(selected >= 0 and (not input_suspended or _can_cast()))

func _position_paused_cards() -> void:
	if not is_node_ready() or not is_inside_tree(): return
	# Move the presentation roots without changing selection, offers or fan layout.
	var offset := (get_viewport().get_visible_rect().size.y+32.0)*_pause_retraction
	hand.get_node("Cards").position.y = _hand_rest_y+offset
	$Shop/View/Root.position.y = _shop_rest_y+offset

func _on_wave_started() -> void:
	_wave_active = true
	hand.set_combat_hand(true)
	_wave_start_pending = false
	_refresh_input_state()

func _on_wave_finished() -> void:
	_wave_active = false
	hand.set_combat_hand(false)
	_refresh_input_state()

func prepare_wave_start() -> void:
	_wave_start_pending = true
	_refresh_input_state()
	$Shop.hide_for_wave_start()

func _refresh_input_state() -> void:
	input_suspended = pause_locked or entry_selection_active or _wave_active or _wave_start_pending or _shop_open
	hand.set_interaction_enabled(not input_suspended or _can_cast())
	select_card(-1)
	hand.set_collapsed(_shop_open)
	hand.set_stowed(entry_selection_active or _wave_start_pending or (_wave_active and not _has_spells()))
	for view: Button in hand.views:
		view.phase_enabled = view.card != null and ((view.card.spell != null) == _wave_active)

func _can_cast() -> bool:
	return commander_enabled and _wave_active and not (pause_locked or entry_selection_active or _wave_start_pending or _shop_open or ScreenTransition.active)

func _can_use(index: int) -> bool:
	if index < 0 or index >= cards.size() or cards[index] == null: return false
	return (_can_cast() and not get_tree().paused) if cards[index].spell != null else not input_suspended

func _has_spells() -> bool:
	return cards.any(func(card: BuildCard): return card != null and card.spell != null)

func deal_commander_spells(wave_index: int) -> void:
	if not commander_enabled or not _wave_active or wave_index <= _last_spell_wave: return
	_last_spell_wave = wave_index
	var shot := starting_spell
	if "heavy" in upgrades: shot = Upgrades.SPELLS.heavy
	if "marksman" in upgrades:
		shot = starting_spell.duplicate()
		shot.damage += 20
		_append_spell(shot)
	_append_spell(shot)
	for id in upgrades:
		if id in Upgrades.TIERS[2] or id in ["heavy", "marksman"]: continue
		_append_spell(Upgrades.SPELLS[id])
	_refresh_input_state()
	cards_changed.emit()

func _append_spell(spell: CommanderSpell) -> void:
	var added := _store_spell(spell)
	if added != null: hand.append_card(added)

func _store_spell(spell: CommanderSpell, amount := 1) -> BuildCard:
	for held in cards:
		if held != null and spell.stacks_with(held.spell):
			held.quantity += amount
			return null
	var card := BuildCard.new()
	card.spell = spell
	card.quantity = amount
	card.price = 0
	cards.append(card)
	return card

func _capture_milestones() -> void:
	if milestone_counts.size() == Upgrades.TIERS.size(): return
	var counts := Upgrades.counts(towers)
	var total := int(counts.values().reduce(func(a,b): return a+b, 0))
	for tier in range(1, Upgrades.TIERS.size()+1):
		if total >= tier*5 and not milestone_counts.has(tier):
			milestone_counts[tier] = counts

func accept_upgrade(id: String) -> bool:
	if not commander_enabled or not _shop_open or not $Shop.can_open() or $Shop.purchase_rule.is_valid(): return false
	if base_level > Upgrades.TIERS.size() or not id in Upgrades.TIERS[base_level - 1]: return false
	if not milestone_counts.has(base_level) or not Upgrades.eligible(id, milestone_counts[base_level]): return false
	upgrades.append(id)
	if base_level == 4:
		_append_spell(Upgrades.SPELLS[id])
		_refresh_input_state()
		cards_changed.emit()
	return true

func add_card(card: BuildCard) -> bool:
	if towers.card_filter.is_valid() and not String(towers.card_filter.call(card)).is_empty(): return false
	if card == null or not card.configuration_error().is_empty():
		return false
	select_card(-1)
	if card.spell != null:
		var added := _store_spell(card.spell,card.quantity)
		if added != null: hand.append_card(added)
		_refresh_input_state()
	else:
		cards.append(card)
		hand.append_card(card)
	cards_changed.emit()
	return true

func place_selected(cell: Vector3i) -> Node3D:
	if not _can_use(selected):
		return null
	var card := cards[selected]
	if card.spell != null:
		if not card.spell.valid_target(towers.combat, cell) or cell == _first_strike:
			GameAudio.play_effect(&"wrong_placement")
			return null
		if card.spell.kind == &"double" and _first_strike == TileConstants.INVALID_CELL:
			_first_strike = cell
			towers.combat.visuals.add_impact(placement.map.to_global(placement.map.map_to_local(cell)),card.spell.radius,card.spell.accent_color,placement.map)
			return null
		var first := _first_strike
		var index := selected
		select_card(-1)
		if card.quantity > 1:
			card.quantity -= 1
		else:
			cards.remove_at(index)
			hand.remove_card(index)
		_refresh_input_state()
		card.spell.resolve(towers.combat, cell)
		if first != TileConstants.INVALID_CELL and towers.combat.wave.active: card.spell.resolve(towers.combat, first)
		cards_changed.emit()
		return self
	var rotation_steps := turns
	if is_instance_valid(construction):
		var error: String = construction.validate_candidate(card,cell,turns)
		if not error.is_empty():
			construction._result(error)
			_rejected_placement(card, cell)
			return null
		if construction.mode == 2 and card.traffic == null:
			return construction.stage_selected(cell)
	var tower: Node3D = towers.place_card(card, cell, turns)
	if tower == null:
		_dirty = true
		_rejected_placement(card, cell)
		return null
	GameAudio.play_effect(&"placement")
	var removed := selected
	cards.remove_at(removed)
	select_card(-1)
	hand.remove_card(removed)
	cards_changed.emit()
	card_placed.emit(card,tower,cell,rotation_steps)
	return tower

func _rejected_placement(card: BuildCard, cell: Vector3i) -> void:
	GameAudio.play_effect(&"wrong_placement")
	if cell == TileConstants.INVALID_CELL or not card.configuration_error().is_empty(): return
	var target: DefenseTower = towers.upgrade_target(cell,card)
	if target != null: preview.show_upgrade(placement.map,target,towers.validate_card(card,cell,turns))
	else: preview.show_at(placement.map, card, cell, turns, false)
	preview.flash_invalid()

func rotate_card(amount: int) -> void:
	if input_suspended or selected < 0:
		return
	for step in range(1,5):
		var next := posmod(turns+amount*step,4)
		if cards[selected].allows_rotation(next):
			turns = next
			break
	_dirty = true
	hand.show_selection(selected, turns)

func _invalidate() -> void:
	_dirty = true

func _unhandled_key_input(event: InputEvent) -> void:
	if (input_suspended and not _can_cast()) or not event is InputEventKey or not event.pressed or event.echo:
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
	if not input_suspended and selected < 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not event.button_mask & (MOUSE_BUTTON_MASK_RIGHT|MOUSE_BUTTON_MASK_MIDDLE):
		var camera := get_viewport().get_camera_3d()
		if camera != null and $Shop.try_open_from_world(camera,event.position):
			get_viewport().set_input_as_handled()
			return
	if not _can_use(selected) or not event is InputEventMouseButton or not event.pressed or (event.button_index == MOUSE_BUTTON_LEFT and event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		place_selected(pick_card_cell(event.position))
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if cards[selected].spell != null: select_card(-1)
		else: rotate_card(1)
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _mouse_in_viewport or get_viewport().gui_get_hovered_control() != null or not get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position()):
		preview.visible = false
		_spell_ring.hide()
		_reset_rotation_hint()
		_dirty = true
		return
	var cell: Vector3i = pick_card_cell(get_viewport().get_mouse_position())
	if selected >= 0 and cards[selected].spell != null:
		var spell := cards[selected].spell
		var map: GridMap = placement.map
		_spell_ring.visible = _can_cast() and spell.valid_target(towers.combat, cell) and cell != _first_strike
		if _spell_ring.visible:
			_spell_ring.global_transform = map.global_transform * Transform3D(Basis.from_scale(map.cell_size * spell.radius), map.map_to_local(cell) + Vector3.UP * 0.13)
		return
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
		_preview_error = construction.validate_candidate(cards[selected],cell,turns) if is_instance_valid(construction) else towers.validate_card(cards[selected], cell, turns)
		preview.geometry_cells = null
		var geometry := get_node_or_null("../GeometryBonuses")
		var message := _preview_error
		if geometry != null and _preview_error.is_empty():
			var drafts: Array = construction.entries if is_instance_valid(construction) else []
			var bonus: Dictionary = geometry.preview(cards[selected],cell,turns,drafts)
			preview.geometry_cells = bonus.get("cells")
			message = "\n".join(bonus.get("messages",[]))
		if is_instance_valid(construction): construction.feedback.emit(message)
		preview_traffic_at(cards[selected], cell, turns, _preview_error.is_empty())
		if cards[selected].configuration_error().is_empty():
			var target: DefenseTower = towers.upgrade_target(cell, cards[selected])
			if cards[selected].special != null and cards[selected].special.kind == SpecialCardDefinition.Kind.CONSUMABLE:
				target = towers.occupied.get(Vector2i(cell.x,cell.z))
			if target != null: preview.show_upgrade(placement.map, target, _preview_error)
			else: preview.show_at(placement.map, cards[selected], cell, turns, _preview_error.is_empty())
		else:
			preview.visible = false
		build_preview_changed.emit(cards[selected],cell,turns,_preview_error)
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
		_spell_ring.hide()
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

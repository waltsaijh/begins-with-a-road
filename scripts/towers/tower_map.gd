extends Node3D
## Validate occupancy first, then commit geometry and influence together.
signal placement_feedback(message: String)
signal towers_changed
signal tower_upgraded(tower: DefenseTower)
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const CombatSystem = preload("res://scripts/combat/combat_system.gd")
@export var tower_scene: PackedScene = preload("res://scenes/towers/sentry.tscn")
var controller: Node
var map: GridMap
var placement: Node3D
var towers := {}
## Anchor -> tower and occupied cell -> tower remain separate for larger towers.
var occupied := {}
var _settings := {}
var last_error := ""
var input_enabled := true
var combat: Node
var traffic: TrafficStructures
var relics: RunRelics

func _ready() -> void:
	controller = get_node_or_null("../PortalMap")
	placement = get_node_or_null("../TilePlacement")
	if controller == null or placement == null:
		set_process(false)
		set_process_unhandled_input(false)
		return
	map = controller.map
	relics = RunRelics.new()
	relics.name = "Relics"
	relics.tower_map = self
	add_child(relics)
	var hover := preload("res://scripts/towers/tower_hover.gd").new()
	hover.tower_map = self
	add_child(hover)
	traffic = TrafficStructures.new()
	traffic.name = "TrafficStructures"
	traffic.tower_map = self
	add_child(traffic)
	combat = CombatSystem.new()
	combat.tower_map = self
	combat.map = map
	combat.wave = get_node_or_null("../EnemyWave")
	add_child(combat)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			return
		var cell: Vector3i = placement.pick_cell(event.position)
		if occupied.has(Vector2i(cell.x, cell.z)):
			remove_tower(cell)
		else:
			place_tower(cell)
		get_viewport().set_input_as_handled()

func _feedback(message: String) -> void:
	last_error = message
	placement_feedback.emit(message)

func place_tower(cell: Vector3i, scene: PackedScene = null) -> DefenseTower:
	if map == null or cell.y != 0 or absi(cell.x) >= 32767 or absi(cell.z) >= 32767:
		return null
	var at := Vector2i(cell.x, cell.z)
	var candidate_scene := scene if scene != null else tower_scene
	if candidate_scene == null:
		return null
	var candidate := candidate_scene.instantiate()
	if not candidate is DefenseTower:
		if is_instance_valid(candidate):
			candidate.free()
		_feedback("請選擇有效的防禦塔")
		return null
	var tower := candidate as DefenseTower
	if tower.definition != null:
		var deployment_error := _validate_deployment(tower.definition,at,tower.rotation_steps)
		if not deployment_error.is_empty():
			_feedback(deployment_error)
			tower.free()
			return null
	if tower.definition != null and not tower.definition.configuration_error().is_empty():
		_feedback(tower.definition.configuration_error())
		tower.free()
		return null
	var error := _validate(tower.footprint_at(at), {})
	if not error.is_empty():
		tower.free()
		_feedback(error)
		return null
	return _commit(tower, at, {})

## Preview is read-only. Commit always validates again against current world state.
func validate_card(card: BuildCard, cell: Vector3i, turns := 0) -> String:
	if map == null or card == null:
		return "請選擇建造卡"
	var error := card.configuration_error()
	if not error.is_empty():
		return error
	if cell.y != 0 or absi(cell.x) >= 32767 or absi(cell.z) >= 32767:
		return "超出可建造範圍"
	var at := Vector2i(cell.x, cell.z)
	if card.traffic != null: return traffic.validate(card.traffic, at, turns)
	if occupied.has(at): return upgrade_error(card, occupied[at])
	var deployment_error := _validate_deployment(card.tower,at,turns)
	if not deployment_error.is_empty(): return deployment_error
	var additions := {}
	for ground in card.ground_cells(at, turns):
		additions[ground] = true
	return _validate(card.tower_cells(at, turns), additions)

func place_card(card: BuildCard, cell: Vector3i, turns := 0) -> Node3D:
	var error := validate_card(card, cell, turns)
	if not error.is_empty():
		_feedback(error)
		return null
	if card.traffic != null:
		_feedback("")
		return traffic.place(card.traffic, Vector2i(cell.x,cell.z), turns)
	var existing := upgrade_target(cell)
	if existing != null:
		if not existing.upgrade(): return null
		_feedback("")
		tower_upgraded.emit(existing)
		return existing
	var tower := DefenseTower.new()
	tower.definition = card.tower
	tower.rotation_steps = posmod(turns, 4)
	var at := Vector2i(cell.x, cell.z)
	var additions := {}
	for ground in card.ground_cells(at, turns):
		additions[ground] = true
	return _commit(tower, at, additions)

func upgrade_target(cell: Vector3i) -> DefenseTower:
	return occupied.get(Vector2i(cell.x, cell.z)) if cell.y == 0 else null

func upgrade_error(card: BuildCard, tower: DefenseTower) -> String:
	if card.tower != tower.definition: return "需要同種類防禦塔卡牌"
	var cards := get_node_or_null("../CardPlacement")
	if cards != null and cards.input_suspended: return "目前不能升級"
	return tower.upgrade_error()

func _validate(footprint: Array[Vector2i], additions: Dictionary) -> String:
	var terminals: Array[Vector2i] = controller.terminal_cells()
	var proposed: Dictionary = occupied.duplicate()
	var added := {}
	if footprint.is_empty() or terminals.is_empty():
		return "防禦塔或起終點尚未準備好"
	for pos: Vector2i in additions:
		if traffic != null and traffic.occupied.has(pos): return "卡片不能覆蓋輔助設施"
		if absi(pos.x) >= 32767 or absi(pos.y) >= 32767:
			return "超出可建造範圍"
		var item := map.get_cell_item(Vector3i(pos.x, 0, pos.y))
		if item == 0 or occupied.has(pos):
			return "卡片範圍與障礙物或防禦塔重疊"
		if pos in terminals:
			return "卡片不能覆蓋起點或終點"
	for pos in footprint:
		if traffic != null and traffic.occupied.has(pos): return "不能覆蓋輔助設施"
		for existing: DefenseTower in towers.values():
			if existing.definition.deployment != null and pos == existing.grid_cell+BuildCard.rotate_cell(Vector2i(0,-1),existing.rotation_steps):
				return "不能覆蓋兵營的士兵駐點"
		if absi(pos.x) >= 32767 or absi(pos.y) >= 32767:
			return "超出可建造範圍"
		if map.get_cell_item(Vector3i(pos.x, 0, pos.y)) <= 0 and not additions.has(pos):
			return "防禦塔必須完整放在地塊上"
		if occupied.has(pos):
			return "此處已被防禦塔占用"
		if pos in terminals:
			return "不能占用起點或終點"
		proposed[pos] = true
		added[pos] = true
	var wave := get_node_or_null("../EnemyWave")
	if wave != null and wave.reserves_cells(added):
		return "此處在敵軍已選定的路線上，請等本波結束"
	if not Snapshot.connects_terminals(Snapshot.capture(map, proposed, additions), terminals):
		return "此處會封死通往終點的道路"
	return ""

func _validate_deployment(definition: TowerDefinition,at: Vector2i,turns: int) -> String:
	if definition.deployment == null: return ""
	var terminals: Array[Vector2i] = controller.terminal_cells()
	var home := at+BuildCard.rotate_cell(Vector2i(0,-1),turns)
	for position in [at,home]:
		if traffic != null and traffic.occupied.has(position): return "兵營或駐點不能覆蓋輔助設施"
		if map.get_cell_item(Vector3i(position.x,0,position.y)) <= 0 or occupied.has(position) or position in terminals:
			return "兵營必須覆蓋既有道路，前方必須保留合法士兵駐點"
	return ""

func _commit(tower: DefenseTower, at: Vector2i, additions: Dictionary) -> DefenseTower:
	var ground: Array[Vector3i] = []
	for pos: Vector2i in additions:
		ground.append(Vector3i(pos.x, 0, pos.y))
	var new_cells: Array[Vector3i] = placement.add_cells(ground, false)
	var footprint := tower.footprint_at(at)
	tower.grid_cell = at
	tower.occupied_cells = footprint
	add_child(tower)
	var cell := Vector3i(at.x, 0, at.y)
	tower.global_transform = map.global_transform*Transform3D(Basis(Vector3.UP, -tower.rotation_steps*PI/2), map.map_to_local(cell)+Vector3.UP*TowerConstants.GROUND_OFFSET)
	towers[at] = tower
	for pos in footprint:
		occupied[pos] = tower
	var values := [tower.influence_offsets().duplicate(), tower.threat]
	_settings[at] = values
	tower.influence_changed.connect(_on_influence_changed.bind(at))
	tower.died.connect(_on_tower_died)
	controller.set_blocked_cells(occupied)
	_apply_change(at, [], values)
	placement.notify_cells(new_cells)
	var tile_visuals := get_node_or_null("../TileVisuals")
	if tile_visuals != null:
		tile_visuals.follow_new_cell(cell, tower.get_node_or_null("Visual"))
	_feedback("")
	towers_changed.emit()
	return tower

func _on_tower_died(tower: Node3D) -> void:
	if towers.get(tower.grid_cell) == tower:
		remove_tower(Vector3i(tower.grid_cell.x, 0, tower.grid_cell.y))

func remove_tower(cell: Vector3i) -> bool:
	var at := Vector2i(cell.x, cell.z)
	if cell.y != 0 or not occupied.has(at):
		return false
	var tower: DefenseTower = occupied[at]
	at = tower.grid_cell
	tower.influence_changed.disconnect(_on_influence_changed.bind(at))
	for position in tower.occupied_cells:
		occupied.erase(position)
	controller.set_blocked_cells(occupied)
	_apply_change(at, _settings[at], [])
	towers.erase(at)
	_settings.erase(at)
	tower.queue_free()
	_feedback("")
	towers_changed.emit()
	return true

func _on_influence_changed(at: Vector2i) -> void:
	var tower: Node3D = towers[at]
	var values := [tower.influence_offsets().duplicate(), tower.threat]
	_apply_change(at, _settings[at], values)
	_settings[at] = values

func _apply_change(at: Vector2i, before: Array, after: Array) -> void:
	var old_cells := {}
	var new_cells := {}
	if not before.is_empty():
		for offset: Vector2i in before[0]: old_cells[offset] = true
	if not after.is_empty():
		for offset: Vector2i in after[0]: new_cells[offset] = true
	var affected := old_cells.duplicate()
	affected.merge(new_cells)
	for y in range(-1, 2):
		for x in range(-1, 2):
			if x != 0 or y != 0: affected[Vector2i(x, y)] = true
	var neighbor_delta := int(not after.is_empty())-int(not before.is_empty())
	var records: RefCounted = controller.tile_parameters
	records.begin_update()
	for offset: Vector2i in affected:
		var old_amount: float = before[1] if old_cells.has(offset) else 0.0
		var new_amount: float = after[1] if new_cells.has(offset) else 0.0
		var nearby := neighbor_delta if absi(offset.x) <= 1 and absi(offset.y) <= 1 and offset != Vector2i.ZERO else 0
		if nearby != 0 or old_amount != new_amount:
			records.change_tower_influence(at+offset, nearby, new_amount-old_amount)
	records.end_update()

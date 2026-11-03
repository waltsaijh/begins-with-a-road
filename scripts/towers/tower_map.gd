extends Node3D
## Validate occupancy first, then commit geometry and influence together.
signal placement_feedback(message: String)
signal towers_changed
signal tower_upgraded(tower: DefenseTower)
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const ConstructionLayout = preload("res://scripts/map/tile/construction_layout.gd")
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
## Optional session-specific allowlist. Formal levels leave this empty.
var card_filter: Callable
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
	if card_filter.is_valid():
		var denied: String = card_filter.call(card)
		if not denied.is_empty(): return denied
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
	if not card.allows_rotation(turns): return "地塊不支援這個旋轉方向"
	if not card.tile_preset.tower_footprint.is_empty() or card.tile_preset.has_explicit_ports() or not placement.port_overrides.is_empty() or card.tile_preset.tower_offset != Vector2i.ZERO:
		return construction_plan([{"card":card,"anchor":cell,"turns":turns}]).error
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
		if BalanceTrace.enabled: BalanceTrace.event("upgrade",BalanceTrace.tower_id(existing),{"level":existing.level,"gold":0})
		return existing
	if not card.tile_preset.tower_footprint.is_empty() or card.tile_preset.has_explicit_ports() or not placement.port_overrides.is_empty() or card.tile_preset.tower_offset != Vector2i.ZERO:
		var built := commit_construction([{"card":card,"anchor":cell,"turns":turns}])
		return built[0] if not built.is_empty() else null
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
			if existing.definition.deployment != null and pos == existing.garrison_cell():
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

func _validate_card_home(card: BuildCard, anchor: Vector2i, turns: int) -> String:
	if card.tower.deployment == null: return ""
	var at := card.tower_anchor(anchor,turns)
	var home := card.home_cell(anchor,turns)
	for pos in [at,home]:
		if traffic != null and traffic.occupied.has(pos): return "兵營或駐點不能覆蓋輔助設施"
		if occupied.has(pos) or pos in controller.terminal_cells(): return "兵營或駐點與占用格衝突"
	if home in card.tower_cells(anchor,turns): return "兵營駐點不能位於塔體內"
	if not card.tile_preset.custom_home: return _validate_deployment(card.tower,at,card.tower_facing(turns))
	if map.get_cell_item(Vector3i(at.x,0,at.y)) <= 0: return "兵營錨點必須覆蓋既有道路"
	if map.get_cell_item(Vector3i(home.x,0,home.y)) <= 0 and not home in card.road_cells(anchor,turns): return "兵營駐點必須是道路"
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
	if BalanceTrace.enabled: BalanceTrace.event("build",BalanceTrace.tower_id(tower),{"level":tower.level,"turns":tower.rotation_steps})
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

## Read-only union validation. A draft may skip terminal connectivity, never
## physical occupancy. Entries are recipes, not temporary world mutations.
func construction_plan(entries: Array, require_connected := true) -> Dictionary:
	var failure := {"ok":false,"error":""}
	if map == null or controller.terminal_cells().is_empty():
		failure.error = "起點與終點尚未準備好"
		return failure
	var terminals: Array[Vector2i] = controller.terminal_cells()
	var ground := {}
	var roads := {}
	var ports := {}
	var proposed := occupied.duplicate()
	var additions := {}
	var upgrades := {}
	var builds: Array[Dictionary] = []
	var homes := {}
	for existing: DefenseTower in towers.values():
		if existing.definition.deployment != null:
			homes[existing.garrison_cell()] = true
	for entry: Dictionary in entries:
		var card: BuildCard = entry.get("card")
		if card_filter.is_valid():
			failure.error = card_filter.call(card)
			if not failure.error.is_empty(): return failure
		var cell: Vector3i = entry.get("anchor",TileConstants.INVALID_CELL)
		var turns: int = entry.get("turns",0)
		if card == null: failure.error = "缺少預擺卡牌"
		elif not card.configuration_error().is_empty(): failure.error = card.configuration_error()
		elif card.traffic != null: failure.error = "輔助設施請在確認預擺後單獨放置"
		elif cell.y != 0 or absi(cell.x) >= 32767 or absi(cell.z) >= 32767: failure.error = "超出可建造範圍"
		if not failure.error.is_empty(): return failure
		var existing := upgrade_target(cell)
		if existing != null:
			failure.error = upgrade_error(card,existing)
			if not failure.error.is_empty(): return failure
			upgrades[existing] = int(upgrades.get(existing,0))+1
			var next_level: int = existing.level+int(upgrades[existing])
			if not existing.unlimited_levels and next_level > card.tower.growth.max_level:
				failure.error = "預擺升級超過最高等級"
				return failure
			for value: float in existing.growth_values(next_level):
				if not is_finite(value) or value <= 0: failure.error = "升級數值超出可表示範圍"
			for value: float in existing.effective_values(next_level).values():
				if not is_finite(value) or value < 0: failure.error = "升級數值超出可表示範圍"
			if not failure.error.is_empty(): return failure
			continue
		if not card.allows_rotation(turns):
			failure.error = "地塊不支援這個旋轉方向"
			return failure
		var anchor := Vector2i(cell.x,cell.z)
		var tower_at := card.tower_anchor(anchor,turns)
		failure.error = _validate_card_home(card,anchor,turns)
		if not failure.error.is_empty(): return failure
		var footprint := card.tower_cells(anchor,turns)
		var explicit := card.tile_preset.has_explicit_ports()
		var entry_roads := card.road_cells(anchor,turns)
		for pos in card.ground_cells(anchor,turns):
			if absi(pos.x) >= 32767 or absi(pos.y) >= 32767: failure.error = "超出可建造範圍"
			elif pos in terminals: failure.error = "地塊不能覆蓋起點或終點"
			elif occupied.has(pos) or map.get_cell_item(Vector3i(pos.x,0,pos.y)) == 0: failure.error = "地塊與已建防禦塔或石地重疊"
			elif traffic != null and traffic.occupied.has(pos): failure.error = "地塊不能覆蓋輔助設施"
			if not failure.error.is_empty(): return failure
			ground[pos] = true
			# Foundation cells never become accidental road junctions.
			if explicit and not pos in entry_roads and not ports.has(pos): ports[pos] = 0
		for pos in entry_roads:
			# Legacy recipes may list their own tower's support tile as road.
			# It is still an obstacle, not a conflicting road from another entry.
			if not pos in footprint: roads[pos] = true
		for pos: Vector2i in card.road_ports(anchor,turns):
			ports[pos] = int(ports.get(pos,0)) | int(card.road_ports(anchor,turns)[pos])
		for pos in footprint:
			if proposed.has(pos): failure.error = "預擺防禦塔互相重疊"
			elif homes.has(pos): failure.error = "不能覆蓋兵營士兵駐點"
			if not failure.error.is_empty(): return failure
			proposed[pos] = true
			additions[pos] = true
		if card.tower.deployment != null:
			homes[card.home_cell(anchor,turns)] = true
		builds.append({"card":card,"at":tower_at,"turns":card.tower_facing(turns),"geometry_turns":turns,"origin":anchor,"footprint":footprint})
	for pos: Vector2i in roads:
		if additions.has(pos):
			failure.error = "道路與另一塊預擺防禦塔重疊"
			return failure
	for pos: Vector2i in homes:
		if additions.has(pos):
			failure.error = "不能覆蓋兵營士兵駐點"
			return failure
	var wave := get_node_or_null("../EnemyWave")
	if wave != null and wave.reserves_cells(additions):
		failure.error = "此處在敵軍已固定的路線上"
		return failure
	var layout := ConstructionLayout.build(map,ground,ports,placement.port_overrides,proposed)
	var reachable: Array[Vector2i] = terminals.duplicate()
	for home: Vector2i in homes:
		if proposed.has(home) or not layout.masks.has(home):
			failure.error = "兵營駐點必須保留可通行道路"
			return failure
		if not home in reachable: reachable.append(home)
	if require_connected and not Snapshot.connects_terminals(layout.snapshot,reachable):
		failure.error = "道路尚未連通：所有入口都必須能抵達終點"
		return failure
	return {"ok":true,"error":"","snapshot":layout.snapshot,"layout":layout,"ground":ground,"ports":ports,"blocked":proposed,"builds":builds,"upgrades":upgrades}

## All possible rejection points precede mutation. Nodes are prepared before the
## one geometry write, then occupancy/influence is published once for the union.
func commit_construction(entries: Array) -> Array[Node3D]:
	var plan := construction_plan(entries)
	var result: Array[Node3D] = []
	if not plan.ok:
		_feedback(plan.error)
		return result
	var prepared: Array[DefenseTower] = []
	for build: Dictionary in plan.builds:
		var tower := DefenseTower.new()
		tower.definition = build.card.tower
		tower.rotation_steps = build.turns
		tower.grid_cell = build.at
		tower.occupied_cells.assign(build.footprint)
		tower.placement_preset = build.card.tile_preset.duplicate(true)
		tower.geometry_turns = build.geometry_turns
		tower.placement_origin = build.origin
		tower.custom_garrison = build.card.home_cell(build.origin,build.geometry_turns) if build.card.tile_preset.custom_home else Vector2i(2147483647,2147483647)
		prepared.append(tower)
	var new_cells: Array[Vector3i] = ConstructionLayout.apply(placement,plan.layout)
	var records: RefCounted = controller.tile_parameters
	records.begin_update()
	for tower in prepared:
		var at := tower.grid_cell
		add_child(tower)
		tower.global_transform = map.global_transform*Transform3D(Basis(Vector3.UP,-tower.rotation_steps*PI/2),map.map_to_local(Vector3i(at.x,0,at.y))+Vector3.UP*TowerConstants.GROUND_OFFSET)
		towers[at] = tower
		for pos in tower.occupied_cells: occupied[pos] = tower
		var values := [tower.influence_offsets().duplicate(),tower.threat]
		_settings[at] = values
		tower.influence_changed.connect(_on_influence_changed.bind(at))
		tower.died.connect(_on_tower_died)
		_apply_change(at,[],values)
		result.append(tower)
	# No await or event loop between validation and these upgrades.
	for tower: DefenseTower in plan.upgrades:
		for i in int(plan.upgrades[tower]):
			tower.upgrade()
			result.append(tower)
	if not prepared.is_empty(): controller.set_blocked_cells(occupied)
	records.end_update()
	placement.notify_cells(new_cells)
	for tower: DefenseTower in plan.upgrades: tower_upgraded.emit(tower)
	if not prepared.is_empty(): towers_changed.emit()
	var visuals := get_node_or_null("../TileVisuals")
	for tower in prepared:
		if visuals != null: visuals.follow_new_cell(Vector3i(tower.grid_cell.x,0,tower.grid_cell.y),tower.get_node_or_null("Visual"))
		if BalanceTrace.enabled: BalanceTrace.event("build",BalanceTrace.tower_id(tower),{"level":tower.level,"turns":tower.rotation_steps})
	for tower: DefenseTower in plan.upgrades:
		if BalanceTrace.enabled: BalanceTrace.event("upgrade",BalanceTrace.tower_id(tower),{"level":tower.level,"gold":0})
	_feedback("")
	return result

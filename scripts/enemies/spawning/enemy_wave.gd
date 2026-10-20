extends Node3D
## Allocate routes by wave index/total, shuffle departure order, then move.
signal enemy_spawned(enemy: Node3D)
signal wave_finished
signal wave_started
signal routes_changed
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const VisualBatch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
const Controls = preload("res://scenes/enemies/components/enemy_wave_controls.tscn")
@export var auto_start := true
@export_range(1, 200, 1, "or_greater") var enemy_count := EnemyConstants.WAVE_SIZE
## Enemies emitted together per interval; the last batch is capped by the total.
@export_range(1, 64, 1, "or_greater") var batch_size := EnemyConstants.BATCH_SIZE
@export_range(0.0, 2.0, 0.05, "or_greater") var spawn_interval := EnemyConstants.SPAWN_INTERVAL
@export_range(0.1, 20.0, 0.1, "or_greater") var move_speed := EnemyConstants.MOVE_SPEED
@export_range(0.1, 40.0, 0.1, "or_greater") var turn_sharpness := EnemyRenderConstants.TURN_SHARPNESS
## Null uses the map's current troop; -1 uses its currently selected origin.
@export var troop: Troop
@export var available_troops: Array[Troop] = TroopCatalog.all()
@export var start_index := -1
@export var show_button := true
## Optional scene-authored action; otherwise controls create a standalone button.
@export var start_button: Button
@export var definition: WaveDefinition
var start_allowed := true
## Runtime ACT entrances join each group's authored entrance without changing its count/ticks.
var additional_start_indices := PackedInt32Array()
var controller: Node
var active := false
var spawned := 0
var alive := 0
var completed := 0
var killed := 0
var pool_size := 0
var _auto_started := false
var _pending: Array[Dictionary] = []
var _living := {}
var _countdown := 0.0
var _scheduled := false
var _schedule_elapsed := 0.0
var elapsed_tick := 0
var _next_enemy_id := 0
var controls: CanvasLayer
var _wave_troop: Troop
var _wave_health := EnemyConstants.MAX_HEALTH
var _wave_shield := 0.0
var _wave_speed := EnemyConstants.MOVE_SPEED
var total := 0
var _committed_routes: Array[Dictionary] = []
var visuals: MultiMeshInstance3D

func _ready() -> void:
	visuals = VisualBatch.new()
	visuals.name = "EnemyMultiMesh"
	add_child(visuals)
	controller = get_node_or_null("../PortalMap")
	# Geometry-only fixtures deliberately remove the map controller.
	if controller == null:
		set_process(false)
		return
	visuals.map = controller.map
	visuals.turn_sharpness = turn_sharpness
	if definition != null:
		apply_definition(definition)
	if troop != null:
		controller.select_troop(troop)
	if show_button:
		controls = Controls.instantiate()
		add_child(controls)
		controls.configure(available_troops, start_button)
		controls.spawn_requested.connect(start_wave)
	controller.plan_changed.connect(_on_plan_ready)
	_on_plan_ready()

func _on_plan_ready() -> void:
	_update_button()
	if auto_start and not _auto_started and controller.plan.get("routes", 0) > 0:
		start_wave.call_deferred()

func start_wave() -> bool:
	if not start_allowed or active or controller == null or controller.computing:
		return false
	_scheduled = definition != null
	if _scheduled:
		var schedule := WaveSpawnSchedule.build(definition, controller, _next_enemy_id, true, additional_start_indices)
		if schedule.is_empty():
			_update_button()
			return false
		_pending.assign(schedule.pending)
		pool_size = schedule.pool_size
	else:
		if not _prepare_legacy_wave(): return false
	total = _pending.size()
	_next_enemy_id += total
	visuals.reserve(total)
	_committed_routes.clear()
	for data: Dictionary in _pending:
		var profile: Troop = data.get("profile", _wave_troop)
		_committed_routes.append({"troop": profile.troop_name, "color": profile.debug_color, "cells": data.route.cells})
	spawned = 0
	alive = 0
	completed = 0
	killed = 0
	active = true
	_auto_started = true
	_countdown = 0.0
	_schedule_elapsed = 0.0
	elapsed_tick = 0
	routes_changed.emit()
	wave_started.emit()
	_update_button()
	return true

func _prepare_legacy_wave() -> bool:
	var profile: Troop = troop if troop != null else controller.troop
	var origin: int = controller.active_start if start_index < 0 else start_index
	var plan: Dictionary = controller.plan_for(profile, origin)
	pool_size = plan.get("routes", 0)
	if not plan.get("valid", false) or pool_size == 0:
		_update_button()
		return false
	_wave_troop = profile
	_wave_health = profile.max_health
	_wave_shield = profile.max_shield
	_wave_speed = move_speed*profile.speed_multiplier
	var map: GridMap = controller.map
	_pending.clear()
	# Capture every path now. Later map/profile edits cannot redirect an enemy,
	# including those still waiting for their staggered spawn time.
	for i in enemy_count:
		var id := _next_enemy_id+i
		var route: Dictionary = controller.allocate_route_for(profile, i, enemy_count, origin)
		if route.is_empty():
			_pending.clear()
			return false
		var points := PackedVector3Array()
		for cell: Vector2 in route.cells:
			points.append(map.to_global(map.map_to_local(Vector3i(int(cell.x), 0, int(cell.y)))+Vector3.UP*EnemyConstants.GROUND_OFFSET))
		_pending.append({"id": id, "wave_index": i, "route": route, "points": points})
	# Randomness changes departure timing only; route quotas are already fixed.
	_pending.shuffle()
	return true

func has_committed_routes() -> bool:
	return not _committed_routes.is_empty()

## Same index/total allocation as combat; preview never shuffles departures.
func routes_for_display() -> Array[Dictionary]:
	if has_committed_routes(): return _committed_routes.duplicate(true)
	var result: Array[Dictionary] = []
	if controller == null or controller.computing: return result
	if definition != null:
		var schedule := WaveSpawnSchedule.build(definition, controller, _next_enemy_id, false, additional_start_indices)
		for data: Dictionary in schedule.get("pending", []):
			result.append({"troop": data.profile.troop_name, "color": data.profile.debug_color, "cells": data.route.cells})
	else:
		var profile: Troop = troop if troop != null else controller.troop
		var origin: int = controller.active_start if start_index < 0 else start_index
		for i in enemy_count:
			var route: Dictionary = controller.allocate_route_for(profile, i, enemy_count, origin)
			if route.is_empty(): return []
			result.append({"troop": profile.troop_name, "color": profile.debug_color, "cells": route.cells})
	return result

func apply_definition(value: WaveDefinition) -> bool:
	if active or value == null or not value.configuration_error().is_empty(): return false
	definition = value
	_committed_routes.clear()
	enemy_count = value.total_count()
	batch_size = value.groups[0].batch_size
	spawn_interval = value.groups[0].interval_ticks*WaveSpawnGroup.TICK_SECONDS
	move_speed = value.move_speed
	start_index = value.groups[0].start_index
	troop = value.groups[0].troop
	if controller != null: controller.select_troop(troop)
	_update_button()
	routes_changed.emit()
	return true

func _process(delta: float) -> void:
	if not active or _pending.is_empty():
		return
	if _scheduled:
		_schedule_elapsed += maxf(0.0, delta)
		elapsed_tick = floori(_schedule_elapsed/WaveSpawnGroup.TICK_SECONDS+0.0000001)
		while active and not _pending.is_empty() and int(_pending[0].spawn_tick) <= elapsed_tick:
			_spawn_entry(_pending.pop_front())
		return
	_countdown -= delta
	if _countdown <= 0.0:
		for i in mini(maxi(1, batch_size), _pending.size()):
			_spawn_entry(_pending.pop_front())
		# Keep the interval after a slow frame; never catch up several batches at once.
		_countdown = maxf(0.0, spawn_interval)
	_update_button()

func _spawn_entry(data: Dictionary) -> void:
	var enemy := EnemyScene.instantiate()
	enemy.troop = data.get("profile", _wave_troop)
	enemy.max_health = data.get("health", _wave_health)
	enemy.health = enemy.max_health
	enemy.max_shield = data.get("shield", _wave_shield)
	enemy.shield = enemy.max_shield
	enemy.move_speed = data.get("speed", _wave_speed)
	enemy.arrived.connect(_on_arrived)
	enemy.died.connect(_on_enemy_died)
	enemy.tree_exiting.connect(_on_enemy_exiting.bind(enemy), CONNECT_ONE_SHOT)
	add_child(enemy)
	_living[enemy] = true
	enemy.follow(data.id, data.route, data.points)
	visuals.add_enemy(enemy)
	spawned += 1
	alive += 1
	enemy_spawned.emit(enemy)

func _on_arrived(enemy: Node3D) -> void:
	_release_enemy(enemy, true)

func _on_enemy_died(enemy: Node3D) -> void:
	killed += 1
	_release_enemy(enemy, false)

func living_enemies() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for enemy: Node3D in _living:
		if is_instance_valid(enemy) and enemy.can_be_targeted():
			result.append(enemy)
	return result

func _on_enemy_exiting(enemy: Node3D) -> void:
	_release_enemy(enemy, false)

func _release_enemy(enemy: Node3D, reached_goal: bool) -> void:
	if not _living.erase(enemy):
		return
	alive -= 1
	if reached_goal:
		completed += 1
	if _pending.is_empty() and alive == 0:
		active = false
		wave_finished.emit()
	_update_button()

## Do not let construction invalidate an enemy's already committed remaining trip.
func reserves_cells(cells: Dictionary) -> bool:
	for data: Dictionary in _pending:
		for cell: Vector2 in data.route.cells:
			if cells.has(Vector2i(cell)):
				return true
	for enemy: Node3D in _living:
		var path: PackedVector2Array = enemy.route.cells
		for i in range(maxi(0, enemy._next - 1), path.size()):
			if cells.has(Vector2i(path[i])):
				return true
	return false

func _update_button() -> void:
	if not is_instance_valid(controls) or not is_instance_valid(controller):
		return
	var profile: Troop = troop if troop != null else controller.troop
	var origin: int = controller.active_start if start_index < 0 else start_index
	var ready := false
	if start_allowed and not active and not controller.computing:
		if definition != null:
			ready = definition.configuration_error().is_empty()
			if ready:
				for group in definition.groups:
					for index in WaveSpawnSchedule.origins_for(group, additional_start_indices):
						var entry: Dictionary = controller.plan_for(group.troop, index)
						ready = ready and entry.get("valid", false) and entry.get("routes", 0) > 0
		else:
			var entry: Dictionary = controller.plan_for(profile, origin)
			ready = entry.get("valid", false) and entry.get("routes", 0) > 0
	controls.refresh(self, profile, ready)

func select_route_selection(selection: int) -> void:
	if active or controller == null or controller.computing:
		return
	if selection not in [Troop.RouteSelection.UNIFORM, Troop.RouteSelection.SOFTMAX]:
		return
	var profile: Troop = troop if troop != null else controller.troop
	if profile == null: return
	profile.route_selection = selection
	_update_button()

func select_troop(index: int) -> void:
	if active or index < 0 or index >= available_troops.size() or available_troops[index] == null:
		return
	troop = available_troops[index]
	controller.select_troop(troop)
	_update_button()

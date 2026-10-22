extends Node3D
## Immutable route snapshot, health and temporary movement effects; no render state.
signal arrived(enemy: Node3D)
signal died(enemy: Node3D)
signal damaged(enemy: Node3D, amount: float)
var troop: Troop
var max_health := EnemyConstants.MAX_HEALTH
var health := EnemyConstants.MAX_HEALTH
var max_shield := 0.0
var shield := 0.0
## Negative hides the optional skill bar; 0..1 shows its progress.
var skill_progress := -1.0
## Insertion order is display order. Each effect type owns a single icon.
var effect_icons: Dictionary[StringName, Texture2D] = {}
@export_range(0.1, 20.0, 0.1, "or_greater") var move_speed := EnemyConstants.MOVE_SPEED
var move_direction := Vector3.FORWARD
var travelled_distance := 0.0
var enemy_id := -1
var route: Dictionary = {}
var waypoints := PackedVector3Array()
var _next := 1
var _finished := false
var _slow_multiplier := 1.0
var _slow_remaining := 0.0

func can_be_targeted() -> bool:
	return not _finished and not is_queued_for_deletion() and health > 0

func add_shield(amount: float) -> void:
	if can_be_targeted() and is_finite(amount) and amount > 0:
		shield += amount
		max_shield = maxf(max_shield, shield)

func take_damage(amount: float) -> void:
	if not can_be_targeted() or not is_finite(amount) or amount <= 0:
		return
	var absorbed := minf(maxf(0.0, shield), amount)
	shield = maxf(0.0, shield-absorbed)
	var applied := minf(health, amount-absorbed)
	health -= applied
	if health <= 0:
		_finished = true
		set_process(false)
		died.emit(self)
		queue_free()
	damaged.emit(self, absorbed+applied)

func set_effect_icon(id: StringName, icon: Texture2D) -> void:
	if icon == null:
		effect_icons.erase(id)
	else:
		effect_icons[id] = icon

func apply_slow(multiplier: float, duration: float, icon: Texture2D = null) -> void:
	if not can_be_targeted() or not is_finite(multiplier) or not is_finite(duration) or multiplier <= 0 or multiplier > 1 or duration <= 0:
		return
	# Merge strength and remaining lifetime independently; neither stacks.
	if _slow_remaining <= 0 or multiplier < _slow_multiplier:
		set_effect_icon(&"slow", icon)
	elif multiplier == _slow_multiplier and icon != null:
		set_effect_icon(&"slow", icon)
	_slow_multiplier = minf(_slow_multiplier, multiplier)
	_slow_remaining = maxf(_slow_remaining, duration)

func _speed_factor(delta: float) -> float:
	var factor := _slow_multiplier
	_slow_remaining = maxf(0.0, _slow_remaining-delta)
	if _slow_remaining <= 0:
		_slow_multiplier = 1.0
		set_effect_icon(&"slow", null)
	return factor

func follow(id: int, selected_route: Dictionary, points: PackedVector3Array, shared_snapshot := false) -> void:
	enemy_id = id
	route = selected_route
	# Spawn scheduling owns immutable packed snapshots; external callers keep
	# the defensive copy. Movement reads waypoints and changes only _next.
	waypoints = points if shared_snapshot else points.duplicate()
	_next = 1
	_finished = false
	travelled_distance = 0.0
	_slow_multiplier = 1.0
	_slow_remaining = 0.0
	effect_icons.clear()
	skill_progress = -1.0
	if not waypoints.is_empty():
		global_position = waypoints[0]
	set_process(not waypoints.is_empty())
	if waypoints.size() > 1:
		move_direction = (waypoints[1]-waypoints[0]).normalized()

func _process(delta: float) -> void:
	if _finished or waypoints.is_empty():
		return
	# Spend leftover distance on the next segment, preserving speed at corners
	# and even when one slow frame crosses several tiles.
	var remaining := maxf(0.0, delta)*move_speed*_speed_factor(maxf(0.0, delta))
	var travelled := 0.0
	while _next < waypoints.size():
		var offset := waypoints[_next]-global_position
		var distance := offset.length()
		if distance > 0.000001:
			move_direction = offset/distance
		if distance > remaining:
			global_position += offset*(remaining/distance)
			travelled_distance += travelled+remaining
			return
		global_position = waypoints[_next]
		remaining -= distance
		travelled += distance
		_next += 1
	_finished = true
	travelled_distance += travelled
	set_process(false)
	arrived.emit(self)
	queue_free()

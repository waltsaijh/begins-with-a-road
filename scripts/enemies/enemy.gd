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
## Insertion order is display order. Reapplying an effect replaces its icon.
var effect_icons: Dictionary[StringName, Texture2D] = {}
@export_range(0.1, 20.0, 0.1, "or_greater") var move_speed := EnemyConstants.MOVE_SPEED
var move_direction := Vector3.FORWARD
var travelled_distance := 0.0
var enemy_id := -1
var route: Dictionary = {}
var waypoints := PackedVector3Array()
var _next := 1
var _finished := false
var _slows: Array[Vector2] = []

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
	if icon != null:
		set_effect_icon(&"slow", icon)
	# Refresh an equal strength; different strengths coexist and the strongest wins.
	for i in _slows.size():
		if _slows[i].x == multiplier:
			_slows[i].y = maxf(_slows[i].y, duration)
			return
	_slows.append(Vector2(multiplier, duration))

func _speed_factor(delta: float) -> float:
	var factor := 1.0
	for i in range(_slows.size()-1, -1, -1):
		factor = minf(factor, _slows[i].x)
		_slows[i].y -= delta
		if _slows[i].y <= 0:
			_slows.remove_at(i)
	if _slows.is_empty():
		set_effect_icon(&"slow", null)
	return factor

func follow(id: int, selected_route: Dictionary, points: PackedVector3Array) -> void:
	enemy_id = id
	route = selected_route
	waypoints = points.duplicate()
	_next = 1
	_finished = false
	travelled_distance = 0.0
	_slows.clear()
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

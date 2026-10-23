class_name DefenseTower
extends Node3D
## Common obstacle instance. A definition supplies its model, footprint and stats.
signal influence_changed
signal died(tower: Node3D)
signal stats_changed
@export var definition: TowerDefinition
var grid_cell := Vector2i.ZERO
var occupied_cells: Array[Vector2i] = []
var rotation_steps := 0:
	set(value):
		value = posmod(value, 4)
		if rotation_steps == value: return
		if is_inside_tree() and definition != null and not occupied_cells.is_empty():
			var rotated := definition.cells_at(grid_cell, value)
			for cell in rotated:
				if not cell in occupied_cells:
					push_warning("旋轉會改變防禦塔佔格，必須重新驗證放置")
					return
		var previous := rotation_steps
		rotation_steps = value
		if is_inside_tree(): rotate_object_local(Vector3.UP, -(value-previous)*PI/2)
		_invalidate_attack_area()
var max_health := TowerConstants.MAX_HEALTH
var health := TowerConstants.MAX_HEALTH
var damage := TowerConstants.DEFAULT_DAMAGE
var attack_interval := TowerConstants.ATTACK_INTERVAL
var attack: TowerAttack
var level := 1
var unlimited_levels := false
var deployment: BarracksDeployment
var relic_effects := {}
var support_bonus := 0.0
var isolated := true
var range_multiplier := 1.0
var relic_clocks := {}
var patrol_distance := 0.0
var rapid_remaining := 0
var rapid_next := 0.0
var mortar_shots := 0

func effect(id: StringName) -> Dictionary: return relic_effects.get(id,{})
func has_relic(id: StringName) -> bool: return relic_effects.has(id)
func relic_value(id: StringName, key: StringName, fallback := 0.0) -> float: return float(effect(id).get(key,fallback))

func combat_origin() -> Vector3:
	return patrol_visual().global_position if has_relic(&"departure") and _visual != null else global_position

func patrol_visual() -> Node3D:
	return _visual.motion_root() if _visual != null and _visual.has_method("motion_root") else _visual

func set_patrol_offset(offset: float) -> void:
	if _visual == null: return
	if _visual.has_method("set_patrol_offset"): _visual.set_patrol_offset(offset)
	else: _visual.position.x = offset

func can_attack_target(target: Node3D) -> bool:
	if attack is VolleyAttack and attack.mortar_visual and target.troop != null and target.troop.has_tag(&"flying") and not has_relic(&"air_strike"): return false
	if has_relic(&"crew_concentration"):
		var origin := patrol_visual() if _visual != null else self
		if origin.to_local(target.global_position).x <= 0: return false
	return true
var next_attack_time := 0.0
var _visual: Node3D
var _aim_pivot: Node3D
var _muzzle: Marker3D
var _attack_offsets: Array[Vector2i] = []
var _attack_lookup := {}
var _attack_area_dirty := true
var attack_radius := TowerConstants.ATTACK_RADIUS:
	set(value):
		if is_finite(value) and attack_radius != maxf(0.0, value):
			attack_radius = maxf(0.0, value)
			_invalidate_attack_area()
var threat := TowerConstants.THREAT:
	set(value):
		if is_finite(value) and threat != maxf(0.0, value):
			threat = maxf(0.0, value)
			influence_changed.emit()

func footprint_at(cell: Vector2i) -> Array[Vector2i]:
	return definition.cells_at(cell, rotation_steps) if definition != null else []

func _ready() -> void:
	if definition == null:
		return
	definition.changed.connect(_invalidate_attack_area)
	attack_radius = definition.attack_radius
	threat = definition.threat
	max_health = definition.max_health
	health = max_health
	damage = definition.default_damage
	attack_interval = definition.attack_interval
	attack = definition.attack.duplicate(true) if definition.attack != null else null
	deployment = definition.deployment.duplicate(true) if definition.deployment != null else null
	if definition.model != null:
		_visual = definition.model.instantiate()
		_visual.name = "Visual"
		add_child(_visual)
		if not definition.aim_pivot_path.is_empty():
			_aim_pivot = _visual.get_node(definition.aim_pivot_path) as Node3D
		if not definition.muzzle_path.is_empty():
			_muzzle = _visual.get_node(definition.muzzle_path) as Marker3D

func upgrade_error() -> String:
	if definition == null or health <= 0 or is_queued_for_deletion(): return "防禦塔已不存在"
	if not unlimited_levels and level >= definition.growth.max_level: return "已達最高等級 Lv.%d" % level
	if level == 9223372036854775807: return "等級超出可表示範圍"
	for value in growth_values(level+1):
		if not is_finite(value) or value <= 0: return "成長數值超出可表示範圍"
	for value in effective_values(level+1).values():
		if not is_finite(value) or value < 0: return "成長數值超出可表示範圍"
	if effective_values(level+1).interval <= 0: return "攻擊間隔超出可表示範圍"
	return ""

func growth_values(at_level: int) -> Array[float]:
	var curve := definition.growth
	return [maxf(definition.default_damage, 0.000001)*curve.multiplier(curve.damage, at_level), definition.attack_interval*curve.multiplier(curve.interval, at_level), definition.max_health*curve.multiplier(curve.health, at_level), curve.multiplier(curve.friendly_health, at_level), curve.multiplier(curve.friendly_damage, at_level)]

func upgrade() -> bool:
	if not upgrade_error().is_empty(): return false
	level += 1
	refresh_stats()
	return true

func refresh_stats() -> void:
	var ratio := health/max_health
	var values := effective_values(level)
	damage = values.damage
	attack_interval = values.interval
	max_health = values.health
	health = max_health*ratio
	if deployment != null:
		deployment.health = values.friendly_health
		deployment.damage = values.friendly_damage
		deployment.interval = values.friendly_interval
		deployment.count = definition.deployment.count+int(relic_value(&"reinforcements", &"extra_units"))
	stats_changed.emit()

func effective_values(at_level: int) -> Dictionary:
	var base := growth_values(at_level)
	var bonus := 1.0+relic_value(&"global_damage", &"bonus")*relic_value(&"global_damage", &"stacks")+support_bonus
	var haste := 1.0+relic_value(&"global_haste", &"bonus")*relic_value(&"global_haste", &"stacks")
	var result := {"damage":definition.default_damage*definition.growth.multiplier(definition.growth.damage,at_level)*bonus,"interval":base[1]/haste,"health":base[2]}
	if has_relic(&"assembled_cannon"):
		result.damage *= relic_value(&"assembled_cannon", &"damage_multiplier")
		result.interval *= relic_value(&"assembled_cannon", &"interval_multiplier")
	if has_relic(&"crew_concentration"): result.damage *= relic_value(&"crew_concentration", &"damage_multiplier")
	if has_relic(&"secret_mission") and isolated: result.damage *= relic_value(&"secret_mission", &"damage_multiplier")
	if definition.deployment != null:
		result.friendly_health = definition.deployment.health*base[3]
		result.friendly_damage = definition.deployment.damage*base[4]*bonus
		result.friendly_interval = definition.deployment.interval/haste
	return result

func _invalidate_attack_area() -> void:
	_attack_area_dirty = true
	influence_changed.emit()

func attack_offsets() -> Array[Vector2i]:
	if _attack_area_dirty:
		_attack_offsets = definition.effective_attack_cells(Vector2i.ZERO, rotation_steps, range_multiplier, has_relic(&"crew_concentration"), attack_radius) if definition != null else TowerAttackArea.circle_cells(Vector2i.ZERO, attack_radius)
		_attack_lookup.clear()
		for offset in _attack_offsets: _attack_lookup[offset] = true
		_attack_area_dirty = false
	return _attack_offsets

func covers_cell(cell: Vector2i) -> bool:
	attack_offsets()
	return _attack_lookup.has(cell-grid_cell)

func influence_offsets() -> Array[Vector2i]:
	if has_relic(&"departure"):
		return definition.patrol_attack_cells(Vector2i.ZERO,rotation_steps,range_multiplier,has_relic(&"crew_concentration"))
	return attack_offsets()

## Override for troop-specific damage rules without changing delivery strategies.
func damage_against(_target: Node3D) -> float:
	return damage

## Called every combat frame, including cooldown and the extra tile of lookahead.
## Returns true once the weapon is close enough to fire without snapping.
func aim_at(target: Vector3, delta: float) -> bool:
	if _aim_pivot == null:
		return true
	var direction := _aim_pivot.get_parent_node_3d().to_local(target)-_aim_pivot.position
	if direction.length_squared() <= 0.000001:
		return false
	var up := Vector3.UP
	if absf(direction.normalized().dot(up)) > 0.999:
		up = Vector3.RIGHT
	var desired := Basis.looking_at(direction, up).get_rotation_quaternion()
	var current := _aim_pivot.quaternion
	var angle := current.angle_to(desired)
	if angle > 0.000001:
		# A speed limit smooths large turns while catching small target movements
		# exactly, so a moving enemy cannot keep the tower perpetually unaligned.
		var blend := minf(1.0, TowerConstants.AIM_TURN_SPEED*maxf(0.0, delta)/angle)
		_aim_pivot.quaternion = current.slerp(desired, blend)
	var forward := (-_aim_pivot.global_basis.z).normalized()
	return forward.dot((target-_aim_pivot.global_position).normalized()) >= cos(TowerConstants.AIM_TOLERANCE)

func prepare_shot(target: Node3D) -> void:
	if _visual != null and _visual.has_method("prepare_target"): _visual.prepare_target(target)

## Query only: firing must never rotate the model or bypass smooth aiming.
func muzzle_position() -> Vector3:
	if _visual != null and _visual.has_method("muzzle_position"): return _visual.muzzle_position()
	if _muzzle != null:
		return _muzzle.global_position
	var origin := _aim_pivot if _aim_pivot != null else (_visual if _visual != null else self)
	return origin.to_global(definition.muzzle_offset if definition != null else TowerConstants.MUZZLE_OFFSET)

func present_shot(target: Node3D,effects: Node = null) -> void:
	if _visual != null and _visual.has_method("fire"): _visual.fire(target,effects)

func take_damage(amount: float) -> void:
	if is_queued_for_deletion() or health <= 0 or not is_finite(amount) or amount <= 0:
		return
	health = maxf(0.0, health-amount)
	if health == 0:
		died.emit(self)
		queue_free()

func _exit_tree() -> void:
	if definition != null and definition.changed.is_connected(_invalidate_attack_area):
		definition.changed.disconnect(_invalidate_attack_area)

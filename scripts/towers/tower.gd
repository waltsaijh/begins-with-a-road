class_name DefenseTower
extends Node3D
## Common obstacle instance. A definition supplies its model, footprint and stats.
signal influence_changed
signal died(tower: Node3D)
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
	if definition.model != null:
		_visual = definition.model.instantiate()
		_visual.name = "Visual"
		add_child(_visual)
		if not definition.aim_pivot_path.is_empty():
			_aim_pivot = _visual.get_node(definition.aim_pivot_path) as Node3D
		if not definition.muzzle_path.is_empty():
			_muzzle = _visual.get_node(definition.muzzle_path) as Marker3D

func _invalidate_attack_area() -> void:
	_attack_area_dirty = true
	influence_changed.emit()

func attack_offsets() -> Array[Vector2i]:
	if _attack_area_dirty:
		_attack_offsets = definition.attack_cells_at(Vector2i.ZERO, rotation_steps, attack_radius) if definition != null else TowerAttackArea.circle_cells(Vector2i.ZERO, attack_radius)
		_attack_lookup.clear()
		for offset in _attack_offsets: _attack_lookup[offset] = true
		_attack_area_dirty = false
	return _attack_offsets

func covers_cell(cell: Vector2i) -> bool:
	attack_offsets()
	return _attack_lookup.has(cell-grid_cell)

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

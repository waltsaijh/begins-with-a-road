class_name DefenseTower
extends Node3D
## Common obstacle instance. A definition supplies its model, footprint and stats.
signal influence_changed
signal died(tower: Node3D)
@export var definition: TowerDefinition
var grid_cell := Vector2i.ZERO
var occupied_cells: Array[Vector2i] = []
var rotation_steps := 0
var max_health := TowerConstants.MAX_HEALTH
var health := TowerConstants.MAX_HEALTH
var damage := TowerConstants.DEFAULT_DAMAGE
var attack_interval := TowerConstants.ATTACK_INTERVAL
var attack: TowerAttack
var next_attack_time := 0.0
var _visual: Node3D
var _aim_pivot: Node3D
var _muzzle: Marker3D
var attack_radius := TowerConstants.ATTACK_RADIUS:
	set(value):
		if is_finite(value) and attack_radius != maxf(0.0, value):
			attack_radius = maxf(0.0, value)
			influence_changed.emit()
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

## Query only: firing must never rotate the model or bypass smooth aiming.
func muzzle_position() -> Vector3:
	if _muzzle != null:
		return _muzzle.global_position
	var origin := _aim_pivot if _aim_pivot != null else (_visual if _visual != null else self)
	return origin.to_global(definition.muzzle_offset if definition != null else TowerConstants.MUZZLE_OFFSET)

func take_damage(amount: float) -> void:
	if is_queued_for_deletion() or health <= 0 or not is_finite(amount) or amount <= 0:
		return
	health = maxf(0.0, health-amount)
	if health == 0:
		died.emit(self)
		queue_free()

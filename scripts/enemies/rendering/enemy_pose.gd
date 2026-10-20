extends RefCounted
## Render state follows the simulation; it never writes back to an enemy.
var yaw := 0.0
var walk_phase := 0.0
var walk_blend := 0.0
var turning := false
var _travelled := 0.0

func _init(enemy: Node3D) -> void:
	yaw = atan2(-enemy.move_direction.x, -enemy.move_direction.z)
	walk_phase = fposmod(float(enemy.enemy_id)*2.39996323, TAU)
	_travelled = enemy.travelled_distance

func advance(enemy: Node3D, delta: float, turn_sharpness: float) -> void:
	var distance: float = maxf(0.0, enemy.travelled_distance-_travelled)
	_travelled = enemy.travelled_distance
	var target := atan2(-enemy.move_direction.x, -enemy.move_direction.z)
	yaw = lerp_angle(yaw, target, 1.0-exp(-turn_sharpness*maxf(delta, 0.0)))
	turning = absf(angle_difference(yaw, target)) > deg_to_rad(EnemyRenderConstants.VISUAL_TURN_TOLERANCE_DEGREES)
	walk_phase = fposmod(walk_phase+distance*EnemyRenderConstants.WALK_PHASE_PER_UNIT, TAU)
	walk_blend = minf(1.0, distance/maxf(delta, 0.0001)*2.0)

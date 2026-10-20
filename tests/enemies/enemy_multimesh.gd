extends Node3D
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Batch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
var _failed := false

func _ready() -> void:
	call_deferred("verify")

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error(message)
		if not OS.has_feature("web"):
			get_tree().quit(1)

func _unit(batch: MultiMeshInstance3D, id: int) -> Node3D:
	var unit: Node3D = Enemy.instantiate()
	unit.move_speed = 1.0
	add_child(unit)
	unit.follow(id, {}, PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, -5)]))
	batch.add_enemy(unit)
	unit.set_process(false)
	return unit

func verify() -> void:
	var batch := Batch.new()
	add_child(batch)
	var units: Array[Node3D] = []
	# Exceed initial capacity, then remove a middle slot and refill it.
	for i in EnemyRenderConstants.INITIAL_CAPACITY + 1:
		units.append(_unit(batch, i))
	_check(batch.multimesh.visible_instance_count == units.size(), "Dense visible slots after capacity growth")
	_check(batch.multimesh.instance_count >= units.size(), "Buffer grew without losing instances")
	var unit := units[0]
	var first_segment: float = unit.waypoints[0].distance_to(unit.waypoints[1])
	var pose: RefCounted = batch._poses[0]
	var phase: float = pose.walk_phase
	unit._process(0.25)
	pose.advance(unit, 0.25, batch.turn_sharpness)
	batch.update_enemy(unit)
	_check(is_equal_approx(pose.walk_phase, fposmod(phase + 0.25 * EnemyRenderConstants.WALK_PHASE_PER_UNIT, TAU)), "Gait advances with travelled distance")
	# The headless dummy renderer does not retain MultiMesh buffer readbacks.
	if DisplayServer.get_name() != "headless":
		_check(is_equal_approx(batch.multimesh.get_instance_custom_data(0).r, pose.walk_phase), "GPU receives individual gait phase")
		_check(batch.multimesh.get_instance_transform(0).origin.is_equal_approx(unit.position), "GPU transform matches simulation")
	unit._process(0.0)
	pose.advance(unit, 0.0, batch.turn_sharpness)
	_check(pose.walk_blend == 0.0, "Stationary legs stop swinging")
	unit._process(first_segment - 0.25 + 0.01) # cross the corner by 0.01 units
	pose.advance(unit, first_segment - 0.25 + 0.01, batch.turn_sharpness)
	_check(pose.yaw < 0.0 and pose.yaw > -PI * 0.5, "Turn interpolates rather than snapping")
	var angle: float = pose.yaw
	unit._process(0.05)
	pose.advance(unit, 0.05, batch.turn_sharpness)
	_check(pose.yaw < angle and pose.yaw > -PI * 0.5, "Turn smoothly converges")
	# Wrapping at +/-PI must choose the short rotation.
	pose.yaw = PI - 0.02
	unit.move_direction = Vector3(-sin(-PI+0.02), 0, -cos(-PI+0.02))
	pose.advance(unit, 0.05, batch.turn_sharpness)
	_check(absf(angle_difference(pose.yaw, PI)) < 0.025, "Angle interpolation crosses PI without a full spin")
	# The same elapsed time gives the same rotation across different frame rates.
	pose.yaw = 0.0
	unit.move_direction = Vector3.RIGHT
	pose.advance(unit, 0.1, batch.turn_sharpness)
	angle = pose.yaw
	pose.yaw = 0.0
	pose.advance(unit, 0.05, batch.turn_sharpness)
	pose.advance(unit, 0.05, batch.turn_sharpness)
	_check(is_equal_approx(angle, pose.yaw), "Frame-rate independent turns")
	_check(unit.rotation == Vector3.ZERO, "Rendering changed the logical orientation")
	var middle := units[10]
	middle.free()
	units.remove_at(10)
	_check(batch.multimesh.visible_instance_count == units.size(), "External deletion also releases the slot")
	_check(batch.units[10] == units[-1], "Last live unit fills removed slot")
	if DisplayServer.get_name() != "headless":
		_check(batch.multimesh.get_instance_transform(10).is_equal_approx(units[-1].transform), "Moved slot keeps its transform")
	var arrays: Array = batch.multimesh.mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var pivots: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var counts := {}
	for i in uv.size():
		var limb := roundi(uv[i].x)
		counts[limb] = counts.get(limb, 0) + 1
		if limb != 0:
			_check(pivots[i].y > 0.0, "Limb pivots baked above the ground")
	for limb in [-2, -1, 0, 1, 2]:
		_check(counts.get(limb, 0) > 0, "Torso and all four limbs exist in shared mesh")
	_check(batch.multimesh.mesh.get_surface_count() == 1, "One mesh surface for every enemy")
	_check(batch.material_override is ShaderMaterial, "GPU walking material installed")
	for enemy in units:
		enemy.free()
	_check(batch.multimesh.visible_instance_count == 0 and batch.units.is_empty(), "All slots cleaned up")
	batch.queue_free()
	if not _failed:
		print("ENEMY_MULTIMESH_CHECK:" + JSON.stringify({"capacity_growth": true, "dense_slots": true, "external_deletion": true, "distance_driven_gait": true, "limbs": 4, "smooth_turns": true, "frame_rate_independent": true, "mesh_surfaces": 1}))
	if not OS.has_feature("web"):
		get_tree().quit(1 if _failed else 0)

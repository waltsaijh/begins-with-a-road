extends MultiMeshInstance3D
## Dense active slots. Removing one enemy moves only the last slot into its hole.
const Model = preload("res://assets/models/enemies/grunt_mesh.res")
const WalkShader = preload("res://assets/shaders/solid_color.gdshader")
const Separation = preload("res://scripts/enemies/rendering/enemy_visual_separation.gd")
const Pose = preload("res://scripts/enemies/rendering/enemy_pose.gd")
const StatusOverlay = preload("res://scenes/enemies/components/enemy_status_overlay.tscn")
const Appearance = preload("res://scripts/enemies/rendering/enemy_model.gd")
const MeshBatch = preload("res://scripts/enemies/rendering/enemy_mesh_batch.gd")
@export var death_effects_scene: PackedScene = preload("res://scenes/effects/death_effects.tscn")
var turn_sharpness := EnemyRenderConstants.TURN_SHARPNESS
var units: Array[Node3D] = []
var _poses: Array[RefCounted] = []
var _appearances: Array[RefCounted] = []
var _slots := {}
var map: GridMap
var separation := Separation.new()
var _offsets := PackedVector2Array()
var _offset_velocities := PackedVector2Array()
var _targets := PackedFloat32Array()
var _countdown := 0.0
var head_positions := PackedVector3Array()
var status_overlay: Control
var death_effects: Node3D
var _batches := {}

func _ready() -> void:
	# Sample a coherent snapshot after all logical movement, then submit once/frame.
	process_priority = 100
	set_process(false)
	_batches[Appearance.DefaultGpu] = MeshBatch.new(self,Appearance.DefaultGpu)
	var status_layer := StatusOverlay.instantiate() as CanvasLayer
	status_overlay = status_layer.get_node("EnemyStatusOverlay")
	status_overlay.renderer = self
	add_child(status_layer)
	death_effects = death_effects_scene.instantiate() as Node3D
	add_child(death_effects)

func reserve(count: int) -> void:
	_batches[Appearance.DefaultGpu].reserve(count)

func reserve_population(counts: Dictionary) -> void:
	var models := {}
	for profile: Troop in counts:
		var model := Appearance.gpu_for(profile)
		if model != null: models[model] = int(models.get(model,0))+int(counts[profile])
	for model: EnemyGpuModel in models: _batch_for(model).reserve(models[model])

func _batch_for(model: EnemyGpuModel) -> RefCounted:
	if not _batches.has(model):
		var view := MultiMeshInstance3D.new()
		view.name = "GpuMesh%d" % _batches.size()
		add_child(view)
		_batches[model] = MeshBatch.new(view,model)
	return _batches[model]

func add_enemy(enemy: Node3D) -> void:
	if _slots.has(enemy):
		return
	_slots[enemy] = units.size()
	units.append(enemy)
	_poses.append(Pose.new(enemy))
	var appearance := Appearance.new(enemy.troop,self)
	if appearance.gpu_model != null:
		appearance.batch = _batch_for(appearance.gpu_model)
		appearance.batch.add(enemy)
	_appearances.append(appearance)
	_offsets.append(Vector2.ZERO)
	_offset_velocities.append(Vector2.ZERO)
	_targets.append(0.0)
	head_positions.append(Vector3.ZERO)
	set_process(true)
	status_overlay.set_process(true)
	enemy.tree_exiting.connect(remove_enemy.bind(enemy), CONNECT_ONE_SHOT)
	enemy.arrived.connect(remove_enemy, CONNECT_ONE_SHOT)
	enemy.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
	update_enemy(enemy)

func update_enemy(enemy: Node3D) -> void:
	var slot: int = _slots.get(enemy, -1)
	if slot < 0 or not is_inside_tree() or not enemy.is_inside_tree():
		return
	var offset := _offsets[slot]
	var shift := Vector3(offset.x, 0, offset.y)
	if map != null:
		shift = map.global_basis*Vector3(offset.x*map.cell_size.x, 0, offset.y*map.cell_size.z)
	var display := enemy.global_transform
	var pose: RefCounted = _poses[slot]
	display.basis = Basis(Vector3.UP, pose.yaw).scaled(display.basis.get_scale())
	display.origin += shift
	var appearance: RefCounted = _appearances[slot]
	var model_transform: Transform3D = appearance.transform_for(display)
	head_positions[slot] = model_transform*appearance.head
	if appearance.batch != null:
		appearance.batch.update(enemy,global_transform.affine_inverse()*model_transform,appearance.custom_data(pose))

func _on_enemy_died(enemy: Node3D) -> void:
	var slot: int = _slots.get(enemy, -1)
	if slot < 0: return
	var offset := _offsets[slot]
	var shift := Vector3(offset.x, 0, offset.y)
	var basis := Basis.IDENTITY
	if map != null:
		basis = map.global_basis*Basis.from_scale(map.cell_size)
		shift = basis*shift
	# Keep the last visual avoidance offset when logical death removes the model.
	death_effects.emit_at(enemy.global_position+shift, basis)
	remove_enemy(enemy)

func remove_enemy(enemy: Node3D) -> void:
	var slot: int = _slots.get(enemy, -1)
	if slot < 0:
		return
	_slots.erase(enemy)
	if _appearances[slot].batch != null: _appearances[slot].batch.remove(enemy)
	_appearances[slot].dispose()
	var last: Node3D = units.pop_back()
	if slot < units.size():
		units[slot] = last
		_slots[last] = slot
		_poses[slot] = _poses[-1]
		_appearances[slot] = _appearances[-1]
		_offsets[slot] = _offsets[-1]
		_offset_velocities[slot] = _offset_velocities[-1]
		_targets[slot] = _targets[-1]
		update_enemy(last)
	_offsets.resize(units.size())
	_offset_velocities.resize(units.size())
	_targets.resize(units.size())
	_poses.resize(units.size())
	_appearances.resize(units.size())
	head_positions.resize(units.size())
	# Instance buffers persist without _draw; explicitly remove departed slots.
	if units.is_empty(): status_overlay.clear()
	else: status_overlay.request_update()
	if units.is_empty():
		set_process(false)
		status_overlay.set_process(false)
		_countdown = 0.0

func _normal(enemy: Node3D) -> Vector2:
	var direction: Vector3 = enemy.move_direction
	if map != null:
		direction = map.global_basis.inverse()*direction
		direction.x /= map.cell_size.x
		direction.z /= map.cell_size.z
	var forward := Vector2(direction.x, direction.z).normalized()
	return Vector2(-forward.y, forward.x)

func _process(delta: float) -> void:
	# Turning state must be current before taking the separation snapshot.
	for i in units.size():
		_poses[i].advance(units[i], delta, turn_sharpness)
		_appearances[i].advance(delta, _poses[i].walk_blend)
	_countdown -= maxf(0.0, delta)
	if _countdown <= 0.0:
		var positions := PackedVector2Array()
		var normals := PackedVector2Array()
		var ids := PackedInt64Array()
		var ignored := PackedByteArray()
		positions.resize(units.size())
		normals.resize(units.size())
		ids.resize(units.size())
		ignored.resize(units.size())
		for i in units.size():
			var point := map.to_local(units[i].global_position) if map != null else units[i].global_position
			positions[i] = Vector2(point.x/map.cell_size.x, point.z/map.cell_size.z) if map != null else Vector2(point.x, point.z)
			normals[i] = _normal(units[i])
			ids[i] = units[i].enemy_id
			ignored[i] = int(_poses[i].turning)
		_targets = separation.solve(positions, normals, ids, _targets, ignored)
		_countdown = EnemyRenderConstants.VISUAL_SEPARATION_INTERVAL
	var elapsed := maxf(0.0, delta)
	var frequency := 2.0/EnemyRenderConstants.VISUAL_OFFSET_SMOOTH_TIME
	var decay := exp(-frequency*elapsed)
	for i in units.size():
		# Keep the existing lane offset while turning, instead of continually
		# rotating it into the straight neighbor and triggering another push.
		if not _poses[i].turning:
			var target := _normal(units[i])*_targets[i]
			var displacement := _offsets[i]-target
			var step := (_offset_velocities[i]+frequency*displacement)*elapsed
			_offset_velocities[i] = (_offset_velocities[i]-frequency*step)*decay
			_offsets[i] = (target+(displacement+step)*decay).limit_length(EnemyRenderConstants.VISUAL_MAX_OFFSET)
		else:
			_offset_velocities[i] = Vector2.ZERO
		update_enemy(units[i])

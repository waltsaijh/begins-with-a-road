extends RefCounted
## Offline GPU meshes, with scene rendering retained for arbitrary imports.
const DefaultScene = preload("res://assets/models/enemies/grunt.tscn")
const DefaultMesh = preload("res://assets/models/enemies/grunt_mesh.res")
const DefaultGpu = preload("res://assets/models/enemies/grunt_gpu.tres")
var batched := true
var gpu_model: EnemyGpuModel
var batch: RefCounted
var clip_phase := 0.0
var instance: Node3D
var animation: AnimationPlayer
var adjustment := Transform3D.IDENTITY
var imported_transform := Transform3D.IDENTITY
var head := Vector3(0, DefaultMesh.get_aabb().end.y+EnemyStatusConstants.HEAD_MARGIN, 0)
var animation_speed := 1.0

func _init(profile: Troop, parent: Node3D) -> void:
	gpu_model = gpu_for(profile)
	if profile == null: return
	adjustment = Transform3D(Basis.from_euler(profile.model_rotation_degrees*PI/180.0).scaled(profile.model_scale), profile.model_offset)
	animation_speed = profile.animation_speed
	batched = gpu_model != null
	if batched:
		imported_transform = gpu_model.root_transform
		var height := gpu_model.rest_height if gpu_model.rest_height > 0 else gpu_model.mesh.get_aabb().end.y
		head = Vector3(0,height+EnemyStatusConstants.HEAD_MARGIN,0)
	if not batched:
		var root := profile.model.instantiate()
		if not root is Node3D:
			root.free()
			batched = true
			gpu_model = DefaultGpu
			return
		instance = root
		parent.add_child(instance)
		imported_transform = instance.transform
		head = Vector3(0, _model_height()+EnemyStatusConstants.HEAD_MARGIN, 0)
		var players := instance.find_children("*", "AnimationPlayer", true, false)
		for player: AnimationPlayer in players:
			var selected := profile.walk_animation
			if selected.is_empty():
				for title in player.get_animation_list():
					if "walk" in title.to_lower() or "run" in title.to_lower():
						selected = title
						break
			if not selected.is_empty() and player.has_animation(selected):
				animation = player
				animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				animation.play(selected)
				animation.advance(0)
				break
	if profile.head_height > 0: head.y = profile.head_height+EnemyStatusConstants.HEAD_MARGIN

static func gpu_for(profile: Troop) -> EnemyGpuModel:
	if profile == null or profile.model == null or profile.model == DefaultScene: return DefaultGpu
	if profile.gpu_model != null and profile.gpu_model.matches(profile.model,profile.walk_animation): return profile.gpu_model
	return null

func _model_height() -> float:
	var height := 0.0
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	if instance is MeshInstance3D: meshes.append(instance)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null: continue
		var relative := instance.global_transform.affine_inverse()*mesh.global_transform
		var bounds := relative*mesh.get_aabb()
		height = maxf(height, bounds.end.y)
	return height

func advance(delta: float, walk_blend: float) -> void:
	if gpu_model != null and gpu_model.clip_length > 0:
		# The authored clips are time-driven and freeze at their current pose
		# when stationary; Soldier retains its distance-driven pose state.
		clip_phase = fposmod(clip_phase+maxf(0.0,delta)*animation_speed*walk_blend*TAU/gpu_model.clip_length,TAU)
	if animation != null and walk_blend > 0:
		# Imported clips need not be marked looping in their import settings.
		if not animation.is_playing(): animation.play(animation.assigned_animation)
		animation.advance(maxf(0.0, delta)*animation_speed*walk_blend)

func custom_data(pose: RefCounted) -> Color:
	return Color(clip_phase,1,0,0) if gpu_model != null and gpu_model.clip_length > 0 else Color(pose.walk_phase,pose.walk_blend,0,0)

func transform_for(display: Transform3D) -> Transform3D:
	var result := display*adjustment*imported_transform
	if instance != null: instance.global_transform = result
	return result

func dispose() -> void:
	if is_instance_valid(instance):
		instance.hide()
		instance.queue_free()
	instance = null
	animation = null

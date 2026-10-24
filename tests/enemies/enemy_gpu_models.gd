extends SceneTree
const Appearance = preload("res://scripts/enemies/rendering/enemy_model.gd")
const Batch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const PARTS := ["Body","LegLeft","LegRight","ArmLeft","ArmRight"]
var failures := 0
var max_vertex_error := 0.0
var max_normal_error := 0.0

func _initialize() -> void: verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func gpu_vertex(v: Vector3, normal: Vector3, uv: Vector2, uv2: Vector2, model: EnemyGpuModel, time: float) -> Array:
	var frame := fposmod(time/model.clip_length,1.0)*model.keyframe_intervals
	var stride := lerpf(sin(floorf(frame)*TAU/model.keyframe_intervals),sin((floorf(frame)+1)*TAU/model.keyframe_intervals),fposmod(frame,1))
	var angle := stride*signf(uv.x)*(-model.arm_swing if absf(uv.x)>1.5 else model.leg_swing)
	var pivot := Vector3(uv2.x,uv2.y,uv.y)
	var limb := Basis(Vector3.RIGHT,angle)
	var body := Basis(Vector3.BACK,stride*model.body_sway)
	return [body*(limb*(v-pivot)+pivot)+Vector3.UP*absf(stride)*model.body_bob,body*limb*normal]

func compare_clip(profile: Troop) -> void:
	var model := profile.gpu_model
	var arrays := model.mesh.surface_get_arrays(0)
	var source := profile.model.instantiate() as Node3D
	root.add_child(source)
	var player: AnimationPlayer = source.get_node("AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("Walk")
	for time in [0.0,0.013,0.05,0.137,0.312,0.64,model.clip_length-0.001]:
		player.seek(time,true)
		var offset := 0
		for part in PARTS:
			var mesh: MeshInstance3D = source.get_node("ModelRoot/"+part+"/Mesh")
			var original := mesh.mesh.surface_get_arrays(0)
			var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in original[Mesh.ARRAY_VERTEX].size(): indices.append(i)
			for index in indices:
				var actual := gpu_vertex(arrays[Mesh.ARRAY_VERTEX][offset],arrays[Mesh.ARRAY_NORMAL][offset],arrays[Mesh.ARRAY_TEX_UV][offset],arrays[Mesh.ARRAY_TEX_UV2][offset],model,time)
				max_vertex_error = maxf(max_vertex_error,actual[0].distance_to(mesh.global_transform*original[Mesh.ARRAY_VERTEX][index]))
				max_normal_error = maxf(max_normal_error,actual[1].distance_to(mesh.global_basis*original[Mesh.ARRAY_NORMAL][index]))
				check(arrays[Mesh.ARRAY_COLOR][offset].is_equal_approx(original[Mesh.ARRAY_COLOR][index]),"Palette changed: "+profile.troop_name)
				offset += 1
	check(max_vertex_error < 0.00001 and max_normal_error < 0.0002,"GPU gait differs from authored clip: "+profile.troop_name)
	source.free()

func verify() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var batch := Batch.new()
	scene.add_child(batch)
	batch.set_process(false)
	for id in ["quickfeet","heavy"]: compare_clip(TroopCatalog.find(id))
	var profiles: Array[Troop] = [TroopCatalog.find("soldier"),TroopCatalog.find("quickfeet"),TroopCatalog.find("heavy")]
	var alternate := profiles[1].duplicate() as Troop
	batch.reserve_population({profiles[1]:85,alternate:86})
	check(batch._batches[profiles[1].gpu_model].view.multimesh.instance_count >= 171,"Profiles sharing one GPU model did not aggregate their reserved population")
	var enemies: Array[Node3D] = []
	for i in 258:
		var enemy := Enemy.instantiate() as Node3D
		enemy.troop = profiles[i%3]
		scene.add_child(enemy)
		enemy.follow(i,{},PackedVector3Array([Vector3.ZERO,Vector3(0,0,-100)]))
		enemy.set_process(false)
		batch.add_enemy(enemy)
		enemies.append(enemy)
	check(batch._batches.size() == 3,"Expected three independent geometry batches")
	for geometry: RefCounted in batch._batches.values():
		check(geometry.units.size() == 86 and geometry.view.multimesh.visible_instance_count == 86,"Per-mesh population or growth incorrect")
		check(geometry.view.material_override.shader == Batch.WalkShader,"GPU batches do not share one shader")
		check(geometry.view.material_override == preload("res://assets/materials/solid_color.tres"),"GPU batches duplicated the shared world material")
	for appearance: RefCounted in batch._appearances:
		check(appearance.instance == null and appearance.animation == null and appearance.batched,"GPU enemy retained scene/AnimationPlayer")
	var quick: RefCounted = batch._appearances[1]
	quick.advance(0.125,0.6)
	check(is_equal_approx(quick.clip_phase,0.125*0.6*3.0*TAU/quick.gpu_model.clip_length),"Quickfeet clip lost 3x playback or blend")
	var phase: float = quick.clip_phase
	quick.advance(0.5,0)
	check(quick.clip_phase == phase,"Stopped authored clip did not freeze")
	# Deliberately move global and per-mesh tail slots in different orders.
	for i in [1,6,5,255,0,127]: enemies[i].free()
	for i in batch.units.size():
		var enemy: Node3D = batch.units[i]
		var appearance: RefCounted = batch._appearances[i]
		check(batch._slots[enemy] == i and appearance.batch.units[appearance.batch.slots[enemy]] == enemy,"Mixed slot compaction lost enemy identity")
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.free()
	for geometry: RefCounted in batch._batches.values(): check(geometry.view.multimesh.visible_instance_count == 0,"GPU batch leaked visible instances")
	check(batch.units.is_empty(),"Overlay order leaked departed enemies")
	scene.free()
	var result := {"failures":failures,"max_vertex_error":max_vertex_error,"max_normal_error":max_normal_error,"mixed_population":258,"batches":3}
	var file := FileAccess.open(Artifacts.path("enemies/gpu_models.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	print("ENEMY_GPU_MODELS_CHECK:"+JSON.stringify(result))
	quit(int(failures>0))

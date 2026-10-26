extends SceneTree
## Bake the CURRENT saved rigid models; never regenerate prototype geometry.
const GpuModel = preload("res://scripts/enemies/rendering/enemy_gpu_model.gd")
const SolidBaker = preload("res://tools/assets/solid_mesh_baker.gd")
const PARTS := {"Body":0.0, "LegLeft":1.0, "LegRight":-1.0, "ArmLeft":2.0, "ArmRight":-2.0}

func _initialize() -> void:
	for name in ["runner", "brute"]:
		var error := bake(name)
		if error != OK:
			push_error("Rigid gait bake failed: "+name)
			quit(error)
			return
	quit()

func bake(name: String) -> int:
	var source := load("res://assets/models/enemies/"+name+".tscn") as PackedScene
	var root := source.instantiate() as Node3D
	var clip: Animation = root.get_node("AnimationPlayer").get_animation("Walk")
	if clip.get_track_count() != 6 or clip.loop_mode != Animation.LOOP_LINEAR or root.get_node("ModelRoot").transform != Transform3D.IDENTITY:
		root.free()
		return ERR_INVALID_DATA
	var model := GpuModel.new()
	model.source = source
	model.root_transform = root.transform
	model.clip_length = clip.length
	model.keyframe_intervals = 16
	# Validate the supported rigid gait, including every authored key. Fail closed
	# if artists change it; unsupported scenes can continue using AnimationPlayer.
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		var node := root.get_node(NodePath(path.get_concatenated_names()))
		var property := path.get_concatenated_subnames()
		if clip.track_get_type(track) != Animation.TYPE_VALUE or clip.track_get_interpolation_type(track) != Animation.INTERPOLATION_LINEAR or clip.track_get_key_count(track) != 17:
			root.free()
			return ERR_INVALID_DATA
		if node.name == &"ModelRoot" and property == "position": model.body_bob = clip.track_get_key_value(track,4).y
		if node.name == &"ModelRoot" and property == "rotation": model.body_sway = clip.track_get_key_value(track,4).z
		for key in 17:
			var wave := sin(float(key)*TAU/16.0)
			var expected := Vector3.ZERO
			if node.name == &"ModelRoot":
				if property == "position": expected.y = absf(wave)*model.body_bob
				elif property == "rotation": expected.z = wave*model.body_sway
				else: return ERR_INVALID_DATA
			elif PARTS.has(String(node.name)) and property == "rotation":
				var limb: float = PARTS[String(node.name)]
				expected.x = wave*signf(limb)*(-model.arm_swing if absf(limb)>1.5 else model.leg_swing)
			else: return ERR_INVALID_DATA
			if not expected.is_equal_approx(clip.track_get_key_value(track,key)) or not is_equal_approx(clip.track_get_key_time(track,key), float(key)*clip.length/16.0):
				root.free()
				return ERR_INVALID_DATA
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for part_name in PARTS:
		var part: Node3D = root.get_node("ModelRoot/"+part_name)
		var instance: MeshInstance3D = part.get_node("Mesh")
		var material := instance.get_active_material(0)
		if instance.mesh.get_surface_count() != 1 or part.basis != Basis.IDENTITY or instance.transform != Transform3D.IDENTITY or not SolidBaker.supports(material):
			root.free()
			return ERR_INVALID_DATA
		var relative: Transform3D = part.transform*instance.transform
		var arrays := instance.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(i)
		for index in indices:
			var point: Vector3 = relative*arrays[Mesh.ARRAY_VERTEX][index]
			vertices.append(point)
			normals.append((relative.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][index]).normalized())
			var tint: Color = material.albedo_color if material is StandardMaterial3D else Color.WHITE
			colors.append(tint*arrays[Mesh.ARRAY_COLOR][index])
			uv.append(Vector2(PARTS[part_name],part.position.z))
			uv2.append(Vector2(part.position.x,part.position.y))
			model.rest_height = maxf(model.rest_height,point.y)
	var merged := []
	merged.resize(Mesh.ARRAY_MAX)
	merged[Mesh.ARRAY_VERTEX] = vertices
	merged[Mesh.ARRAY_NORMAL] = normals
	merged[Mesh.ARRAY_COLOR] = colors
	merged[Mesh.ARRAY_TEX_UV] = uv
	merged[Mesh.ARRAY_TEX_UV2] = uv2
	# Match Soldier's indexed vertex format for a single shared render signature.
	var indices := PackedInt32Array()
	for i in vertices.size(): indices.append(i)
	merged[Mesh.ARRAY_INDEX] = indices
	model.mesh = ArrayMesh.new()
	# Fill all attributes before upload: an intermediate mesh would quantize
	# normals twice and accumulate error on each source-to-GPU bake.
	model.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,SolidBaker.gait_arrays(merged,model),[],{},SolidBaker.CUSTOM_FLAGS)
	model.mesh.surface_set_material(0,SolidBaker.MATERIAL)
	model.mesh.custom_aabb = model.mesh.get_aabb().grow(0.3)
	var base := "res://assets/models/enemies/"+name
	var result := ResourceSaver.save(model.mesh,base+"_mesh.res")
	if result == OK:
		model.mesh = load(base+"_mesh.res")
		result = ResourceSaver.save(model,base+"_gpu.tres")
	root.free()
	return result

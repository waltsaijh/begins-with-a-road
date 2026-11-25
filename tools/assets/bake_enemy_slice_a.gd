extends SceneTree
## Bake the imported rigid object clips into the existing MultiMesh renderer.
const Clip = preload("res://scripts/enemies/rendering/enemy_rigid_clip.gd")
const ClipShader = preload("res://assets/shaders/enemy_rigid_clip.gdshader")
const Baker = preload("res://tools/assets/solid_mesh_baker.gd")
const DIR := "res://assets/models/enemies/slice_a/"
const IDS := ["soldier","rook","scout","bomber","bloodmage","winged","rats","quickfeet","heavy"]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for id in IDS:
		if not bake(id):
			push_error("Failed baking " + id)
			quit(1)
			return
	quit()

func bake(id: String) -> bool:
	var model := Clip.new()
	model.source = load(DIR + id + ".glb")
	var scene := model.source.instantiate() as Node3D
	root.add_child(scene)
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation("Walk"):
		push_error("Expected imported Walk clip, got " + str(player.get_animation_list() if player else []))
		scene.free()
		return false
	var animation := player.get_animation("Walk")
	for name_of_clip in [&"Cast", &"Throw"]:
		if player.has_animation(name_of_clip): model.gesture = name_of_clip
	if animation.loop_mode != Animation.LOOP_LINEAR:
		push_error("Loop flag missing")
		scene.free()
		return false
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("Walk")
	model.clip_length = animation.length
	# Keep rapid paw swings accurate between source frames at close inspection zoom.
	model.keyframe_intervals = maxi(2,roundi(animation.length * 96))
	var parts := scene.find_children("*","MeshInstance3D",true,false)
	var image := Image.create_empty(model.keyframe_intervals, parts.size()*3, false, Image.FORMAT_RGBAF)
	var bounds := AABB()
	for frame in model.keyframe_intervals:
		player.seek(frame*animation.length/model.keyframe_intervals, true)
		for part in parts.size():
			var node := parts[part] as MeshInstance3D
			var pose := node.global_transform
			model.frames.append(pose)
			if frame == 0:
				model.part_bounds.append(node.get_aabb())
			# Conservative bounds for culling over all poses, including wing tips.
			var box := pose * node.get_aabb()
			bounds = box if frame == 0 and part == 0 else bounds.merge(box)
			for row in 3:
				image.set_pixel(frame,part*3+row,Color(pose.basis.x[row],pose.basis.y[row],pose.basis.z[row],pose.origin[row]))
	var mat := ShaderMaterial.new()
	mat.shader = ClipShader
	mat.set_shader_parameter("joint_frames",ImageTexture.create_from_image(image))
	var combined := SurfaceTool.new()
	combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	combined.set_material(mat)
	for part in parts.size():
		var node := parts[part] as MeshInstance3D
		for surface in node.mesh.get_surface_count():
			var source := node.get_active_material(surface) as StandardMaterial3D
			if source == null or source.albedo_texture != null or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				scene.free()
				return false
			var data := Baker.arrays(node.mesh.surface_get_arrays(surface), source.albedo_color, false, source.roughness, source.metallic_specular)
			var joint: PackedFloat32Array = data[Mesh.ARRAY_CUSTOM0]
			for vertex in data[Mesh.ARRAY_VERTEX].size():
				joint[vertex*4] = part
			data[Mesh.ARRAY_CUSTOM0] = joint
			var piece := ArrayMesh.new()
			piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data, [], {}, Baker.CUSTOM_FLAGS)
			combined.append_from(piece, 0, Transform3D.IDENTITY)
	model.mesh = combined.commit()
	model.mesh.custom_aabb = bounds
	model.rest_height = bounds.end.y
	var error := ResourceSaver.save(model, DIR + id + "_gpu.res", ResourceSaver.FLAG_COMPRESS)
	print(id, " parts=",parts.size()," period=",animation.length," bounds=",bounds," triangles=",model.mesh.surface_get_array_index_len(0)/3)
	scene.free()
	return error == OK


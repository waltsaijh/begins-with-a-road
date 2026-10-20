extends SceneTree
## Import the prototype grunt, runner and brute without runtime source dependencies.
## Grunt keeps the GPU mesh; runner/brute use five rigid meshes and a walk clip.
## godot --headless --path . --script tools/assets/build_enemy.gd
## Optional: -- --prototype=D:/path/to/card-tower-defense

func _initialize() -> void:
	var source := ProjectSettings.globalize_path("res://../card-tower-defense").simplify_path()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prototype="):
			source = argument.trim_prefix("--prototype=")
	var scratch := "res://.godot/enemy_model_source/"
	for file: String in ["enemies/miniature_humanoid.gd", "skybridge_kit.gd", "materials/skybridge_palette.gd"]:
		var original := source.path_join("art").path_join(file)
		if not FileAccess.file_exists(original):
			push_error("Missing prototype model source: "+original)
			quit(1)
			return
		var target := scratch+file
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target, FileAccess.WRITE).store_string(FileAccess.get_file_as_string(original).replace("res://art/", scratch))
	var body := Node3D.new()
	var generator: GDScript = load(scratch+"enemies/miniature_humanoid.gd")
	var parts: Dictionary = generator.create(body, "grunt")
	var limbs := {}
	for i in parts.legs.size():
		limbs[parts.legs[i]] = 1.0 if i % 2 == 0 else -1.0
	for i in parts.arms.size():
		limbs[parts.arms[i]] = 2.0 if i % 2 == 0 else -2.0
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var pivots := PackedVector3Array()
	var limb_ids := PackedFloat32Array()
	_collect(body, Transform3D.IDENTITY, positions, normals, colors, pivots, limb_ids, limbs)
	var bottom := INF
	for position in positions:
		bottom = minf(bottom, position.y)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in positions.size():
		surface.set_normal(normals[i])
		surface.set_color(colors[i])
		var pivot := pivots[i] - Vector3.UP * bottom
		surface.set_uv(Vector2(limb_ids[i], pivot.z))
		surface.set_uv2(Vector2(pivot.x, pivot.y))
		surface.add_vertex(positions[i]-Vector3.UP*bottom)
	surface.index()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	material.metallic_specular = 0.12
	surface.set_material(material)
	var mesh := surface.commit()
	# GPU limb motion can extend beyond the rest pose. Keep culling conservative.
	mesh.custom_aabb = mesh.get_aabb().grow(0.2)
	mesh.resource_name = "Prototype red grunt"
	DirAccess.make_dir_recursive_absolute("res://assets/models/enemies")
	var error := ResourceSaver.save(mesh, "res://assets/models/enemies/grunt_mesh.res")
	body.free()
	if error != OK:
		push_error(error_string(error))
	print("Grunt: one surface, ", positions.size()/3, " triangles; source: ", source)
	for profile: String in ["runner", "brute"]:
		if _build_profile_scene(generator, profile) != OK:
			quit(1)
			return
	quit(0)

func _build_profile_scene(generator: GDScript, profile: String) -> Error:
	var source := Node3D.new()
	var parts: Dictionary = generator.create(source, profile)
	var limbs := {}
	for i in parts.legs.size():
		limbs[parts.legs[i]] = 1.0 if i % 2 == 0 else -1.0
	for i in parts.arms.size():
		limbs[parts.arms[i]] = 2.0 if i % 2 == 0 else -2.0
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var pivots := PackedVector3Array()
	var ids := PackedFloat32Array()
	_collect(source, Transform3D.IDENTITY, positions, normals, colors, pivots, ids, limbs)
	source.free()
	var bottom := INF
	for point in positions: bottom = minf(bottom, point.y)
	var root := Node3D.new()
	root.name = profile.capitalize()
	root.set_meta("source_profile", profile)
	var model := Node3D.new()
	model.name = "ModelRoot"
	root.add_child(model)
	model.owner = root
	var material := StandardMaterial3D.new()
	material.resource_name = "Prototype palette"
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	material.metallic_specular = 0.12
	var names := {0: "Body", 1: "LegLeft", -1: "LegRight", 2: "ArmLeft", -2: "ArmRight"}
	for id: int in [0, 1, -1, 2, -2]:
		var group := Node3D.new()
		group.name = names[id]
		model.add_child(group)
		group.owner = root
		var pivot := Vector3.ZERO
		if id != 0:
			for i in ids.size():
				if int(ids[i]) == id:
					pivot = pivots[i]
					break
		group.position = pivot-Vector3.UP*bottom
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in positions.size():
			if int(ids[i]) != id: continue
			surface.set_normal(normals[i])
			surface.set_color(colors[i])
			surface.add_vertex(positions[i]-pivot)
		surface.index()
		surface.set_material(material)
		var instance := MeshInstance3D.new()
		instance.name = "Mesh"
		instance.mesh = surface.commit()
		group.add_child(instance)
		instance.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var gait := 1.25 if profile == "runner" else 0.85
	var walk := Animation.new()
	walk.resource_name = "Walk"
	walk.length = 1.0/gait
	walk.loop_mode = Animation.LOOP_LINEAR
	for id: int in [1, -1, 2, -2]:
		var track := walk.add_track(Animation.TYPE_VALUE)
		walk.track_set_path(track, NodePath("ModelRoot/"+names[id]+":rotation"))
		var swing := 0.3 if absi(id) == 1 else -0.20
		if id < 0: swing = -swing
		for step in 17:
			var fraction := float(step)/16.0
			walk.track_insert_key(track, fraction*walk.length, Vector3(sin(fraction*TAU)*swing, 0, 0))
	var bob := walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(bob, NodePath("ModelRoot:position"))
	var sway := walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(sway, NodePath("ModelRoot:rotation"))
	for step in 17:
		var fraction := float(step)/16.0
		var stride := sin(fraction*TAU)
		walk.track_insert_key(bob, fraction*walk.length, Vector3(0, absf(stride)*0.026*gait, 0))
		walk.track_insert_key(sway, fraction*walk.length, Vector3(0, 0, stride*0.025))
	var library := AnimationLibrary.new()
	library.add_animation("Walk", walk)
	player.add_animation_library("", library)
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, "res://assets/models/enemies/"+profile+".tscn")
	root.free()
	if error != OK: push_error(error_string(error))
	print(profile.capitalize(), ": five meshes, ", positions.size()/3, " triangles; walk ", walk.length, "s")
	return error

func _collect(node: Node3D, parent: Transform3D, positions: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, pivots: PackedVector3Array, limb_ids: PackedFloat32Array, limbs: Dictionary, limb_id := 0.0, pivot := Vector3.ZERO) -> void:
	var pose := parent*node.transform
	if limbs.has(node):
		limb_id = limbs[node]
		pivot = pose.origin
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for s in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var face_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var material := instance.material_override as StandardMaterial3D
			var normal_basis := pose.basis.inverse().transposed()
			for i in (indices.size() if not indices.is_empty() else vertices.size()):
				var index := indices[i] if not indices.is_empty() else i
				positions.append(pose*vertices[index])
				normals.append((normal_basis*source_normals[index]).normalized())
				colors.append(material.albedo_color*(face_colors[index] if not face_colors.is_empty() else Color.WHITE))
				pivots.append(pivot)
				limb_ids.append(limb_id)
	for child in node.get_children():
		if child is Node3D:
			_collect(child, pose, positions, normals, colors, pivots, limb_ids, limbs, limb_id, pivot)

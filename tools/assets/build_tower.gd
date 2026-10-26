extends SceneTree
## Bake the prototype sentry once; production has no dependency on its generator.

func _initialize() -> void:
	var source := ProjectSettings.globalize_path("res://../card-tower-defense").simplify_path()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prototype="):
			source = argument.trim_prefix("--prototype=")
	var scratch := "res://.godot/tower_model_source/"
	for file: String in ["towers/skybridge_towers.gd", "props/skybridge_props.gd", "skybridge_kit.gd", "materials/skybridge_palette.gd"]:
		var original := source.path_join("art").path_join(file)
		if not FileAccess.file_exists(original):
			push_error("Missing prototype source: " + original)
			quit(1)
			return
		var target := scratch + file
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target, FileAccess.WRITE).store_string(FileAccess.get_file_as_string(original).replace("res://art/", scratch))
	# Resolve nested script constants before parsing the full six-tower generator.
	var dependencies: Array[GDScript] = []
	for file: String in ["materials/skybridge_palette.gd", "skybridge_kit.gd", "props/skybridge_props.gd"]:
		dependencies.append(load(scratch + file))
	var generator: GDScript = load(scratch + "towers/skybridge_towers.gd")
	if generator == null or not generator.can_instantiate():
		quit(1)
		return
	var model: Node3D = generator.create(0)
	var upper: Node3D = model.get_meta("recoil")
	# The first upper part is the round mount: keep it with the fixed base.
	var mount := upper.get_child(0) as MeshInstance3D
	var base := SurfaceTool.new()
	base.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collect(model, Transform3D.IDENTITY, base, upper)
	_collect(mount, upper.transform, base)
	var weapon := SurfaceTool.new()
	weapon.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collect(upper, upper.transform.affine_inverse(), weapon, mount)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	material.metallic_specular = 0.12
	DirAccess.make_dir_recursive_absolute("res://assets/models/towers")
	var triangles := 0
	for part: String in ["base", "weapon"]:
		var surface := base if part == "base" else weapon
		surface.index()
		surface.set_material(material)
		var mesh := preload("res://tools/assets/solid_mesh_baker.gd").mesh(surface.commit())
		mesh.resource_name = "Prototype wooden sentry " + part
		triangles += mesh.get_faces().size()/3
		var error := ResourceSaver.save(mesh, "res://assets/models/towers/sentry_%s_mesh.res" % part)
		if error != OK:
			model.free()
			push_error(error_string(error))
			quit(1)
			return
	model.free()
	print("Sentry: fixed base + aimable weapon, ", triangles, " triangles")
	quit()

func _collect(node: Node3D, parent: Transform3D, surface: SurfaceTool, skip: Node3D = null) -> void:
	if node == skip:
		return
	var pose := parent * node.transform
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for s in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var material := instance.material_override as StandardMaterial3D
			var normal_basis := pose.basis.inverse().transposed()
			for i in (indices.size() if not indices.is_empty() else vertices.size()):
				var index := indices[i] if not indices.is_empty() else i
				surface.set_normal((normal_basis * normals[index]).normalized())
				surface.set_color(material.albedo_color * (colors[index] if not colors.is_empty() else Color.WHITE))
				surface.add_vertex(pose * vertices[index])
	for child in node.get_children():
		if child is Node3D:
			_collect(child, pose, surface, skip)

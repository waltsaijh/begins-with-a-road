extends Resource
## Rebuildable palette inputs and shared A/B meshes. Does not alter materials or animation.
@export_enum("A", "B") var variant := "B"
@export var identity_colors: Dictionary[String, Color] = {}
@export var identity_parts: Dictionary = {}
@export var baseline_meshes: Dictionary[String, Mesh] = {}
@export var colored_meshes: Dictionary[String, Mesh] = {}

func apply_to(root: Node, selected := "") -> void:
	var use_variant := variant if selected.is_empty() else selected
	assert(use_variant in ["A", "B"])
	var choices := colored_meshes if use_variant == "B" else baseline_meshes
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null: continue
		var path := node.mesh.resource_path
		if not (path.begins_with("res://assets/models/towers/integrated/") or path.begins_with("res://assets/models/towers/color_identity/b/")): continue
		var key := path.get_file()
		if choices.has(key): node.mesh = choices[key]

func colored_copy(source: Mesh, kind: String, part: String) -> ArrayMesh:
	var rules: Dictionary = identity_parts.get(kind, {})
	var full: bool = rules.get("full", []).any(func(pattern): return part.match(pattern))
	var upper: bool = rules.get("upper", []).any(func(pattern): return part.match(pattern))
	if not full and not upper: return source
	var result := ArrayMesh.new()
	var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR].duplicate()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in colors.size():
			# Keep true bore walls, strings and dark mechanical pieces unchanged.
			if maxf(colors[i].r, maxf(colors[i].g, colors[i].b)) < .5: continue
			if full or upper and normals[i].y > .65: colors[i] = identity_colors[kind]
		arrays[Mesh.ARRAY_COLOR] = colors
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], {}, flags)
		result.surface_set_material(surface, source.surface_get_material(surface))
	return result

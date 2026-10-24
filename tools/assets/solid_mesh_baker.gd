extends RefCounted
## Offline-only palette conversion. Never replaces an unsupported material.
const MATERIAL = preload("res://assets/materials/solid_color.tres")
const CUSTOM_FLAGS = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RG_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

static func supports(material: Material) -> bool:
	if material == MATERIAL: return true
	if not material is StandardMaterial3D: return false
	var reference := StandardMaterial3D.new()
	reference.roughness = 0.98
	reference.metallic_specular = 0.12
	# Compare every stored render setting, including textures, emission, alpha,
	# culling, shading and next_pass. Only palette inputs may differ.
	for property in reference.get_property_list():
		var name: String = property.name
		if not property.usage & PROPERTY_USAGE_STORAGE or name.begins_with("resource_") or name in ["albedo_color","vertex_color_use_as_albedo","roughness","metallic_specular"]: continue
		if material.get(name) != reference.get(name): return false
	return material.albedo_color.a == 1.0

static func arrays(source: Array, tint := Color.WHITE, use_colors := true, roughness := 0.98, specular := 0.12) -> Array:
	var result := source.duplicate()
	var count: int = source[Mesh.ARRAY_VERTEX].size()
	var colors := PackedColorArray()
	var original: PackedColorArray = source[Mesh.ARRAY_COLOR] if source[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	for i in count: colors.append(tint*(original[i] if use_colors and not original.is_empty() else Color.WHITE))
	result[Mesh.ARRAY_COLOR] = colors
	for channel in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
		if result[channel] == null or result[channel].is_empty():
			var uv := PackedVector2Array()
			uv.resize(count)
			result[channel] = uv
	if result[Mesh.ARRAY_CUSTOM0] == null or result[Mesh.ARRAY_CUSTOM0].is_empty():
		var data := PackedFloat32Array()
		data.resize(count*4)
		result[Mesh.ARRAY_CUSTOM0] = data
	if result[Mesh.ARRAY_CUSTOM1] == null or result[Mesh.ARRAY_CUSTOM1].is_empty():
		var response := PackedFloat32Array()
		for i in count:
			response.append(roughness)
			response.append(specular)
		result[Mesh.ARRAY_CUSTOM1] = response
	if result[Mesh.ARRAY_INDEX] == null or result[Mesh.ARRAY_INDEX].is_empty():
		var indices := PackedInt32Array()
		for i in count: indices.append(i)
		result[Mesh.ARRAY_INDEX] = indices
	# No normal map uses tangents in this material.
	result[Mesh.ARRAY_TANGENT] = null
	return result

static func mesh(source: Mesh, override: Material = null, surface_overrides: Array[Material] = []) -> ArrayMesh:
	# Re-saving already baked sources must not repeatedly quantize normals.
	if source is ArrayMesh and override == null:
		var unchanged := true
		var solid_count := 0
		for surface in source.get_surface_count():
			var original := source.surface_get_material(surface)
			var active := surface_overrides[surface] if surface < surface_overrides.size() and surface_overrides[surface] != null else original
			if active != original or (active != MATERIAL and supports(active)): unchanged = false
			if active == MATERIAL:
				solid_count += 1
				if (source.surface_get_format(surface) & Mesh.ARRAY_FORMAT_CUSTOM1) == 0: unchanged = false
		if unchanged and solid_count <= 1: return source
	# This converter is for static/rigid, single-LOD source geometry. Never
	# silently discard imported skeletons, morphs or authored LODs.
	if source is ArrayMesh and source.get_blend_shape_count() > 0:
		push_error("Solid bake does not support blend shapes")
		return null
	for surface in source.get_surface_count():
		var data := source.surface_get_arrays(surface)
		if data[Mesh.ARRAY_BONES] != null and not data[Mesh.ARRAY_BONES].is_empty():
			push_error("Solid bake does not support skinning")
			return null
		if source is ArrayMesh and not RenderingServer.mesh_get_surface(source.get_rid(),surface).get("lods",[]).is_empty():
			push_error("Solid bake does not support authored LODs")
			return null
	var result := ArrayMesh.new()
	var solid := SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	solid.set_material(MATERIAL)
	var has_solid := false
	for surface in source.get_surface_count():
		var primitive: int = source.surface_get_primitive_type(surface) if source is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		var material := override if override != null else (surface_overrides[surface] if surface < surface_overrides.size() and surface_overrides[surface] != null else source.surface_get_material(surface))
		var data := source.surface_get_arrays(surface)
		if supports(material) and primitive == Mesh.PRIMITIVE_TRIANGLES:
			if material != MATERIAL: data = arrays(data,material.albedo_color,material.vertex_color_use_as_albedo,material.roughness,material.metallic_specular)
			else: data = arrays(data)
			var part := ArrayMesh.new()
			part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data,[],{},CUSTOM_FLAGS)
			solid.append_from(part,0,Transform3D.IDENTITY)
			has_solid = true
		else:
			var flags: int = source.surface_get_format(surface) if source is ArrayMesh else 0
			result.add_surface_from_arrays(primitive,data,[],{},flags)
			result.surface_set_material(result.get_surface_count()-1,material)
	if has_solid: solid.commit(result)
	result.resource_name = source.resource_name
	if source is ArrayMesh: result.custom_aabb = source.custom_aabb
	return result

static func gait(source: ArrayMesh, model: Resource) -> ArrayMesh:
	var original := source.surface_get_arrays(0)
	var data := gait_arrays(original,model)
	if data[Mesh.ARRAY_CUSTOM0] == original[Mesh.ARRAY_CUSTOM0] and source.surface_get_material(0) == MATERIAL and (source.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM1) != 0: return source
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data,[],{},CUSTOM_FLAGS)
	result.surface_set_material(0,MATERIAL)
	result.custom_aabb = source.custom_aabb
	result.resource_name = source.resource_name
	return result

static func gait_arrays(source: Array, model: Resource) -> Array:
	var data := arrays(source)
	var custom := PackedFloat32Array()
	for uv: Vector2 in data[Mesh.ARRAY_TEX_UV]:
		custom.append(signf(uv.x)*(-model.arm_swing if absf(uv.x)>1.5 else model.leg_swing))
		custom.append(model.body_bob)
		custom.append(model.body_sway)
		custom.append(float(model.keyframe_intervals+1))
	data[Mesh.ARRAY_CUSTOM0] = custom
	return data

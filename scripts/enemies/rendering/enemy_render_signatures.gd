extends RefCounted
## Conservative render combinations, independent of troop names and mesh shapes.
const DefaultScene = preload("res://assets/models/enemies/grunt.tscn")
const DefaultMesh = preload("res://assets/models/enemies/grunt_mesh.res")
const WalkShader = preload("res://assets/shaders/solid_color.gdshader")
const Appearance = preload("res://scripts/enemies/rendering/enemy_model.gd")

static func profile_keys(profile: Troop) -> Array[String]:
	var gpu := Appearance.gpu_for(profile)
	if gpu != null:
		return ["multimesh:"+resource_key(WalkShader)+":"+str(gpu.mesh.surface_get_format(0))+":"+str(gpu.mesh.surface_get_primitive_type(0))]
	var root := profile.model.instantiate()
	var keys: Array[String] = []
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: meshes.append(root)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			var key := "mesh:"+str(mesh.mesh.surface_get_format(surface))+":"+str(mesh.mesh.surface_get_primitive_type(surface))
			key += ":skin="+str(mesh.skin != null)+":blend="+str(mesh.mesh.get_blend_shape_count() > 0)
			key += ":shadow="+str(mesh.cast_shadow)+":material="+resource_key(material)
			key += ":overlay="+resource_key(mesh.material_overlay)
			key += ":layers="+str(mesh.layers)+":gi="+str(mesh.gi_mode)
			key += ":fade="+str(mesh.visibility_range_fade_mode)+":alpha="+str(mesh.transparency)
			# Skinned/blended and scripted scenes may change render state at runtime.
			if mesh.skin != null or mesh.mesh.get_blend_shape_count() > 0:
				key += ":scene="+profile.model.resource_path
			if not keys.has(key): keys.append(key)
	# Non-transform animation tracks and scripts are opaque: never merge scenes.
	var opaque := false
	for node in [root]+root.find_children("*", "", true, false):
		if node.get_script() != null: opaque = true
		if node is AnimationPlayer:
			for title in node.get_animation_list():
				var animation: Animation = node.get_animation(title)
				for track in animation.get_track_count():
					var type := animation.track_get_type(track)
					var property := String(animation.track_get_path(track).get_concatenated_subnames())
					var transform_value := type == Animation.TYPE_VALUE and property in ["position", "rotation", "rotation_degrees", "scale", "transform"]
					if not transform_value and type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]: opaque = true
	if opaque or keys.is_empty(): keys.append("scene:"+str(profile.model.get_instance_id()))
	root.free()
	keys.sort()
	return keys

static func resource_key(resource: Resource) -> String:
	if resource == null: return "none"
	if resource.get_script() != null: return "scripted:"+str(resource.get_instance_id())
	# Texture identity preserves distinct texture formats and sampling inputs.
	if resource is Texture: return "texture:"+str(resource.get_instance_id())
	var values: Array = [resource.get_class()]
	for property in resource.get_property_list():
		var name: String = property.name
		if not property.usage & PROPERTY_USAGE_STORAGE or name.begins_with("resource_") or name == "script": continue
		var value: Variant = resource.get(name)
		if value is Resource: value = resource_key(value)
		values.append([name, value])
	return var_to_str(values).sha256_text()

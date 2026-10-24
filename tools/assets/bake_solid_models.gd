extends SceneTree
## Convert the saved local assets in place, preserving transforms and animation.
## Does NOT call prototype generators, rebuild topology or reset maps.
const Baker = preload("res://tools/assets/solid_mesh_baker.gd")
var converted := {}
var failures := 0

func _initialize() -> void:
	for name in ["sentry_base","sentry_weapon"]:
		var path: String = "res://assets/models/towers/"+name+"_mesh.res"
		save(Baker.mesh(load(path)),path)
	for folder in ["tiles","tiles/variants","endpoints","enemies"]:
		for filename in DirAccess.get_files_at("res://assets/models/"+folder):
			if not filename.ends_with(".tscn"): continue
			var path: String = "res://assets/models/"+folder+"/"+filename
			# Grunt shares the animated mesh baked below; don't overwrite its data.
			if filename == "grunt.tscn": continue
			var packed := load(path) as PackedScene
			var root := packed.instantiate()
			for node: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
				if node.mesh == null: continue
				var eligible := false
				var materials: Array[Material] = []
				for surface in node.mesh.get_surface_count():
					materials.append(node.get_active_material(surface))
					eligible = eligible or Baker.supports(materials[-1])
				if not eligible: continue
				var key := str(node.mesh.get_instance_id())+":"+str(materials)
				if not converted.has(key): converted[key] = Baker.mesh(node.mesh,null,materials)
				if converted[key] == null:
					push_error("Unsupported mesh: "+path+":"+str(node.get_path()))
					quit(1)
					return
				node.mesh = converted[key]
				node.material_override = null
				for surface in node.mesh.get_surface_count(): node.set_surface_override_material(surface,null)
			var result := PackedScene.new()
			result.pack(root)
			root.free()
			save(result,path)
	# Convert the current library directly, preserving designer geometry/items.
	var library := load("res://assets/models/mesh_library.tres") as MeshLibrary
	for item in library.get_item_list():
		var mesh := Baker.mesh(library.get_item_mesh(item))
		if mesh == null:
			quit(1)
			return
		library.set_item_mesh(item,mesh)
	save(library,"res://assets/models/mesh_library.tres")
	for name in ["grunt","runner","brute"]:
		var model := load("res://assets/models/enemies/"+name+"_gpu.tres")
		save(Baker.gait(model.mesh,model),"res://assets/models/enemies/"+name+"_mesh.res")
	print("SOLID_BAKE: failures=",failures)
	quit(int(failures>0))

func save(resource: Resource, path: String) -> void:
	if resource == null:
		failures += 1
		push_error("Unsupported mesh: "+path)
		return
	var uid := ResourceLoader.get_resource_uid(path)
	var error := ResourceSaver.save(resource,path)
	if error == OK and uid != ResourceUID.INVALID_ID: error = ResourceSaver.set_uid(path,uid)
	if error != OK:
		failures += 1
		push_error(path+": "+error_string(error))

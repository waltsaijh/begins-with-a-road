extends SceneTree
const IDS = ["great_ballista","watchtower","barracks","mortar","crossfire","broadside_airship"]
const BASE = "res://assets/models/towers/art_slice_d/"
const Baker = preload("res://tools/assets/solid_mesh_baker.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report := {}
	for id in IDS:
		var model: Node = load(BASE+id+".glb").instantiate()
		root.add_child(model)
		var nodes := model.find_children("*","",true,false)
		var count := 0
		model.scene_file_path = ""
		DirAccess.make_dir_recursive_absolute(BASE+id+"_meshes")
		for n in nodes:
			n.scene_file_path = ""
			n.owner = model
			if n is MeshInstance3D:
				var baked: ArrayMesh = Baker.mesh(n.mesh)
				assert(baked != null,"Unsupported mesh: "+str(n.name))
				for surface in baked.get_surface_count():
					assert(baked.surface_get_format(surface)&Mesh.ARRAY_FORMAT_CUSTOM0)
					assert(baked.surface_get_format(surface)&Mesh.ARRAY_FORMAT_CUSTOM1)
				var path: String = BASE+id+"_meshes/part_%03d.res" % count
				assert(ResourceSaver.save(baked,path)==OK)
				n.mesh=load(path)
				count+=1
			elif n is Node3D and ("Muzzle" in str(n.name) or "ArrowRelease" in str(n.name)):
				assert(n.get_child_count()==0)
				var marker := Marker3D.new()
				marker.name=n.name
				marker.transform=n.transform
				var parent: Node = n.get_parent()
				parent.remove_child(n);parent.add_child(marker);marker.owner=model;n.free()
		var packed := PackedScene.new()
		assert(packed.pack(model)==OK)
		assert(ResourceSaver.save(packed,BASE+id+"_visual.tscn")==OK)
		report[id]={"baked_meshes":count,"shared_material":"res://assets/materials/solid_color.tres","marker3d":true}
		model.free()
	var f := FileAccess.open("res://bake-check.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"));f.close()
	print("SLICE_D_BAKE PASS");quit()

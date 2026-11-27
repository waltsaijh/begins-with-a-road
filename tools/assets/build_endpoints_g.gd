extends SceneTree
## Art Slice G endpoint art: assets/models/endpoints/{castle,camp}.glb (from
## tools/assets/blender/art_slice_g/endpoints.py) -> castle.tscn / camp.tscn with the
## shared solid-colour material, static parts merged, and endpoint_visual.gd on the root.
## Run: godot --headless --path . --script res://tools/assets/build_endpoints_g.gd
const DIR := "res://assets/models/endpoints/"
const MATERIAL := preload("res://assets/materials/solid_color.tres")
const Baker := preload("res://tools/assets/solid_mesh_baker.gd")
const Facing := preload("res://scripts/map/terrain/endpoint_visual.gd")

func _initialize() -> void: call_deferred("build")

func merge(parent: Node3D, owner_node: Node) -> void:
	var parts: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if child is MeshInstance3D: parts.append(child)
		elif child is Node3D: merge(child, owner_node)
	if parts.size() < 2: return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT); tool.set_custom_format(1, SurfaceTool.CUSTOM_RG_FLOAT)
	tool.set_material(MATERIAL)
	for p in parts:
		for surface in p.mesh.get_surface_count(): tool.append_from(p.mesh, surface, p.transform)
		p.free()
	var mesh := MeshInstance3D.new(); mesh.name = "StaticAssembly"; mesh.mesh = tool.commit()
	parent.add_child(mesh); mesh.owner = owner_node

func build() -> void:
	for kind in ["castle", "camp"]:
		var source: PackedScene = load(DIR+kind+".glb")
		assert(source != null, "Missing "+kind+".glb")
		var model := source.instantiate() as Node3D
		root.add_child(model)
		for n in model.find_children("*", "MeshInstance3D", true, false):
			n.mesh = Baker.mesh(n.mesh)
		for n in model.find_children("*Lamp", "Node3D", true, false):
			n.name = String(n.name).get_slice("__", 1)
		merge(model, model)
		var index := 0
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var path: String = DIR+"%s_part_%02d.res" % [kind, index]
			assert(ResourceSaver.save(mesh.mesh, path) == OK)
			mesh.mesh = load(path); index += 1
		var wrapper := Node3D.new(); wrapper.name = kind.capitalize()
		wrapper.set_script(Facing)
		root.remove_child(model); wrapper.add_child(model)
		for node in model.find_children("*", "", true, false): node.owner = wrapper; node.scene_file_path = ""
		model.owner = wrapper; model.scene_file_path = ""
		var packed := PackedScene.new(); assert(packed.pack(wrapper) == OK)
		assert(ResourceSaver.save(packed, DIR+kind+".tscn") == OK)
		wrapper.free()
		print("ENDPOINT_BUILT ", kind, " meshes=", index)
	quit()

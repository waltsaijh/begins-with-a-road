extends SceneTree
## Bake source models for GridMap. Geometry stays shared across placed cells.
## godot --headless --path . --script tools/assets/build_tile_library.gd
## Add -- --demo only when intentionally resetting the example map.

const SOURCES := TileConstants.BASE_NAMES
const LIBRARY_PATH := "res://assets/models/mesh_library.tres"

func _initialize() -> void:
	var library := MeshLibrary.new()
	for id in SOURCES.size():
		var source := load("res://assets/models/tiles/%s.tscn" % SOURCES[id]) as PackedScene
		if source == null:
			quit(1)
			return
		var model := source.instantiate() as Node3D
		library.create_item(id)
		library.set_item_name(id, SOURCES[id])
		library.set_item_mesh(id, bake(model))
		if id > 0:
			var support: Node3D = load("res://assets/models/tiles/variants/pillar_support.tscn").instantiate()
			model.add_child(support)
			var pillar_id := TileConstants.item_for(id, TileConstants.Appearance.PILLAR)
			library.create_item(pillar_id)
			library.set_item_name(pillar_id, SOURCES[id] + "_pillar")
			library.set_item_mesh(pillar_id, bake(model))
		model.free()
	var wood: Node3D = load("res://assets/models/tiles/variants/wood_straight.tscn").instantiate()
	library.create_item(TileConstants.WOOD_STRAIGHT)
	library.set_item_name(TileConstants.WOOD_STRAIGHT, "wood_straight")
	library.set_item_mesh(TileConstants.WOOD_STRAIGHT, bake(wood))
	wood.free()
	var error := ResourceSaver.save(library, LIBRARY_PATH, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		push_error("Could not save tile library: %s" % error)
		quit(1)
		return
	if "--demo" in OS.get_cmdline_user_args():
		error = save_demo()
	print("Tile library: ", library.get_item_list().size(), " models. Result: ", error_string(error))
	quit(0 if error == OK else 1)

func bake(model: Node3D) -> ArrayMesh:
	var surfaces := {}
	_collect(model, Transform3D.IDENTITY, surfaces)
	var mesh := ArrayMesh.new()
	for builder: SurfaceTool in surfaces.values():
		builder.commit(mesh)
	return mesh

func _collect(node: Node3D, parent: Transform3D, surfaces: Dictionary) -> void:
	var pose := parent * node.transform
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			if not surfaces.has(material):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				builder.set_material(material)
				surfaces[material] = builder
			surfaces[material].append_from(node.mesh, surface, pose)
	for child in node.get_children():
		if child is Node3D:
			_collect(child, pose, surfaces)

func save_demo() -> Error:
	var map := GridMap.new()
	map.name = "TileMap"
	map.mesh_library = load(LIBRARY_PATH) as MeshLibrary
	map.cell_size = Vector3.ONE
	map.cell_center_y = false
	map.position = Vector3(-12, 0, -0.5)
	# Prototype frontier_outpost: 24 cells across. Keep only its straight spine.
	var horizontal := map.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2))
	for x in 24:
		map.set_cell_item(Vector3i(x, 0, 0), 1, horizontal)
	var scene := PackedScene.new()
	var error := scene.pack(map)
	if error == OK:
		error = ResourceSaver.save(scene, "res://scenes/maps/tile_map.tscn")
	map.free()
	return error

extends SceneTree
## Bake editable variant sources, adapted from the prototype's bridge_detail
## and terrain_mass rings. Run before tools/assets/build_tile_library.gd.

const DESTINATION := "res://assets/models/tiles/variants/"
const WOOD = preload("res://assets/materials/wood.tres")
const LIGHT_WOOD = preload("res://assets/materials/wood_light.tres")
const DARK_WOOD = preload("res://assets/materials/wood_dark.tres")
const PILLAR = preload("res://assets/materials/pillar_stone.tres")

func _initialize() -> void:
	if not _save(_wood_bridge(), "wood_straight.tscn"):
		quit(1)
		return
	quit(0 if _save(_pillar(), "pillar_support.tscn") else 1)

func _wood_bridge() -> Node3D:
	var root := Node3D.new()
	root.name = "WoodStraight"
	# Prototype bridge_detail has its travel axis along X; ours is along Z.
	for i in 6:
		_box(root, "Plank%d" % i, Vector3(0.63, 0.022, 0.15), Vector3(0, 0.04, -0.42 + i * 0.167), LIGHT_WOOD if i % 2 == 0 else WOOD)
	for side in [-1.0, 1.0]:
		_box(root, "Handrail", Vector3(0.035, 0.035, 0.98), Vector3(side * 0.43, 0.23, 0), DARK_WOOD)
		_box(root, "Beam", Vector3(0.075, 0.12, 1.0), Vector3(side * 0.245, -0.04, 0), DARK_WOOD)
		for z in [-0.39, 0.39]:
			_box(root, "Post", Vector3(0.04, 0.26, 0.04), Vector3(side * 0.43, 0.10, z), WOOD)
	return root

func _box(root: Node3D, title: String, size: Vector3, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = title
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	node.mesh = mesh
	node.position = at
	root.add_child(node, true)
	node.owner = root

func _pillar() -> Node3D:
	var root := Node3D.new()
	root.name = "PillarSupport"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(PILLAR)
	# Chamfered cross-section; uneven rock bands echo the prototype terrain mass.
	var ring: Array[Vector2] = [Vector2(-0.5, -0.35), Vector2(-0.35, -0.5), Vector2(0.35, -0.5), Vector2(0.5, -0.35), Vector2(0.5, 0.35), Vector2(0.35, 0.5), Vector2(-0.35, 0.5), Vector2(-0.5, 0.35)]
	var heights := [-0.37, -0.68, -1.32, -2.35, -4.0]
	var widths := [0.995, 1.14, 0.94, 1.01, 0.82]
	for band in 4:
		for i in ring.size():
			var next := (i + 1) % ring.size()
			var a := _ring_point(ring[i], i, band, heights, widths)
			var b := _ring_point(ring[next], next, band, heights, widths)
			var c := _ring_point(ring[next], next, band + 1, heights, widths)
			var d := _ring_point(ring[i], i, band + 1, heights, widths)
			var outward := Vector3(ring[i].x + ring[next].x, 0, ring[i].y + ring[next].y)
			var value := (1.0 - band * 0.08) * (0.94 + 0.06 * cos(i * 1.7))
			_quad(st, a, b, c, d, Color(value, value, value, 1), outward)
	for i in range(1, ring.size() - 1):
		_triangle(st, _ring_point(ring[0], 0, 4, heights, widths), _ring_point(ring[i], i, 4, heights, widths), _ring_point(ring[i + 1], i + 1, 4, heights, widths), Color(0.6, 0.6, 0.6), Vector3.DOWN)
	var node := MeshInstance3D.new()
	node.name = "FacetedStone"
	node.mesh = st.commit()
	root.add_child(node)
	node.owner = root
	return root

func _ring_point(point: Vector2, index: int, band: int, heights: Array, widths: Array) -> Vector3:
	var y: float = heights[band]
	if band > 0 and band < 4:
		y += sin(index * 1.3 + band * 1.7) * 0.07
	return Vector3(point.x * widths[band], y, point.y * widths[band])

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward: Vector3) -> void:
	_triangle(st, a, b, c, color, outward)
	_triangle(st, a, c, d, color, outward)

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot(outward) < 0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for point in [a, b, c]:
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(point)

func _save(model: Node3D, filename: String) -> bool:
	var scene := PackedScene.new()
	var error := scene.pack(model)
	if error == OK:
		error = ResourceSaver.save(scene, DESTINATION + filename)
	model.free()
	if error != OK:
		push_error("Variant bake: " + error_string(error))
	return error == OK

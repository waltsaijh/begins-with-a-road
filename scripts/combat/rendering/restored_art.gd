extends RefCounted
## Small visual-only vocabulary from the prototype palette / mesh kit.
const COLORS := {"cyan":Color("9bd8df"),"amber":Color("edc184"),"ivory":Color("e0d5b9"),"red":Color("a16459"),"dust":Color("b2aa96"),"hit":Color("f7e8c6")}
static var meshes := {}
static var materials := {}
static func group(parent: Node3D,label: String,at := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.position = at
	return node
static func part(parent: Node3D,kind: String,size: Vector3,at: Vector3,color: String) -> MeshInstance3D:
	if not meshes.has(kind):
		if kind == "ring":
			var shape := TorusMesh.new()
			shape.inner_radius = 0.44
			shape.outer_radius = 0.5
			shape.rings = 24
			shape.ring_segments = 4
			meshes[kind] = shape
		else:
			var shape := CylinderMesh.new()
			shape.height = 1
			shape.bottom_radius = 0.5
			shape.top_radius = 0.33
			shape.radial_segments = 5
			meshes[kind] = shape
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLORS[color]
		mat.roughness = 0.98
		if color in ["cyan","amber","hit"]:
			mat.emission_enabled = true
			mat.emission = COLORS[color]
			mat.emission_energy_multiplier = 0.25
		materials[color] = mat
	var node := MeshInstance3D.new()
	node.mesh = meshes[kind]
	node.material_override = materials[color]
	parent.add_child(node)
	node.position = at
	node.scale = size
	return node

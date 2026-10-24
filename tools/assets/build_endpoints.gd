extends SceneTree
## Bake editable endpoint scenes, adapted from the prototype's endpoint/kit models.
## godot --headless --path . --script tools/assets/build_endpoints.gd

const COLORS := {
	"stone": "a6aca9", "stone_light": "cec8b2", "cliff": "7d8991",
	"wood_dark": "594c43", "brass": "aa9469", "red": "a16459",
	"blue": "58758f", "ivory": "e0d5b9", "iron": "465361",
	"amber": "edc184", "cyan": "9bd8df"
}
var materials: Dictionary = {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/models/endpoints")
	for is_goal in [false, true]:
		var model := build_endpoint(is_goal)
		set_owners(model, model)
		var scene := PackedScene.new()
		var error := scene.pack(model)
		if error == OK:
			error = ResourceSaver.save(scene, "res://assets/models/endpoints/%s.tscn" % ("goal" if is_goal else "start"))
		model.free()
		if error != OK:
			push_error(error_string(error))
			quit(1)
			return
	print("Saved start and goal endpoint models.")
	quit()

func material(key: String) -> StandardMaterial3D:
	if not materials.has(key):
		var result := StandardMaterial3D.new()
		result.resource_name = key
		result.albedo_color = Color(COLORS[key])
		result.roughness = 0.98
		result.metallic_specular = 0.12
		if key in ["cyan", "amber"]:
			result.emission_enabled = true
			result.emission = result.albedo_color
			result.emission_energy_multiplier = 0.25
		materials[key] = result
	return materials[key]

func part(parent: Node3D, kind: String, dimensions: Vector3, at: Vector3, color: String) -> MeshInstance3D:
	var mesh: PrimitiveMesh
	if kind == "box":
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mesh = box
	else:
		var cylinder := CylinderMesh.new()
		cylinder.height = 1.0
		cylinder.bottom_radius = 0.5
		cylinder.top_radius = 0.0 if kind == "cone" else 0.5
		cylinder.radial_segments = 5 if kind in ["cone", "crystal"] else 10
		cylinder.rings = 1
		mesh = cylinder
	mesh.material = material(color)
	var node := MeshInstance3D.new()
	node.name = kind.capitalize() + color.capitalize()
	node.mesh = preload("res://tools/assets/solid_mesh_baker.gd").mesh(mesh) if preload("res://tools/assets/solid_mesh_baker.gd").supports(mesh.material) else mesh
	node.scale = dimensions
	node.position = at
	parent.add_child(node, true)
	return node

func banner(parent: Node3D, at: Vector3, enemy: bool, height: float) -> void:
	part(parent, "box", Vector3(0.035, height, 0.035), at + Vector3(0, height * 0.5, 0), "wood_dark")
	part(parent, "box", Vector3(0.30, 0.025, 0.025), at + Vector3(0.13, height - 0.06, 0), "brass")
	part(parent, "box", Vector3(0.23, height * 0.42, 0.018), at + Vector3(0.13, height * 0.72, 0), "red" if enemy else "blue")
	part(parent, "box", Vector3(0.034, height * 0.35, 0.022), at + Vector3(0.13, height * 0.74, -0.01), "brass" if enemy else "ivory")

func build_endpoint(is_goal: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Goal" if is_goal else "Start"
	part(root, "box", Vector3(0.96, 0.12, 0.96), Vector3(0, 0.06, 0), "cliff")
	part(root, "box", Vector3(0.9216, 0.07, 0.9216), Vector3(0, 0.155, 0), "stone_light")
	if is_goal:
		for x in [-0.37, 0.37]:
			part(root, "box", Vector3(0.16, 0.32, 0.72), Vector3(x, 0.31, 0.02), "stone")
			part(root, "box", Vector3(0.20, 0.06, 0.78), Vector3(x, 0.49, 0.02), "stone_light")
		part(root, "cylinder", Vector3(0.52, 0.18, 0.52), Vector3(0, 0.28, 0), "brass")
		var size := Vector3(0.35, 0.60, 0.35)
		var at := Vector3(0, 0.68, 0)
		part(root, "crystal", size * Vector3(1, 0.6, 1), at, "cyan")
		part(root, "cone", size * Vector3(1, 0.55, 1), at + Vector3(0, size.y * 0.55, 0), "cyan")
		part(root, "cone", size * Vector3(1, 0.3, 1), at - Vector3(0, size.y * 0.43, 0), "cyan").rotation.x = PI
		banner(root, Vector3(-0.38, 0.44, 0.29), false, 0.52)
		banner(root, Vector3(0.29, 0.44, 0.29), false, 0.52)
		for i in 2:
			part(root, "box", Vector3(0.42, 0.07, 0.15), Vector3(0, 0.04 + i * 0.06, -0.51 + i * 0.12), "stone_light")
	else:
		banner(root, Vector3(-0.12, 0.17, 0.26), true, 0.86)
		for x in [-0.34, 0.34]:
			var at := Vector3(x, 0.18, -0.28)
			part(root, "box", Vector3(0.055, 0.32, 0.055), at + Vector3(0, 0.16, 0), "wood_dark")
			part(root, "cylinder", Vector3(0.12, 0.08, 0.12), at + Vector3(0, 0.33, 0), "iron")
			part(root, "cone", Vector3(0.11, 0.19, 0.11), at + Vector3(0, 0.43, 0), "amber")
			part(root, "cone", Vector3(0.025, 0.05, 0.025), at + Vector3(0.03, 0.59, 0), "amber")
		part(root, "box", Vector3(0.65, 0.06, 0.23), Vector3(0, 0.20, 0.29), "wood_dark")
	return root

func set_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		set_owners(child, root)

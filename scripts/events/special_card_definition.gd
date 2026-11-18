@tool
class_name SpecialCardDefinition
extends Resource
enum Kind { ROAD, TILE, CONSUMABLE }
@export var id: StringName
@export var kind := Kind.TILE
@export var cells: Array[Vector2i] = [Vector2i.ZERO]
@export var accent_color := Color("799d99")
@export var icon: Texture2D
@export var model: PackedScene
@export_group("Placement Effects")
@export var damage_bonus := 0.0
@export var wave_gold := 0
@export_range(0.0,1.0,0.01) var incomplete_damage_multiplier := 1.0

func localized_name() -> String:
	return tr("event.card.%s.name" % id)

func configuration_error() -> String:
	if id.is_empty() or (kind != Kind.CONSUMABLE and cells.is_empty()): return "Invalid special card"
	return ""

func create_visual() -> Node3D:
	var root := Node3D.new()
	if model != null:
		root.add_child(model.instantiate())
		return root
	if kind in [Kind.ROAD,Kind.CONSUMABLE]: return root
	for cell in cells:
		var mesh := MeshInstance3D.new()
		if id in [&"large_gem", &"small_gem"]:
			var gem := PrismMesh.new()
			gem.size = Vector3(0.62, 0.65, 0.62)
			mesh.mesh = gem
		else:
			var stone := BoxMesh.new()
			stone.size = Vector3(0.72, 0.3, 0.64)
			mesh.mesh = stone
		var material := StandardMaterial3D.new()
		material.albedo_color = accent_color
		material.roughness = 0.85
		mesh.material_override = material
		mesh.position = Vector3(cell.x, 0.25, cell.y)
		root.add_child(mesh)
	return root

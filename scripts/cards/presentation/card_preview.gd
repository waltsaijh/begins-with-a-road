extends Node3D
## Placement and attack tiles share the definition used by real combat/threat.
@export var valid_color := Color(0.35, 0.93, 0.75, 0.52)
@export var invalid_color := Color(1.0, 0.3, 0.22, 0.56)
@export var range_fill_color := Color(0.96, 0.68, 0.21, 0.18)
@export var range_border_color := Color(0.85, 0.53, 0.12, 0.5)
@onready var ground: MeshInstance3D = $Ground
@onready var attack_area: MeshInstance3D = $AttackArea
var range_cells: Array[Vector2i] = []
var ghost: Node3D
var _definition: TowerDefinition
var _material: StandardMaterial3D
var hint_anchor := Vector3.ZERO

func _ready() -> void:
	_material = ground.material_override.duplicate()
	ground.material_override = _material

func show_at(map: GridMap, card: BuildCard, cell: Vector3i, turns: int, valid: bool) -> void:
	visible = true
	global_transform = map.global_transform
	_material.albedo_color = valid_color if valid else invalid_color
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for pos in card.ground_cells(Vector2i(cell.x, cell.z), turns):
		var center := map.map_to_local(Vector3i(pos.x, 0, pos.y))+Vector3.UP*0.05
		for corner in [Vector3(-0.45,0,-0.45), Vector3(0.45,0,-0.45), Vector3(0.45,0,0.45), Vector3(-0.45,0,-0.45), Vector3(0.45,0,0.45), Vector3(-0.45,0,0.45)]:
			mesh.surface_add_vertex(center+corner)
	mesh.surface_end()
	ground.mesh = mesh
	_show_attack_area(map, card.tower, cell, turns)
	if _definition != card.tower:
		if ghost != null:
			ghost.free()
		_definition = card.tower
		ghost = null
		if _definition != null and _definition.model != null:
			ghost = _definition.model.instantiate()
			add_child(ghost)
			_tint(ghost)
	if ghost != null:
		ghost.transform = Transform3D(Basis(Vector3.UP, -turns*PI/2), map.map_to_local(cell)+Vector3.UP*TowerConstants.GROUND_OFFSET)
	hint_anchor = map.to_global(map.map_to_local(cell))
	if ghost != null:
		hint_anchor.y = _top_height(ghost, hint_anchor.y)
	hint_anchor += Vector3.UP*0.12

func _show_attack_area(map: GridMap, definition: TowerDefinition, cell: Vector3i, turns: int) -> void:
	range_cells = definition.attack_cells_at(Vector2i(cell.x, cell.z), turns)
	var mesh := ImmediateMesh.new()
	if not range_cells.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for at in range_cells:
			var center := map.map_to_local(Vector3i(at.x, 0, at.y))+Vector3.UP*0.035
			_range_quad(mesh, center, -0.43, -0.43, 0.43, 0.43, range_fill_color)
			_range_quad(mesh, center, -0.46, -0.46, 0.46, -0.43, range_border_color)
			_range_quad(mesh, center, -0.46, 0.43, 0.46, 0.46, range_border_color)
			_range_quad(mesh, center, -0.46, -0.43, -0.43, 0.43, range_border_color)
			_range_quad(mesh, center, 0.43, -0.43, 0.46, 0.43, range_border_color)
		mesh.surface_end()
	attack_area.mesh = mesh

func _range_quad(mesh: ImmediateMesh, center: Vector3, left: float, top: float, right: float, bottom: float, color: Color) -> void:
	mesh.surface_set_color(color)
	for point in [Vector3(left, 0, top), Vector3(right, 0, top), Vector3(right, 0, bottom), Vector3(left, 0, top), Vector3(right, 0, bottom), Vector3(left, 0, bottom)]:
		mesh.surface_add_vertex(center+point)

func _top_height(node: Node, height: float) -> float:
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.get_aabb()
		for i in 8:
			height = maxf(height, (node.global_transform*bounds.get_endpoint(i)).y)
	for child in node.get_children():
		height = _top_height(child, height)
	return height

func _tint(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = _material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_tint(child)

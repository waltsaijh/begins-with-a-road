extends Node3D
## One flat footprint mesh plus the shared tower model. No physics or map edits.
var ground := MeshInstance3D.new()
var ghost: Node3D
var _definition: TowerDefinition
var _material := StandardMaterial3D.new()
var hint_anchor := Vector3.ZERO

func _ready() -> void:
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = _material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	visible = false

func show_at(map: GridMap, card: BuildCard, cell: Vector3i, turns: int, valid: bool) -> void:
	visible = true
	global_transform = map.global_transform
	_material.albedo_color = Color(0.35, 0.93, 0.75, 0.52) if valid else Color(1.0, 0.3, 0.22, 0.56)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for pos in card.ground_cells(Vector2i(cell.x, cell.z), turns):
		var center := map.map_to_local(Vector3i(pos.x, 0, pos.y))+Vector3.UP*0.05
		for corner in [Vector3(-0.45,0,-0.45), Vector3(0.45,0,-0.45), Vector3(0.45,0,0.45), Vector3(-0.45,0,-0.45), Vector3(0.45,0,0.45), Vector3(-0.45,0,0.45)]:
			mesh.surface_add_vertex(center+corner)
	mesh.surface_end()
	ground.mesh = mesh
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

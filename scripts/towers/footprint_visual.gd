extends RefCounted
const BODY_HEIGHT := 1.0
const ANCHOR_HEIGHT := 0.06

static func create(cells: Array[Vector2i], anchor: Vector2i, turns: int, material: Material) -> Node3D:
	var result := Node3D.new()
	result.name = "FootprintBody"
	for cell in cells:
		var block := MeshInstance3D.new()
		var box := BoxMesh.new()
		var height := ANCHOR_HEIGHT if cell == anchor else BODY_HEIGHT
		box.size = Vector3(0.94,height,0.94)
		block.mesh = box; block.material_override = material
		var offset := BuildCard.rotate_cell(cell-anchor,-turns)
		block.position = Vector3(offset.x,height/2.0,offset.y)
		result.add_child(block)
	return result

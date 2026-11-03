extends RefCounted
## Prospective and committed compound roads use the same reciprocal port contract.
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")

static func build(map: GridMap, ground: Dictionary, requested: Dictionary, stored: Dictionary, blocked: Dictionary) -> Dictionary:
	var original := Snapshot.capture(map)
	var masks := {}
	for i in original.ports.size():
		masks[Vector2i(original.cells[2*i], original.cells[2*i+1])] = int(original.ports[i])
	var allowed := stored.duplicate()
	var affected := {}
	for cell: Vector2i in ground:
		if not masks.has(cell): masks[cell] = 0
		affected[cell] = true
		for direction: Vector3i in TileConstants.DIRECTIONS:
			affected[cell+Vector2i(direction.x,direction.z)] = true
	for cell: Vector2i in requested:
		# Overlay joins explicitly requested ports to existing roads. Neighboring
		# parallel roads do not acquire side exits merely because they touch.
		allowed[cell] = int(allowed.get(cell,masks.get(cell,0))) | int(requested[cell])
	for cell: Vector2i in affected:
		if not masks.has(cell): continue
		if blocked.has(cell) and not ground.has(cell): continue
		var mask := 0
		for d in 4:
			var direction: Vector3i = TileConstants.DIRECTIONS[d]
			var neighbor := cell+Vector2i(direction.x,direction.z)
			if masks.has(neighbor) and int(allowed.get(cell,15)) & (1<<d) and int(allowed.get(neighbor,15)) & (1<<((d+2)%4)):
				mask |= 1<<d
		masks[cell] = mask
	# Foundations retain their authored road record for tower removal, but no
	# traversable neighbor is allowed to advertise an exit into an obstacle.
	for cell: Vector2i in masks:
		if blocked.has(cell): continue
		for d in 4:
			var direction: Vector3i = TileConstants.DIRECTIONS[d]
			if blocked.has(cell+Vector2i(direction.x,direction.z)):
				masks[cell] = int(masks[cell]) & ~(1<<d)
	var cells := PackedInt32Array()
	var ports := PackedByteArray()
	for cell: Vector2i in masks:
		if blocked.has(cell): continue
		cells.append_array(PackedInt32Array([cell.x,cell.y]))
		ports.append(masks[cell])
	return {"masks":masks,"allowed":allowed,"snapshot":{"cells":cells,"ports":ports}}

static func apply(placement: Node, layout: Dictionary) -> Array[Vector3i]:
	var added: Array[Vector3i] = []
	placement.port_overrides = layout.allowed.duplicate()
	for pos: Vector2i in layout.masks:
		var cell := Vector3i(pos.x,0,pos.y)
		var original: int = placement.map.get_cell_item(cell)
		if original == GridMap.INVALID_CELL_ITEM: added.append(cell)
		var tile: Vector2i = placement.tile_for_mask(layout.masks[pos])
		var appearance := TileConstants.appearance_of(original) if original > 0 else TileConstants.Appearance.STONE
		var item := TileConstants.item_for(tile.x,appearance)
		if item != original or placement.map.get_cell_item_orientation(cell) != tile.y:
			placement.map.set_cell_item(cell,item,tile.y)
	return added

extends RefCounted
## Pack tile coordinates and rendered ports once; native code finds adjacency.

static func capture(map: GridMap, blocked_cells: Dictionary = {}, additions: Dictionary = {}) -> Dictionary:
	# A prospective batch must match TilePlacement's local port refresh exactly.
	# Never change the real GridMap to validate a construction preview.
	if not additions.is_empty():
		var original := capture(map)
		var ground := {}
		for i in original.ports.size():
			ground[Vector2i(original.cells[i*2], original.cells[i*2+1])] = int(original.ports[i])
		var affected := {}
		for cell: Vector2i in additions:
			if ground.has(cell):
				continue
			ground[cell] = 0
			affected[cell] = true
			for direction in TileConstants.DIRECTIONS:
				affected[cell + Vector2i(direction.x, direction.z)] = true
		for cell: Vector2i in affected:
			if not ground.has(cell):
				continue
			var mask := 0
			for d in 4:
				var direction: Vector3i = TileConstants.DIRECTIONS[d]
				if ground.has(cell + Vector2i(direction.x, direction.z)):
					mask |= 1 << d
			ground[cell] = mask
		var packed_cells := PackedInt32Array()
		var packed_ports := PackedByteArray()
		for cell: Vector2i in ground:
			if not blocked_cells.has(cell):
				packed_cells.append(cell.x)
				packed_cells.append(cell.y)
				packed_ports.append(ground[cell])
		return {"cells": packed_cells, "ports": packed_ports}
	var used: Array[Vector3i] = []
	for cell in map.get_used_cells():
		if cell.y == 0 and map.get_cell_item(cell) > 0 and not blocked_cells.has(Vector2i(cell.x, cell.z)):
			used.append(cell)
	var cells := PackedInt32Array()
	var ports := PackedByteArray()
	cells.resize(used.size()*2)
	ports.resize(used.size())
	var rotations := {}
	for i in used.size():
		var cell := used[i]
		var item := TileConstants.base_item(map.get_cell_item(cell))
		var key := item*24 + map.get_cell_item_orientation(cell)
		if not rotations.has(key):
			var mask := 0
			var basis := map.get_cell_item_basis(cell)
			if item < TileConstants.BASE_MASKS.size():
				for d in 4:
					if TileConstants.BASE_MASKS[item] & (1 << d):
						var offset := Vector3i((basis*Vector3(TileConstants.DIRECTIONS[d])).round())
						var direction: int = TileConstants.DIRECTIONS.find(offset)
						if direction >= 0:
							mask |= 1 << direction
			rotations[key] = mask
		cells[i*2] = cell.x
		cells[i*2+1] = cell.z
		ports[i] = rotations[key]
	return {"cells": cells, "ports": ports}

## One reverse flood fill verifies every origin against the proposed obstacles.
## Reciprocal ports are required, exactly as in native graph construction.
static func connects_terminals(snapshot: Dictionary, terminals: Array[Vector2i]) -> bool:
	if terminals.is_empty():
		return false
	var ports_at := {}
	for i in snapshot.ports.size():
		ports_at[Vector2i(snapshot.cells[i*2], snapshot.cells[i*2+1])] = snapshot.ports[i]
	for cell in terminals:
		if not ports_at.has(cell):
			return false
	var visited := {terminals[0]: true}
	var queue: Array[Vector2i] = [terminals[0]]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var mask: int = ports_at[cell]
		for d in 4:
			if not mask & (1 << d):
				continue
			var offset: Vector3i = TileConstants.DIRECTIONS[d]
			var next := cell + Vector2i(offset.x, offset.z)
			if not visited.has(next) and ports_at.get(next, 0) & (1 << ((d+2)%4)):
				visited[next] = true
				queue.append(next)
	for cell in terminals:
		if not visited.has(cell):
			return false
	return true

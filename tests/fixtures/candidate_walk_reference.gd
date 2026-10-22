extends RefCounted
## Test-only scalar reference for the native candidate pipeline.
## Dense tile indices keep loop erasure linear in the sampled walk length.

static func normalize(route: Dictionary, tiles: PackedVector2Array, tile_indices: Dictionary, node_at: PackedInt32Array, segment_ids: Dictionary) -> Dictionary:
	var original: PackedVector2Array = route.cells
	if original.is_empty(): return {"valid": false, "error": "候選路線沒有地塊"}
	var indices := PackedInt32Array()
	indices.resize(original.size())
	var seen := {}
	var count := 0
	for cell: Vector2 in original:
		var index: int = tile_indices.get(Vector2i(cell), -1)
		if index < 0: return {"valid": false, "error": "候選路線包含未知地塊"}
		var previous: int = seen.get(index, -1)
		if previous >= 0:
			# Each pushed index is popped at most once over the whole walk.
			while count > previous+1:
				count -= 1
				seen.erase(indices[count])
		else:
			seen[index] = count
			indices[count] = index
			count += 1
	indices.resize(count)
	var cells := PackedVector2Array()
	cells.resize(count)
	var nodes := PackedInt32Array()
	var edges := PackedInt32Array()
	var ranges: Array[Vector2i] = []
	var begin := -1
	for i in count:
		cells[i] = tiles[indices[i]]
		var node: int = node_at[indices[i]]
		if node < 0: continue
		nodes.append(node)
		if begin >= 0:
			var span := indices.slice(begin, i+1)
			# A splice can span several former native edges. Identify the actual
			# retained walk instead of attaching an unrelated native edge ID.
			if not segment_ids.has(span): segment_ids[span] = segment_ids.size()
			edges.append(segment_ids[span])
			ranges.append(Vector2i(begin, i))
		begin = i
	if node_at[indices[0]] < 0 or node_at[indices[-1]] < 0:
		return {"valid": false, "error": "候選路線起終點不是入口節點"}
	var erased_steps := original.size()-count
	route.cells = cells
	route.nodes = nodes
	route.edges = edges
	route.length = count-1
	# Exploration scores belong to the untrimmed native guide. The caller
	# computes raw evaluation, best score and distribution after normalization.
	route.erase("score")
	route.erase("best_score")
	return {"valid": true, "route": route, "indices": indices, "ranges": ranges, "erased_steps": erased_steps}

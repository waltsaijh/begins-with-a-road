extends RefCounted
## One immutable world-space walk per distinct route in this wave build.
## A fresh cache captures the current map transform; no cross-wave invalidation.
static func for_route(route: Dictionary, map: GridMap, cache: Dictionary, flight_height := 0.0) -> PackedVector3Array:
	var cells: PackedVector2Array = route.cells
	var key := [cells, flight_height]
	if not cache.has(key):
		var points := PackedVector3Array()
		points.resize(cells.size())
		for i in cells.size():
			var cell := Vector2i(cells[i])
			points[i] = map.to_global(map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*(EnemyConstants.GROUND_OFFSET+flight_height*map.cell_size.y))
		cache[key] = points
	return cache[key]
